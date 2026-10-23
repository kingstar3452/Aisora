#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
  if command -v godot >/dev/null 2>&1; then
    godot_bin="$(command -v godot)"
  elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
  elif [[ -x "$HOME/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    godot_bin="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
  else
    echo 'Godot 4.6.3 is required. Install Godot or set GODOT_BIN to its executable.' >&2
    exit 1
  fi
fi
# Keep sandboxed cloud cache/config writes inside the checkout, outside tracked files.
if [[ "$(uname -s)" == Linux ]]; then
  mkdir -p .local/cloud/data .local/cloud/config .local/cloud/cache
  touch .local/.gdignore
  export XDG_DATA_HOME="$repo_dir/.local/cloud/data"
  export XDG_CONFIG_HOME="$repo_dir/.local/cloud/config"
  export XDG_CACHE_HOME="$repo_dir/.local/cloud/cache"
fi
exec "$godot_bin" --path "$repo_dir" "$@"
