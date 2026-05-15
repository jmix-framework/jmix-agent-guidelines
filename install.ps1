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
    Jmix version (e.g. 2, 2.8, 2.8.0). Optional. The script picks the
    best-matching guideline folder: exact -> major.minor -> major. If
    none of these match, or when omitted/empty, the latest available
    version is used (sorted by major, then minor, then patch).

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
    [string]$Version = '',
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

    function Get-VersionSortKey {
        param([string]$Version)
        $parts = $Version -split '[.-]'
        $key = ''
        for ($i = 0; $i -lt 5; $i++) {
            $segment = if ($i -lt $parts.Length) { $parts[$i] } else { '0' }
            $value = 0
            [void][int]::TryParse($segment, [ref]$value)
            $key += $value.ToString('00000')
        }
        return $key
    }

    function Find-LatestSkillsDir {
        param([string]$ExtractedDir)
        $bestKey = $null
        $bestPath = $null
        foreach ($dir in Get-ChildItem -Path $ExtractedDir -Directory) {
            if (-not $dir.Name.StartsWith('v')) { continue }
            $skillsPath = Join-Path $dir.FullName 'skills'
            if (-not (Test-Path $skillsPath -PathType Container)) { continue }
            $version = $dir.Name.Substring(1)
            if ([string]::IsNullOrEmpty($version)) { continue }
            $key = Get-VersionSortKey -Version $version
            if ($null -eq $bestKey -or [string]::Compare($key, $bestKey) -gt 0) {
                $bestKey = $key
                $bestPath = $skillsPath
            }
        }
        return $bestPath
    }

    # Returns [PSCustomObject] with Path + Status:
    #   Status = 'matched' (exact, major.minor, major, or no-version default)
    #   Status = 'fallback' (requested version did not match any tier; latest used)
    #   Status = 'none'    (no v*/skills dir exists)
    function Resolve-SkillsDir {
        param(
            [string]$ExtractedDir,
            [string]$Requested
        )

        if ([string]::IsNullOrWhiteSpace($Requested)) {
            $path = Find-LatestSkillsDir -ExtractedDir $ExtractedDir
            if ($path) {
                return [PSCustomObject]@{ Path = $path; Status = 'matched' }
            }
            return [PSCustomObject]@{ Path = $null; Status = 'none' }
        }

        $exact = Join-Path $ExtractedDir "v$Requested/skills"
        if (Test-Path $exact -PathType Container) {
            return [PSCustomObject]@{ Path = $exact; Status = 'matched' }
        }

        $parts = $Requested -split '[.-]'
        if ($parts.Length -ge 2 -and $parts[0] -ne '' -and $parts[1] -ne '') {
            $majorMinor = "$($parts[0]).$($parts[1])"
            if ($majorMinor -ne $Requested) {
                $candidate = Join-Path $ExtractedDir "v$majorMinor/skills"
                if (Test-Path $candidate -PathType Container) {
                    return [PSCustomObject]@{ Path = $candidate; Status = 'matched' }
                }
            }
        }

        if ($parts.Length -ge 1 -and $parts[0] -ne '') {
            $major = $parts[0]
            if ($major -ne $Requested) {
                $candidate = Join-Path $ExtractedDir "v$major/skills"
                if (Test-Path $candidate -PathType Container) {
                    return [PSCustomObject]@{ Path = $candidate; Status = 'matched' }
                }
            }
        }

        $fallback = Find-LatestSkillsDir -ExtractedDir $ExtractedDir
        if ($fallback) {
            return [PSCustomObject]@{ Path = $fallback; Status = 'fallback' }
        }
        return [PSCustomObject]@{ Path = $null; Status = 'none' }
    }

    $resolved = Resolve-SkillsDir -ExtractedDir $extractedDir.FullName -Requested $Version
    if ($resolved.Status -eq 'none' -or -not $resolved.Path) {
        $available = (Get-ChildItem -Path $extractedDir.FullName -Directory | Select-Object -ExpandProperty Name) -join ' '
        Write-ErrAndExit "no v*/skills directory found in $Ref. Available top-level entries: $available"
    }

    $sourceSkillsDir = $resolved.Path
    $resolvedVersionDir = Split-Path -Leaf (Split-Path -Parent $sourceSkillsDir)
    if ($resolved.Status -eq 'fallback') {
        Write-Info "Version '$Version' did not match any folder, falling back to latest available ($resolvedVersionDir)"
    }
    Write-Info "Using guidelines from $($sourceSkillsDir.Substring($extractedDir.FullName.Length + 1))"

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
