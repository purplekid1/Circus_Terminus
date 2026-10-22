#!/usr/bin/env bash
# Scene header for mansion.tscn.
#
#   tools/gen_header.sh WANTED_IDS_FILE
#
# Reads the ExtResource ids the assembled node list actually refers to (one per
# line) and emits declarations for exactly those. Emitting the lot instead would
# leave dead ext_resources for the editor to prune out from under the generator,
# and a missing one makes Godot drop every node that used it with only a warning.
#
# Materials are files under Materials/ now, not sub_resources, so the prop
# scenes in Scenes/props/ can share them. Only collision shapes are left inline:
# they are scene-specific and nothing else wants them.

set -euo pipefail
cd "$(dirname "$0")/.."

WANTED=${1:?usage: gen_header.sh <file listing wanted ExtResource ids>}

# ---- registry: id -> type, path, uid ("-" when the file has none) ----------
# Hand-authored gameplay resources. props.part refers to these by id.
REGISTRY='
1_door      PackedScene uid://cumceln8hk70f res://Scenes/door.tscn
2_pick      PackedScene -                   res://Scenes/pickup.tscn
3_safe      PackedScene uid://bu7wcm3myos1v res://Scenes/safe.tscn
5_storm     PackedScene -                   res://Scenes/storm_door.tscn
6_end       Script      uid://cwfu6psq0q7qm res://Scripts/DemoEnd.gd
7_gen       Script      uid://db7k25fr2vpkd res://Scripts/Generator.gd
8_talk      Script      uid://bpye31184pace res://Scripts/DialogueTrigger.gd
9_studykey  Resource    -                   res://Items/study_key.tres
10_glass    Resource    -                   res://Items/magnifier.tres
11_fuel     Resource    -                   res://Items/fuel.tres
12_crow     Resource    -                   res://Items/crowbar.tres
13_bkey     Resource    -                   res://Items/bureau_key.tres
14_obst     Script      uid://dyv4p8qabqnbn res://Scripts/Obstacle.gd
15_read     PackedScene -                   res://Scenes/readable.tscn
16_bureau   PackedScene -                   res://Scenes/bureau.tscn
17_flick    Script      uid://d2sccwyytkeme res://Scripts/FlickerLight.gd
18_grim     PackedScene -                   res://Scenes/grimoire.tscn
'

# Materials and prop scenes are discovered, so adding one needs no edit here.
for f in Materials/Mat_*.tres; do
  [ -e "$f" ] || continue
  REGISTRY="$REGISTRY
$(basename "$f" .tres) Material - res://$f"
done
for f in Scenes/props/pf_*.tscn; do
  [ -e "$f" ] || continue
  REGISTRY="$REGISTRY
$(basename "$f" .tscn) PackedScene - res://$f"
done

echo '[gd_scene format=3 uid="uid://b87fyg08f10rh"]'
echo

missing=0
while read -r want; do
  [ -z "$want" ] && continue
  line=$(printf '%s\n' "$REGISTRY" | awk -v w="$want" '$1 == w { print; exit }')
  if [ -z "$line" ]; then
    echo "gen_header.sh: no registry entry for ExtResource \"$want\"" >&2
    missing=1
    continue
  fi
  set -- $line
  # Path only, no uid=. A uid that is not in the project's uid_cache.bin makes
  # Godot warn "invalid UID ... using text path instead" on every load, and the
  # cache goes stale whenever a script is added outside the editor. Paths always
  # resolve, and a uid buys nothing for a file this script regenerates anyway.
  printf '[ext_resource type="%s" path="%s" id="%s"]\n' "$2" "$4" "$1"
done < "$WANTED"
[ "$missing" = "0" ] || exit 1

# ---- collision shapes -----------------------------------------------------
# The two stair ramps are appended by build.sh, which sizes them from the
# flights so the collider and the treads cannot disagree.
cat <<'EOF'

[sub_resource type="BoxShape3D" id="Box_pitramp"]
size = Vector3(3.6, 4, 6.386)

[sub_resource type="BoxShape3D" id="Box_gen"]
size = Vector3(1.7, 1.2, 1.1)

[sub_resource type="BoxShape3D" id="Box_debris"]
size = Vector3(5, 2.6, 1.6)

[sub_resource type="BoxShape3D" id="Box_end"]
size = Vector3(8, 3, 4)

[sub_resource type="BoxShape3D" id="Box_trigger"]
size = Vector3(6, 3, 4)
EOF
