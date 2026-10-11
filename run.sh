#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# The cloud workspace needs writable XDG locations. Desktop installs retain
# Godot's usual user-data locations unless the caller chooses XDG variables.
if [ -d /workspace/scratch ]; then
  export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/scratch/fazenda-runtime/cache}"
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/scratch/fazenda-runtime/config}"
  export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/scratch/fazenda-runtime/data}"
  mkdir -p "$XDG_CACHE_HOME/fontconfig" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
fi
godot_bin="${GODOT_BIN:-godot}"
exec "$godot_bin" --path "$PWD" "$@"
