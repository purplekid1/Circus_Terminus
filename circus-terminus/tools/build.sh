#!/usr/bin/env bash
# Assemble Scenes/mansion.tscn from the generators.
#
#   tools/build.sh                 write Scenes/mansion.tscn
#   tools/build.sh --bake          ...then bake the CSG down to static meshes
#   tools/build.sh -o FILE         write somewhere else
#   tools/build.sh --scene-only    skip regenerating Materials/ and Scenes/props/
#
# The generators emit CSG, which is a modelling tool: live CSG in the editor is
# what made the scene crawl. --bake runs tools/bake.sh afterwards to turn it
# into MeshInstance3D, and is what you want unless you are iterating on the
# generators themselves.
#
# Also refreshes the shared material resources and the prop scenes the house
# instances, because all three have to agree about ids.
#
# Section order matters: a .tscn declares every ext_resource, then every
# sub_resource, then the nodes, and a node's parent must already have been
# declared. Hence header -> Mansion -> Shell -> stairs -> props -> Exterior ->
# Interior. The header is written last, from a scan of the finished node list,
# so it can declare exactly the resources that are actually referenced.
#
# Regenerating clobbers the scene, so close it in the Godot editor first: the
# editor writes the whole thing back on save and will undo this.

set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Scenes/mansion.tscn
DEPS=1
BAKE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT=$2; shift 2 ;;
    --scene-only) DEPS=0; shift ;;
    --bake) BAKE=1; shift ;;
    *) echo "build.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done

# ---- do not clobber a hand-edited scene ---------------------------------
# Once the house has been baked and then opened, arranged and saved in the
# editor, this script is no longer the source of truth for it: regenerating
# throws away everything that was moved by hand. That has already happened
# once. A baked scene has no CSG left in it, which is the tell, so refuse.
#
# Override with FORCE=1 when you genuinely mean to start the layout again.
if [ "$OUT" = "Scenes/mansion.tscn" ] && [ -f "$OUT" ] && [ "${FORCE:-0}" != "1" ]; then
  if ! grep -q 'type="CSG' "$OUT"; then
    cat >&2 <<'MSG'
build.sh: Scenes/mansion.tscn has been baked and hand-edited -- there is no CSG
          left in it. Regenerating would discard every change made in the
          editor since the last bake.

          To edit the house from the generators again you must first decide
          that the hand edits are expendable, then:

              FORCE=1 tools/build.sh --bake

          To change one thing in the house as it stands, edit the .tscn.
          To try the generators out without touching it:

              tools/build.sh -o /tmp/mansion.tscn
MSG
    exit 1
  fi
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

AWK=${AWK:-awk}

if [ "$DEPS" = "1" ]; then
  bash tools/gen_materials.sh
  # Items before props: both draw on the same Materials/, and the item models
  # are what the pickups in parts/props.part point at through Items/*.tres.
  bash tools/gen_items.sh
  bash tools/gen_props.sh
  # The safe and its dials are generated too. Not part of the mansion, but
  # they share the materials and there is no sense in a second entry point.
  bash tools/gen_safe.sh
fi

# Stairs run first: the ramp collision shapes they size have to land in the
# header, which is written before any node.
"$AWK" -f tools/lib.awk -f tools/gen_stairs.awk -v shapes="$TMP/shapes" > "$TMP/stairs"

{
  echo '[node name="Mansion" type="Node3D"]'
  bash tools/gen_shell.sh
  cat "$TMP/stairs"
  echo
  cat tools/parts/props.part
  echo
  bash tools/gen_exterior.sh
  echo
  "$AWK" -f tools/lib.awk -f tools/builtins.awk -f tools/gen_interior.awk
} > "$TMP/nodes"

# Godot reports a dangling parent as a warning per node and then silently drops
# half the house, so check here instead.
"$AWK" '
function attr(line, key,   s, e) {
  s = index(line, key "=\"");  if (!s) return ""
  s += length(key) + 2
  e = index(substr(line, s), "\"")
  return substr(line, s, e - 1)
}
/^\[node /{
  name = attr($0, "name"); par = attr($0, "parent")
  if (par == "") { node["."] = 1; root++; next }
  if (!(par in node)) { printf "orphan: %s wants parent %s (line %d)\n", name, par, NR; bad++ }
  node[(par == "." ? "" : par "/") name] = 1
}
END {
  if (root != 1) { printf "expected exactly one root node, found %d\n", root; bad++ }
  if (bad) exit 1
}
' "$TMP/nodes" || { echo "build failed structural check" >&2; exit 1; }

"$AWK" -f tools/check_facing.awk "$TMP/nodes" >&2 || true
"$AWK" -f tools/check_zfight.awk "$TMP/nodes" >&2 || true

grep -o 'ExtResource("[^"]*")' "$TMP/nodes" | sed 's/ExtResource("//;s/")//' | sort -u > "$TMP/wanted"

{
  bash tools/gen_header.sh "$TMP/wanted"
  cat "$TMP/shapes"
  echo
  cat "$TMP/nodes"
} > "$TMP/scene"

for ref in $(grep -o 'SubResource("[^"]*")' "$TMP/scene" | sed 's/SubResource("//;s/")//' | sort -u); do
  grep -q "^\[sub_resource.*id=\"$ref\"\]" "$TMP/scene" || { echo "undeclared SubResource: $ref" >&2; exit 1; }
done

mv "$TMP/scene" "$OUT"

printf 'wrote %s  (%s nodes, %s instanced props, %s lines)\n' \
  "$OUT" "$(grep -c '^\[node' "$OUT")" "$(grep -c 'instance=ExtResource("pf_' "$OUT")" \
  "$(wc -l < "$OUT" | tr -d ' ')"

if [ "$BAKE" = "1" ]; then
  bash tools/bake.sh
fi
