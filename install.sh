#!/usr/bin/env bash
# Jmix AI Agents Toolkit installer.
#
# Default (no subcommand) launches an interactive wizard that guides through:
#   1. Installing Jmix skills (globally or into the project) for one or all agents.
#   2. Adding project-level guidelines (CLAUDE.md / AGENTS.md / .junie/guidelines.md).
#   3. Registering the JetBrains MCP server with the agent.
#   4. Registering the Context7 MCP server with the agent.
#
# Subcommands are available for non-interactive use; see `install.sh --help`.

set -euo pipefail

REPO_OWNER="jmix-framework"
REPO_NAME="jmix-agent-guidelines"

# Global state populated by ensure_tarball()
STAGING=""
# Temp dir for the Playwright install; global so the EXIT trap can clean it
# after cmd_playwright() returns (function locals are out of scope by then).
PW_STAGING=""
EXTRACTED_DIR=""
SOURCE_SKILLS_DIR=""
SOURCE_AGENTS_MD=""
RESOLVED_VERSION_DIR=""
TARBALL_READY=0

VERSION=""
REF="main"
BACKUP_EXISTING=0
VERBOSE=0

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

ALL_AGENTS="claude codex opencode junie"
JETBRAINS_AGENTS="claude codex opencode junie"
CONTEXT7_AGENTS="claude codex opencode junie"

# =================================================================
# Helpers
# =================================================================

log() {
    printf '%s\n' "$*"
}

err() {
    printf 'error: %s\n' "$*" >&2
}

die() {
    err "$*"
    exit 1
}

# Prints a diagnostic line to stderr, only when --verbose/--debug is set.
vlog() {
    [ "$VERBOSE" -eq 1 ] && printf '[debug] %s\n' "$*" >&2
    return 0
}

# Dumps environment + tool versions (verbose only) to help diagnose user issues.
debug_env() {
    [ "$VERBOSE" -eq 1 ] || return 0
    vlog "os: $(uname -a 2>/dev/null)"
    vlog "pwd: $(pwd -P 2>/dev/null)"
    vlog "HOME: ${HOME:-}"
    vlog "PATH: ${PATH:-}"
    vlog "bash: ${BASH_VERSION:-?}"
    vlog "curl: $(command -v curl 2>/dev/null || echo 'not found')"
    vlog "tar: $(command -v tar 2>/dev/null || echo 'not found')"
    vlog "git: $(git --version 2>/dev/null || echo 'not found')"
    vlog "node: $(node --version 2>/dev/null || echo 'not found')"
    vlog "npx: $(npx --version 2>/dev/null || echo 'not found')"
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || die "$1 not found. Install it and re-run."
}

# Ensures npx (Node.js) is on PATH. When missing, prints per-OS install guidance
# and exits (no automatic runtime install).
require_npx() {
    command -v npx >/dev/null 2>&1 && return 0
    err "npx (Node.js) is required for the Playwright step but was not found on PATH."
    err "Install Node.js (includes npx), then re-run:"
    case "$(uname -s 2>/dev/null)" in
        Darwin) err "  macOS:  brew install node    (or download from https://nodejs.org)" ;;
        Linux)  err "  Linux:  install via your package manager (e.g. 'sudo apt install nodejs npm') or download from https://nodejs.org" ;;
        *)      err "  See https://nodejs.org/en/download" ;;
    esac
    exit 1
}

# Replaces or installs $dest with a copy of $src. When BACKUP_EXISTING=1, an
# existing $dest is moved aside to <dest>.bak-<timestamp>; otherwise it is
# deleted. Prints a per-item log line.
# $1 - src path (file or dir)
# $2 - dest path
# $3 - short label shown in the log line
write_dest() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local existed=0
    [ -e "$dest" ] && existed=1
    local backup_info=""
    if [ "$existed" -eq 1 ]; then
        if [ "$BACKUP_EXISTING" -eq 1 ]; then
            local backup="${dest}.bak-${TIMESTAMP}"
            mv "$dest" "$backup" || die "cannot rename ${dest}"
            backup_info=" (backup: $(basename "$backup"))"
        else
            rm -rf "$dest" || die "cannot remove ${dest}"
        fi
    fi
    cp -R "$src" "$dest" || die "cannot copy to ${dest}"
    if [ "$existed" -eq 1 ]; then
        log "  Updated: ${label}${backup_info}"
    else
        log "  Installed: ${label}"
    fi
}

# Parses a comma-separated agents list. Single value (e.g. "claude") is allowed.
# Validates each token. Emits a space-separated list to stdout.
# $1 - csv string (may be empty)
# $2 - subcommand name for the error message
parse_agents_csv() {
    local csv="$1"
    local subcommand="$2"
    if [ -z "$csv" ]; then
        die "${subcommand}: --agents is required (e.g. --agents claude,codex)"
    fi
    local result=""
    local token
    for token in $(printf '%s' "$csv" | tr ',' ' ' | tr -s ' ' ' '); do
        case "$token" in
            claude|codex|opencode|junie) result="${result} ${token}" ;;
            "") ;;
            *) die "unknown agent in --agents: '$token'" ;;
        esac
    done
    result="$(printf '%s' "$result" | sed 's/^ //;s/ $//')"
    [ -n "$result" ] || die "${subcommand}: --agents resolved to an empty list"
    printf '%s' "$result"
}

# Reads a line from /dev/tty so prompts work under `curl ... | bash`.
# Falls back to the supplied default when no TTY is available.
prompt() {
    local message="$1"
    local default="${2:-}"
    local hint=""
    [ -n "$default" ] && hint=" [${default}]"

    # Subshell with stderr silenced so /dev/tty redirection errors stay quiet
    # in headless environments.
    local answer
    answer="$(
        exec 2>/dev/null
        if printf '%s%s: ' "$message" "$hint" >/dev/tty; then
            local ans=""
            IFS= read -r ans </dev/tty || ans=""
            printf '%s' "$ans"
        fi
    )"

    if [ -z "$answer" ] && [ -n "$default" ]; then
        answer="$default"
    fi
    printf '%s' "$answer"
}

prompt_yes_no() {
    local message="$1"
    local default="${2:-y}"
    local hint="[Y/n]"
    [ "$default" = "n" ] && hint="[y/N]"
    local answer
    answer="$(prompt "$message $hint" "$default")"
    case "$answer" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

usage() {
    cat <<'EOF'
Jmix AI Agents Toolkit installer.

Usage:
  install.sh [--version V] [--ref REF]                           # interactive wizard
  install.sh skills        [--agents CSV] [--scope global|local]   # install skills into the canonical store and symlink agent dirs
  install.sh agents-md     [options]                             # install project guidelines
  install.sh mcp-jetbrains [options]                             # register JetBrains MCP
  install.sh mcp-context7  [options] [--context7-key KEY]        # register Context7 MCP
  install.sh playwright    [options]                             # install Playwright

Common options:
  --version V                Jmix version (e.g. 2.8.0). Optional. Best-matching
                             folder is picked: exact -> major.minor -> major ->
                             latest.
  --ref REF                  Git ref to download (default: main).
  --agents CSV               Comma-separated agent list. Accepts a single value
                             too (e.g. "claude" or "claude,codex"). Required by
                             every subcommand. Valid values:
                             claude, codex, opencode, junie.
  --backup-existing-files    Rename overwritten files/dirs to
                             <name>.bak-<timestamp> instead of deleting them.
                             Off by default.
  --verbose, --debug         Print extra diagnostic output (OS, PATH, resolved
                             paths, tool versions) to help troubleshoot problems.
  -h, --help                 Show this help.

skills options:
  --scope global|local   Where to install skills. "global" (default) writes to
                         the per-agent user-home dir; "local" writes to the
                         matching dir under the current project (e.g.
                         ./.claude/skills).

mcp-context7 options:
  --context7-key K   Context7 API key. Prompted interactively when missing.

playwright options:
  (uses common --agents flag; requires `npx` (Node.js) on PATH)
EOF
}

# =================================================================
# Tarball + version resolution
# =================================================================

version_sort_key() {
    printf '%s' "$1" | awk -F'[.-]' '{
        for (i = 1; i <= 5; i++) {
            v = (i <= NF) ? $i : 0
            if (v ~ /^[0-9]+$/) printf "%05d", v
            else printf "%05d", 0
        }
        print ""
    }'
}

find_latest_skills_dir() {
    local extracted="$1"
    local best_key=""
    local best_path=""
    for dir in "$extracted"/v*/; do
        [ -d "${dir}skills" ] || continue
        local name="${dir%/}"
        name="${name##*/v}"
        [ -n "$name" ] || continue
        local key
        key="$(version_sort_key "$name")"
        if [ -z "$best_key" ] || [ "$key" \> "$best_key" ]; then
            best_key="$key"
            best_path="${dir}skills"
        fi
    done
    [ -n "$best_path" ] || return 1
    printf '%s\n' "$best_path"
}

# Resolves skills dir using tiered match (exact, major.minor, major) with
# latest-version fallback. Exit codes:
#   0 - matched (or no-version default)
#   2 - fallback used (requested didn't match any tier)
#   1 - no v*/skills dir found
resolve_skills_dir() {
    local extracted="$1"
    local requested="$2"

    if [ -z "$requested" ]; then
        find_latest_skills_dir "$extracted"
        return $?
    fi

    if [ -d "${extracted}/v${requested}/skills" ]; then
        printf '%s\n' "${extracted}/v${requested}/skills"
        return 0
    fi

    local major_minor
    major_minor="$(printf '%s' "$requested" | awk -F'[.-]' '{ if (NF >= 2 && $1 != "" && $2 != "") print $1"."$2 }')"
    if [ -n "$major_minor" ] && [ "$major_minor" != "$requested" ] && [ -d "${extracted}/v${major_minor}/skills" ]; then
        printf '%s\n' "${extracted}/v${major_minor}/skills"
        return 0
    fi

    local major
    major="$(printf '%s' "$requested" | awk -F'[.-]' '{print $1}')"
    if [ -n "$major" ] && [ "$major" != "$requested" ] && [ -d "${extracted}/v${major}/skills" ]; then
        printf '%s\n' "${extracted}/v${major}/skills"
        return 0
    fi

    local fallback_path
    fallback_path="$(find_latest_skills_dir "$extracted")" || return 1
    printf '%s\n' "$fallback_path"
    return 2
}

# Downloads and extracts the tarball, resolves the version folder, and populates
# SOURCE_SKILLS_DIR / SOURCE_AGENTS_MD / RESOLVED_VERSION_DIR. Idempotent.
ensure_tarball() {
    [ "$TARBALL_READY" -eq 1 ] && return 0

    require_tool curl
    require_tool tar

    STAGING="$(mktemp -d 2>/dev/null || mktemp -d -t jmix-install)"
    trap 'rm -rf "$STAGING"' INT TERM EXIT

    local tarball_url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${REF}"
    local tarball_path="${STAGING}/source.tar.gz"
    vlog "staging dir: ${STAGING}"
    vlog "requested version: '${VERSION}', ref: '${REF}'"

    log "Downloading ${tarball_url}"
    local http_status
    http_status="$(curl -sSL --retry 3 --retry-delay 2 --connect-timeout 30 --max-time 300 -w '%{http_code}' -o "$tarball_path" "$tarball_url" || echo "000")"
    if [ "$http_status" != "200" ]; then
        die "failed to download ${tarball_url} (HTTP ${http_status})"
    fi

    tar -xzf "$tarball_path" -C "$STAGING"
    EXTRACTED_DIR="$(find "$STAGING" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n 1)"
    [ -n "$EXTRACTED_DIR" ] || die "extracted source directory not found in ${STAGING}"

    local resolve_status=0
    SOURCE_SKILLS_DIR="$(resolve_skills_dir "$EXTRACTED_DIR" "$VERSION")" || resolve_status=$?
    if [ "$resolve_status" -eq 1 ] || [ -z "$SOURCE_SKILLS_DIR" ]; then
        local available
        available="$(find "$EXTRACTED_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | tr '\n' ' ')"
        die "no v*/skills directory found in ${REF}. Available top-level entries: ${available}"
    fi

    RESOLVED_VERSION_DIR="$(basename "$(dirname "$SOURCE_SKILLS_DIR")")"
    SOURCE_AGENTS_MD="$(dirname "$SOURCE_SKILLS_DIR")/AGENTS.md"
    vlog "extracted dir: ${EXTRACTED_DIR}"
    vlog "resolved version dir: ${RESOLVED_VERSION_DIR}"
    vlog "source skills dir: ${SOURCE_SKILLS_DIR}"

    if [ "$resolve_status" -eq 2 ]; then
        log "Version '${VERSION}' did not match any folder, falling back to latest available (${RESOLVED_VERSION_DIR})"
    fi
    log "Using guidelines from ${SOURCE_SKILLS_DIR#"${EXTRACTED_DIR}"/}"

    TARBALL_READY=1
}

# =================================================================
# skills install (global, per agent)
# =================================================================

# Validates the install scope. Emits the normalized value ("global"/"local").
# $1 - raw scope string (may be empty -> defaults to global)
parse_scope() {
    case "${1:-global}" in
        global|local) printf '%s' "${1:-global}" ;;
        *) die "skills: --scope must be 'global' or 'local' (got '$1')" ;;
    esac
}

# Relative skills dir each agent reads, used as a whole-dir symlink to the store.
# claude -> .claude/skills ; codex & opencode -> .agents/skills (open standard) ;
# junie -> .junie/skills. Rooted at $HOME (global) or the project dir (local).
agent_symlink_rel() {
    case "$1" in
        claude)            printf '.claude/skills' ;;
        codex|opencode)    printf '.agents/skills' ;;
        junie)             printf '.junie/skills' ;;
        *) die "unknown agent '$1'" ;;
    esac
}

# Removes a path only when it is a dangling (broken) symlink, so a later
# `mkdir -p` does not fail with ENOENT on macOS/BSD when a path component points
# at a missing target (e.g. a leftover ~/.junie symlink). A symlink that resolves
# to an existing directory is left untouched.
clear_dangling_symlink() {
    local p="$1"
    [ -L "$p" ] && [ ! -e "$p" ] || return 0
    if [ "$BACKUP_EXISTING" -eq 1 ]; then
        mv "$p" "${p}.bak-${TIMESTAMP}" 2>/dev/null || rm -f "$p"
    else
        rm -f "$p"
    fi
}

# Creates (or refreshes) a whole-dir symlink $1 -> $2. Replaces an existing
# symlink; an existing real dir is backed up (when --backup-existing-files) or
# removed. Requires symlink support; fails otherwise.
create_symlink() {
    local link="$1"
    local target="$2"
    if [ -L "$link" ]; then
        rm -f "$link" || die "cannot replace symlink ${link}"
    elif [ -e "$link" ]; then
        if [ "$BACKUP_EXISTING" -eq 1 ]; then
            mv "$link" "${link}.bak-${TIMESTAMP}" || die "cannot back up ${link}"
        else
            rm -rf "$link" || die "cannot remove ${link}"
        fi
    fi
    mkdir -p "$(dirname "$link")" || die "cannot create parent of ${link}"
    ln -s "$target" "$link" \
        || die "cannot create symlink ${link} -> ${target}. Your filesystem/OS may not permit symlinks."
}

# Copies each source skill folder into the canonical store (overwrite or backup
# via write_dest).
install_skills_to_store() {
    local store_dir="$1"
    log ""
    log "Installing skills into store ${store_dir}"
    mkdir -p "$store_dir" || die "cannot create store ${store_dir}"
    local skill name dest
    for skill in "$SOURCE_SKILLS_DIR"/*/; do
        [ -d "$skill" ] || continue
        name="$(basename "$skill")"
        dest="${store_dir}/${name}"
        write_dest "$skill" "$dest" "$name"
    done
}

# Per-skill symlinks: link each store skill folder into the agent skills dir,
# so Jmix skills coexist with other skills already present there.
# $1 - agent skills dir (kept as a real dir)
# $2 - store dir holding the skill folders
link_skills_into_dir() {
    local agent_dir="$1"
    local store_dir="$2"
    # Clear a broken-symlink agent base/dir (e.g. ~/.junie -> missing) so mkdir works.
    clear_dangling_symlink "$(dirname "$agent_dir")"
    clear_dangling_symlink "$agent_dir"
    mkdir -p "$agent_dir" || die "cannot create ${agent_dir}"
    local skill name
    for skill in "$store_dir"/*/; do
        [ -d "$skill" ] || continue
        name="$(basename "$skill")"
        create_symlink "${agent_dir}/${name}" "${store_dir}/${name}"
    done
}

agent_label() {
    case "$1" in
        claude)   printf 'Claude Code' ;;
        codex)    printf 'Codex' ;;
        opencode) printf 'OpenCode' ;;
        junie)    printf 'Junie' ;;
        *) printf '%s' "$1" ;;
    esac
}

cmd_skills() {
    local agents_csv=""
    local scope="global"

    local _argc=-1
    while [ $# -gt 0 ]; do
        [ "$#" -ne "$_argc" ] || die "argument parser made no progress near: $1"
        _argc=$#
        case "$1" in
            --agents)
                [ $# -ge 2 ] || die "--agents requires an argument"
                agents_csv="$2"; shift 2 ;;
            --scope)
                [ $# -ge 2 ] || die "--scope requires an argument"
                scope="$2"; shift 2 ;;
            --backup-existing-files)
                BACKUP_EXISTING=1; shift ;;
            --version)
                [ $# -ge 2 ] || die "--version requires an argument"
                VERSION="$2"; shift 2 ;;
            --ref)
                [ $# -ge 2 ] || die "--ref requires an argument"
                REF="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local agents
    agents="$(parse_agents_csv "$agents_csv" "skills")"
    scope="$(parse_scope "$scope")"

    ensure_tarball

    local root store_dir
    if [ "$scope" = "local" ]; then
        root="$(pwd -P)"
        store_dir="${root}/.skills"
    else
        root="${HOME}"
        store_dir="${HOME}/.agents/.jmix/skills/${RESOLVED_VERSION_DIR}"
    fi

    vlog "scope=${scope} root=${root} store=${store_dir}"
    install_skills_to_store "$store_dir"

    log ""
    log "Linking store skills into agent dirs"
    local agent rel agent_dir seen=" "
    for agent in $agents; do
        rel="$(agent_symlink_rel "$agent")"
        case "$seen" in
            *" ${rel} "*) continue ;;
        esac
        seen="${seen}${rel} "
        agent_dir="${root}/${rel}"
        link_skills_into_dir "$agent_dir" "$store_dir"
        log "  Linked skills into ${agent_dir}"
    done

    log ""
    log "Done. Installed ${scope} skills store at ${store_dir} and linked: $(printf '%s' "$agents" | tr ' ' ',' | sed 's/,/, /g')"
}

# =================================================================
# agents-md install (project-level)
# =================================================================

agents_md_dest_for_agent() {
    local agent="$1"
    local pwd_
    pwd_="$(pwd -P)"
    case "$agent" in
        claude)   printf '%s/CLAUDE.md' "$pwd_" ;;
        codex)    printf '%s/AGENTS.md' "$pwd_" ;;
        opencode) printf '%s/AGENTS.md' "$pwd_" ;;
        junie)    printf '%s/.junie/guidelines.md' "$pwd_" ;;
        *) die "unknown agent '$1'" ;;
    esac
}

install_agents_md_for() {
    local agent="$1"
    local dest
    dest="$(agents_md_dest_for_agent "$agent")"
    local label
    label="$(agent_label "$agent")"

    [ -f "$SOURCE_AGENTS_MD" ] || die "AGENTS.md not found in ${RESOLVED_VERSION_DIR}"

    local dest_dir
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir" || die "cannot create directory ${dest_dir}"

    write_dest "$SOURCE_AGENTS_MD" "$dest" "$dest"
    log "  Project guidelines installed for ${label}"
}

cmd_agents_md() {
    local agents_csv=""

    local _argc=-1
    while [ $# -gt 0 ]; do
        [ "$#" -ne "$_argc" ] || die "argument parser made no progress near: $1"
        _argc=$#
        case "$1" in
            --agents)
                [ $# -ge 2 ] || die "--agents requires an argument"
                agents_csv="$2"; shift 2 ;;
            --backup-existing-files)
                BACKUP_EXISTING=1; shift ;;
            --version)
                [ $# -ge 2 ] || die "--version requires an argument"
                VERSION="$2"; shift 2 ;;
            --ref)
                [ $# -ge 2 ] || die "--ref requires an argument"
                REF="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local agents
    agents="$(parse_agents_csv "$agents_csv" "agents-md")"

    log "Project guidelines target directory: $(pwd -P)"
    ensure_tarball

    local agent
    for agent in $agents; do
        install_agents_md_for "$agent"
    done
}

# =================================================================
# MCP install - JetBrains
# =================================================================

mcp_jetbrains_for_claude() {
    require_tool claude
    log "Adding JetBrains MCP for Claude Code..."
    claude mcp add --transport sse jetbrains --scope user http://localhost:64342/sse
}

mcp_jetbrains_for_codex() {
    require_tool codex
    log "Adding JetBrains MCP for Codex (Streamable HTTP; requires IntelliJ 2026.1+)..."
    log "For older IntelliJ versions, follow the STDIO setup in the README manually."
    codex mcp add jetbrains --url http://localhost:64342/stream
}

mcp_jetbrains_for_opencode() {
    local config_dir="${HOME}/.config/opencode"
    local config_file="${config_dir}/opencode.json"
    mkdir -p "$config_dir"
    [ -f "$config_file" ] || echo '{}' > "$config_file"

    if ! command -v jq >/dev/null 2>&1; then
        log "OpenCode requires jq to edit ${config_file}. Add this block manually:"
        cat <<'EOF'
  "mcp": {
    "jetbrains": {
      "type": "remote",
      "url": "http://localhost:64342/sse",
      "enabled": true
    }
  }
EOF
        return 1
    fi

    local tmp
    tmp="$(mktemp)"
    jq '.mcp = (.mcp // {}) | .mcp.jetbrains = {"type":"remote","url":"http://localhost:64342/sse","enabled":true}' "$config_file" > "$tmp"
    mv "$tmp" "$config_file"
    log "Updated ${config_file} with JetBrains MCP entry."
}

mcp_jetbrains_for_junie() {
    log "Junie runs inside IntelliJ and already has native IDE access. No JetBrains MCP needed."
}

install_jetbrains_for() {
    local agent="$1"
    log ""
    log "[JetBrains MCP] $(agent_label "$agent")"
    case "$agent" in
        claude)   mcp_jetbrains_for_claude ;;
        codex)    mcp_jetbrains_for_codex ;;
        opencode) mcp_jetbrains_for_opencode ;;
        junie)    mcp_jetbrains_for_junie ;;
        *) die "unknown agent '$1'" ;;
    esac
}

cmd_mcp_jetbrains() {
    local agents_csv=""

    local _argc=-1
    while [ $# -gt 0 ]; do
        [ "$#" -ne "$_argc" ] || die "argument parser made no progress near: $1"
        _argc=$#
        case "$1" in
            --agents)
                [ $# -ge 2 ] || die "--agents requires an argument"
                agents_csv="$2"; shift 2 ;;
            --backup-existing-files)
                BACKUP_EXISTING=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local agents
    agents="$(parse_agents_csv "$agents_csv" "mcp-jetbrains")"

    local agent rc=0
    for agent in $agents; do
        install_jetbrains_for "$agent" || rc=1
    done
    return $rc
}

# =================================================================
# MCP install - Context7
# =================================================================

mcp_context7_for_claude() {
    local key="$1"
    require_tool claude
    log "Adding Context7 MCP for Claude Code..."
    claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp --api-key "$key"
}

mcp_context7_for_codex() {
    local key="$1"
    require_tool codex
    log "Adding Context7 MCP for Codex..."
    codex mcp add context7 -- npx -y @upstash/context7-mcp --api-key "$key"
}

mcp_context7_for_opencode() {
    local key="$1"
    local config_dir="${HOME}/.config/opencode"
    local config_file="${config_dir}/opencode.json"
    mkdir -p "$config_dir"
    [ -f "$config_file" ] || echo '{}' > "$config_file"

    if ! command -v jq >/dev/null 2>&1; then
        log "OpenCode requires jq to edit ${config_file}. Add this block manually:"
        cat <<EOF
  "mcp": {
    "context7": {
      "type": "local",
      "command": ["npx", "-y", "@upstash/context7-mcp", "--api-key", "${key}"],
      "enabled": true
    }
  }
EOF
        return 1
    fi

    local tmp
    tmp="$(mktemp)"
    jq --arg key "$key" '.mcp = (.mcp // {}) | .mcp.context7 = {"type":"local","command":["npx","-y","@upstash/context7-mcp","--api-key",$key],"enabled":true}' "$config_file" > "$tmp"
    mv "$tmp" "$config_file"
    log "Updated ${config_file} with Context7 MCP entry."
}

mcp_context7_for_junie() {
    local key="$1"
    log "Junie does not support automated MCP setup."
    log "Open IntelliJ Settings -> Tools -> Junie -> MCP Settings, click Add, then paste:"
    cat <<EOF
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp", "--api-key", "${key}"]
    }
  }
}
EOF
}

install_context7_for() {
    local agent="$1"
    local key="$2"
    log ""
    log "[Context7 MCP] $(agent_label "$agent")"
    case "$agent" in
        claude)   mcp_context7_for_claude "$key" ;;
        codex)    mcp_context7_for_codex "$key" ;;
        opencode) mcp_context7_for_opencode "$key" ;;
        junie)    mcp_context7_for_junie "$key" ;;
        *) die "unknown agent '$1'" ;;
    esac
}

cmd_mcp_context7() {
    local agents_csv=""
    local key=""

    local _argc=-1
    while [ $# -gt 0 ]; do
        [ "$#" -ne "$_argc" ] || die "argument parser made no progress near: $1"
        _argc=$#
        case "$1" in
            --agents)
                [ $# -ge 2 ] || die "--agents requires an argument"
                agents_csv="$2"; shift 2 ;;
            --backup-existing-files)
                BACKUP_EXISTING=1; shift ;;
            --context7-key)
                [ $# -ge 2 ] || die "--context7-key requires an argument"
                key="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local agents
    agents="$(parse_agents_csv "$agents_csv" "mcp-context7")"

    if [ -z "$key" ]; then
        key="$(prompt 'Context7 API key' '')"
        [ -n "$key" ] || die "Context7 API key is required"
    fi

    local agent rc=0
    for agent in $agents; do
        install_context7_for "$agent" "$key" || rc=1
    done
    return $rc
}

# =================================================================
# Playwright install (npx @playwright/cli)
# =================================================================

cmd_playwright() {
    local agents_csv=""
    local _argc=-1
    while [ $# -gt 0 ]; do
        [ "$#" -ne "$_argc" ] || die "argument parser made no progress near: $1"
        _argc=$#
        case "$1" in
            --agents)
                [ $# -ge 2 ] || die "--agents requires an argument"
                agents_csv="$2"; shift 2 ;;
            --backup-existing-files)
                BACKUP_EXISTING=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local agents
    agents="$(parse_agents_csv "$agents_csv" "playwright")"

    require_npx

    # Playwright skills always install globally. Mirror the Jmix model: copy the
    # skills into a canonical store, then per-skill symlink them into each agent
    # skills dir so they coexist with other skills already present there.
    local root="${HOME}"
    local store_dir="${HOME}/.agents/.playwright/skills"

    # @playwright/cli install --skills writes to <cwd>/.claude/skills/<skill>.
    # Run it inside a private staging dir so nothing leaks into the project or a
    # real agent dir, then copy the produced skill folders into the store.
    PW_STAGING="$(mktemp -d 2>/dev/null || mktemp -d -t jmix-playwright)" \
        || die "cannot create temp dir for Playwright install"
    trap 'rm -rf ${PW_STAGING:+"$PW_STAGING"} ${STAGING:+"$STAGING"}' INT TERM EXIT

    log "Installing Playwright skills via npx (@playwright/cli)..."
    ( cd "$PW_STAGING" && npx -y @playwright/cli@latest install --skills ) \
        || die "@playwright/cli install --skills failed"

    local produced="${PW_STAGING}/.claude/skills"
    [ -d "$produced" ] || die "@playwright/cli produced no skills under ${produced}"

    log ""
    log "Installing Playwright skills into store ${store_dir}"
    mkdir -p "$store_dir" || die "cannot create store ${store_dir}"
    local skill name dest count=0
    for skill in "$produced"/*/; do
        [ -d "$skill" ] || continue
        name="$(basename "$skill")"
        dest="${store_dir}/${name}"
        write_dest "$skill" "$dest" "$name"
        count=$((count + 1))
    done
    [ "$count" -gt 0 ] || die "no Playwright skill folders found under ${produced}"

    log ""
    log "Linking store skills into agent dirs"
    local agent rel agent_dir seen=" "
    for agent in $agents; do
        rel="$(agent_symlink_rel "$agent")"
        case "$seen" in
            *" ${rel} "*) continue ;;
        esac
        seen="${seen}${rel} "
        agent_dir="${root}/${rel}"
        link_skills_into_dir "$agent_dir" "$store_dir"
        log "  Linked skills into ${agent_dir}"
    done

    log ""
    log "Done. Installed Playwright skills store at ${store_dir} and linked: $(printf '%s' "$agents" | tr ' ' ',' | sed 's/,/, /g')"
}

# =================================================================
# Wizard
# =================================================================

wizard_pick_agent() {
    local default_choice="$1"
    shift
    local prompt_label="$1"
    shift
    local options="$*"

    {
        log ""
        log "$prompt_label"
        printf '  a) For all agents\n'
        local i=1
        local opt
        for opt in $options; do
            printf '  %d) %s\n' "$i" "$(agent_label "$opt")"
            i=$((i + 1))
        done
        printf '  s) Skip\n'
    } >&2

    local answer
    answer="$(prompt 'Choice' "$default_choice")"
    case "$answer" in
        s|S|skip|SKIP) printf 'skip'; return 0 ;;
        a|A|all|ALL) printf '%s' "$options"; return 0 ;;
    esac
    if ! printf '%s' "$answer" | grep -Eq '^[0-9]+$'; then
        log "Unrecognized choice '${answer}'. Skipping." >&2
        printf 'skip'
        return 0
    fi
    local idx=1
    for opt in $options; do
        if [ "$idx" -eq "$answer" ]; then
            printf '%s' "$opt"
            return 0
        fi
        idx=$((idx + 1))
    done
    log "Unrecognized choice '${answer}'. Skipping." >&2
    printf 'skip'
}

cmd_wizard() {
    local _argc=-1
    while [ $# -gt 0 ]; do
        [ "$#" -ne "$_argc" ] || die "argument parser made no progress near: $1"
        _argc=$#
        case "$1" in
            --version)
                [ $# -ge 2 ] || die "--version requires an argument"
                VERSION="$2"; shift 2 ;;
            --ref)
                [ $# -ge 2 ] || die "--ref requires an argument"
                REF="$2"; shift 2 ;;
            --backup-existing-files)
                BACKUP_EXISTING=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    log "=== Jmix AI Agents Toolkit ==="
    [ -n "$VERSION" ] && log "Jmix version: ${VERSION}"
    log "Working directory: $(pwd -P)"

    local summary_skills="skipped"
    local summary_guidelines="skipped"
    local summary_jetbrains="skipped"
    local summary_context7="skipped"
    local summary_playwright="skipped"

    # Step 1: skills
    local sel
    sel="$(wizard_pick_agent all '[1/5] Install Jmix skills?' "$ALL_AGENTS")"
    if [ "$sel" != "skip" ]; then
        local scope_answer scope="local"
        scope_answer="$(prompt 'Install scope: (l)ocal project dir or (g)lobal user home' 'l')"
        case "$scope_answer" in g|G|global|GLOBAL) scope="global" ;; esac
        ensure_tarball
        local root store_dir
        if [ "$scope" = "local" ]; then
            root="$(pwd -P)"; store_dir="${root}/.skills"
        else
            root="${HOME}"; store_dir="${HOME}/.agents/.jmix/skills/${RESOLVED_VERSION_DIR}"
        fi
        install_skills_to_store "$store_dir" || true
        local agent rel agent_dir seen=" "
        for agent in $sel; do
            rel="$(agent_symlink_rel "$agent")"
            case "$seen" in *" ${rel} "*) continue ;; esac
            seen="${seen}${rel} "
            agent_dir="${root}/${rel}"
            link_skills_into_dir "$agent_dir" "$store_dir" || true
        done
        summary_skills="$sel (${scope})"
    fi

    # Step 2: agents-md
    sel="$(wizard_pick_agent all '[2/5] Add Jmix coding guidelines to this directory?' "$ALL_AGENTS")"
    if [ "$sel" != "skip" ]; then
        if prompt_yes_no "Target directory: $(pwd -P). Proceed?" "y"; then
            ensure_tarball
            local agent
            for agent in $sel; do
                install_agents_md_for "$agent" || true
            done
            summary_guidelines="$sel"
        else
            summary_guidelines="skipped (declined)"
        fi
    fi

    # Step 3: JetBrains MCP
    sel="$(wizard_pick_agent skip '[3/5] Connect agent to IntelliJ IDEA via JetBrains MCP?' "$JETBRAINS_AGENTS")"
    if [ "$sel" != "skip" ]; then
        local agent
        for agent in $sel; do
            install_jetbrains_for "$agent" || true
        done
        summary_jetbrains="$sel"
    fi

    # Step 4: Context7 MCP
    sel="$(wizard_pick_agent skip '[4/5] Connect agent to library docs via Context7 MCP?' "$CONTEXT7_AGENTS")"
    if [ "$sel" != "skip" ]; then
        local key
        key="$(prompt 'Context7 API key' '')"
        if [ -n "$key" ]; then
            local agent
            for agent in $sel; do
                install_context7_for "$agent" "$key" || true
            done
            summary_context7="$sel"
        else
            log "API key not provided, skipping Context7 setup."
            summary_context7="skipped (no key)"
        fi
    fi

    # Step 5: Playwright
    sel="$(wizard_pick_agent skip '[5/5] Install Playwright? (requires npx)' "$ALL_AGENTS")"
    if [ "$sel" != "skip" ]; then
        local pw_csv
        pw_csv="$(printf '%s' "$sel" | tr ' ' ',' | sed 's/^,//;s/,$//')"
        cmd_playwright --agents "$pw_csv" || true
        summary_playwright="$sel"
    fi

    log ""
    log "=== Setup complete ==="
    log "  Skills:      ${summary_skills}"
    log "  Guidelines:  ${summary_guidelines}"
    log "  JetBrains:   ${summary_jetbrains}"
    log "  Context7:    ${summary_context7}"
    log "  Playwright:  ${summary_playwright}"
}

# =================================================================
# Main dispatch
# =================================================================

# Pull global --verbose/--debug out of the args so every subcommand benefits.
_args=()
for _a in "$@"; do
    case "$_a" in
        --verbose|--debug) VERBOSE=1 ;;
        *) _args+=("$_a") ;;
    esac
done
set -- ${_args[@]+"${_args[@]}"}
debug_env

if [ $# -eq 0 ]; then
    cmd_wizard
    exit $?
fi

case "$1" in
    skills)        shift; cmd_skills "$@" ;;
    agents-md)     shift; cmd_agents_md "$@" ;;
    mcp-jetbrains) shift; cmd_mcp_jetbrains "$@" ;;
    mcp-context7)  shift; cmd_mcp_context7 "$@" ;;
    playwright)    shift; cmd_playwright "$@" ;;
    -h|--help)     usage ;;
    --*)           cmd_wizard "$@" ;;
    *)             die "unknown subcommand: $1" ;;
esac
