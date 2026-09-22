#Requires -Version 5.1
<#
.SYNOPSIS
    管理本仓库 skills 到多个目标目录的目录链接（优先符号链接，无权限时自动回退 Junction）。

.DESCRIPTION
    扫描仓库中包含 SKILL.md 的顶层目录作为 skill，与每个目标目录（如 C:\Users\<user>\.agents\skills、
    C:\Users\<user>\.claude\skills）中的同名条目比对，展示每个 skill 在各目标目录下的链接状态与链接路径，并支持：
      - 添加 / 解除链接（可多选或全部；多目标目录时可先选择作用于哪几个目录）
      - 添加 / 移除目标目录，或将目标目录覆盖式设置为唯一目录（数量不限）
      - 清理目标目录中指向本仓库、但仓库里已不存在的失效链接

    目标目录列表保存在仓库根的 .skill-link.json（已加入 .gitignore）：
        { "targetDirs": [ "C:\\Users\\me\\.agents\\skills", "C:\\Users\\me\\.claude\\skills" ] }
    旧版单目录配置 { "targetDir": "..." } 会在读取时自动迁移为多目录格式，不会丢失原设置。
    首次运行若配置文件不存在且 ~\.agents\skills 存在，会自动使用该目录并写入配置文件。
    目标目录中不指向本仓库的条目（如手工安装的其他 skill）不会被脚本改动。

    操作默认作用于全部目标目录；用 -TargetDir 可把本次操作限定到指定目录（编号 / 路径 / 路径尾部片段）。
    -TargetDir / -AddTarget / -RemoveTarget 接受逗号分隔的多个值；token 优先按整体匹配，
    整体不匹配时才按逗号拆分，因此含逗号的真实路径不会被误拆。
    注意：Windows 创建符号链接需要管理员权限或开启"开发者模式"；
    权限不足时脚本会自动改用 Junction（目录联接），对本场景效果相同。

.EXAMPLE
    .\link-skills.ps1                      # 交互式菜单

.EXAMPLE
    .\link-skills.ps1 -List                # 查看所有目标目录的链接状态

.EXAMPLE
    .\link-skills.ps1 -AddTarget C:\Users\me\.claude\skills

.EXAMPLE
    .\link-skills.ps1 -AddTarget C:\Users\me\.claude\skills,C:\Users\me\.codex\skills

.EXAMPLE
    .\link-skills.ps1 -RemoveTarget 2      # 按编号移除（编号见 -List 输出）

.EXAMPLE
    .\link-skills.ps1 -RemoveTarget 3,4    # 一次移除多个

.EXAMPLE
    .\link-skills.ps1 -RemoveTarget all    # 清空目标目录列表（磁盘内容不动）

.EXAMPLE
    .\link-skills.ps1 -SetTarget C:\Users\me\.agents\skills   # 覆盖为唯一目标目录

.EXAMPLE
    .\link-skills.ps1 -Link all            # 向所有目标目录链接全部 skill

.EXAMPLE
    .\link-skills.ps1 -Link doc-visualizer,execute-plan -TargetDir 2

.EXAMPLE
    .\link-skills.ps1 -Link all -TargetDir .claude\skills,.codex\skills

.EXAMPLE
    .\link-skills.ps1 -Unlink all

.EXAMPLE
    .\link-skills.ps1 -Clean               # 清理所有目标目录中的失效链接
#>
[CmdletBinding()]
param(
    [switch]$List,
    [string]$SetTarget,         # 覆盖式设置：把目标目录列表替换为这一个目录
    [string[]]$AddTarget,       # 追加目标目录（可多个，逗号分隔）
    [string[]]$RemoveTarget,    # 移除目标目录（可多个：编号 / 路径 / 路径尾部片段）
    [string[]]$TargetDir,       # 限定 -Link / -Unlink / -Clean / -List 的作用目录（默认全部）
    [string[]]$Link,
    [string[]]$Unlink,
    [switch]$Clean,
    [switch]$Force              # 配合 -Link：目标处存在同名真实目录/异向链接时直接替换（不备份）
)

$ErrorActionPreference = 'Stop'

$RepoRoot      = $PSScriptRoot
$ConfigFile    = Join-Path $RepoRoot '.skill-link.json'
$BackupDir     = Join-Path $RepoRoot '.skill-link-backup'
$DefaultTarget = Join-Path $HOME '.agents\skills'

# ---------- 基础工具 ----------

function Get-NormalizedPath {
    param([string]$Path)
    if ($Path.StartsWith('\\?\')) { $Path = $Path.Substring(4) }
    try { return ([IO.Path]::GetFullPath($Path)).TrimEnd('\') } catch { return $Path.TrimEnd('\') }
}

# 把用户输入（可含 ~、引号、相对路径）解析为规范化的绝对路径
function Resolve-InputPath {
    param([string]$Path)
    $Path = $Path.Trim().Trim('"')
    if ($Path -eq '~') { $Path = $HOME }
    elseif ($Path.StartsWith('~')) { $Path = $HOME + $Path.Substring(1) }
    if (-not [IO.Path]::IsPathRooted($Path)) {
        $Path = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
    }
    return (Get-NormalizedPath $Path)
}

function Test-SameDir {
    param([string]$A, [string]$B)
    if (-not $A -or -not $B) { return $false }
    return ((Get-NormalizedPath $A).ToLowerInvariant() -eq (Get-NormalizedPath $B).ToLowerInvariant())
}

# ---------- 配置读写（.skill-link.json / targetDirs） ----------

function ConvertTo-ConfigEntries {
    param([string[]]$Dirs, [string]$Source = '配置文件 .skill-link.json')
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $out = @()
    foreach ($d in @($Dirs)) {
        if (-not $d) { continue }
        $n = Get-NormalizedPath $d
        if ($seen.Add($n)) { $out += [pscustomobject]@{ Dir = $n; Source = $Source } }
    }
    return @($out)
}

function Save-TargetConfig {
    param([string[]]$Paths)
    $norm = @()
    foreach ($p in @($Paths)) {
        if ($p -and "$p".Trim()) { $norm += (Get-NormalizedPath $p) }
    }
    $json = [pscustomobject]@{ targetDirs = @($norm) } | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $ConfigFile -Value $json -Encoding UTF8
}

# 返回 @( [pscustomobject]@{ Dir; Source } )；列表为空时返回 @()
function Get-TargetConfig {
    param([switch]$Quiet)
    $fileExists = Test-Path -LiteralPath $ConfigFile
    if ($fileExists) {
        try {
            $cfg = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Warning '.skill-link.json 解析失败，已忽略（不覆盖原文件）。'
            return @()
        }
        $names = @($cfg.PSObject.Properties | ForEach-Object { $_.Name })
        if ($names -contains 'targetDirs') {
            $dirs = @(@($cfg.targetDirs) | Where-Object { $_ -and ([string]$_).Trim() } |
                      ForEach-Object { Resolve-InputPath ([string]$_) })
            return @(ConvertTo-ConfigEntries $dirs)
        }
        if ($names -contains 'targetDir') {
            # 旧版单目录配置 → 迁移为多目录格式
            $dirs = @()
            if ("$($cfg.targetDir)".Trim()) { $dirs = @(Resolve-InputPath ([string]$cfg.targetDir)) }
            Save-TargetConfig $dirs
            if (-not $Quiet) { Write-Host '[提示] 已将旧版单目录配置迁移为多目录格式 targetDirs。' -ForegroundColor DarkYellow }
            return @(ConvertTo-ConfigEntries $dirs)
        }
        return @()
    }
    # 配置文件不存在 → 自动检测默认目录
    if (Test-Path -LiteralPath $DefaultTarget) {
        Save-TargetConfig @($DefaultTarget)
        Write-Host "[提示] 首次运行：已将自动检测到的目标目录写入 .skill-link.json ：$DefaultTarget" -ForegroundColor DarkYellow
        return @(ConvertTo-ConfigEntries @($DefaultTarget) '自动检测 ~\.agents\skills')
    }
    return @()
}

function Show-TargetDirList {
    param([string[]]$Dirs)
    $cfg = @(Get-TargetConfig -Quiet)
    if (-not $Dirs) { $Dirs = @($cfg | ForEach-Object Dir) }
    if (@($Dirs).Count -eq 0) { Write-Host '目标目录: (未设置)' -ForegroundColor Yellow; return }
    Write-Host "目标目录 ($(@($Dirs).Count) 个):"
    $i = 0
    foreach ($d in @($Dirs)) {
        $i++
        $tag = ''
        if (-not (Test-Path -LiteralPath $d)) { $tag = '   (不存在，添加链接时会自动创建)' }
        Write-Host ("  [{0}] {1}{2}" -f $i, $d, $tag)
    }
}

# 把单个 token（编号 / 路径 / 路径尾部片段）解析为目标目录；可能命中 1 个或多个
function Find-TargetDirMatches {
    param([string[]]$All, [string]$Token)
    $All = @($All)
    if ($All.Count -eq 0) { return @() }
    $n = 0
    if ([int]::TryParse($Token.Trim(), [ref]$n) -and $n -ge 1 -and $n -le $All.Count) {
        return @($All[$n - 1])
    }
    $rp = Resolve-InputPath $Token
    $exact = @($All | Where-Object { Test-SameDir $_ $rp })
    if ($exact.Count -gt 0) { return $exact }
    $tail = '\' + ($Token.Trim().Trim('"').TrimEnd('\').TrimStart('\').Replace('/', '\'))
    return @($All | Where-Object { $_.ToLowerInvariant().EndsWith($tail.ToLowerInvariant()) })
}

# 参数 token 展开：整体优先（避免把含逗号的真实目录误拆），整体无法匹配时才按逗号拆分
function Expand-DirArg {
    param([string[]]$Raw, [string[]]$KnownDirs)
    $out = @()
    foreach ($r in @($Raw)) {
        if (-not $r -or -not "$r".Trim()) { continue }
        $whole = "$r".Trim()
        $isKnown = $false
        if (@($KnownDirs).Count -gt 0) {
            $isKnown = (@(Find-TargetDirMatches $KnownDirs $whole).Count -gt 0)
        }
        if (-not $isKnown) {
            try { $isKnown = Test-Path -LiteralPath (Resolve-InputPath $whole) } catch { $isKnown = $false }
        }
        if ($isKnown -or ($whole -notmatch ',')) {
            $out += $whole
        } else {
            $out += @($whole -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
    }
    return @($out)
}

function Add-TargetDir {
    param([string[]]$Paths, [bool]$Interactive)
    $cfg = @(Get-TargetConfig -Quiet)
    $dirs = @($cfg | ForEach-Object Dir)
    foreach ($p in @(Expand-DirArg $Paths $dirs)) {
        if (-not $p -or -not "$p".Trim()) { continue }
        $path = Resolve-InputPath $p
        if (Test-SameDir $path $RepoRoot) {
            Write-Host '[错误] 目标目录不能是仓库本身。' -ForegroundColor Red
            continue
        }
        if (@($dirs | Where-Object { Test-SameDir $_ $path }).Count -gt 0) {
            Write-Host "[提示] 目标目录已存在，忽略: $path" -ForegroundColor DarkYellow
            continue
        }
        if (-not (Test-Path -LiteralPath $path)) {
            $create = $true
            if ($Interactive) {
                $create = ((Read-Host "目录不存在: $path ，是否创建? [Y/n]") -notmatch '^(n|N)')
            }
            if (-not $create) { Write-Host "  [跳过] 未创建: $path" -ForegroundColor DarkGray; continue }
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
        $dirs += $path
        Write-Host "[OK] 已添加目标目录: $path" -ForegroundColor Green
    }
    Save-TargetConfig $dirs
}

function Remove-TargetDir {
    param([string[]]$Paths)
    $cfg = @(Get-TargetConfig -Quiet)
    $dirs = @($cfg | ForEach-Object Dir)
    if ($dirs.Count -eq 0) { Write-Host '当前没有目标目录。' -ForegroundColor Yellow; return }
    $tokens = @(Expand-DirArg $Paths $dirs)
    if ($tokens | Where-Object { $_ -ieq 'all' }) { $tokens = @($dirs) }
    foreach ($p in $tokens) {
        if (-not $p -or -not "$p".Trim()) { continue }
        $m = @(Find-TargetDirMatches $dirs $p)
        if ($m.Count -eq 0) { Write-Host "[提示] 未找到目标目录: $p" -ForegroundColor Yellow; continue }
        if ($m.Count -gt 1) {
            Write-Host "[提示] `"$p`" 匹配到多个目标目录，请改用编号或完整路径:" -ForegroundColor Yellow
            foreach ($x in $m) { Write-Host "        - $x" -ForegroundColor Yellow }
            continue
        }
        $dirs = @($dirs | Where-Object { -not (Test-SameDir $_ $m[0]) })
        Write-Host "[OK] 已从配置移除(磁盘内容未改动): $($m[0])" -ForegroundColor Green
    }
    if ($dirs.Count -eq 0) {
        Write-Host '[注意] 目标目录列表已清空，请用 -AddTarget 重新添加。' -ForegroundColor Yellow
    }
    Save-TargetConfig $dirs
}

function Set-TargetDir {
    param([string]$Path, [bool]$Interactive)
    if (-not $Path -or -not $Path.Trim()) { return $false }
    $path = Resolve-InputPath $Path
    if (Test-SameDir $path $RepoRoot) {
        Write-Host '[错误] 目标目录不能是仓库本身。' -ForegroundColor Red
        return $false
    }
    if (-not (Test-Path -LiteralPath $path)) {
        $create = $true
        if ($Interactive) {
            $create = ((Read-Host "目录不存在: $path ，是否创建? [Y/n]") -notmatch '^(n|N)')
        }
        if ($create) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
        else { return $false }
    }
    Save-TargetConfig @($path)
    Write-Host "[OK] 目标目录已设置(覆盖为唯一目录): $path" -ForegroundColor Green
    return $true
}

# ---------- skill 状态 ----------

function Get-RepoSkills {
    @(Get-ChildItem -LiteralPath $RepoRoot -Directory -Force |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
        Sort-Object Name)
}

# 返回某路径的链接信息（LinkType / 解析为绝对路径的 Target）；不是链接则返回 $null
function Get-LinkInfo {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.LinkType) { return $null }
    $t = @($item.Target)[0]
    if (-not $t) { return [pscustomobject]@{ LinkType = $item.LinkType; Target = '' } }
    if (-not [IO.Path]::IsPathRooted($t)) {
        $t = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $Path) $t))
    }
    return [pscustomobject]@{ LinkType = $item.LinkType; Target = $t }
}

# 单个目标目录下所有 skill 的状态
function Get-SkillStates {
    param([string]$TargetDir)
    $states = foreach ($s in (Get-RepoSkills)) {
        $dest = Join-Path $TargetDir $s.Name
        $info = Get-LinkInfo $dest
        $state = 'unlinked'; $linkType = ''; $linkTarget = ''
        if ($info) {
            $linkType = $info.LinkType; $linkTarget = $info.Target
            if (Test-SameDir $info.Target $s.FullName) { $state = 'linked' } else { $state = 'mismatch' }
        } elseif (Test-Path -LiteralPath $dest) {
            $state = 'conflict'
        }
        [pscustomobject]@{
            TargetDir = $TargetDir; Name = $s.Name; RepoDir = $s.FullName; Dest = $dest
            State = $state; LinkType = $linkType; LinkTarget = $linkTarget
        }
    }
    return @($states)
}

# 多目标目录的扁平状态列表（目录为主序，目录内按 skill 名排序），编号与展示顺序一致
function Get-AllSkillStates {
    param([string[]]$TargetDirs)
    $all = @()
    foreach ($d in @($TargetDirs)) { $all += @(Get-SkillStates $d) }
    return @($all)
}

# 目标目录中指向本仓库、但仓库里已无对应 skill（或指向已不存在目录）的链接
function Get-OrphanLinks {
    param([string]$TargetDir)
    if (-not (Test-Path -LiteralPath $TargetDir)) { return @() }
    $repoSkillNames = @(Get-RepoSkills | ForEach-Object Name)
    $rootPattern = (Get-NormalizedPath $RepoRoot) + '\*'
    $orphans = foreach ($c in (Get-ChildItem -LiteralPath $TargetDir -Force)) {
        if (-not $c.LinkType) { continue }
        $t = @($c.Target)[0]
        if (-not $t) { continue }
        if (-not [IO.Path]::IsPathRooted($t)) {
            $t = [IO.Path]::GetFullPath((Join-Path $TargetDir $t))
        }
        if ($t -like $rootPattern -and
            (($repoSkillNames -notcontains $c.Name) -or (-not (Test-Path -LiteralPath $t)))) {
            $c
        }
    }
    return @($orphans)
}

# ---------- 展示 ----------

# 按目标目录分组打印 skill 列表，编号为跨目录的全局编号
function Show-SkillList {
    param([object[]]$States)
    if (-not $States) { Write-Host '  (没有可显示的 skill)' -ForegroundColor DarkGray; return }
    $States = @($States)
    if ($States.Count -eq 0) { Write-Host '  (没有可显示的 skill)' -ForegroundColor DarkGray; return }

    $width = 22
    foreach ($s in $States) { if ($s.Name.Length -gt $width) { $width = $s.Name.Length } }

    $dirs = @()
    foreach ($s in $States) {
        if (@($dirs | Where-Object { $_ -ieq $s.TargetDir }).Count -eq 0) { $dirs += $s.TargetDir }
    }

    $i = 0
    foreach ($d in $dirs) {
        $sd = @($States | Where-Object { $_.TargetDir -ieq $d })
        $cLinked   = @($sd | Where-Object { $_.State -eq 'linked' }).Count
        $cUnlinked = @($sd | Where-Object { $_.State -eq 'unlinked' }).Count
        $cConflict = @($sd | Where-Object { $_.State -eq 'conflict' }).Count
        $cMismatch = @($sd | Where-Object { $_.State -eq 'mismatch' }).Count
        $summary = @()
        if ($cLinked)   { $summary += "$cLinked 已链接" }
        if ($cUnlinked) { $summary += "$cUnlinked 未链接" }
        if ($cConflict) { $summary += "$cConflict 冲突(真实目录)" }
        if ($cMismatch) { $summary += "$cMismatch 指向不符" }

        Write-Host ''
        Write-Host "  @ $d" -ForegroundColor Cyan
        Write-Host ('    ' + ($summary -join ' | '))

        foreach ($s in $sd) {
            $i++
            $head = ('    [{0,2}] {1,-' + $width + '}  ') -f $i, $s.Name
            switch ($s.State) {
                'linked' {
                    Write-Host $head -NoNewline
                    Write-Host ('{0,-16}' -f '已链接') -NoNewline -ForegroundColor Green
                    Write-Host "$($s.LinkType) -> $($s.LinkTarget)"
                }
                'unlinked' {
                    Write-Host $head -NoNewline
                    Write-Host ('{0,-16}' -f '未链接') -NoNewline -ForegroundColor DarkGray
                    Write-Host '-'
                }
                'conflict' {
                    Write-Host $head -NoNewline
                    Write-Host ('{0,-16}' -f '冲突(真实目录)') -NoNewline -ForegroundColor Yellow
                    Write-Host "目标处存在同名真实目录: $($s.Dest)"
                }
                'mismatch' {
                    Write-Host $head -NoNewline
                    Write-Host ('{0,-16}' -f '指向不符') -NoNewline -ForegroundColor Red
                    Write-Host "$($s.LinkType) -> $($s.LinkTarget)"
                }
            }
        }
    }
}

function Show-Status {
    param([string[]]$TargetDirs)
    $repoSkills = @(Get-RepoSkills)
    Write-Host ''
    Write-Host "仓库: $RepoRoot  (共 $($repoSkills.Count) 个 skill)"

    $cfg = @(Get-TargetConfig -Quiet)
    if (-not $TargetDirs) { $TargetDirs = @($cfg | ForEach-Object Dir) }
    $dirs = @($TargetDirs)

    if ($dirs.Count -eq 0) {
        Write-Host '目标目录: (未设置)' -NoNewline -ForegroundColor Yellow
        Write-Host '  —— 用菜单选项 3 或参数 -AddTarget / -SetTarget 设置；默认建议:'
        Write-Host "       $DefaultTarget"
        return
    }

    Write-Host "目标目录: $($dirs.Count) 个"
    for ($i = 0; $i -lt $dirs.Count; $i++) {
        $src = @($cfg | Where-Object { Test-SameDir $_.Dir $dirs[$i] } | ForEach-Object Source)[0]
        if (-not $src) { $src = '参数指定' }
        $tag = ''
        if (-not (Test-Path -LiteralPath $dirs[$i])) { $tag = '  (不存在，执行添加链接时会自动创建)' }
        Write-Host ("  [{0}] {1}  [{2}]{3}" -f ($i + 1), $dirs[$i], $src, $tag)
    }

    Show-SkillList @(Get-AllSkillStates $dirs)

    $orphanTotal = 0
    foreach ($d in $dirs) {
        if (Test-Path -LiteralPath $d) { $orphanTotal += @(Get-OrphanLinks $d).Count }
    }
    if ($orphanTotal -gt 0) {
        Write-Host ''
        Write-Host "另有 $orphanTotal 个失效链接(指向本仓库但 skill 已不存在)，详见选项 4 或参数 -Clean。" -ForegroundColor Yellow
    }
}

# ---------- 链接操作 ----------

function New-SkillLink {
    param($State)
    $symErr = $null
    try {
        New-Item -ItemType SymbolicLink -Path $State.Dest -Target $State.RepoDir -ErrorAction Stop | Out-Null
        return 'SymbolicLink'
    } catch {
        $symErr = $_.Exception.Message
    }
    try {
        New-Item -ItemType Junction -Path $State.Dest -Target $State.RepoDir -ErrorAction Stop | Out-Null
        if (-not $script:JunctionHintShown) {
            $script:JunctionHintShown = $true
            Write-Host '  [提示] 无符号链接权限(需管理员或开发者模式)，已改用 Junction，效果相同。' -ForegroundColor DarkYellow
        }
        return 'Junction'
    } catch {
        Write-Host "  [失败] $($State.Name): 创建链接失败。" -ForegroundColor Red
        Write-Host "         符号链接: $symErr" -ForegroundColor Red
        Write-Host "         Junction : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# 删除一个链接本身（Junction / 目录符号链接），不影响其指向的内容
function Remove-LinkAt {
    param([string]$Path)
    try {
        (Get-Item -LiteralPath $Path -Force).Delete()
        if (-not (Test-Path -LiteralPath $Path)) { return $true }
    } catch { }
    & cmd /c rmdir "$Path" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $Path))
}

function Backup-AndRemoveRealDir {
    param([string]$Path)
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $backup = Join-Path $BackupDir ("{0}-{1}" -f (Split-Path -Leaf $Path), (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item -LiteralPath $Path -Destination $backup
    return $backup
}

function Invoke-LinkSkills {
    param([object[]]$States, [bool]$Interactive, [bool]$ForceReplace)
    foreach ($s in $States) {
        switch ($s.State) {
            'linked' {
                Write-Host "  [跳过] $($s.Name): 已是链接" -ForegroundColor DarkGray
            }
            'unlinked' {
                $lt = New-SkillLink $s
                if ($lt) { Write-Host "  [OK] $($s.Name): 已创建 $lt" -ForegroundColor Green }
            }
            'conflict' {
                Write-Host "  [注意] $($s.Name): 目标处存在同名真实目录(非链接): $($s.Dest)" -ForegroundColor Yellow
                $choice = 's'
                if ($ForceReplace) {
                    $choice = 'd'
                } elseif ($Interactive) {
                    $choice = (Read-Host '         [b]备份到 .skill-link-backup 后替换 / [d]直接删除后替换 / [s]跳过').Trim().ToLower()
                } else {
                    Write-Host '         未替换（交互模式下可选择替换，或使用 -Force 直接替换）' -ForegroundColor Yellow
                }
                switch ($choice) {
                    'b' {
                        $backup = Backup-AndRemoveRealDir $s.Dest
                        $lt = New-SkillLink $s
                        if ($lt) { Write-Host "  [OK] $($s.Name): 已备份到 $backup 并创建 $lt" -ForegroundColor Green }
                    }
                    'd' {
                        Remove-Item -LiteralPath $s.Dest -Recurse -Force
                        $lt = New-SkillLink $s
                        if ($lt) { Write-Host "  [OK] $($s.Name): 已删除真实目录并创建 $lt" -ForegroundColor Green }
                    }
                    default {
                        Write-Host "  [跳过] $($s.Name)" -ForegroundColor DarkGray
                    }
                }
            }
            'mismatch' {
                Write-Host "  [注意] $($s.Name): 目标处的链接指向别处: $($s.LinkTarget)" -ForegroundColor Red
                $choice = 's'
                if ($ForceReplace) {
                    $choice = 'y'
                } elseif ($Interactive) {
                    $choice = (Read-Host '         [y]删除该链接并指向本仓库 / [回车]跳过').Trim().ToLower()
                }
                if ($choice -eq 'y') {
                    if (Remove-LinkAt $s.Dest) {
                        $lt = New-SkillLink $s
                        if ($lt) { Write-Host "  [OK] $($s.Name): 已重新指向 $($s.RepoDir)" -ForegroundColor Green }
                    } else {
                        Write-Host "  [失败] $($s.Name): 删除旧链接失败" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  [跳过] $($s.Name)（非交互模式且未指定 -Force）" -ForegroundColor DarkGray
                }
            }
        }
    }
}

function Invoke-UnlinkSkills {
    param([object[]]$States, [bool]$Interactive)
    foreach ($s in $States) {
        switch ($s.State) {
            'unlinked' {
                Write-Host "  [跳过] $($s.Name): 未链接" -ForegroundColor DarkGray
            }
            'linked' {
                if (Remove-LinkAt $s.Dest) {
                    Write-Host "  [OK] $($s.Name): 已解除链接" -ForegroundColor Green
                } else {
                    Write-Host "  [失败] $($s.Name): 解除链接失败" -ForegroundColor Red
                }
            }
            'mismatch' {
                $choice = 'y'
                if ($Interactive) {
                    $choice = (Read-Host "  [注意] $($s.Name) 的链接指向别处: $($s.LinkTarget) ，确认删除? [y/N]").Trim().ToLower()
                }
                if ($choice -eq 'y') {
                    if (Remove-LinkAt $s.Dest) {
                        Write-Host "  [OK] $($s.Name): 已删除链接" -ForegroundColor Green
                    } else {
                        Write-Host "  [失败] $($s.Name): 删除链接失败" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  [跳过] $($s.Name)" -ForegroundColor DarkGray
                }
            }
            'conflict' {
                Write-Host "  [跳过] $($s.Name): 目标处是真实目录而非链接，未改动" -ForegroundColor Yellow
            }
        }
    }
}

function Invoke-CleanOrphans {
    param([bool]$Interactive, [string[]]$TargetDirs)
    $cfg = @(Get-TargetConfig -Quiet)
    if (-not $TargetDirs) { $TargetDirs = @($cfg | ForEach-Object Dir) }
    $dirs = @($TargetDirs)
    if ($dirs.Count -eq 0) { Write-Host '没有可清理的失效链接。'; return }

    $items = @()
    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        foreach ($o in @(Get-OrphanLinks $d)) {
            $items += [pscustomobject]@{ Dir = $d; Name = $o.Name; Path = $o.FullName; Target = (@($o.Target))[0] }
        }
    }
    if ($items.Count -eq 0) { Write-Host '没有失效链接。'; return }

    foreach ($it in $items) {
        Write-Host "  - [$($it.Dir)] $($it.Name) -> $($it.Target)" -ForegroundColor Yellow
    }
    $do = $true
    if ($Interactive) {
        $do = ((Read-Host "确认清理以上 $($items.Count) 个失效链接? [y/N]").Trim() -match '^(y|Y)')
    }
    if (-not $do) { Write-Host '已取消。'; return }
    foreach ($it in $items) {
        if (Remove-LinkAt $it.Path) {
            Write-Host "  [OK] 已清理: $($it.Name)" -ForegroundColor Green
        } else {
            Write-Host "  [失败] $($it.Name)" -ForegroundColor Red
        }
    }
}

# ---------- 名称解析 / 选择 ----------

# 把 -TargetDir 的 token 列表解析为目标目录数组；未指定(或空)时返回全部
function Resolve-TargetDirFilter {
    param([string[]]$Tokens)
    $cfg = @(Get-TargetConfig -Quiet)
    $all = @($cfg | ForEach-Object Dir)
    $flat = @(Expand-DirArg $Tokens $all)
    if ($flat.Count -eq 0) { return @($all) }
    if ($flat | Where-Object { $_ -ieq 'all' }) { return @($all) }
    $picked = @()
    foreach ($t in $flat) {
        $m = @(Find-TargetDirMatches $all $t)
        if ($m.Count -eq 0) { Write-Host "  [提示] 未找到目标目录: $t" -ForegroundColor Yellow; continue }
        if ($m.Count -gt 1) {
            Write-Host "  [提示] `"$t`" 匹配到多个目标目录，请改用编号或完整路径:" -ForegroundColor Yellow
            foreach ($x in $m) { Write-Host "          - $x" -ForegroundColor Yellow }
            continue
        }
        if (@($picked | Where-Object { Test-SameDir $_ $m[0] }).Count -eq 0) { $picked += $m[0] }
    }
    return @($picked)
}

function Resolve-SkillStates {
    param([string[]]$Names, [string[]]$TargetDirs)
    $dirs = @()
    if ($TargetDirs) { $dirs = @($TargetDirs) }
    if ($dirs.Count -eq 0) {
        Write-Host '[错误] 未设置目标目录，请先用 -AddTarget <路径> 或 -SetTarget <路径> 设置。' -ForegroundColor Red
        return $null
    }
    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $states = @(Get-AllSkillStates $dirs)
    $tokens = @($Names | ForEach-Object { ($_ -split ',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($tokens | Where-Object { $_ -ieq 'all' }) { return $states }
    $picked = @()
    foreach ($n in $tokens) {
        $m = @($states | Where-Object { $_.Name -ieq $n })
        if ($m.Count -gt 0) { $picked += $m }
        else { Write-Host "  [提示] 未找到 skill: $n" -ForegroundColor Yellow }
    }
    if ($picked.Count -eq 0) {
        Write-Host ('可用: ' + ((@($states | ForEach-Object Name) | Select-Object -Unique) -join ', ')) -ForegroundColor Yellow
        return $null
    }
    return @($picked)
}

function Select-SkillStates {
    param([object[]]$States, [string]$Action)
    Show-SkillList $States
    if (-not $States) { return $null }
    $list = @($States)
    Write-Host ''
    $in = (Read-Host "输入要$Action 的编号(逗号分隔, a=全部, 回车取消)").Trim()
    if (-not $in) { return $null }
    if ($in -ieq 'a') { return $list }
    $picked = @()
    foreach ($tok in ($in -split ',')) {
        $tok = $tok.Trim()
        $n = 0
        if ($tok -and [int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $list.Count) {
            $picked += $list[$n - 1]
        } elseif ($tok) {
            Write-Host "  [提示] 忽略无效编号: $tok" -ForegroundColor Yellow
        }
    }
    if ($picked.Count -eq 0) { return $null }
    return @($picked)
}

# 交互式选择本次操作作用于哪些目标目录（仅 1 个时直接返回）
function Select-TargetDirsForAction {
    param([string]$Action)
    $cfg = @(Get-TargetConfig -Quiet)
    $all = @($cfg | ForEach-Object Dir)
    if ($all.Count -eq 0) { Write-Host '请先添加目标目录（选项 3）。' -ForegroundColor Yellow; return @() }
    if ($all.Count -eq 1) { return @($all) }

    Write-Host ''
    Show-TargetDirList $all
    $in = (Read-Host "对哪些目标目录$Action ? (编号逗号分隔, a=全部, 回车=全部)").Trim()
    if (-not $in -or $in -ieq 'a') { return @($all) }
    $picked = @(Resolve-TargetDirFilter ($in -split ','))
    if ($picked.Count -eq 0) { Write-Host '未选择有效目标目录。' -ForegroundColor Yellow; return @() }
    return @($picked)
}

# ---------- 交互式菜单 ----------

function Invoke-MenuLink {
    $dirs = @(Select-TargetDirsForAction '添加链接')
    if ($dirs.Count -eq 0) { return }
    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $states = @(Get-AllSkillStates $dirs)
    $picked = Select-SkillStates $states '添加链接'
    if ($picked) { Invoke-LinkSkills -States $picked -Interactive $true -ForceReplace:$false }
}

function Invoke-MenuUnlink {
    $dirs = @(Select-TargetDirsForAction '解除链接')
    if ($dirs.Count -eq 0) { return }
    $states = @(Get-AllSkillStates $dirs)
    $picked = Select-SkillStates $states '解除链接'
    if ($picked) { Invoke-UnlinkSkills -States $picked -Interactive $true }
}

function Invoke-MenuManageDirs {
    while ($true) {
        Write-Host ''
        Show-TargetDirList
        Write-Host ''
        Write-Host '  a) 添加目录    d) 移除目录    s) 覆盖为唯一目录    l) 重新显示    回车) 返回'
        $c = ''
        try { $c = (Read-Host '选择').Trim().ToLower() } catch { return }
        if (-not $c) { return }
        if ($c -eq 'a') {
            $in = (Read-Host '要添加的目录(可多个, 逗号分隔)').Trim()
            if ($in) { Add-TargetDir ($in -split ',') $true }
        } elseif ($c -eq 'd') {
            $all = @(Get-TargetConfig -Quiet | ForEach-Object Dir)
            if ($all.Count -eq 0) {
                Write-Host '当前没有目标目录。' -ForegroundColor Yellow
            } else {
                $in = (Read-Host '要移除的目录(编号逗号分隔, a=全部; 磁盘内容不会被删除)').Trim()
                if ($in -ieq 'a') { Remove-TargetDir $all }
                elseif ($in) { Remove-TargetDir ($in -split ',') }
            }
        } elseif ($c -eq 's') {
            $default = @(Get-TargetConfig -Quiet | ForEach-Object Dir)[0]
            if (-not $default) { $default = $DefaultTarget }
            $in = (Read-Host "目标目录(回车使用 $default ；将覆盖现有列表)").Trim()
            if (-not $in) { $in = $default }
            Set-TargetDir $in $true | Out-Null
        } elseif ($c -eq 'l') {
            continue
        } else {
            Write-Host '无效选择。' -ForegroundColor Yellow
        }
    }
}

function Show-Menu {
    $emptyInputs = 0
    while ($true) {
        Show-Status

        $orphanCount = 0
        foreach ($d in @(Get-TargetConfig -Quiet | ForEach-Object Dir)) {
            if (Test-Path -LiteralPath $d) { $orphanCount += @(Get-OrphanLinks $d).Count }
        }

        Write-Host ''
        Write-Host '  1) 添加链接    2) 解除链接    3) 管理目标目录' -NoNewline
        if ($orphanCount -gt 0) {
            Write-Host "    4) 清理失效链接($orphanCount)" -NoNewline -ForegroundColor Yellow
        } else {
            Write-Host '    4) 清理失效链接' -NoNewline
        }
        Write-Host '    q) 退出'

        $choice = ''
        try { $choice = (Read-Host '选择').Trim() } catch { return }
        if ([string]::IsNullOrEmpty($choice)) {
            $emptyInputs++
            if ($emptyInputs -ge 3) { return }
            continue
        }
        $emptyInputs = 0
        switch ($choice) {
            '1' { Invoke-MenuLink }
            '2' { Invoke-MenuUnlink }
            '3' { Invoke-MenuManageDirs }
            '4' { Invoke-CleanOrphans $true (@(Get-TargetConfig -Quiet | ForEach-Object Dir)) }
            'q' { return }
            default { Write-Host '无效选择。' -ForegroundColor Yellow }
        }
    }
}

# ---------- 入口 ----------

$anyCliAction = $List -or $SetTarget -or $AddTarget -or $RemoveTarget -or $TargetDir -or $Link -or $Unlink -or $Clean
if (-not $anyCliAction) {
    Show-Menu
    return
}

if ($SetTarget)   { Set-TargetDir $SetTarget $false | Out-Null }
if ($AddTarget)   { Add-TargetDir $AddTarget $false }
if ($RemoveTarget) { Remove-TargetDir $RemoveTarget }

$scope = @(Resolve-TargetDirFilter $TargetDir)

if ($scope.Count -eq 0 -and ($Link -or $Unlink -or $Clean)) {
    Write-Host '[错误] 未匹配到任何目标目录（或尚未设置目标目录），本次操作已取消。' -ForegroundColor Red
    Write-Host '       用 -List 查看已配置的目标目录，或用 -AddTarget / -SetTarget 设置。' -ForegroundColor Red
    return
}

if ($Link) {
    $picked = Resolve-SkillStates $Link $scope
    if ($picked) { Invoke-LinkSkills -States $picked -Interactive $false -ForceReplace:$Force }
}
if ($Unlink) {
    $picked = Resolve-SkillStates $Unlink $scope
    if ($picked) { Invoke-UnlinkSkills -States $picked -Interactive $false }
}
if ($Clean) {
    Invoke-CleanOrphans $false $scope
}

Show-Status -TargetDirs $scope
