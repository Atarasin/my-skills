"""Assemble a page into a self-contained single HTML file (offline, no CDN).

Inlines the locally compiled Tailwind CSS and the bundled Alpine.js so the output
works with zero network access.

用法：
    SRC_HTML=/abs/path/src.html 是给 tailwind 用的；
    本脚本直接收三个路径参数：

    python build.py <src.html> <out.css> <out.html>

    # 完整流程（示例）
    NODE_MODULES=<托管 node workspace>/node_modules
    SRC_HTML=$PWD/src.html node "$NODE_MODULES/tailwindcss/lib/cli.js" \
        -c tailwind.config.js -i input.css -o out.css --minify
    python build.py src.html out.css ../../.doc-visualizer-output/2026-01-01_主题.html
"""
from __future__ import annotations

import sys
from pathlib import Path

NODE_MODULES = Path(
    "C:/Users/Atarasin/.workbuddy/binaries/node/workspace/node_modules"
)
ALPINE = NODE_MODULES / "alpinejs" / "dist" / "cdn.min.js"

CSS_PLACEHOLDER = "/*__TAILWIND_CSS__*/"
JS_PLACEHOLDER = "/*__ALPINE_JS__*/"


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    src_path, css_path, out_path = (Path(p) for p in sys.argv[1:4])

    src = src_path.read_text(encoding="utf-8")
    css = css_path.read_text(encoding="utf-8")
    alpine = ALPINE.read_text(encoding="utf-8")

    # 1) 结构自查：分段写入被截断时，文件不会以 </html> 结尾
    if not src.rstrip().endswith("</html>"):
        print("FAIL: src.html 未以 </html> 结尾（疑为写入被截断，检查分段拼接）")
        return 1

    # 2) 占位符必须存在（否则内联静默失效）
    for placeholder in (CSS_PLACEHOLDER, JS_PLACEHOLDER):
        if placeholder not in src:
            print(f"FAIL: src.html 缺少占位符 {placeholder}")
            return 1

    # 3) 内联目标不得自带闭合标签（会提前闭合 <style>/<script>，页面直接崩）
    if "</style>" in css:
        print("FAIL: out.css 含 </style>")
        return 1
    if "</script>" in alpine:
        print("FAIL: alpine 包含 </script>")
        return 1

    html = src.replace(CSS_PLACEHOLDER, css).replace(JS_PLACEHOLDER, alpine)

    # 4) 内联成功的唯一硬证据：无任何运行时 CDN 残留
    for needle in ("cdn.tailwindcss.com", "cdn.jsdelivr.net", "mermaid"):
        if needle in html:
            print(f"FAIL: 运行时依赖残留 {needle}")
            return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(html, encoding="utf-8")

    # 5) 顺带报告标签数（应与 verify.js 的 TABS 一致）
    tabs = html.count("x-show=\"tab===")
    size = out_path.stat().st_size
    print(f"OK  {out_path}  {size:,} bytes  tabs={tabs}")
    if size < 30_000:
        print("WARN: 产物偏小（<30KB），内联可能没生效")
    return 0


if __name__ == "__main__":
    sys.exit(main())
