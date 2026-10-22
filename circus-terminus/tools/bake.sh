#!/usr/bin/env bash
# Bakes the generated CSG down to static meshes. Needs a Godot binary.
#
#   GODOT=/path/to/godot tools/bake.sh
#
# Run after tools/build.sh. Rewrites Scenes/props/*.tscn and Scenes/mansion.tscn
# in place and fills Meshes/ -- the generators remain the source of truth, so
# the loop is always build then bake.

set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${GODOT:-}" ]; then
  for c in godot godot4 Godot; do
    if command -v "$c" >/dev/null 2>&1; then GODOT=$c; break; fi
  done
fi
if [ -z "${GODOT:-}" ]; then
  echo "bake.sh: no Godot binary found. Set GODOT=/path/to/godot." >&2
  exit 1
fi

"$GODOT" --headless --path . --script tools/bake.gd
