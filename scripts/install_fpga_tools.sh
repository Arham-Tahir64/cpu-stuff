#!/usr/bin/env bash
# Optional only; M0-M5 use Ubuntu packages without this large download.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    echo 'Pinned bundle targets Linux x86_64 only.' >&2
    exit 1
fi
if [[ -e tools/oss-cad-suite ]]; then
    echo 'tools/oss-cad-suite already exists. Keeping it; inspect its version before reuse.' >&2
    exit 1
fi
readarray -t lock < <(python3 -c '
import json
with open("tools/oss-cad-suite.lock.json") as f:
    d = json.load(f)
for k in ("archive", "url", "sha256"):
    print(d[k])
')
archive=${lock[0]}
url=${lock[1]}
digest=${lock[2]}
mkdir -p tools/downloads
curl --fail --location --retry 3 --output "tools/downloads/$archive" "$url"
printf '%s  %s\n' "$digest" "tools/downloads/$archive" | sha256sum --check -
tar -xzf "tools/downloads/$archive" -C tools
test -f tools/oss-cad-suite/environment
echo 'Installed. Run: source tools/oss-cad-suite/environment'
echo 'Then rerun make check and make manifest to record the tool selection.'
