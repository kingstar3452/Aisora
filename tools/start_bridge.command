#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
if ! command -v python3 >/dev/null 2>&1; then
  echo 'Python 3.10 or newer is required. Install it from https://www.python.org/downloads/macos/.'
  exit 1
fi
exec python3 browser-controller/bridge.py "$@"
