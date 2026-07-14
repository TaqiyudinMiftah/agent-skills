param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RawBase = "https://raw.githubusercontent.com/TaqiyudinMiftah/agent-skills/main"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Get-TemplateFile {
    param(
        [Parameter(Mandatory = $true)][string]$RemotePath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )
    Invoke-WebRequest -Uri "$RawBase/$RemotePath" -OutFile $OutputPath -UseBasicParsing
}

function Backup-ExistingFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $BackupPath = "$Path.bak.$Timestamp"
    $Counter = 1
    while (Test-Path -LiteralPath $BackupPath) {
        $BackupPath = "$Path.bak.$Timestamp.$Counter"
        $Counter++
    }

    Copy-Item -LiteralPath $Path -Destination $BackupPath
    Write-Host "  backup: $BackupPath"
    return $BackupPath
}

function Install-OrUpdateFile {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath
        Write-Host "  installed: $Label"
        return
    }

    $SourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $DestinationHash = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
    if ($SourceHash -eq $DestinationHash) {
        Write-Host "  unchanged: $Label"
        return
    }

    Backup-ExistingFile -Path $DestinationPath | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    Write-Host "  updated: $Label"
}

New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
$ResolvedTarget = (Resolve-Path -LiteralPath $TargetPath).Path
New-Item -ItemType Directory -Path (Join-Path $ResolvedTarget ".codex\agents") -Force | Out-Null

$TempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("sol-terra-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempDirectory | Out-Null

try {
    Write-Host "Installing Sol–Terra workflow into: $ResolvedTarget"

    $AgentsTemplate = Join-Path $TempDirectory "AGENTS.md"
    Get-TemplateFile -RemotePath "template/AGENTS.md" -OutputPath $AgentsTemplate
    $AgentsDestination = Join-Path $ResolvedTarget "AGENTS.md"
    $ManagedStart = "<!-- sol-terra-workflow:start -->"
    $ManagedEnd = "<!-- sol-terra-workflow:end -->"
    $TemplateContent = [System.IO.File]::ReadAllText($AgentsTemplate)

    if (-not (Test-Path -LiteralPath $AgentsDestination)) {
        Write-Utf8File -Path $AgentsDestination -Content $TemplateContent
        Write-Host "  installed: AGENTS.md"
    }
    else {
        $ExistingContent = [System.IO.File]::ReadAllText($AgentsDestination)
        if ($ExistingContent.Contains($ManagedStart)) {
            $Pattern = "(?s)" + [regex]::Escape($ManagedStart) + ".*?" + [regex]::Escape($ManagedEnd)
            $Replacement = $TemplateContent.TrimEnd("`r", "`n")
            $MergedContent = [regex]::Replace($ExistingContent, $Pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($Match) $Replacement }, 1)
            $MergedPath = Join-Path $TempDirectory "AGENTS.merged.md"
            Write-Utf8File -Path $MergedPath -Content $MergedContent
            Install-OrUpdateFile -SourcePath $MergedPath -DestinationPath $AgentsDestination -Label "AGENTS.md managed block"
        }
        else {
            Backup-ExistingFile -Path $AgentsDestination | Out-Null
            $AppendedContent = $ExistingContent.TrimEnd("`r", "`n") + "`r`n`r`n" + $TemplateContent
            Write-Utf8File -Path $AgentsDestination -Content $AppendedContent
            Write-Host "  appended: Sol–Terra block in AGENTS.md"
        }
    }

    $ConfigTemplate = Join-Path $TempDirectory "config.toml"
    Get-TemplateFile -RemotePath "template/.codex/config.toml" -OutputPath $ConfigTemplate
    $ConfigDestination = Join-Path $ResolvedTarget ".codex\config.toml"

    if (-not (Test-Path -LiteralPath $ConfigDestination)) {
        Copy-Item -LiteralPath $ConfigTemplate -Destination $ConfigDestination
        Write-Host "  installed: .codex/config.toml"
    }
    elseif ($Force) {
        Install-OrUpdateFile -SourcePath $ConfigTemplate -DestinationPath $ConfigDestination -Label ".codex/config.toml"
    }
    else {
        Write-Host "  preserved: .codex/config.toml (use -Force to back up and replace)"
    }

    $AgentTemplate = Join-Path $TempDirectory "terra-executor.toml"
    Get-TemplateFile -RemotePath "template/.codex/agents/terra-executor.toml" -OutputPath $AgentTemplate
    $AgentDestination = Join-Path $ResolvedTarget ".codex\agents\terra-executor.toml"
    Install-OrUpdateFile -SourcePath $AgentTemplate -DestinationPath $AgentDestination -Label ".codex/agents/terra-executor.toml"

    $ShellLauncher = @'
#!/usr/bin/env sh
set -eu
exec codex -m gpt-5.6-sol "$@"
'@
    $ShellLauncherPath = Join-Path $ResolvedTarget "codex-sol-terra"
    Write-Utf8File -Path $ShellLauncherPath -Content $ShellLauncher
    Write-Host "  installed: codex-sol-terra"

    $PowerShellLauncher = @'
& codex -m gpt-5.6-sol @args
exit $LASTEXITCODE
'@
    $PowerShellLauncherPath = Join-Path $ResolvedTarget "codex-sol-terra.ps1"
    Write-Utf8File -Path $PowerShellLauncherPath -Content $PowerShellLauncher
    Write-Host "  installed: codex-sol-terra.ps1"

    Write-Host ""
    Write-Host "Done."
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Review the installed files and any .bak.* backups."
    Write-Host "  2. Start Codex with: ./codex-sol-terra.ps1"
    Write-Host "  3. Trust the project when Codex asks, so project-scoped .codex files load."
    Write-Host "  4. Use /agent inside Codex to inspect Terra's executor thread."
}
finally {
    if (Test-Path -LiteralPath $TempDirectory) {
        Remove-Item -LiteralPath $TempDirectory -Recurse -Force
    }
}
