#!/usr/bin/env bash
# Check relative Markdown links resolve to files in the repository.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

python3 - <<'PY'
import os
import re
import sys

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
SKIP_PREFIX = ("http://", "https://", "mailto:", "tel:", "#")

errors = []
for dirpath, dirnames, filenames in os.walk("."):
    dirnames[:] = [d for d in dirnames if d not in {".git", "node_modules", "__pycache__"}]
    for name in filenames:
        if not name.endswith(".md"):
            continue
        path = os.path.join(dirpath, name)
        with open(path, encoding="utf-8") as fh:
            for lineno, line in enumerate(fh, 1):
                for target in LINK_RE.findall(line):
                    if target.startswith(SKIP_PREFIX):
                        continue
                    clean = target.split("#", 1)[0]
                    if not clean:
                        continue
                    resolved = os.path.normpath(os.path.join(dirpath, clean))
                    if not os.path.exists(resolved):
                        errors.append(f"{path}:{lineno}: missing link target: {target}")

if errors:
    print("Link check failed:\n")
    print("\n".join(errors))
    sys.exit(1)

print("Link check passed: all relative Markdown links resolve.")
PY
