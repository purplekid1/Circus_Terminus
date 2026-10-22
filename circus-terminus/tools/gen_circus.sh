#!/usr/bin/env bash
# Writes circus_level.tscn -- where the book puts you.
#
# THREE PLATFORMS, roughly 130 m of walking each, laid out +Z to -Z:
#
#   z +190 .. +60   platform one. Dense forest, no landmarks, no sight lines.
#                   You land here, find the lens, and have to pick a direction.
#   z +60 .. -70    platform two. It thins. The tent starts showing over the
#                   trees, and from then on the level tells you where to go by
#                   letting you see it rather than by putting an arrow on it.
#   z -70 .. -180   platform three. The fairground: stalls, bunting, nobody.
#                   Reaching the far end ends the level.
#
# The tent is 110 m across and 66 m tall, sitting at z -265. It is not
# enterable here and is not meant to be -- it is the objective, and the whole
# reason the walk has a direction.
#
# THE PATH IS THE LEVEL. tools/circus.awk holds it as a polyline; the forest
# fills what it does not use, the fairground is placed along it, and
# tools/probe_circus.gd walks it. It is also emitted into the scene as Route/,
# so nothing has to keep a second copy of the waypoints.
#
# GREYBOX. The geometry is real and walkable and the beats are staged. The
# enemy, the stealth and the chase are not built.

set -euo pipefail
cd "$(dirname "$0")/.."

AWK=${AWK:-awk}
OUT=circus_level.tscn
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

"$AWK" -f tools/lib.awk -f tools/items.awk -f tools/surroundings.awk -f tools/circus.awk -e '
BEGIN {
  path_init()

  # ---- the hunt, as one table -------------------------------------------
  # Which waypoints carry a creature, and what each is called. The clearing,
  # the patrol and the thing walking it are all generated from these four
  # lines, so they cannot drift apart: move a number here and the glade, the
  # markers, the thickets and the stalker all move with it.
  #
  # Nothing before waypoint 5. The player needs the walk from the landing to
  # find the lens, learn that it is heavy and slow, and get bored enough to put
  # it down. Being caught is what teaches them to raise it again.
  HW[0] = 5;  HN[0] = "A"
  HW[1] = 8;  HN[1] = "B"
  HW[2] = 12; HN[2] = "C"
  HW[3] = 16; HN[3] = "D"
  HUNTS = 4

  # Registered BEFORE forest() so the trees keep out of them. See glade() in
  # circus.awk for why the encounters need open ground rather than corridor.
  for (h = 0; h < HUNTS; h++) glade(PX[HW[h]], PZ[HW[h]], 15)
  # And the ground the big top stands on, so the treeline opens out as the
  # player arrives rather than running right up to the canvas.
  glade(0, -208, 44)

  # ---- the ground ------------------------------------------------------
  # One plate under everything, reaching well past the tent so the world has
  # no visible edge from anywhere the player can stand.
  printf "\n[node name=\"Ground\" type=\"CSGCombiner3D\" parent=\".\"]\nuse_collision = true\n"
  sbox("Ground", "Field", 0, -0.5, -30, 240, 1, 620, "Mat_lawn", 0, 0, 0)
  # The trodden path, a shade darker and a hair proud of the grass so it reads
  # as a route rather than a stain.
  for (i = 0; i < PN - 1; i++) {
    mx = (PX[i] + PX[i+1]) / 2; mz = (PZ[i] + PZ[i+1]) / 2
    dx = PX[i+1] - PX[i]; dz = PZ[i+1] - PZ[i]
    len = sqrt(dx * dx + dz * dz)
    ang = atan2(dx, dz) * 180 / 3.14159265
    sbox("Ground", "Path", mx, 0.012, mz, 3.4, 0.03, len + 3.0, "Mat_drive", 0, ang, 0)
  }

  # ---- the woods -------------------------------------------------------
  printf "\n[node name=\"Woods\" type=\"CSGCombiner3D\" parent=\".\"]\nuse_collision = true\n"
  # Platforms one and two: tight either side of the route, so the corridor has
  # walls and you cannot see across the level.
  forest("Woods", -62, 62, -68, 205, 5.5, 4.4)
  # Everything else, coarse, out to the horizon. The 30 m clearance is what
  # leaves the fairground open while still walling it in at the sides.
  forest("Woods", -118, 118, -215, 245, 13.0, 30.0)

  # ---- the hunt ---------------------------------------------------------
  # Four creatures, one to a glade, across platforms one and two. The first is
  # at waypoint 5 and not before: the player needs the walk from the landing to
  # find the lens, learn that it is heavy and slow, and get bored enough to
  # stop using it. Being caught is what teaches them to raise it again.
  #
  # Scrub does NOT collide. A bush you cannot walk into is a wall with leaves
  # on it, and these exist to be dived into.
  printf "\n[node name=\"Scrub\" type=\"CSGCombiner3D\" parent=\".\"]\nuse_collision = false\n"
  for (h = 0; h < HUNTS; h++) {
    w = HW[h]
    thicket("Scrub", path_off(w, -6,  7.5, "x"), path_off(w, -6,  7.5, "z"), "s" h "a")
    thicket("Scrub", path_off(w,  5, -8.0, "x"), path_off(w,  5, -8.0, "z"), "s" h "b")
    thicket("Scrub", path_off(w, 10,  6.0, "x"), path_off(w, 10,  6.0, "z"), "s" h "c")
  }

  printf "\n[node name=\"Cover\" type=\"Node3D\" parent=\".\"]\n"
  for (h = 0; h < HUNTS; h++) {
    w = HW[h]
    thicket_area("Cover", path_off(w, -6,  7.5, "x"), path_off(w, -6,  7.5, "z"), h "a")
    thicket_area("Cover", path_off(w,  5, -8.0, "x"), path_off(w,  5, -8.0, "z"), h "b")
    thicket_area("Cover", path_off(w, 10,  6.0, "x"), path_off(w, 10,  6.0, "z"), h "c")
  }

  printf "\n[node name=\"Hunt\" type=\"Node3D\" parent=\".\"]\n"
  printf "script = ExtResource(\"10_hunt\")\n"
  printf "route = NodePath(\"../Route\")\n"
  for (h = 0; h < HUNTS; h++) {
    patrol("Hunt", "Route" HN[h], HW[h], 9.0, 8.0, HN[h])
    stalker("Hunt", "Stalker" HN[h], "Route" HN[h], HW[h], 9.0, 8.0)
  }

  # ---- platform three: the tent ------------------------------------------
  printf "\n[node name=\"Tent\" type=\"CSGCombiner3D\" parent=\".\"]\nuse_collision = true\n"
  tent("Tent", 0, -265, 55, 24.0, 42.0)
  # The way in. A CSG subtraction, so it has to come AFTER the tent it bites
  # into. Eighteen metres deep, which makes it a passage rather than an alcove:
  # the door falls INTO somewhere, and the dark past it is what the player has
  # been walking toward since the trees thinned.
  cut_opening("Tent", "TentMouth", 0, 5.2, -218, 11.0, 10.4, 20.0)

  printf "\n[node name=\"Yard\" type=\"CSGCombiner3D\" parent=\".\"]\nuse_collision = true\n"
  tent_yard("Yard", 0, -265, 55, "y")

  # ---- the route, as nodes ---------------------------------------------
  # Last, so the scene file reads geometry first and metadata after.
  path_markers("Route")
}
' > "$BODY"

lines=$(wc -l < "$BODY")
if [ "$lines" -lt 400 ]; then
  echo "gen_circus.sh: body came out at only $lines lines -- refusing to write" >&2
  exit 1
fi

{
  echo '[gd_scene load_steps=40 format=3]'
  echo
  echo '; GENERATED by tools/gen_circus.sh -- re-run it rather than editing here.'
  echo ';'
  echo '; Where the book puts you. See the header of that script for the layout;'
  echo '; the short version is three platforms, +Z to -Z, and a very large tent.'
  echo
  echo '[ext_resource type="PackedScene" path="res://Scenes/player.tscn" id="1_player"]'
  echo '[ext_resource type="Environment" path="res://Materials/env_night.tres" id="2_env"]'
  echo '[ext_resource type="PackedScene" path="res://Scenes/audio.tscn" id="3_audio"]'
  echo '[ext_resource type="Script" path="res://Scripts/DialogueTrigger.gd" id="4_talk"]'
  echo '[ext_resource type="Script" path="res://Scripts/WakeUp.gd" id="5_wake"]'
  echo '[ext_resource type="PackedScene" path="res://Scenes/anim/wake.tscn" id="5_wakeanim"]'
  echo '[ext_resource type="PackedScene" path="res://Scenes/pickup.tscn" id="6_pick"]'
  echo '[ext_resource type="Resource" path="res://Items/magnifier.tres" id="7_glass"]'
  echo '[ext_resource type="Script" path="res://Scripts/ConcealArea.gd" id="9_conceal"]'
  echo '[ext_resource type="Script" path="res://Scripts/Hunt.gd" id="10_hunt"]'
  echo '[ext_resource type="PackedScene" path="res://Scenes/stalker.tscn" id="11_stalker"]'
  echo '[ext_resource type="PackedScene" path="res://Scenes/fall_door.tscn" id="12_door"]'
  echo '[ext_resource type="PackedScene" path="res://Scenes/wall_switch.tscn" id="13_switch"]'
  for m in Mat_lawn Mat_drive Mat_bark Mat_foliage Mat_wood Mat_iron Mat_canvas \
           Mat_velvet Mat_deck Mat_cloth Mat_label Mat_brass Mat_glass Mat_taillamp \
           Mat_enamel Mat_steel Mat_rust Mat_tyre Mat_shell Mat_lamp; do
    echo "[ext_resource type=\"Material\" path=\"res://Materials/$m.tres\" id=\"$m\"]"
  done
  echo
  echo '; Inside the big top. Dense, warm, and lit from within by the doorway'
  echo '; lamp, so walking through the door is walking into a wall of it.'
  echo ';'
  echo '; The environment already has volumetric fog switched on, which is what'
  echo '; makes a FogVolume work at all -- this only adds local density on top'
  echo '; of it. See Materials/env_night.tres.'
  echo '[sub_resource type="FogMaterial" id="Fog_tent"]'
  echo 'density = 1.6'
  echo 'albedo = Color(0.93, 0.86, 0.76, 1)'
  echo 'emission = Color(0.26, 0.15, 0.07, 1)'
  echo 'height_falloff = 0.0'
  echo 'edge_fade = 0.12'
  echo
  echo '; A far thinner body for the few metres OUTSIDE the mouth, so the fog'
  echo '; does not stop dead on the plane of the doorway. At the interior'
  echo '; density it whited out the approach and hid the door and the switch,'
  echo '; which are the two things the player has to be able to find.'
  echo '[sub_resource type="FogMaterial" id="Fog_mouth"]'
  echo 'density = 0.22'
  echo 'albedo = Color(0.93, 0.86, 0.76, 1)'
  echo 'emission = Color(0.14, 0.08, 0.04, 1)'
  echo 'height_falloff = 0.4'
  echo 'edge_fade = 0.5'
  echo
  echo '[sub_resource type="BoxShape3D" id="Box_trigger"]'
  echo 'size = Vector3(26, 5, 8)'
  echo
  echo '; Crouch inside a thicket and you are gone. Wider than the scrub that'
  echo '; draws it, so the player is hidden a moment before they look hidden --'
  echo '; the reverse reads as the game cheating.'
  echo '[sub_resource type="BoxShape3D" id="Box_thicket"]'
  echo 'size = Vector3(4.4, 2.4, 4.4)'
  echo
  echo '[node name="CircusLevel" type="Node3D"]'
  cat "$BODY"

  cat <<'EOF'

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = ExtResource("2_env")

; Low and cold, from behind the tent, so the whole walk is toward a silhouette.
; Brighter than the mansion's night: there the torch is the point and the dark
; is the threat, here the player has to read a route across 450 m.
[node name="Moonlight" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.94, -0.17, 0.3, 0, 0.87, 0.49, -0.34, -0.46, 0.82, 0, 60, -200)
light_color = Color(0.72, 0.79, 1, 1)
light_energy = 0.9
shadow_enabled = true

; The tent, lit from within. The only landmark in the level -- it is what the
; player steers by once the trees thin out, so it needs a range that reaches
; back up the whole walk.
[node name="TentGlow" type="OmniLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 16, -258)
light_color = Color(1, 0.66, 0.3, 1)
light_energy = 16.0
omni_range = 150.0

; Facing -Z, down the route, because the first thing they see when they stand
; up should be the way on.
[node name="Player" parent="." instance=ExtResource("1_player")]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 1.2, 190)

[node name="Audio" parent="." instance=ExtResource("3_audio")]

; Coming round on the forest floor. Holds the controls until the character is
; on their feet -- see Scripts/WakeUp.gd.
[node name="WakeUp" type="Node3D" parent="."]
script = ExtResource("5_wake")
player_path = NodePath("../Player")
lines = PackedStringArray("Ground. Wet ground, and pine.", "Nothing is broken. I do not understand why nothing is broken.", "There is a light away through the trees. It is a long way off.")
objective = "Head for the light."

; The whole running order of the wake-up -- both blinks, the head turn, the
; body coming up, the stagger and the hand-back -- is keyed in this
; animation rather than written in WakeUp.gd, which now only says what the
; poses mean.
[node name="Anim" parent="WakeUp" instance=ExtResource("5_wakeanim")]

; Where it fell out of his coat when he landed. Deliberately a few steps from
; the spawn: the first thing the player does is look around, and the first
; thing they should find is the one tool this level is about.
[node name="Magnifier" parent="." instance=ExtResource("6_pick")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.4, 0.42, 186.5)
item = ExtResource("7_glass")
grants_magnifier = true
prompt = "The glass, in the pine needles"
examine_lines = Array[String](["It came through with me.", "Of course it did."])

; ---- the beats, staged as triggers -----------------------------------------
; These speak lines for now. The enemy and the stealth loop replace them.

[node name="TalkWoods" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 130)
script = ExtResource("4_talk")
lines = Array[String](["Something moved between the trunks.", "Not an animal. It did not sound like weight on the ground.", "The glass showed me things in the house. It might show me this."])

[node name="Shape" type="CollisionShape3D" parent="TalkWoods"]
shape = SubResource("Box_trigger")

[node name="TalkSight" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 40)
script = ExtResource("4_talk")
lines = Array[String](["There. Over the tops of the trees.", "That is a tent. That is a circus tent, and it is enormous."])

[node name="Shape" type="CollisionShape3D" parent="TalkSight"]
shape = SubResource("Box_trigger")

[node name="TalkYard" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, -190)
script = ExtResource("4_talk")
lines = Array[String](["Stakes, and rope, and cases stacked where somebody put them down.", "This is the back of it. There is no front."])

[node name="Shape" type="CollisionShape3D" parent="TalkYard"]
shape = SubResource("Box_trigger")

; THE WAY IN. A switch on the canvas, and a door that does not open.
;
; This replaces the hand-over to the fairground that used to sit at z -82. The
; midway was a second place grafted onto the front of the first: you walked
; 400 m of woods to reach a circus and were then made to walk a fair before you
; got to it. Cutting it means the tent is what the whole level has been
; steering toward since the trees first thinned, and arriving is arriving.
;
; The door falls INTO the passage, away from the player, so the dust comes at
; them down an eighteen metre tunnel rather than going off in their face.
[node name="BigTopDoor" parent="." instance=ExtResource("12_door")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -210)
lines = Array[String](["It did not open. It came down.", "There is a smell of sawdust, and something underneath it."])

[node name="DoorSwitch" parent="." instance=ExtResource("13_switch")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.4, 1.5, -209.4)
prompt = "switch, beside the door"
targets = [NodePath("../BigTopDoor")]
examine_lines = Array[String](["A knife switch, low on the canvas. The only thing out here I can reach."])

; The passage past the door. TentGlow is buried in the middle of the tent,
; behind fifty metres of solid canvas, and lights none of this.
; WHAT IS INSIDE THE TENT IS FOG, and that is a decision rather than a stopgap.
;
; The game does not end when the player walks in -- there is no trigger on the
; door and none is wanted. So there has to be somewhere to walk INTO, and a
; lit eighteen-metre corridor ending in a flat canvas wall is the worst
; possible version of that: it reads as the edge of the map, which is exactly
; what it is.
;
; Dense fog reads as depth instead. The lamp above the door lights it from
; behind so the doorway glows rather than gapes, the far wall is gone by four
; or five metres in, and the passage becomes somewhere that continues.
[node name="TentFog" type="FogVolume" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 5.2, -220)
size = Vector3(11, 10.4, 22)
material = SubResource("Fog_tent")

; A second, thinner body spilling out of the mouth, so the fog does not stop
; dead on the plane of the doorway. It should look like it is leaking out.
[node name="TentFogMouth" type="FogVolume" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3.0, -207.5)
size = Vector3(13, 6.5, 6)
material = SubResource("Fog_mouth")

[node name="DoorwayGlow" type="OmniLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 5, -217)
light_color = Color(1, 0.6, 0.28, 1)
light_energy = 3.4
omni_range = 26.0

EOF
} > "$OUT"

printf 'wrote %s (%s nodes)\n' "$OUT" "$(grep -c '^\[node' "$OUT")"
