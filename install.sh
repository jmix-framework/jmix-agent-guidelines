#!/usr/bin/env bash
# Installs Jmix agent skills into the global skills directories used by:
# - Claude Code (~/.claude/skills)
# - Codex (~/.codex/skills)
# - OpenCode (~/.config/opencode/skills)
# - Junie (~/.junie/skills)

set -euo pipefail

REPO_OWNER="jmix-framework"
REPO_NAME="jmix-agent-guidelines"
VERSION=""
REF="main"
INSTALL_CLAUDE=1
INSTALL_CODEX=1
INSTALL_OPENCODE=1
INSTALL_JUNIE=1

usage() {
    cat <<'EOF'
Installs Jmix agent skills into global skills directories.

Usage:
  install.sh [--version V] [--ref REF] [--no-claude] [--no-codex] [--no-opencode] [--no-junie]

Flags:
  --version V      Jmix version (e.g. 2, 2.8, 2.8.0). Optional. The script picks
                   the best-matching guideline folder: exact -> major.minor ->
                   major. If none of these match, or when the flag is omitted /
                   empty, the latest available version is used (sorted by
                   major, then minor, then patch).
  --ref REF        Git ref to download (default: main).
  --no-claude      Skip installing into ~/.claude/skills.
  --no-codex       Skip installing into ~/.codex/skills.
  --no-opencode    Skip installing into ~/.config/opencode/skills.
  --no-junie       Skip installing into ~/.junie/skills.
  -h, --help       Show this help.
EOF
}

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

while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            [ $# -ge 2 ] || die "--version requires an argument"
            VERSION="$2"
            shift 2
            ;;
        --ref)
            [ $# -ge 2 ] || die "--ref requires an argument"
            REF="$2"
            shift 2
            ;;
        --no-claude)
            INSTALL_CLAUDE=0
            shift
            ;;
        --no-codex)
            INSTALL_CODEX=0
            shift
            ;;
        --no-opencode)
            INSTALL_OPENCODE=0
            shift
            ;;
        --no-junie)
            INSTALL_JUNIE=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

if [ "$INSTALL_CLAUDE" -eq 0 ] && [ "$INSTALL_CODEX" -eq 0 ] && [ "$INSTALL_OPENCODE" -eq 0 ] && [ "$INSTALL_JUNIE" -eq 0 ]; then
    die "nothing to install (all --no-* flags set)"
fi

require_tool curl
require_tool tar

STAGING="$(mktemp -d 2>/dev/null || mktemp -d -t jmix-install)"
trap 'rm -rf "$STAGING"' EXIT

TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${REF}"
TARBALL_PATH="${STAGING}/source.tar.gz"

log "Downloading ${TARBALL_URL}"
HTTP_STATUS="$(curl -sSL -w '%{http_code}' -o "$TARBALL_PATH" "$TARBALL_URL" || echo "000")"
if [ "$HTTP_STATUS" != "200" ]; then
    die "failed to download ${TARBALL_URL} (HTTP ${HTTP_STATUS})"
fi

tar -xzf "$TARBALL_PATH" -C "$STAGING"

EXTRACTED_DIR="$(find "$STAGING" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n 1)"
[ -n "$EXTRACTED_DIR" ] || die "extracted source directory not found in ${STAGING}"

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
    extracted="$1"
    best_key=""
    best_path=""
    for dir in "$extracted"/v*/; do
        [ -d "${dir}skills" ] || continue
        name="${dir%/}"
        name="${name##*/v}"
        [ -n "$name" ] || continue
        key="$(version_sort_key "$name")"
        if [ -z "$best_key" ] || [ "$key" \> "$best_key" ]; then
            best_key="$key"
            best_path="${dir}skills"
        fi
    done
    [ -n "$best_path" ] || return 1
    printf '%s\n' "$best_path"
}

# Prints resolved skills dir on success.
# Exit codes:
#   0 - matched (exact, major.minor, major, or no-version default)
#   2 - fallback used (requested version didn't match any tier)
#   1 - no v*/skills dir present at all
resolve_skills_dir() {
    extracted="$1"
    requested="$2"

    if [ -z "$requested" ]; then
        find_latest_skills_dir "$extracted"
        return $?
    fi

    if [ -d "${extracted}/v${requested}/skills" ]; then
        printf '%s\n' "${extracted}/v${requested}/skills"
        return 0
    fi

    major_minor="$(printf '%s' "$requested" | awk -F'[.-]' '{ if (NF >= 2 && $1 != "" && $2 != "") print $1"."$2 }')"
    if [ -n "$major_minor" ] && [ "$major_minor" != "$requested" ] && [ -d "${extracted}/v${major_minor}/skills" ]; then
        printf '%s\n' "${extracted}/v${major_minor}/skills"
        return 0
    fi

    major="$(printf '%s' "$requested" | awk -F'[.-]' '{print $1}')"
    if [ -n "$major" ] && [ "$major" != "$requested" ] && [ -d "${extracted}/v${major}/skills" ]; then
        printf '%s\n' "${extracted}/v${major}/skills"
        return 0
    fi

    fallback_path="$(find_latest_skills_dir "$extracted")" || return 1
    printf '%s\n' "$fallback_path"
    return 2
}

RESOLVE_STATUS=0
SOURCE_SKILLS_DIR="$(resolve_skills_dir "$EXTRACTED_DIR" "$VERSION")" || RESOLVE_STATUS=$?
if [ "$RESOLVE_STATUS" -eq 1 ] || [ -z "$SOURCE_SKILLS_DIR" ]; then
    AVAILABLE="$(find "$EXTRACTED_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | tr '\n' ' ')"
    die "no v*/skills directory found in ${REF}. Available top-level entries: ${AVAILABLE}"
fi

RESOLVED_VERSION_DIR="$(basename "$(dirname "$SOURCE_SKILLS_DIR")")"
if [ "$RESOLVE_STATUS" -eq 2 ]; then
    log "Version '${VERSION}' did not match any folder, falling back to latest available (${RESOLVED_VERSION_DIR})"
fi
log "Using guidelines from ${SOURCE_SKILLS_DIR#${EXTRACTED_DIR}/}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

install_to_target() {
    target_dir="$1"
    agent_label="$2"

    log ""
    log "Installing skills for ${agent_label} into ${target_dir}"
    mkdir -p "$target_dir" || die "cannot write to ${target_dir}: mkdir failed"

    count=0
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

    log "  ${count} skill(s) processed for ${agent_label}"
}

TARGETS=""

append_target() {
    if [ -n "$TARGETS" ]; then
        TARGETS="${TARGETS}, $1"
    else
        TARGETS="$1"
    fi
}

if [ "$INSTALL_CLAUDE" -eq 1 ]; then
    install_to_target "${HOME}/.claude/skills" "Claude"
    append_target "Claude"
fi
if [ "$INSTALL_CODEX" -eq 1 ]; then
    install_to_target "${HOME}/.codex/skills" "Codex"
    append_target "Codex"
fi
if [ "$INSTALL_OPENCODE" -eq 1 ]; then
    install_to_target "${HOME}/.config/opencode/skills" "OpenCode"
    append_target "OpenCode"
fi
if [ "$INSTALL_JUNIE" -eq 1 ]; then
    install_to_target "${HOME}/.junie/skills" "Junie"
    append_target "Junie"
fi

log ""
log "Done. Installed skills for: ${TARGETS}"
