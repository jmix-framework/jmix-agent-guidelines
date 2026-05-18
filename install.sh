#!/usr/bin/env bash
# Jmix AI Agent Guidelines installer.
#
# Default (no subcommand) launches an interactive wizard that guides through:
#   1. Installing Jmix skills globally for one or all agents.
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
EXTRACTED_DIR=""
SOURCE_SKILLS_DIR=""
SOURCE_AGENTS_MD=""
RESOLVED_VERSION_DIR=""
TARBALL_READY=0

VERSION=""
REF="main"

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

require_tool() {
    command -v "$1" >/dev/null 2>&1 || die "$1 not found. Install it and re-run."
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
Jmix AI Agent Guidelines installer.

Usage:
  install.sh [--version V] [--ref REF]                  # interactive wizard
  install.sh skills        [options]                    # install global skills only
  install.sh agents-md     [options]                    # install project guidelines
  install.sh mcp-jetbrains [options]                    # register JetBrains MCP
  install.sh mcp-context7  [options] [--key KEY]        # register Context7 MCP

Common options:
  --version V        Jmix version (e.g. 2.8.0). Optional. Best-matching folder
                     is picked: exact -> major.minor -> major -> latest.
  --ref REF          Git ref to download (default: main).
  --agent NAME       Apply to one of: claude, codex, opencode, junie.
  --all              Apply to every supported agent for the subcommand.
  -h, --help         Show this help.

skills options:
  --agents CSV     Comma-separated agent list (e.g. claude,codex).
                   Mutually exclusive with --agent and --all.
  --no-claude  --no-codex  --no-opencode  --no-junie    (back-compat with --all)

mcp-context7 options:
  --key KEY          Context7 API key. Prompted interactively when missing.
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
    trap 'rm -rf "$STAGING"' EXIT

    local tarball_url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${REF}"
    local tarball_path="${STAGING}/source.tar.gz"

    log "Downloading ${tarball_url}"
    local http_status
    http_status="$(curl -sSL -w '%{http_code}' -o "$tarball_path" "$tarball_url" || echo "000")"
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

    if [ "$resolve_status" -eq 2 ]; then
        log "Version '${VERSION}' did not match any folder, falling back to latest available (${RESOLVED_VERSION_DIR})"
    fi
    log "Using guidelines from ${SOURCE_SKILLS_DIR#${EXTRACTED_DIR}/}"

    TARBALL_READY=1
}

# =================================================================
# skills install (global, per agent)
# =================================================================

skills_target_for_agent() {
    case "$1" in
        claude)   printf '%s' "${HOME}/.claude/skills" ;;
        codex)    printf '%s' "${HOME}/.codex/skills" ;;
        opencode) printf '%s' "${HOME}/.config/opencode/skills" ;;
        junie)    printf '%s' "${HOME}/.junie/skills" ;;
        *) die "unknown agent '$1'" ;;
    esac
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

install_skills_for_agent() {
    local agent="$1"
    local target_dir
    target_dir="$(skills_target_for_agent "$agent")"
    local label
    label="$(agent_label "$agent")"

    log ""
    log "Installing skills for ${label} into ${target_dir}"
    mkdir -p "$target_dir" || die "cannot write to ${target_dir}: mkdir failed"

    local count=0
    local skill name dest backup
    for skill in "$SOURCE_SKILLS_DIR"/*/; do
        [ -d "$skill" ] || continue
        name="$(basename "$skill")"
        dest="${target_dir}/${name}"
        if [ -e "$dest" ]; then
            backup="${dest}.bak-${TIMESTAMP}"
            mv "$dest" "$backup" || die "cannot write to ${dest}: rename failed"
            cp -R "$skill" "$dest" || die "cannot write to ${dest}: copy failed"
            log "  Updated: ${name} (backup: $(basename "$backup"))"
        else
            cp -R "$skill" "$dest" || die "cannot write to ${dest}: copy failed"
            log "  Installed: ${name}"
        fi
        count=$((count + 1))
    done
    log "  ${count} skill(s) processed for ${label}"
}

cmd_skills() {
    local agents=""
    local pick_all=0
    local pick_agent=""
    local pick_agents_csv=""

    # Back-compat flags
    local nc=0 nx=0 no=0 nj=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --all) pick_all=1; shift ;;
            --agent)
                [ $# -ge 2 ] || die "--agent requires an argument"
                pick_agent="$2"; shift 2 ;;
            --agents)
                [ $# -ge 2 ] || die "--agents requires an argument"
                pick_agents_csv="$2"; shift 2 ;;
            --no-claude)   nc=1; shift ;;
            --no-codex)    nx=1; shift ;;
            --no-opencode) no=1; shift ;;
            --no-junie)    nj=1; shift ;;
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

    local exclusive_count=0
    [ "$pick_all" -eq 1 ] && exclusive_count=$((exclusive_count + 1))
    [ -n "$pick_agent" ] && exclusive_count=$((exclusive_count + 1))
    [ -n "$pick_agents_csv" ] && exclusive_count=$((exclusive_count + 1))
    if [ "$exclusive_count" -gt 1 ]; then
        die "--all, --agent and --agents are mutually exclusive"
    fi

    if [ -n "$pick_agent" ]; then
        agents="$pick_agent"
    elif [ -n "$pick_agents_csv" ]; then
        # Parse CSV -> space-separated list, validate each token.
        local raw token
        raw="$(printf '%s' "$pick_agents_csv" | tr ',' ' ' | tr -s ' ' ' ')"
        for token in $raw; do
            case "$token" in
                claude|codex|opencode|junie) agents="${agents} ${token}" ;;
                "") ;;
                *) die "unknown agent in --agents: '$token'" ;;
            esac
        done
    elif [ "$pick_all" -eq 1 ] || [ "$nc$nx$no$nj" = "0000" ]; then
        agents="$ALL_AGENTS"
    else
        [ "$nc" -eq 0 ] && agents="${agents} claude"
        [ "$nx" -eq 0 ] && agents="${agents} codex"
        [ "$no" -eq 0 ] && agents="${agents} opencode"
        [ "$nj" -eq 0 ] && agents="${agents} junie"
    fi

    agents="$(printf '%s' "$agents" | tr -s ' ' ' ' | sed 's/^ //;s/ $//')"
    [ -n "$agents" ] || die "nothing to install (no agents resolved)"

    ensure_tarball

    local agent
    for agent in $agents; do
        install_skills_for_agent "$agent"
    done
    log ""
    log "Done. Installed skills for: $(printf '%s' "$agents" | tr ' ' ',' | sed 's/,/, /g')"
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

    if [ -e "$dest" ]; then
        local backup="${dest}.bak-${TIMESTAMP}"
        mv "$dest" "$backup" || die "cannot rename existing ${dest}"
        cp "$SOURCE_AGENTS_MD" "$dest" || die "cannot write ${dest}"
        log "  Updated: ${dest} (backup: $(basename "$backup"))"
    else
        cp "$SOURCE_AGENTS_MD" "$dest" || die "cannot write ${dest}"
        log "  Installed: ${dest}"
    fi
    log "  Project guidelines installed for ${label}"
}

cmd_agents_md() {
    local pick_all=0
    local pick_agent=""
    local pick_agents_csv=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --all) pick_all=1; shift ;;
            --agent)
                [ $# -ge 2 ] || die "--agent requires an argument"
                pick_agent="$2"; shift 2 ;;
            --agents)
                [ $# -ge 2 ] || die "--agents requires an argument"
                pick_agents_csv="$2"; shift 2 ;;
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

    local exclusive_count=0
    [ "$pick_all" -eq 1 ] && exclusive_count=$((exclusive_count + 1))
    [ -n "$pick_agent" ] && exclusive_count=$((exclusive_count + 1))
    [ -n "$pick_agents_csv" ] && exclusive_count=$((exclusive_count + 1))
    if [ "$exclusive_count" -gt 1 ]; then
        die "--all, --agent and --agents are mutually exclusive"
    fi

    local agents=""
    if [ -n "$pick_agent" ]; then
        agents="$pick_agent"
    elif [ -n "$pick_agents_csv" ]; then
        local raw token
        raw="$(printf '%s' "$pick_agents_csv" | tr ',' ' ' | tr -s ' ' ' ')"
        for token in $raw; do
            case "$token" in
                claude|codex|opencode|junie) agents="${agents} ${token}" ;;
                "") ;;
                *) die "unknown agent in --agents: '$token'" ;;
            esac
        done
        agents="$(printf '%s' "$agents" | sed 's/^ //;s/ $//')"
        [ -n "$agents" ] || die "agents-md: --agents resolved to empty list"
    elif [ "$pick_all" -eq 1 ]; then
        agents="$ALL_AGENTS"
    else
        die "agents-md: specify --all, --agent NAME, or --agents CSV"
    fi

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
    local pick_all=0
    local pick_agent=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --all) pick_all=1; shift ;;
            --agent)
                [ $# -ge 2 ] || die "--agent requires an argument"
                pick_agent="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local agents=""
    if [ -n "$pick_agent" ]; then
        agents="$pick_agent"
    elif [ "$pick_all" -eq 1 ]; then
        agents="$JETBRAINS_AGENTS"
    else
        die "mcp-jetbrains: specify --all or --agent NAME"
    fi

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
    local pick_all=0
    local pick_agent=""
    local key=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --all) pick_all=1; shift ;;
            --agent)
                [ $# -ge 2 ] || die "--agent requires an argument"
                pick_agent="$2"; shift 2 ;;
            --key)
                [ $# -ge 2 ] || die "--key requires an argument"
                key="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local agents=""
    if [ -n "$pick_agent" ]; then
        agents="$pick_agent"
    elif [ "$pick_all" -eq 1 ]; then
        agents="$CONTEXT7_AGENTS"
    else
        die "mcp-context7: specify --all or --agent NAME"
    fi

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
# Wizard
# =================================================================

wizard_pick_agent() {
    local prompt_label="$1"
    shift
    local options="$*"

    {
        log ""
        log "$prompt_label"
        local i=1
        local opt
        for opt in $options; do
            printf '  %d) %s\n' "$i" "$(agent_label "$opt")"
            i=$((i + 1))
        done
        printf '  %d) For all agents\n' "$i"
        printf '  s) Skip\n'
    } >&2

    local total=$((i))
    local answer
    answer="$(prompt 'Choice' 's')"
    case "$answer" in
        s|S|skip|SKIP) printf 'skip'; return 0 ;;
    esac
    if ! printf '%s' "$answer" | grep -Eq '^[0-9]+$'; then
        log "Unrecognized choice '${answer}'. Skipping." >&2
        printf 'skip'
        return 0
    fi
    if [ "$answer" -eq "$total" ]; then
        printf '%s' "$options"
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
    while [ $# -gt 0 ]; do
        case "$1" in
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

    log "=== Jmix AI Agent Guidelines - Setup ==="
    [ -n "$VERSION" ] && log "Jmix version: ${VERSION}"
    log "Working directory: $(pwd -P)"

    local summary_skills="skipped"
    local summary_guidelines="skipped"
    local summary_jetbrains="skipped"
    local summary_context7="skipped"

    # Step 1: skills
    local sel
    sel="$(wizard_pick_agent '[1/4] Install Jmix skills globally?' $ALL_AGENTS)"
    if [ "$sel" != "skip" ]; then
        ensure_tarball
        local agent
        for agent in $sel; do
            install_skills_for_agent "$agent" || true
        done
        summary_skills="$sel"
    fi

    # Step 2: agents-md
    sel="$(wizard_pick_agent '[2/4] Add Jmix coding guidelines to this directory?' $ALL_AGENTS)"
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
    sel="$(wizard_pick_agent '[3/4] Connect agent to IntelliJ IDEA via JetBrains MCP?' $JETBRAINS_AGENTS)"
    if [ "$sel" != "skip" ]; then
        local agent
        for agent in $sel; do
            install_jetbrains_for "$agent" || true
        done
        summary_jetbrains="$sel"
    fi

    # Step 4: Context7 MCP
    sel="$(wizard_pick_agent '[4/4] Connect agent to library docs via Context7 MCP?' $CONTEXT7_AGENTS)"
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

    log ""
    log "=== Setup complete ==="
    log "  Skills:      ${summary_skills}"
    log "  Guidelines:  ${summary_guidelines}"
    log "  JetBrains:   ${summary_jetbrains}"
    log "  Context7:    ${summary_context7}"
}

# =================================================================
# Main dispatch
# =================================================================

if [ $# -eq 0 ]; then
    cmd_wizard
    exit $?
fi

case "$1" in
    skills)        shift; cmd_skills "$@" ;;
    agents-md)     shift; cmd_agents_md "$@" ;;
    mcp-jetbrains) shift; cmd_mcp_jetbrains "$@" ;;
    mcp-context7)  shift; cmd_mcp_context7 "$@" ;;
    -h|--help)     usage ;;
    --*)           cmd_wizard "$@" ;;
    *)             die "unknown subcommand: $1" ;;
esac
