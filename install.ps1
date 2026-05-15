<#
.SYNOPSIS
    Installs Jmix agent skills into the global skills directories used by
    Claude Code (~/.claude/skills), Codex (~/.codex/skills),
    OpenCode (~/.config/opencode/skills) and Junie (~/.junie/skills).

.DESCRIPTION
    Downloads the jmix-framework/jmix-agent-guidelines repository archive at
    the requested git ref, then copies every direct subdirectory of
    v<Version>/skills/ into the global skills folder of each enabled agent.
    Existing skill directories are backed up to <name>.bak-<timestamp>/ before
    being overwritten.

.PARAMETER Version
    Major guideline version. Default: 2. Reads v<Version>/skills/ from repo.

.PARAMETER Ref
    Git ref (branch or tag) to download. Default: main.

.PARAMETER NoClaude
    Skip installing into ~/.claude/skills.

.PARAMETER NoCodex
    Skip installing into ~/.codex/skills.

.PARAMETER NoOpenCode
    Skip installing into ~/.config/opencode/skills.

.PARAMETER NoJunie
    Skip installing into ~/.junie/skills.

.EXAMPLE
    iwr -useb https://raw.githubusercontent.com/jmix-framework/jmix-agent-guidelines/main/install.ps1 | iex

.EXAMPLE
    & ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/jmix-framework/jmix-agent-guidelines/main/install.ps1).Content)) -NoCodex
#>
[CmdletBinding()]
param(
    [string]$Version = '2',
    [string]$Ref = 'main',
    [switch]$NoClaude,
    [switch]$NoCodex,
    [switch]$NoOpenCode,
    [switch]$NoJunie
)

$ErrorActionPreference = 'Stop'

$RepoOwner = 'jmix-framework'
$RepoName  = 'jmix-agent-guidelines'

function Write-Info {
    param([string]$Message)
    Write-Output $Message
}

function Write-ErrAndExit {
    param([string]$Message)
    [Console]::Error.WriteLine("error: $Message")
    exit 1
}

if ($NoClaude -and $NoCodex -and $NoOpenCode -and $NoJunie) {
    Write-ErrAndExit 'nothing to install (all -No* flags set)'
}

if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
    Write-ErrAndExit 'Expand-Archive not found. PowerShell 5+ is required.'
}

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("jmix-install-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging -Force | Out-Null

try {
    $archiveUrl = "https://codeload.github.com/$RepoOwner/$RepoName/zip/$Ref"
    $zipPath    = Join-Path $staging 'source.zip'

    Write-Info "Downloading $archiveUrl"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $archiveUrl -OutFile $zipPath
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        Write-ErrAndExit "failed to download $archiveUrl (HTTP $status)"
    }

    Expand-Archive -Path $zipPath -DestinationPath $staging -Force

    $extractedDir = Get-ChildItem -Path $staging -Directory |
        Where-Object { $_.Name -like "$RepoName-*" } |
        Select-Object -First 1

    if (-not $extractedDir) {
        Write-ErrAndExit "extracted source directory not found in $staging"
    }

    $sourceSkillsDir = Join-Path $extractedDir.FullName "v$Version/skills"
    if (-not (Test-Path $sourceSkillsDir -PathType Container)) {
        $available = (Get-ChildItem -Path $extractedDir.FullName -Directory | Select-Object -ExpandProperty Name) -join ' '
        Write-ErrAndExit "v$Version/skills/ not found in $Ref. Available top-level entries: $available"
    }

    $script:sourceSkillsDir = $sourceSkillsDir
    $script:timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')

    function Install-Skills {
        param(
            [string]$TargetDir,
            [string]$AgentLabel
        )

        Write-Info ''
        Write-Info "Installing skills for $AgentLabel into $TargetDir"

        try {
            if (-not (Test-Path $TargetDir)) {
                New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
            }
        } catch {
            Write-ErrAndExit "cannot write to ${TargetDir}: $($_.Exception.Message)"
        }

        $count = 0
        $skillDirs = Get-ChildItem -Path $script:sourceSkillsDir -Directory
        foreach ($skill in $skillDirs) {
            $name = $skill.Name
            $dest = Join-Path $TargetDir $name
            $backupName = "$name.bak-$script:timestamp"

            try {
                if (Test-Path $dest) {
                    Rename-Item -Path $dest -NewName $backupName -ErrorAction Stop
                    Copy-Item -Path $skill.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
                    Write-Info "  Updated: $name (backup: $backupName)"
                } else {
                    Copy-Item -Path $skill.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
                    Write-Info "  Installed: $name"
                }
            } catch {
                Write-ErrAndExit "cannot write to ${dest}: $($_.Exception.Message)"
            }

            $count++
        }

        Write-Info "  $count skill(s) processed for $AgentLabel"
    }

    $targets = @()
    if (-not $NoClaude) {
        Install-Skills -TargetDir (Join-Path $HOME '.claude/skills') -AgentLabel 'Claude'
        $targets += 'Claude'
    }
    if (-not $NoCodex) {
        Install-Skills -TargetDir (Join-Path $HOME '.codex/skills') -AgentLabel 'Codex'
        $targets += 'Codex'
    }
    if (-not $NoOpenCode) {
        Install-Skills -TargetDir (Join-Path $HOME '.config/opencode/skills') -AgentLabel 'OpenCode'
        $targets += 'OpenCode'
    }
    if (-not $NoJunie) {
        Install-Skills -TargetDir (Join-Path $HOME '.junie/skills') -AgentLabel 'Junie'
        $targets += 'Junie'
    }

    Write-Info ''
    Write-Info "Done. Installed skills for: $($targets -join ', ')"
}
finally {
    Remove-Item -Recurse -Force -Path $staging -ErrorAction SilentlyContinue
}
