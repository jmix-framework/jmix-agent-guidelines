<#
.SYNOPSIS
    Jmix AI Agents Toolkit installer.

.DESCRIPTION
    Default invocation (no subcommand) launches an interactive wizard that
    guides through:
      1. Installing Jmix skills (globally or into the project) for one or all agents.
      2. Adding project-level guidelines (CLAUDE.md / AGENTS.md / .junie\guidelines.md).
      3. Registering the JetBrains MCP server with the agent.
      4. Registering the Context7 MCP server with the agent.

    Subcommands are available for non-interactive use:
      install.ps1 skills        -Agents CSV [-Scope global|local] [-Version V] [-Ref REF]
                                Installs skills into a canonical store once, then symlinks each
                                selected agent's skills dir to that store.
      install.ps1 agents-md     -Agents CSV [-Version V] [-Ref REF]
      install.ps1 mcp-jetbrains -Agents CSV
      install.ps1 mcp-context7  -Agents CSV [-Context7Key KEY]
      install.ps1 playwright    -Agents CSV   # requires npx (Node.js) on PATH

    Add -BackupExistingFiles to any subcommand to rename overwritten files/dirs
    to <name>.bak-<timestamp> instead of deleting them.

.PARAMETER Subcommand
    Optional subcommand. When omitted, the interactive wizard is started.

.PARAMETER Version
    Jmix version (e.g. 2, 2.8, 2.8.0). Optional. Best-matching folder is picked:
    exact -> major.minor -> major -> latest.

.PARAMETER Ref
    Git ref (branch or tag) to download. Default: main.

.PARAMETER Agents
    Comma-separated list of agents (e.g. "claude,codex"). Single value is also
    accepted (e.g. "claude"). Required by every subcommand. Valid values:
    claude, codex, opencode, junie.

.PARAMETER Scope
    Skills install scope: "global" (default) writes to the per-agent user-home
    dir; "local" writes to the matching dir under the current project (e.g.
    .\.claude\skills). Applies to the `skills` subcommand.

.PARAMETER Context7Key
    Context7 API key (mcp-context7). Prompted interactively when missing.

.PARAMETER BackupExistingFiles
    When set, an existing destination file or folder is renamed to
    <name>.bak-<timestamp> instead of being deleted before the new content is
    copied. Off by default.

.EXAMPLE
    iwr -useb https://raw.githubusercontent.com/jmix-framework/jmix-agent-guidelines/main/install.ps1 | iex

.EXAMPLE
    & ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/jmix-framework/jmix-agent-guidelines/main/install.ps1).Content)) skills -Agent claude
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Subcommand = '',
    [string]$Version = '',
    [string]$Ref = 'main',
    [string]$Agents = '',
    [string]$Scope = '',
    [string]$Context7Key = '',
    [switch]$BackupExistingFiles
)

$ErrorActionPreference = 'Stop'

$script:RepoOwner = 'jmix-framework'
$script:RepoName  = 'jmix-agent-guidelines'

$script:AllAgents       = @('claude', 'codex', 'opencode', 'junie')
$script:JetbrainsAgents = @('claude', 'codex', 'opencode', 'junie')
$script:Context7Agents  = @('claude', 'codex', 'opencode', 'junie')

$script:TarballReady     = $false
$script:Staging          = $null
$script:ExtractedDir     = $null
$script:SourceSkillsDir  = $null
$script:SourceAgentsMd   = $null
$script:ResolvedVersionDir = $null
$script:Timestamp        = (Get-Date).ToString('yyyyMMdd-HHmmss')

# =================================================================
# Helpers
# =================================================================

function Write-Info {
    param([string]$Message)
    Write-Output $Message
}

function Write-ErrAndExit {
    param([string]$Message)
    [Console]::Error.WriteLine("error: $Message")
    exit 1
}

function Test-Tool {
    param([string]$Tool)
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        Write-ErrAndExit "$Tool not found. Install it and re-run."
    }
}

# Ensures npx (Node.js) is on PATH. When missing, prints install guidance and
# exits (no automatic runtime install).
function Assert-Npx {
    if (Get-Command npx -ErrorAction SilentlyContinue) { return }
    Write-Info 'npx (Node.js) is required for the Playwright step but was not found on PATH.'
    Write-Info 'Install Node.js (includes npx), then re-run:'
    Write-Info '  Windows: winget install OpenJS.NodeJS   (or download from https://nodejs.org)'
    Write-ErrAndExit 'npx not available on PATH'
}

function Read-Prompt {
    param(
        [string]$Message,
        [string]$Default = ''
    )
    $hint = ''
    if ($Default) { $hint = " [$Default]" }
    $answer = Read-Host "$Message$hint"
    if ([string]::IsNullOrEmpty($answer) -and $Default) {
        return $Default
    }
    return $answer
}

function Read-YesNo {
    param(
        [string]$Message,
        [string]$Default = 'y'
    )
    $hint = if ($Default -eq 'n') { '[y/N]' } else { '[Y/n]' }
    $answer = Read-Prompt -Message "$Message $hint" -Default $Default
    return ($answer -match '^(y|yes)$')
}

function Get-AgentLabel {
    param([string]$Agent)
    switch ($Agent) {
        'claude'   { 'Claude Code' }
        'codex'    { 'Codex' }
        'opencode' { 'OpenCode' }
        'junie'    { 'Junie' }
        default    { $Agent }
    }
}

function Write-Dest {
    param(
        [string]$Src,
        [string]$Dest,
        [string]$Label
    )
    $existed = Test-Path $Dest
    $backupInfo = ''
    if ($existed) {
        if ($BackupExistingFiles) {
            $backupName = "$([System.IO.Path]::GetFileName($Dest)).bak-$($script:Timestamp)"
            Rename-Item -Path $Dest -NewName $backupName -ErrorAction Stop
            $backupInfo = " (backup: $backupName)"
        } else {
            Remove-Item -Path $Dest -Recurse -Force -ErrorAction Stop
        }
    }
    Copy-Item -Path $Src -Destination $Dest -Recurse -Force -ErrorAction Stop
    if ($existed) {
        Write-Info "  Updated: $Label$backupInfo"
    } else {
        Write-Info "  Installed: $Label"
    }
}

function Resolve-AgentsCsv {
    param(
        [string]$Csv,
        [string]$Subcommand
    )
    if ([string]::IsNullOrWhiteSpace($Csv)) {
        Write-ErrAndExit "${Subcommand}: -Agents is required (e.g. -Agents claude,codex)"
    }
    $known = @('claude', 'codex', 'opencode', 'junie')
    $tokens = $Csv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    $resolved = @()
    foreach ($t in $tokens) {
        if ($known -notcontains $t) {
            Write-ErrAndExit "unknown agent in -Agents: '$t'"
        }
        $resolved += $t
    }
    if ($resolved.Count -eq 0) {
        Write-ErrAndExit "${Subcommand}: -Agents resolved to an empty list"
    }
    return $resolved
}

# =================================================================
# Tarball + version resolution
# =================================================================

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
        $name = $dir.Name.Substring(1)
        if ([string]::IsNullOrEmpty($name)) { continue }
        $key = Get-VersionSortKey -Version $name
        if ($null -eq $bestKey -or [string]::Compare($key, $bestKey) -gt 0) {
            $bestKey = $key
            $bestPath = $skillsPath
        }
    }
    return $bestPath
}

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

function Initialize-Tarball {
    if ($script:TarballReady) { return }

    if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
        Write-ErrAndExit 'Expand-Archive not found. PowerShell 5+ is required.'
    }

    $script:Staging = Join-Path ([System.IO.Path]::GetTempPath()) ("jmix-install-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:Staging -Force | Out-Null

    $archiveUrl = "https://codeload.github.com/$($script:RepoOwner)/$($script:RepoName)/zip/$Ref"
    $zipPath    = Join-Path $script:Staging 'source.zip'

    Write-Info "Downloading $archiveUrl"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $archiveUrl -OutFile $zipPath
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        Write-ErrAndExit "failed to download $archiveUrl (HTTP $status)"
    }

    Expand-Archive -Path $zipPath -DestinationPath $script:Staging -Force

    $script:ExtractedDir = (Get-ChildItem -Path $script:Staging -Directory |
        Where-Object { $_.Name -like "$($script:RepoName)-*" } |
        Select-Object -First 1).FullName

    if (-not $script:ExtractedDir) {
        Write-ErrAndExit "extracted source directory not found in $($script:Staging)"
    }

    $resolved = Resolve-SkillsDir -ExtractedDir $script:ExtractedDir -Requested $Version
    if ($resolved.Status -eq 'none' -or -not $resolved.Path) {
        $available = (Get-ChildItem -Path $script:ExtractedDir -Directory | Select-Object -ExpandProperty Name) -join ' '
        Write-ErrAndExit "no v*/skills directory found in $Ref. Available top-level entries: $available"
    }

    $script:SourceSkillsDir = $resolved.Path
    $script:ResolvedVersionDir = Split-Path -Leaf (Split-Path -Parent $script:SourceSkillsDir)
    $script:SourceAgentsMd = Join-Path (Split-Path -Parent $script:SourceSkillsDir) 'AGENTS.md'

    if ($resolved.Status -eq 'fallback') {
        Write-Info "Version '$Version' did not match any folder, falling back to latest available ($($script:ResolvedVersionDir))"
    }
    Write-Info "Using guidelines from $($script:SourceSkillsDir.Substring($script:ExtractedDir.Length + 1))"

    $script:TarballReady = $true
}

# =================================================================
# skills install (global, per agent)
# =================================================================

function Resolve-Scope {
    param([string]$Scope)
    if ([string]::IsNullOrWhiteSpace($Scope)) { return 'global' }
    switch ($Scope) {
        'global' { return 'global' }
        'local'  { return 'local' }
        default  { Write-ErrAndExit "skills: -Scope must be 'global' or 'local' (got '$Scope')" }
    }
}

function Get-AgentSymlinkRel {
    param([string]$Agent)
    switch ($Agent) {
        'claude'   { '.claude/skills' }
        'codex'    { '.agents/skills' }
        'opencode' { '.agents/skills' }
        'junie'    { '.junie/skills' }
        default    { throw "unknown agent '$Agent'" }
    }
}

# Creates/refreshes a whole-dir symlink $Link -> $Target. Replaces an existing
# symlink; an existing real dir is backed up (when -BackupExistingFiles) or removed.
# Requires symlink privileges; fails with guidance otherwise.
function New-DirSymlink {
    param([string]$Link, [string]$Target)
    if (Test-Path $Link) {
        $item = Get-Item $Link -Force
        if ($item.LinkType) {
            Remove-Item $Link -Force
        } elseif ($BackupExistingFiles) {
            Rename-Item -Path $Link -NewName "$([System.IO.Path]::GetFileName($Link)).bak-$($script:Timestamp)"
        } else {
            Remove-Item $Link -Recurse -Force
        }
    }
    $parent = Split-Path -Parent $Link
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    try {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target -ErrorAction Stop | Out-Null
    } catch {
        Write-ErrAndExit "cannot create symlink $Link -> $Target. Enable Windows Developer Mode or run as Administrator to allow symlinks."
    }
}

function Install-SkillsToStore {
    param([string]$StoreDir)
    Write-Info ''
    Write-Info "Installing skills into store $StoreDir"
    if (-not (Test-Path $StoreDir)) { New-Item -ItemType Directory -Path $StoreDir -Force | Out-Null }
    foreach ($skill in Get-ChildItem -Path $script:SourceSkillsDir -Directory) {
        $dest = Join-Path $StoreDir $skill.Name
        Write-Dest -Src $skill.FullName -Dest $dest -Label $skill.Name
    }
}

# Per-skill symlinks: link each store skill folder into the agent skills dir,
# so Jmix skills coexist with other skills already present there.
function New-SkillSymlinks {
    param([string]$AgentDir, [string]$StoreDir)
    if (-not (Test-Path $AgentDir)) { New-Item -ItemType Directory -Path $AgentDir -Force | Out-Null }
    foreach ($skill in Get-ChildItem -Path $StoreDir -Directory) {
        $link = Join-Path $AgentDir $skill.Name
        New-DirSymlink -Link $link -Target $skill.FullName
    }
}

function Invoke-CmdSkills {
    $agents = Resolve-AgentsCsv -Csv $Agents -Subcommand 'skills'
    $resolvedScope = Resolve-Scope -Scope $Scope
    Initialize-Tarball

    if ($resolvedScope -eq 'local') {
        $root = (Get-Location).Path
        $storeDir = Join-Path $root '.skills'
    } else {
        $root = $HOME
        $storeDir = Join-Path $HOME (Join-Path '.agents/.jmix/skills' $script:ResolvedVersionDir)
    }

    Install-SkillsToStore -StoreDir $storeDir

    Write-Info ''
    Write-Info 'Linking store skills into agent dirs'
    $seen = @{}
    foreach ($a in $agents) {
        $rel = Get-AgentSymlinkRel -Agent $a
        if ($seen.ContainsKey($rel)) { continue }
        $seen[$rel] = $true
        $agentDir = Join-Path $root $rel
        New-SkillSymlinks -AgentDir $agentDir -StoreDir $storeDir
        Write-Info "  Linked skills into $agentDir"
    }

    Write-Info ''
    Write-Info "Done. Installed $resolvedScope skills store at $storeDir and linked: $($agents -join ', ')"
}

# =================================================================
# agents-md install (project-level)
# =================================================================

function Get-AgentsMdDest {
    param([string]$Agent)
    $proj = (Get-Location).Path
    switch ($Agent) {
        'claude'   { Join-Path $proj 'CLAUDE.md' }
        'codex'    { Join-Path $proj 'AGENTS.md' }
        'opencode' { Join-Path $proj 'AGENTS.md' }
        'junie'    { Join-Path $proj '.junie/guidelines.md' }
        default    { throw "unknown agent '$Agent'" }
    }
}

function Install-AgentsMdFor {
    param([string]$Agent)
    $dest = Get-AgentsMdDest -Agent $Agent
    $label = Get-AgentLabel -Agent $Agent

    if (-not (Test-Path $script:SourceAgentsMd)) {
        Write-ErrAndExit "AGENTS.md not found in $($script:ResolvedVersionDir)"
    }

    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Write-Dest -Src $script:SourceAgentsMd -Dest $dest -Label $dest
    Write-Info "  Project guidelines installed for $label"
}

function Invoke-CmdAgentsMd {
    $agents = Resolve-AgentsCsv -Csv $Agents -Subcommand 'agents-md'
    Write-Info "Project guidelines target directory: $((Get-Location).Path)"
    Initialize-Tarball
    foreach ($a in $agents) {
        Install-AgentsMdFor -Agent $a
    }
}

# =================================================================
# MCP install - JetBrains
# =================================================================

function Get-OpencodeConfigPath {
    $dir = Join-Path $HOME '.config/opencode'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $file = Join-Path $dir 'opencode.json'
    if (-not (Test-Path $file)) { '{}' | Out-File -FilePath $file -Encoding utf8 }
    return $file
}

function Set-OpencodeMcpEntry {
    param(
        [string]$Name,
        [hashtable]$Entry
    )
    $file = Get-OpencodeConfigPath
    $json = Get-Content -Raw -Path $file | ConvertFrom-Json -ErrorAction Stop
    if (-not $json.PSObject.Properties.Match('mcp')) {
        $json | Add-Member -MemberType NoteProperty -Name 'mcp' -Value (New-Object PSObject)
    }
    if ($json.mcp.PSObject.Properties.Match($Name)) {
        $json.mcp.PSObject.Properties.Remove($Name)
    }
    $json.mcp | Add-Member -MemberType NoteProperty -Name $Name -Value ([PSCustomObject]$Entry)
    $json | ConvertTo-Json -Depth 10 | Out-File -FilePath $file -Encoding utf8
    Write-Info "Updated $file with $Name MCP entry."
}

function Install-JetbrainsForClaude {
    Test-Tool -Tool 'claude'
    Write-Info 'Adding JetBrains MCP for Claude Code...'
    & claude mcp add --transport sse jetbrains --scope user http://localhost:64342/sse
}

function Install-JetbrainsForCodex {
    Test-Tool -Tool 'codex'
    Write-Info 'Adding JetBrains MCP for Codex (Streamable HTTP; requires IntelliJ 2026.1+)...'
    Write-Info 'For older IntelliJ versions, follow the STDIO setup in the README manually.'
    & codex mcp add jetbrains --url http://localhost:64342/stream
}

function Install-JetbrainsForOpencode {
    Set-OpencodeMcpEntry -Name 'jetbrains' -Entry @{
        type    = 'remote'
        url     = 'http://localhost:64342/sse'
        enabled = $true
    }
}

function Install-JetbrainsForJunie {
    Write-Info 'Junie runs inside IntelliJ and already has native IDE access. No JetBrains MCP needed.'
}

function Install-JetbrainsFor {
    param([string]$Agent)
    Write-Info ''
    Write-Info "[JetBrains MCP] $(Get-AgentLabel -Agent $Agent)"
    switch ($Agent) {
        'claude'   { Install-JetbrainsForClaude }
        'codex'    { Install-JetbrainsForCodex }
        'opencode' { Install-JetbrainsForOpencode }
        'junie'    { Install-JetbrainsForJunie }
        default    { throw "unknown agent '$Agent'" }
    }
}

function Invoke-CmdMcpJetbrains {
    $agents = Resolve-AgentsCsv -Csv $Agents -Subcommand 'mcp-jetbrains'
    foreach ($a in $agents) {
        try { Install-JetbrainsFor -Agent $a } catch { Write-Info "error: $($_.Exception.Message)" }
    }
}

# =================================================================
# MCP install - Context7
# =================================================================

function Install-Context7ForClaude {
    param([string]$Key)
    Test-Tool -Tool 'claude'
    Write-Info 'Adding Context7 MCP for Claude Code...'
    & claude mcp add context7 --scope user -- npx -y '@upstash/context7-mcp' --api-key $Key
}

function Install-Context7ForCodex {
    param([string]$Key)
    Test-Tool -Tool 'codex'
    Write-Info 'Adding Context7 MCP for Codex...'
    & codex mcp add context7 -- npx -y '@upstash/context7-mcp' --api-key $Key
}

function Install-Context7ForOpencode {
    param([string]$Key)
    Set-OpencodeMcpEntry -Name 'context7' -Entry @{
        type    = 'local'
        command = @('npx', '-y', '@upstash/context7-mcp', '--api-key', $Key)
        enabled = $true
    }
}

function Install-Context7ForJunie {
    param([string]$Key)
    Write-Info 'Junie does not support automated MCP setup.'
    Write-Info 'Open IntelliJ Settings -> Tools -> Junie -> MCP Settings, click Add, then paste:'
    Write-Output @"
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp", "--api-key", "$Key"]
    }
  }
}
"@
}

function Install-Context7For {
    param(
        [string]$Agent,
        [string]$Key
    )
    Write-Info ''
    Write-Info "[Context7 MCP] $(Get-AgentLabel -Agent $Agent)"
    switch ($Agent) {
        'claude'   { Install-Context7ForClaude -Key $Key }
        'codex'    { Install-Context7ForCodex -Key $Key }
        'opencode' { Install-Context7ForOpencode -Key $Key }
        'junie'    { Install-Context7ForJunie -Key $Key }
        default    { throw "unknown agent '$Agent'" }
    }
}

function Invoke-CmdMcpContext7 {
    $agents = Resolve-AgentsCsv -Csv $Agents -Subcommand 'mcp-context7'

    $apiKey = $Context7Key
    if (-not $apiKey) {
        $apiKey = Read-Prompt -Message 'Context7 API key' -Default ''
        if (-not $apiKey) { Write-ErrAndExit 'Context7 API key is required' }
    }

    foreach ($a in $agents) {
        try { Install-Context7For -Agent $a -Key $apiKey } catch { Write-Info "error: $($_.Exception.Message)" }
    }
}

# =================================================================
# Playwright install (npx @playwright/cli)
# =================================================================

function Install-PlaywrightForAgents {
    param([string[]]$Agents)

    Assert-Npx

    $claudeSkills = Join-Path $HOME '.claude/skills'
    if (-not (Test-Path $claudeSkills)) {
        New-Item -ItemType Directory -Path $claudeSkills -Force | Out-Null
    }

    $before = @()
    if (Test-Path $claudeSkills) {
        $before = Get-ChildItem -Path $claudeSkills -Directory | Select-Object -ExpandProperty Name
    }

    Write-Info 'Installing Playwright skills via npx (@playwright/cli)...'
    & npx -y '@playwright/cli@latest' install --skills
    if ($LASTEXITCODE -ne 0) {
        Write-ErrAndExit '@playwright/cli install --skills failed'
    }

    $after = Get-ChildItem -Path $claudeSkills -Directory | Select-Object -ExpandProperty Name
    $newSkills = $after | Where-Object { $before -notcontains $_ }

    if ($newSkills.Count -eq 0) {
        Write-Info "  No new skill folders detected in $claudeSkills."
    } else {
        Write-Info "  Playwright skill(s) installed in ${claudeSkills}: $($newSkills -join ' ')"
    }

    foreach ($agent in $Agents) {
        if ($agent -eq 'claude') { continue }
        $target = Join-Path $HOME (Get-AgentSymlinkRel -Agent $agent)
        if (-not (Test-Path $target)) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
        foreach ($skill in $newSkills) {
            $src = Join-Path $claudeSkills $skill
            if (-not (Test-Path $src)) { continue }
            $dest = Join-Path $target $skill
            Write-Dest -Src $src -Dest $dest -Label $dest
        }
    }

    Write-Info ''
    Write-Info "Done. Playwright skills installed for: $($Agents -join ', ')"
}

function Invoke-CmdPlaywright {
    $agents = Resolve-AgentsCsv -Csv $Agents -Subcommand 'playwright'
    Install-PlaywrightForAgents -Agents $agents
}

# =================================================================
# Wizard
# =================================================================

function Read-AgentChoice {
    param(
        [string]$Label,
        [string[]]$Options,
        [string]$Default = 'skip'
    )
    Write-Info ''
    Write-Info $Label
    Write-Output '  a) For all agents'
    $i = 1
    foreach ($opt in $Options) {
        Write-Output ("  {0}) {1}" -f $i, (Get-AgentLabel -Agent $opt))
        $i++
    }
    Write-Output '  s) Skip'

    $answer = Read-Prompt -Message 'Choice' -Default $Default
    if ($answer -match '^(s|skip)$') { return @('skip') }
    if ($answer -match '^(a|all)$') { return $Options }
    if ($answer -notmatch '^\d+$') {
        Write-Info "Unrecognized choice '$answer'. Skipping."
        return @('skip')
    }
    $num = [int]$answer
    if ($num -ge 1 -and $num -le $Options.Length) { return @($Options[$num - 1]) }
    Write-Info "Unrecognized choice '$answer'. Skipping."
    return @('skip')
}

function Invoke-Wizard {
    Write-Info '=== Jmix AI Agents Toolkit ==='
    if ($Version) { Write-Info "Jmix version: $Version" }
    Write-Info "Working directory: $((Get-Location).Path)"

    $summaryStrings = @{
        skills     = 'skipped'
        guidelines = 'skipped'
        jetbrains  = 'skipped'
        context7   = 'skipped'
        playwright = 'skipped'
    }

    # Step 1: skills
    $sel = Read-AgentChoice -Label '[1/5] Install Jmix skills?' -Options $script:AllAgents -Default 'all'
    if ($sel[0] -ne 'skip') {
        $scopeAnswer = Read-Prompt -Message 'Install scope: (l)ocal project dir or (g)lobal user home' -Default 'l'
        $resolvedScope = if ($scopeAnswer -match '^(g|global)$') { 'global' } else { 'local' }
        Initialize-Tarball
        try {
            if ($resolvedScope -eq 'local') {
                $wizRoot = (Get-Location).Path
                $wizStoreDir = Join-Path $wizRoot '.skills'
            } else {
                $wizRoot = $HOME
                $wizStoreDir = Join-Path $HOME (Join-Path '.agents/.jmix/skills' $script:ResolvedVersionDir)
            }
            Install-SkillsToStore -StoreDir $wizStoreDir
            Write-Info ''
            Write-Info 'Linking agent skill dirs to the store'
            $wizSeen = @{}
            foreach ($a in $sel) {
                $rel = Get-AgentSymlinkRel -Agent $a
                if ($wizSeen.ContainsKey($rel)) { continue }
                $wizSeen[$rel] = $true
                $agentDir = Join-Path $wizRoot $rel
                New-SkillSymlinks -AgentDir $agentDir -StoreDir $wizStoreDir
                Write-Info "  Linked skills into $agentDir"
            }
        } catch { Write-Info "error: $($_.Exception.Message)" }
        $summaryStrings.skills = "$($sel -join ', ') ($resolvedScope)"
    }

    # Step 2: agents-md
    $sel = Read-AgentChoice -Label '[2/5] Add Jmix coding guidelines to this directory?' -Options $script:AllAgents -Default 'all'
    if ($sel[0] -ne 'skip') {
        if (Read-YesNo -Message "Target directory: $((Get-Location).Path). Proceed?" -Default 'y') {
            Initialize-Tarball
            foreach ($a in $sel) {
                try { Install-AgentsMdFor -Agent $a } catch { Write-Info "error: $($_.Exception.Message)" }
            }
            $summaryStrings.guidelines = $sel -join ', '
        } else {
            $summaryStrings.guidelines = 'skipped (declined)'
        }
    }

    # Step 3: JetBrains MCP
    $sel = Read-AgentChoice -Label '[3/5] Connect agent to IntelliJ IDEA via JetBrains MCP?' -Options $script:JetbrainsAgents
    if ($sel[0] -ne 'skip') {
        foreach ($a in $sel) {
            try { Install-JetbrainsFor -Agent $a } catch { Write-Info "error: $($_.Exception.Message)" }
        }
        $summaryStrings.jetbrains = $sel -join ', '
    }

    # Step 4: Context7 MCP
    $sel = Read-AgentChoice -Label '[4/5] Connect agent to library docs via Context7 MCP?' -Options $script:Context7Agents
    if ($sel[0] -ne 'skip') {
        $apiKey = Read-Prompt -Message 'Context7 API key' -Default ''
        if ($apiKey) {
            foreach ($a in $sel) {
                try { Install-Context7For -Agent $a -Key $apiKey } catch { Write-Info "error: $($_.Exception.Message)" }
            }
            $summaryStrings.context7 = $sel -join ', '
        } else {
            Write-Info 'API key not provided, skipping Context7 setup.'
            $summaryStrings.context7 = 'skipped (no key)'
        }
    }

    # Step 5: Playwright
    $sel = Read-AgentChoice -Label '[5/5] Install Playwright? (requires npx)' -Options $script:AllAgents
    if ($sel[0] -ne 'skip') {
        try {
            Install-PlaywrightForAgents -Agents $sel
            $summaryStrings.playwright = $sel -join ', '
        } catch {
            Write-Info "error: $($_.Exception.Message)"
        }
    }

    Write-Info ''
    Write-Info '=== Setup complete ==='
    Write-Info "  Skills:      $($summaryStrings.skills)"
    Write-Info "  Guidelines:  $($summaryStrings.guidelines)"
    Write-Info "  JetBrains:   $($summaryStrings.jetbrains)"
    Write-Info "  Context7:    $($summaryStrings.context7)"
    Write-Info "  Playwright:  $($summaryStrings.playwright)"
}

# =================================================================
# Main dispatch
# =================================================================

try {
    switch ($Subcommand) {
        ''               { Invoke-Wizard }
        'skills'         { Invoke-CmdSkills }
        'agents-md'      { Invoke-CmdAgentsMd }
        'mcp-jetbrains'  { Invoke-CmdMcpJetbrains }
        'mcp-context7'   { Invoke-CmdMcpContext7 }
        'playwright'     { Invoke-CmdPlaywright }
        default          { Write-ErrAndExit "unknown subcommand: $Subcommand" }
    }
}
finally {
    if ($script:Staging -and (Test-Path $script:Staging)) {
        Remove-Item -Recurse -Force -Path $script:Staging -ErrorAction SilentlyContinue
    }
}
