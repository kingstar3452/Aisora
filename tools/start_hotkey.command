#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
if [[ "$(uname -s)" != Darwin ]]; then echo 'This optional helper is macOS-only.' >&2; exit 1; fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Optional global shortcut needs Apple Command Line Tools (xcode-select --install). In-app F8/F9 works without it.' >&2
  exit 1
fi
mkdir -p .local
touch .local/.gdignore
if [[ ! -x .local/aisora-hotkey || tools/mac_hotkey.swift -nt .local/aisora-hotkey ]]; then
  xcrun swiftc tools/mac_hotkey.swift -o .local/aisora-hotkey
fi
exec .local/aisora-hotkey --config "$repo_dir/.local/bridge.json" "$@"
