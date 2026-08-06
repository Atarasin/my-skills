#!/usr/bin/env bash
# 跑一轮 codex 外部方案评审。
# 组装提示词 → 调 codex exec（结构化输出）→ 校验 JSON → 打印摘要。
# 一次只跑一轮；多轮由调用方（skill）驱动，因为轮次之间需要人/智能体做核实与处置。
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
用法:
  codex_review.sh --plan <方案文件> [选项]

必需:
  --plan <path>        方案文档路径（markdown）。方案必须已落盘，codex 要读它。

选项:
  --round <N>          轮次，默认 1。N>=2 时必须给 --prior。
  --prior <path>       上一轮的处置记录（disposition markdown）。轮次 >=2 时必需。
  --mode repo|text     repo=给 codex 只读仓库权限（默认，能核对方案与代码是否对得上）
                       text=只喂方案正文，不给仓库访问（快，但抓不到 repo-mismatch）
  --repo <dir>         仓库根，默认由方案路径向上找 git 根
  --out <dir>          产物目录，默认 <方案目录>/review/<方案文件名去后缀>/
  --focus "<文本>"      追加的关注点，例如"重点看数据口径"
  --context <path>     额外让 codex 先读的文件，可重复。默认自动带上仓库的 AGENTS.md/CLAUDE.md
  --effort <level>     codex 推理强度 low|medium|high|xhigh，默认 xhigh
  --timeout <秒>       默认 1800
  --dry-run            只生成提示词，不调用 codex

产物:
  <out>/round<N>-prompt.md    实际发给 codex 的提示词
  <out>/round<N>-review.json  结构化评审结果
  <out>/round<N>-codex.log    codex 运行日志
EOF
}

PLAN=""; ROUND=1; PRIOR=""; MODE="repo"; REPO=""; OUT=""; FOCUS=""
EFFORT="xhigh"; TIMEOUT=1800; DRY_RUN=0
CONTEXT_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) PLAN="${2:-}"; shift 2 ;;
    --round) ROUND="${2:-}"; shift 2 ;;
    --prior) PRIOR="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --focus) FOCUS="${2:-}"; shift 2 ;;
    --context) CONTEXT_FILES+=("${2:-}"); shift 2 ;;
    --effort) EFFORT="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 64 ;;
  esac
done

die() { echo "错误: $*" >&2; exit 1; }

[[ -n "$PLAN" ]] || { usage >&2; die "缺少 --plan"; }
[[ -f "$PLAN" ]] || die "方案文件不存在: $PLAN"
[[ "$ROUND" =~ ^[1-9][0-9]*$ ]] || die "--round 必须是正整数"
[[ "$MODE" == "repo" || "$MODE" == "text" ]] || die "--mode 只能是 repo 或 text"
command -v codex >/dev/null || die "找不到 codex 命令"

if (( ROUND > 3 )); then
  die "轮次上限是 3。第 3 轮之后仍未收敛说明方案存在需要人判断的根本分歧，应该找用户拍板，而不是继续刷评审。"
fi

PLAN="$(cd "$(dirname "$PLAN")" && pwd)/$(basename "$PLAN")"
PLAN_DIR="$(dirname "$PLAN")"
PLAN_STEM="$(basename "${PLAN%.*}")"

if [[ -z "$REPO" ]]; then
  REPO="$(git -C "$PLAN_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PLAN_DIR")"
fi
[[ -d "$REPO" ]] || die "仓库目录不存在: $REPO"

[[ -n "$OUT" ]] || OUT="$PLAN_DIR/review/$PLAN_STEM"
mkdir -p "$OUT" || die "无法创建产物目录: $OUT"

if (( ROUND >= 2 )); then
  [[ -n "$PRIOR" ]] || die "第 $ROUND 轮必须用 --prior 提供上一轮的处置记录，否则 codex 会重复上一轮的意见"
  [[ -f "$PRIOR" ]] || die "处置记录不存在: $PRIOR"
fi

PROMPT="$OUT/round${ROUND}-prompt.md"
RESULT="$OUT/round${ROUND}-review.json"
LOG="$OUT/round${ROUND}-codex.log"
SCHEMA="$SKILL_DIR/scripts/review_schema.json"
[[ -f "$SCHEMA" ]] || die "找不到 schema: $SCHEMA"

# ---------- 组装提示词 ----------
{
  cat "$SKILL_DIR/references/reviewer-prompt.md"
  echo
  if (( ROUND >= 2 )); then
    sed "s/第 N 轮复评/第 $ROUND 轮复评/" "$SKILL_DIR/references/reviewer-prompt-followup.md"
    echo
  fi

  echo "---"
  echo
  echo "## 本次评审的对象"
  echo
  echo "- 轮次：第 $ROUND 轮（硬上限 3 轮）"
  echo "- 方案文件：\`$PLAN\`"
  if [[ "$MODE" == "repo" ]]; then
    echo "- 仓库根：\`$REPO\`（你有**只读**权限，可以自由 grep/读文件来核实方案与代码是否对得上）"
  else
    echo "- 无仓库访问权限。方案正文见文末。凡是需要读代码才能确认的疑虑，一律放 \`unverifiable\`，不要报成 finding。"
  fi
  [[ -n "$FOCUS" ]] && { echo "- 用户额外指定的关注点：$FOCUS"; }
  echo

  if [[ "$MODE" == "repo" ]]; then
    echo "### 先读这些"
    echo
    echo "1. 方案全文：\`$PLAN\`"
    local_ctx=()
    if (( ${#CONTEXT_FILES[@]} )); then
      local_ctx=("${CONTEXT_FILES[@]}")
    else
      for f in "$REPO/AGENTS.md" "$REPO/CLAUDE.md"; do
        [[ -f "$f" ]] && local_ctx+=("$f")
      done
    fi
    n=2
    for f in "${local_ctx[@]-}"; do
      [[ -n "$f" ]] || continue
      echo "$n. 仓库既有约定：\`$f\`（方案违反这里的硬性规则属于 P0/P1 的 repo-mismatch）"
      n=$((n+1))
    done
    echo
    echo "然后针对方案里出现的每一个具体路径 / 符号名 / 命令 / 数字基线，实际去仓库里核对。"
  fi
  echo

  if (( ROUND >= 2 )); then
    echo "---"
    echo
    echo "## 上一轮意见与作者处置"
    echo
    cat "$PRIOR"
    echo
  fi

  if [[ "$MODE" == "text" ]]; then
    echo "---"
    echo
    echo "## 方案全文"
    echo
    cat "$PLAN"
    echo
  fi
} > "$PROMPT" || die "写提示词失败"

echo "提示词已生成: $PROMPT"

if (( DRY_RUN )); then
  echo "(--dry-run，未调用 codex)"
  exit 0
fi

# ---------- 调用 codex ----------
CODEX_ARGS=(exec -s read-only --output-schema "$SCHEMA" -o "$RESULT"
            -c "model_reasoning_effort=\"$EFFORT\"")
if [[ "$MODE" == "repo" ]]; then
  CODEX_ARGS+=(-C "$REPO" --skip-git-repo-check)
else
  CODEX_ARGS+=(-C "$OUT" --skip-git-repo-check)
fi

echo "调用 codex（mode=$MODE, effort=$EFFORT, timeout=${TIMEOUT}s）… repo 模式实测 9-11 分钟，text 模式约 1 分钟。"
echo "盯进度: tail -f $LOG"
rm -f "$RESULT"
start_ts=$SECONDS
timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" - < "$PROMPT" > "$LOG" 2>&1
rc=$?
elapsed=$((SECONDS - start_ts))

if (( rc == 124 )); then
  die "codex 超时（${TIMEOUT}s）。日志: $LOG。可以加大 --timeout，或改用 --mode text / --effort medium。"
fi
if (( rc != 0 )); then
  echo "--- codex 日志末尾 ---" >&2
  tail -30 "$LOG" >&2
  die "codex 退出码 $rc。完整日志: $LOG"
fi
if [[ ! -s "$RESULT" ]]; then
  echo "--- codex 日志末尾 ---" >&2
  tail -30 "$LOG" >&2
  die "codex 未产出结果文件 $RESULT"
fi

# ---------- 校验 + 摘要 ----------
python3 - "$RESULT" "$ROUND" "$elapsed" <<'PY'
import json, sys

path, rnd, elapsed = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print(f"错误: 结果不是合法 JSON（{exc}）。原始输出仍在 {path}，请直接阅读。", file=sys.stderr)
    sys.exit(2)

findings = data.get("findings") or []
prior = data.get("prior_round_status") or []
unver = data.get("unverifiable") or []

order = {"P0": 0, "P1": 1, "P2": 2}
findings.sort(key=lambda f: order.get(f.get("severity"), 9))

print(f"\n=== 第 {rnd} 轮评审结果（{elapsed}s） ===")
print(f"总体判断: {data.get('overall', '').strip()}\n")

if prior:
    print("上一轮意见复核:")
    for p in prior:
        print(f"  [{p.get('status'):<10}] {p.get('id')}  {p.get('note', '').strip()}")
    print()

counts = {}
for f in findings:
    counts[f.get("severity")] = counts.get(f.get("severity"), 0) + 1
new_n = sum(1 for f in findings if f.get("is_new"))
tally = " ".join(f"{k}×{counts[k]}" for k in ("P0", "P1", "P2") if k in counts) or "无"
print(f"本轮 findings: {len(findings)} 条（{tally}），其中新增 {new_n} 条")
for f in findings:
    flag = "新增" if f.get("is_new") else f"重申←{f.get('relates_to') or '?'}"
    print(f"  {f.get('id')} [{f.get('severity')}][{f.get('kind')}][{flag}] {f.get('title')}")

if unver:
    print(f"\ncodex 自述未核实事项 {len(unver)} 条（这些不是 finding，但值得你自己去确认）:")
    for u in unver:
        print(f"  - {u}")

print(f"\n完整结果: {path}")
if not findings:
    print("→ findings 为空：本轮无实质问题，可以终止评审循环。")
else:
    print("→ 下一步：逐条到仓库核实，判定 成立/不成立/无法核实，再决定采纳或驳回。禁止未经核实直接采纳。")
PY
exit $?
