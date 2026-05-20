#!/usr/bin/env python3
"""Generate .studio/skills-manifest.json (version -> {skills[], sha256}).

The aggregate hash is byte-identical to SkillsHasher.kt in jmix-studio:
for each listed skill folder, walk files; entry = relpath(UTF-8) + 0x00 + bytes,
relpath is POSIX-separated and relative to the version's skills/ dir; sort
entries by relpath bytes; SHA-256 over the concatenation; lowercase hex.
"""
import hashlib
import json
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Per-scope agent skill directories (relative to the scope root: the user home
# for "global", the project base for "local"). Mirrors install.sh / install.ps1.
# Studio reads these from the manifest instead of hardcoding paths.
AGENTS_DIRS = {
    "global": [
        ".claude/skills",
        ".codex/skills",
        ".config/opencode/skills",
        ".junie/skills",
    ],
    "local": [
        ".claude/skills",
        ".codex/skills",
        ".opencode/skills",
        ".junie/skills",
    ],
}


def list_skill_names(skills_dir):
    return sorted(
        name for name in os.listdir(skills_dir)
        if os.path.isdir(os.path.join(skills_dir, name))
    )


def aggregate_hash(skills_dir, skill_names):
    entries = []
    for name in sorted(skill_names):
        base = os.path.join(skills_dir, name)
        if not os.path.isdir(base):
            continue
        for current, _dirs, files in os.walk(base):
            for filename in files:
                full = os.path.join(current, filename)
                rel = os.path.relpath(full, skills_dir).replace(os.sep, "/")
                with open(full, "rb") as f:
                    entries.append((rel, f.read()))
    entries.sort(key=lambda e: e[0].encode("utf-8"))
    digest = hashlib.sha256()
    for rel, data in entries:
        digest.update(rel.encode("utf-8"))
        digest.update(b"\x00")
        digest.update(data)
    return digest.hexdigest()


def build_manifest():
    versions = {}
    for entry in sorted(os.listdir(REPO_ROOT)):
        if not entry.startswith("v"):
            continue
        skills_dir = os.path.join(REPO_ROOT, entry, "skills")
        if not os.path.isdir(skills_dir):
            continue
        names = list_skill_names(skills_dir)
        versions[entry] = {"skills": names, "sha256": aggregate_hash(skills_dir, names)}
    return {"schemaVersion": 1, "agents-dirs": AGENTS_DIRS, "versions": versions}


def main():
    manifest = build_manifest()
    out_dir = os.path.join(REPO_ROOT, ".studio")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "skills-manifest.json")
    text = json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote " + out_path)


if __name__ == "__main__":
    main()
