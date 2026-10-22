#!/usr/bin/env bash
# Writes Scenes/items/it_*.tscn -- one scene per carryable object.
#
# Same shape as gen_props.sh, and deliberately so: an item is a prop that
# happens to fit in a pocket. Splitting them out buys one thing, which is that
# bake.gd can bake this directory before the props and the mansion, and the
# pickup scene, the dropped-item body and the journal icon then all point at
# the same baked mesh instead of each carrying their own copy.
#
# No collision on any of them. A pickup's collider is a plain box in
# pickup.tscn sized to the hand, not a trimesh of a key's wards -- you should
# be able to grab a dropped key without pixel-hunting for its bit.

set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Scenes/items
mkdir -p "$OUT"

AWK=${AWK:-awk}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# id            which        root node name
CATALOGUE='
it_crowbar      crowbar      Crowbar
it_magnifier    magnifier    Magnifier
it_fuse         fuse         Fuse
it_battery      battery      Battery
it_fuelcan      fuelcan      FuelCan
it_key_store    key_store    StoreKey
it_key_hall     key_hall     HallKey
it_key_study    key_study    StudyKey
it_key_bureau   key_bureau   BureauKey
it_grimoire     grimoire     Grimoire
it_token        token        Token
'

count=0
while read -r id which root; do
  [ -z "$id" ] && continue
  case "$id" in \#*) continue ;; esac

  "$AWK" -f tools/lib.awk -f tools/items.awk -v WHICH="$which" -f tools/gen_items.awk > "$TMP/body"

  # Only list materials the item actually uses, so the editor does not prune
  # dead ext_resources out from under the generator.
  mats=$(grep -o 'ExtResource("Mat_[A-Za-z0-9_]*")' "$TMP/body" \
         | sed 's/ExtResource("//;s/")//' | sort -u)
  steps=$(printf '%s\n' "$mats" | grep -c . || true)

  {
    echo "[gd_scene load_steps=$((steps + 1)) format=3]"
    echo
    for m in $mats; do
      echo "[ext_resource type=\"Material\" path=\"res://Materials/$m.tres\" id=\"$m\"]"
    done
    echo
    echo "[node name=\"$root\" type=\"CSGCombiner3D\"]"
    cat "$TMP/body"
  } > "$OUT/$id.tscn"

  count=$((count + 1))
done <<< "$CATALOGUE"

printf 'wrote %s item scenes to %s/\n' "$count" "$OUT"
