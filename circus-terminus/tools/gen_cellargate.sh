#!/usr/bin/env bash
# Writes Scenes/cellar_gate.tscn -- the barred gate across the HEAD of the
# cellar stairs.
#
# WHAT IT IS FOR
#
# The cellar used to be a corridor. You came down the storm steps, took the
# fuel can off the floor, started the generator and walked straight up into
# the house, and the only thing the lights changed was how much you could see
# of a room you were already leaving. This gate is what makes the lights
# matter: it is locked, the key for it is somewhere in the cellar, and you
# cannot search a cellar you cannot see.
#
# It is IRON BARS, not a door, for two reasons. You can see the stairs through
# it, so the way out is visible and obviously shut rather than merely absent.
# And it cannot be mistaken for the house's own joinery -- every other door in
# the building is a panelled timber one.
#
# LOCAL FRAME: origin at the FLOOR, on the HINGE side of the opening is NOT
# the origin -- the origin is the centre of the opening, x runs across the
# stairwell, the gate lies in the x-y plane and swings about x = -HALF.
# mansion.tscn places it at (12, 0, -26.75), which is the top of the flight,
# standing on the ground-floor slab just clear of the stairwell opening.
#
# THE HEAD, NOT THE FOOT. At the foot it would have to stand on a 30-degree
# ramp a metre from the cellar's back wall, and there is no room for a 2.4 m
# screen under a flight that is 0.6 m above the floor by then. At the head the
# stairwell opening is the only way up out of the cellar, so a screen across
# it is the whole route -- you cannot walk round a hole.

set -euo pipefail
cd "$(dirname "$0")/.."

AWK=${AWK:-awk}
OUT=Scenes/cellar_gate.tscn
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

"$AWK" -f tools/lib.awk -e '
function WIDTH()  { return 4.60 }   # the whole stairwell, jamb to jamb
function HEIGHT() { return 2.40 }
function LEAF()   { return 1.20 }   # the part that opens
function THICK()  { return 0.12 }

## A run of vertical bars between x0 and x1, with rails top and bottom.
function bars(parent, x0, x1, y0, y1, pitch,   i, n, x) {
  n = int((x1 - x0) / pitch)
  if (n < 1) n = 1
  for (i = 1; i < n; i++) {
    x = x0 + (x1 - x0) * i / n
    cyl(parent, "Bar", x, (y0 + y1) / 2, 0, 0.017, y1 - y0, "Mat_iron", 0, 6)
  }
  box(parent, "Rail", (x0 + x1) / 2, y0 + 0.10, 0, x1 - x0, 0.055, 0.05, "Mat_iron", 0)
  box(parent, "Rail", (x0 + x1) / 2, (y0 + y1) / 2, 0, x1 - x0, 0.070, 0.05, "Mat_iron", 0)
  box(parent, "Rail", (x0 + x1) / 2, y1 - 0.10, 0, x1 - x0, 0.055, 0.05, "Mat_iron", 0)
}

BEGIN {
  # TH, not T: lib.awk already has a function called T() and an awk variable
  # of the same name shadows it.
  H = HEIGHT(); W = WIDTH(); L = LEAF(); TH = THICK()
  half = L / 2

  # ---- the fixed screen: two jambs, a head, and the bars either side of the
  # opening. Its own combiner, no collision on it -- a trimesh of thirty thin
  # cylinders is a thing the player capsule catches on.
  printf "\n[node name=\"Screen\" type=\"CSGCombiner3D\" parent=\".\"]\n"
  box("Screen", "Jamb", -W / 2 + 0.06, H / 2, 0, 0.12, H, TH + 0.02, "Mat_iron", 0)
  box("Screen", "Jamb",  W / 2 - 0.06, H / 2, 0, 0.12, H, TH + 0.02, "Mat_iron", 0)
  box("Screen", "Head", 0, H - 0.07, 0, W, 0.14, TH + 0.02, "Mat_iron", 0)
  box("Screen", "Threshold", 0, 0.035, 0, W, 0.07, TH + 0.02, "Mat_iron", 0)
  # The stiles the leaf shuts against.
  box("Screen", "Stile", -half - 0.05, H / 2, 0, 0.10, H - 0.14, TH, "Mat_iron", 0)
  box("Screen", "Stile",  half + 0.05, H / 2, 0, 0.10, H - 0.14, TH, "Mat_iron", 0)
  bars("Screen", -W / 2 + 0.12, -half - 0.10, 0.07, H - 0.14, 0.145)
  bars("Screen",  half + 0.10,  W / 2 - 0.12, 0.07, H - 0.14, 0.145)

  # Plain boxes for what the player actually walks into. Two of them, one per
  # fixed panel, so the opening is genuinely open.
  printf "\n[node name=\"Solid\" type=\"StaticBody3D\" parent=\".\"]\n"
  printf "\n[node name=\"West\" type=\"CollisionShape3D\" parent=\"Solid\"]\n"
  printf "transform = %s\n", T((-W / 2 + (-half - 0.10)) / 2, H / 2, 0)
  printf "shape = SubResource(\"Shape_fixed\")\n"
  printf "\n[node name=\"East\" type=\"CollisionShape3D\" parent=\"Solid\"]\n"
  printf "transform = %s\n", T((W / 2 + (half + 0.10)) / 2, H / 2, 0)
  printf "shape = SubResource(\"Shape_fixed\")\n"

  # ---- the leaf. Hinge at the west stile, panel centred half a leaf along
  # it, exactly like door.tscn -- Door.gd turns $Hinge and nothing else.
  printf "\n[node name=\"Hinge\" type=\"Node3D\" parent=\".\"]\n"
  printf "transform = %s\n", T(-half, 0, 0)
  printf "\n[node name=\"Panel\" type=\"AnimatableBody3D\" parent=\"Hinge\"]\n"
  printf "transform = %s\n", T(half, H / 2, 0)
  printf "sync_to_physics = false\n"
  printf "\n[node name=\"CollisionShape3D\" type=\"CollisionShape3D\" parent=\"Hinge/Panel\"]\n"
  printf "shape = SubResource(\"Shape_leaf\")\n"
  printf "\n[node name=\"Leaf\" type=\"CSGCombiner3D\" parent=\"Hinge/Panel\"]\n"

  # Built around the PANEL origin, which sits at the middle of the leaf at
  # mid-height -- so everything here is offset from centre, not from the floor.
  box("Hinge/Panel/Leaf", "Stile", -L / 2 + 0.045, 0, 0, 0.09, H - 0.16, TH - 0.02, "Mat_iron", 0)
  box("Hinge/Panel/Leaf", "Stile",  L / 2 - 0.045, 0, 0, 0.09, H - 0.16, TH - 0.02, "Mat_iron", 0)
  bars("Hinge/Panel/Leaf", -L / 2 + 0.09, L / 2 - 0.09, -(H - 0.16) / 2, (H - 0.16) / 2, 0.135)

  # Lock plate and a ring to pull on, on the shutting stile.
  box("Hinge/Panel/Leaf", "LockPlate", L / 2 - 0.10, -0.05, 0.035, 0.16, 0.30, 0.03, "Mat_iron", 0)
  cyl("Hinge/Panel/Leaf", "Ring", L / 2 - 0.10, 0.06, 0.06, 0.055, 0.016, "Mat_iron", 0, 12)
}' > "$BODY"

mats=$(grep -o 'ExtResource("Mat_[A-Za-z0-9_]*")' "$BODY" \
       | sed 's/ExtResource("//;s/")//' | sort -u)

{
  echo '[gd_scene load_steps=5 format=3]'
  echo
  echo '; THE CELLAR GATE. Generated by tools/gen_cellargate.sh.'
  echo ';'
  echo '; Locked with "cellar_key", which is hidden in the cellar and only'
  echo '; findable once the generator is running. See that script.'
  echo
  echo '[ext_resource type="Script" path="res://Scripts/Door.gd" id="1_door"]'
  for m in $mats; do
    echo "[ext_resource type=\"Material\" path=\"res://Materials/$m.tres\" id=\"$m\"]"
  done
  echo
  echo '; One box per fixed panel and one for the leaf. Trimesh collision on'
  echo '; thirty thin bars is a wall the player capsule snags on.'
  echo '[sub_resource type="BoxShape3D" id="Shape_fixed"]'
  echo 'size = Vector3(1.6, 2.4, 0.14)'
  echo
  echo '[sub_resource type="BoxShape3D" id="Shape_leaf"]'
  echo 'size = Vector3(1.2, 2.24, 0.12)'
  echo
  echo '[node name="CellarGate" type="Node3D" groups=["interactable"]]'
  echo 'script = ExtResource("1_door")'
  echo 'open_angle = -105.0'
  echo 'swing_time = 0.7'
  echo 'locked = true'
  echo 'key_id = "cellar_key"'
  echo 'locked_prompt = "Chained shut"'
  echo 'prompt = "Iron gate"'
  echo 'examine_lines = Array[String](["Bars right across the cellar, wall to wall. Someone did not want anyone getting past.", "There is a keyhole. Whatever opens it is down here with me."])'
  cat "$BODY"
} > "$OUT"

printf 'wrote %s  (%s nodes)\n' "$OUT" "$(grep -c '^\[node' "$OUT")"

if [ -n "${GODOT:-}" ]; then
  BAKE_ONLY="res://$OUT" "$GODOT" --headless --path . --script tools/bake.gd \
    2>&1 | grep -E "mesh\(es\)|baked" || true
else
  echo "gen_cellargate.sh: set GODOT= to bake; leaving live CSG for now." >&2
fi
