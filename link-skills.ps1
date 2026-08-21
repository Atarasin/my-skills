#Requires -Version 5.1
<#
.SYNOPSIS
    管理本仓库 skills 到目标目录的目录链接（优先符号链接，无权限时自动回退 Junction）。

.DESCRIPTION
    扫描仓库中包含 SKILL.md 的顶层目录作为 skill，与目标目录（如 C:\Users\<user>\.agents\skills）
    中的同名条目比对，展示每个 skill 的链接状态与链接路径，并支持：
      - 添加 / 解除链接（可多选或全部）
      - 设置目标目录
      - 清理目标目录中指向本仓库、但仓库里已不存在的失效链接

    目标目录保存在仓库根的 .skill-link.json（已加入 .gitignore）。
    首次运行若配置不存在且 ~\.agents\skills 存在，会自动使用该目录并写入配置文件。
    目标目录中不指向本仓库的条目（如手工安装的其他 skill）不会被脚本改动。

    注意：Windows 创建符号链接需要管理员权限或开启"开发者模式"；
    权限不足时脚本会自动改用 Junction（目录联接），对本场景效果相同。

.EXAMPLE
    .\link-skills.ps1                      # 交互式菜单

.EXAMPLE
    .\link-skills.ps1 -List                # 仅查看状态

.EXAMPLE
    .\link-skills.ps1 -SetTarget C:\Users\me\.agents\skills

.EXAMPLE
    .\link-skills.ps1 -Link all            # 链接全部 skill

.EXAMPLE
    .\link-skills.ps1 -Link doc-visualizer,execute-plan

.EXAMPLE
    .\link-skills.ps1 -Unlink all

.EXAMPLE
    .\link-skills.ps1 -Clean               # 清理失效链接
#>
[CmdletBinding()]
param(
    [switch]$List,
    [string]$SetTarget,
    [string[]]$Link,
    [string[]]$Unlink,
    [switch]$Clean,
    [switch]$Force      # 配合 -Link：目标处存在同名真实目录时直接删除替换（不备份）
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

function Get-TargetConfig {
    $fileExists = Test-Path -LiteralPath $ConfigFile
    if ($fileExists) {
        try {
            $cfg = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.targetDir) {
                return [pscustomobject]@{ Dir = [string]$cfg.targetDir; Source = '配置文件 .skill-link.json' }
            }
        } catch {
            Write-Warning '.skill-link.json 解析失败，已忽略。'
        }
    }
    if (Test-Path -LiteralPath $DefaultTarget) {
        # 仅当配置文件不存在时才把自动检测结果落盘；文件存在但无效时不覆盖，避免吞掉用户设置
        if (-not $fileExists) {
            Save-TargetConfig $DefaultTarget
            Write-Host "[提示] 首次运行：已将自动检测到的目标目录写入 .skill-link.json ：$DefaultTarget" -ForegroundColor DarkYellow
            return [pscustomobject]@{ Dir = $DefaultTarget; Source = '自动检测(已写入配置)' }
        }
        return [pscustomobject]@{ Dir = $DefaultTarget; Source = '自动检测 ~\.agents\skills' }
    }
    return $null
}

function Save-TargetConfig {
    param([string]$Path)
    [pscustomobject]@{ targetDir = $Path } | ConvertTo-Json |
        Set-Content -LiteralPath $ConfigFile -Encoding UTF8
}

function Set-TargetDir {
    param([string]$Path, [bool]$Interactive)
    $Path = $Path.Trim().Trim('"')
    if ($Path -eq '~') { $Path = $HOME }
    elseif ($Path.StartsWith('~')) { $Path = $HOME + $Path.Substring(1) }
    if (-not [IO.Path]::IsPathRooted($Path)) {
        $Path = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
    }
    if ((Get-NormalizedPath $Path) -eq (Get-NormalizedPath $RepoRoot)) {
        Write-Host '[错误] 目标目录不能是仓库本身。' -ForegroundColor Red
        return $false
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        $create = $true
        if ($Interactive) {
            $create = ((Read-Host "目录不存在: $Path ，是否创建? [Y/n]") -notmatch '^(n|N)')
        }
        if ($create) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        else { return $false }
    }
    Save-TargetConfig $Path
    Write-Host "[OK] 目标目录已设置: $Path" -ForegroundColor Green
    return $true
}

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

function Get-SkillStates {
    param([string]$TargetDir)
    $states = foreach ($s in (Get-RepoSkills)) {
        $dest = Join-Path $TargetDir $s.Name
        $info = Get-LinkInfo $dest
        $state = 'unlinked'; $linkType = ''; $linkTarget = ''
        if ($info) {
            $linkType = $info.LinkType; $linkTarget = $info.Target
            if ((Get-NormalizedPath $info.Target) -eq (Get-NormalizedPath $s.FullName)) {
                $state = 'linked'
            } else {
                $state = 'mismatch'
            }
        } elseif (Test-Path -LiteralPath $dest) {
            $state = 'conflict'
        }
        [pscustomobject]@{
            Name = $s.Name; RepoDir = $s.FullName; Dest = $dest
            State = $state; LinkType = $linkType; LinkTarget = $linkTarget
        }
    }
    return @($states)
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

function Show-Status {
    $cfg = Get-TargetConfig
    Write-Host ''
    Write-Host "仓库: $RepoRoot  (共 $((Get-RepoSkills).Count) 个 skill)"
    if (-not $cfg) {
        Write-Host '目标: (未设置)' -NoNewline -ForegroundColor Yellow
        Write-Host '  —— 用菜单选项 3 或参数 -SetTarget 设置；默认建议: '
        Write-Host "       $DefaultTarget"
        return
    }
    $states = Get-SkillStates $cfg.Dir
    Write-Host "目标: $($cfg.Dir)  [$($cfg.Source)]"
    if (-not (Test-Path -LiteralPath $cfg.Dir)) {
        Write-Host "      (目标目录不存在，执行添加链接时会自动创建)" -ForegroundColor Yellow
    }

    $cLinked    = @($states | Where-Object State -eq 'linked').Count
    $cUnlinked  = @($states | Where-Object State -eq 'unlinked').Count
    $cConflict  = @($states | Where-Object State -eq 'conflict').Count
    $cMismatch  = @($states | Where-Object State -eq 'mismatch').Count
    $summary = @()
    if ($cLinked)   { $summary += "$cLinked 已链接" }
    if ($cUnlinked) { $summary += "$cUnlinked 未链接" }
    if ($cConflict) { $summary += "$cConflict 冲突(真实目录)" }
    if ($cMismatch) { $summary += "$cMismatch 指向不符" }
    Write-Host ('统计: ' + ($summary -join ' | '))

    $width = 24
    foreach ($s in $states) { if ($s.Name.Length -gt $width) { $width = $s.Name.Length } }
    $i = 0
    foreach ($s in $states) {
        $i++
        $head = ('[{0,2}] {1,-' + $width + '}  ') -f $i, $s.Name
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

    $orphans = Get-OrphanLinks $cfg.Dir
    if ($orphans.Count -gt 0) {
        Write-Host ''
        Write-Host "另有 $($orphans.Count) 个失效链接(指向本仓库但 skill 已不存在): " -ForegroundColor Yellow
        foreach ($o in $orphans) {
            Write-Host "  - $($o.Name) -> $(@($o.Target)[0])" -ForegroundColor Yellow
        }
        Write-Host '可用菜单选项 4 或参数 -Clean 清理。' -ForegroundColor Yellow
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
    param([bool]$Interactive)
    $cfg = Get-TargetConfig
    if (-not $cfg -or -not (Test-Path -LiteralPath $cfg.Dir)) {
        Write-Host '没有可清理的失效链接。'
        return
    }
    $orphans = Get-OrphanLinks $cfg.Dir
    if ($orphans.Count -eq 0) {
        Write-Host '没有失效链接。'
        return
    }
    foreach ($o in $orphans) {
        Write-Host "  - $($o.Name) -> $((@($o.Target))[0])" -ForegroundColor Yellow
    }
    $do = $true
    if ($Interactive) {
        $do = ((Read-Host "确认清理以上 $($orphans.Count) 个失效链接? [y/N]").Trim() -match '^(y|Y)')
    }
    if (-not $do) { Write-Host '已取消。'; return }
    foreach ($o in $orphans) {
        if (Remove-LinkAt $o.FullName) {
            Write-Host "  [OK] 已清理: $($o.Name)" -ForegroundColor Green
        } else {
            Write-Host "  [失败] $($o.Name)" -ForegroundColor Red
        }
    }
}

# ---------- 名称解析 / 选择 ----------

function Resolve-SkillStates {
    param([string[]]$Names)
    $cfg = Get-TargetConfig
    if (-not $cfg) {
        Write-Host '[错误] 未设置目标目录，请先用 -SetTarget <路径> 或交互菜单选项 3 设置。' -ForegroundColor Red
        return $null
    }
    if (-not (Test-Path -LiteralPath $cfg.Dir)) {
        New-Item -ItemType Directory -Path $cfg.Dir -Force | Out-Null
    }
    $states = Get-SkillStates $cfg.Dir
    $tokens = @($Names | ForEach-Object { ($_ -split ',').Trim() } | Where-Object { $_ })
    if ($tokens | Where-Object { $_ -ieq 'all' }) { return $states }
    $picked = @()
    foreach ($n in $tokens) {
        $m = $states | Where-Object { $_.Name -ieq $n }
        if ($m) { $picked += $m }
        else { Write-Host "  [提示] 未找到 skill: $n" -ForegroundColor Yellow }
    }
    if ($picked.Count -eq 0) {
        Write-Host ('可用: ' + (($states | ForEach-Object Name) -join ', ')) -ForegroundColor Yellow
        return $null
    }
    return @($picked)
}

function Select-SkillStates {
    param([object[]]$States, [string]$Action)
    $in = (Read-Host "输入要$Action 的编号(逗号分隔, a=全部, 回车取消)").Trim()
    if (-not $in) { return $null }
    if ($in -ieq 'a') { return $States }
    $picked = @()
    foreach ($tok in ($in -split ',')) {
        $tok = $tok.Trim()
        $n = 0
        if ($tok -and [int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $States.Count) {
            $picked += $States[$n - 1]
        } elseif ($tok) {
            Write-Host "  [提示] 忽略无效编号: $tok" -ForegroundColor Yellow
        }
    }
    if ($picked.Count -eq 0) { return $null }
    return @($picked)
}

# ---------- 交互式菜单 ----------

function Invoke-MenuLink {
    $cfg = Get-TargetConfig
    if (-not $cfg) { Write-Host '请先设置目标目录（选项 3）。' -ForegroundColor Yellow; return }
    if (-not (Test-Path -LiteralPath $cfg.Dir)) {
        New-Item -ItemType Directory -Path $cfg.Dir -Force | Out-Null
    }
    $states = Get-SkillStates $cfg.Dir
    $picked = Select-SkillStates $states '添加链接'
    if ($picked) { Invoke-LinkSkills -States $picked -Interactive $true -ForceReplace:$false }
}

function Invoke-MenuUnlink {
    $cfg = Get-TargetConfig
    if (-not $cfg) { Write-Host '请先设置目标目录（选项 3）。' -ForegroundColor Yellow; return }
    $states = Get-SkillStates $cfg.Dir
    $picked = Select-SkillStates $states '解除链接'
    if ($picked) { Invoke-UnlinkSkills -States $picked -Interactive $true }
}

function Invoke-MenuSetTarget {
    $default = (Get-TargetConfig).Dir
    if (-not $default) { $default = $DefaultTarget }
    $in = (Read-Host "目标目录(回车使用 $default)").Trim()
    if (-not $in) { $in = $default }
    Set-TargetDir $in $true | Out-Null
}

function Show-Menu {
    $emptyInputs = 0
    while ($true) {
        Show-Status
        $cfg = Get-TargetConfig
        $orphanCount = 0
        if ($cfg -and (Test-Path -LiteralPath $cfg.Dir)) {
            $orphanCount = (Get-OrphanLinks $cfg.Dir).Count
        }
        Write-Host ''
        Write-Host '  1) 添加链接    2) 解除链接    3) 设置目标目录' -NoNewline
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
            '3' { Invoke-MenuSetTarget }
            '4' { Invoke-CleanOrphans $true }
            'q' { return }
            default { Write-Host '无效选择。' -ForegroundColor Yellow }
        }
    }
}

# ---------- 入口 ----------

$anyCliAction = $List -or $SetTarget -or $Link -or $Unlink -or $Clean
if (-not $anyCliAction) {
    Show-Menu
    return
}

if ($SetTarget) {
    Set-TargetDir $SetTarget $false | Out-Null
}
if ($Link) {
    $picked = Resolve-SkillStates $Link
    if ($picked) { Invoke-LinkSkills -States $picked -Interactive $false -ForceReplace:$Force }
}
if ($Unlink) {
    $picked = Resolve-SkillStates $Unlink
    if ($picked) { Invoke-UnlinkSkills -States $picked -Interactive $false }
}
if ($Clean) {
    Invoke-CleanOrphans $false
}
Show-Status
