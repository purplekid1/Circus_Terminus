#!/usr/bin/env bash
# Writes Scenes/menu.tscn -- the title screen, as an ACTUAL SCENE TREE.
#
# It used to be built entirely by Scripts/MainMenu.gd at load: every tree,
# every kerbstone, every label and button called into existence in _ready().
# That meant opening menu.tscn in the editor showed you one node called
# MainMenu and nothing else -- nothing to select, nothing to nudge, no way to
# see what the screen looked like without running the game.
#
# Now the nodes are here. MainMenu.gd only does the things that are genuinely
# behaviour: scrolling the scenery, weaving the car, aiming the camera, and
# running the departure when "Drive on" is pressed.
#
#   tools/gen_menu.sh
#
# THE SCENERY'S AUTHORED Z IS ITS OFFSET ALONG THE LOOP. Everything under
# `Scroll` is recycled -- it travels from the fog line to just behind the shot
# and wraps -- so its z is overwritten every frame. What the scene file stores
# in z is where the piece sits in the cycle; its x and y are real. Move a tree
# sideways in the editor and it stays moved; move it along the road and you
# have changed its phase, which is also useful and is why it works this way.
#
# As with every other generated scene here: re-running this OVERWRITES hand
# edits. Tune the tables below rather than the output, or stop running it once
# the scene has been arranged by hand -- which is what happened to the mansion.

set -euo pipefail
cd "$(dirname "$0")/.."

AWK=${AWK:-awk}
OUT=Scenes/menu.tscn
BODY=$(mktemp)
MESH=$(mktemp)
trap 'rm -f "$BODY" "$MESH"' EXIT

# Geometry of the drive. These MUST agree with the constants of the same name
# in MainMenu.gd -- the script wraps the scenery using SPAN and BEHIND, and a
# mismatch shows up as pieces popping in front of the camera.
SPAN=210
BEHIND=16
LANE=3.4
VERGE=5.2
TREE_LINE=21
CAR_X=1.55
CAR_Z=-17

"$AWK" -v SPAN="$SPAN" -v LANE="$LANE" -v VERGE="$VERGE" -v TREE_LINE="$TREE_LINE" \
       -v MESHFILE="$MESH" '
function jit(key, spread,   h) {
  # The same hash MainMenu.gd used, so the woods keep the layout they had.
  h = (key * 2654435761) % 1000003
  return ((h % 2000) / 1000.0 - 1.0) * spread
}

function node(name, type, parent) {
  printf "\n[node name=\"%s\" type=\"%s\" parent=\"%s\"]\n", name, type, parent
}

function at(x, y, z) {
  printf "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f)\n", x, y, z
}

## A MeshInstance3D under Scroll whose z is its phase in the loop.
##
## NUMBERED. Eighteen sibling nodes all called "Dash" is not eighteen nodes:
## names are unique per parent, and the scene came back with one dash, one
## kerb line and one verge slab in it -- the road markings simply vanished.
function piece(name, mesh, x, y, offset) {
  N++
  node(name N, "MeshInstance3D", "Scroll")
  at(x, y, offset)
  printf "mesh = SubResource(\"%s\")\n", mesh
  printf "cast_shadow = 0\n"
}

BEGIN {
  # ------------------------------------------------------------ tree heights
  # Eight heights, shared out among the trees. They used to be eight sets of
  # CylinderMesh sub-resources -- a trunk and three cones each -- because the
  # treeline was built from primitives. It is the hand-modelled pine now, one
  # mesh for all of them, so only the heights survive.
  nvar = 8
  split("10.5 12.0 13.2 14.4 15.5 16.6 17.8 12.9", th, " ")
  PINE_H = 4.198

  # --------------------------------------------------------------- the road
  node("Scroll", "Node3D", ".")

  # Centre dashes, every twelve metres.
  for (z = 0; z < SPAN; z += 12) piece("Dash", "Mesh_dash", 0, 0, z)

  # Kerb lines, in shorter lengths and out of step side to side so the eye
  # cannot lock onto the repeat.
  for (z = 0; z < SPAN; z += 9)
    for (s = -1; s <= 1; s += 2)
      piece("KerbLine", "Mesh_kerbline", s * (LANE - 0.15), 0, z + (s > 0 ? 3 : 0))

  # Kerbstone verge.
  for (z = 0; z < SPAN; z += 6)
    for (s = -1; s <= 1; s += 2)
      piece("Verge", "Mesh_verge", s * VERGE, 0.06, z)

  # Marker posts with a reflector on each.
  for (z = 0; z < SPAN; z += 22) {
    for (s = -1; s <= 1; s += 2) {
      P++
      x = s * (VERGE + 0.9)
      node("Post" P, "Node3D", "Scroll")
      at(0, 0, z + (s > 0 ? 11 : 0))
      node("Shaft", "MeshInstance3D", "Scroll/Post" P)
      at(x, 0.60, 0)
      printf "mesh = SubResource(\"Mesh_shaft\")\ncast_shadow = 0\n"
      node("Cat", "MeshInstance3D", "Scroll/Post" P)
      at(x, 0.94, 0.05)
      printf "mesh = SubResource(\"Mesh_cat\")\ncast_shadow = 0\n"
    }
  }

  # The woods: two ragged rows a side.
  #
  # ONE NODE PER TREE. Each was a Node3D holding a trunk and three cones --
  # four MeshInstance3Ds, 320 of them across the eighty trees. Now it is one
  # MeshInstance3D wearing Meshes/pine.res, so the whole treeline is eighty
  # nodes and looks like a wood rather than like a row of cones.
  #
  # The transform carries the SCALE and a YAW. The 12-float Transform3D in a
  # .tscn is three basis ROWS, so a yaw of `a` about Y is
  # [[c,0,sn],[0,1,0],[-sn,0,c]] times the scale. Without the yaw, eighty
  # copies of one mesh all face the same way and the repeat is obvious.
  #
  # Lifted 0.173*scale, because the lowest vertex of the pine mesh sits below
  # its own origin.
  idx = 0
  for (z = 0; z < SPAN; z += 11) {
    for (s = -1; s <= 1; s += 2) {
      for (rank = 0; rank < 2; rank++) {
        T++
        h = th[(idx % nvar) + 1]
        sc = h / PINE_H
        a = jit(idx * 13 + 3, 3.14159)
        c = cos(a); sn = sin(a)
        x = s * (TREE_LINE + rank * 9.0 + jit(idx, 3.2))
        node("Tree" T, "MeshInstance3D", "Scroll")
        printf "transform = Transform3D(%.4f, 0, %.4f, 0, %.4f, 0, %.4f, 0, %.4f, %.4f, %.4f, %.4f)\n", \
               sc * c, sc * sn, sc, -sc * sn, sc * c, \
               x, 0.173 * sc, z + jit(idx + 7, 4.2) + rank * 5.0
        printf "mesh = ExtResource(\"6_pine\")\n"
        printf "material_override = ExtResource(\"7_pinemat\")\n"
        printf "cast_shadow = 0\n"
        idx++
      }
    }
  }
}' > "$BODY"

GROUND_Z=$(awk -v s="$SPAN" -v b="$BEHIND" 'BEGIN { printf "%.1f", -s / 2 + b }')
ROAD_W=$(awk -v l="$LANE" 'BEGIN { printf "%.1f", l * 2 }')
LONG=$(awk -v s="$SPAN" 'BEGIN { printf "%.1f", s + 80 }')
CAM_X=$(awk -v a="$CAR_X" 'BEGIN { printf "%.2f", a - 3.35 }')
CAM_Z=$(awk -v a="$CAR_Z" 'BEGIN { printf "%.2f", a + 7.60 }')

{
cat <<HEADER
[gd_scene load_steps=2 format=3]

; THE TITLE SCREEN. Generated by tools/gen_menu.sh -- read that file first.
;
; Everything you can see is a node in here: the road, the woods, the car, the
; camera, the menu itself. Scripts/MainMenu.gd only moves them.
;
; Under \`Scroll\`, a node's AUTHORED Z IS ITS PHASE IN THE LOOP, not a place.
; The script overwrites z every frame as the piece travels toward the camera
; and wraps. x and y are real.

[ext_resource type="Script" path="res://Scripts/MainMenu.gd" id="1_menu"]
[ext_resource type="Script" path="res://Scripts/KeybindsPanel.gd" id="2_keys"]
[ext_resource type="Script" path="res://Scripts/SettingsPanel.gd" id="2_setpanel"]
[ext_resource type="PackedScene" path="res://Scenes/car.tscn" id="3_car"]
[ext_resource type="Environment" path="res://Materials/env_night.tres" id="4_env"]
[ext_resource type="AudioStream" path="res://Audio/menu_theme.mp3" id="5_music"]
[ext_resource type="Material" path="res://Materials/Mat_asphalt.tres" id="Mat_asphalt"]
[ext_resource type="Material" path="res://Materials/Mat_kerb.tres" id="Mat_kerb"]
[ext_resource type="Material" path="res://Materials/Mat_lawn.tres" id="Mat_lawn"]
[ext_resource type="Material" path="res://Materials/Mat_bark.tres" id="Mat_bark"]
[ext_resource type="Material" path="res://Materials/Mat_foliage.tres" id="Mat_foliage"]
[ext_resource type="ArrayMesh" path="res://Meshes/pine.res" id="6_pine"]
[ext_resource type="Material" path="res://Materials/Mat_pine.tres" id="7_pinemat"]

; Road paint. Slightly emissive, because paint at night is retroreflective and
; this is the cheap way to say so without a second light.
[sub_resource type="StandardMaterial3D" id="Mat_line"]
albedo_color = Color(0.74, 0.72, 0.66, 1)
emission_enabled = true
emission = Color(0.3, 0.31, 0.33, 1)
emission_energy_multiplier = 0.8

; A marker-post reflector. Unshaded, so it glows exactly as far as its own
; edges -- forty of these as real lights is forty lights to cull.
[sub_resource type="StandardMaterial3D" id="Mat_reflector"]
shading_mode = 0
albedo_color = Color(0.9, 0.35, 0.2, 1)
emission_enabled = true
emission = Color(1, 0.42, 0.22, 1)
emission_energy_multiplier = 3.0

[sub_resource type="BoxMesh" id="Mesh_ground"]
material = ExtResource("Mat_lawn")
size = Vector3(260, 0.1, $LONG)

[sub_resource type="BoxMesh" id="Mesh_road"]
material = ExtResource("Mat_asphalt")
size = Vector3($ROAD_W, 0.08, $LONG)

[sub_resource type="BoxMesh" id="Mesh_dash"]
material = SubResource("Mat_line")
size = Vector3(0.16, 0.02, 3)

[sub_resource type="BoxMesh" id="Mesh_kerbline"]
material = SubResource("Mat_line")
size = Vector3(0.12, 0.02, 7)

[sub_resource type="BoxMesh" id="Mesh_verge"]
material = ExtResource("Mat_kerb")
size = Vector3(1.4, 0.16, 6)

[sub_resource type="BoxMesh" id="Mesh_shaft"]
material = SubResource("Mat_line")
size = Vector3(0.11, 1.05, 0.06)

[sub_resource type="BoxMesh" id="Mesh_cat"]
material = SubResource("Mat_reflector")
size = Vector3(0.09, 0.14, 0.02)

; The vignette behind the menu text. A GRADIENT, not a flat rect: flat, it
; ends in a hard vertical line down the middle of the screen, which was
; invisible over a dark cabin interior and glaring over a moonlit road.
[sub_resource type="Gradient" id="Grad_shade"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0, 0, 0, 0.8, 0, 0, 0, 0)

[sub_resource type="GradientTexture2D" id="Tex_shade"]
gradient = SubResource("Grad_shade")
width = 256
height = 4
fill_to = Vector2(1, 0)

HEADER
cat "$MESH"
cat <<FIXTURES
[node name="MainMenu" type="Node3D"]
script = ExtResource("1_menu")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = ExtResource("4_env")

; No shadows on the moon. The only things they would fall on are trees
; streaming past at fourteen metres a second.
; rotation_degrees rather than a baked basis: hand-multiplying Ry*Rx to write
; a Transform3D here is how the first version ended up lighting the scene from
; 41 degrees when it meant 34.
[node name="Moon" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-34, 152, 0)
light_color = Color(0.62, 0.72, 1, 1)
light_energy = 0.3
shadow_enabled = false

; The ONE shadow caster, and it exists to put the car on the road -- without
; it nothing under the car darkens and it reads as a sticker on the tarmac.
; Capped at forty metres: the treeline is two hundred metres of silhouette and
; there is nothing out there for a shadow to fall on.
[node name="Key" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-28, 128, 0)
light_color = Color(0.66, 0.75, 1, 1)
light_energy = 0.4
shadow_enabled = true
directional_shadow_max_distance = 40.0

; Positioned and aimed every frame by MainMenu._aim_camera. What is stored
; here is where it rests, so the scene looks right in the editor.
[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, $CAM_X, 2.15, $CAM_Z)
fov = 55.0
near = 0.05
far = 320.0

; The car that pulls up at the gate in the intro, so the title screen and the
; opening are the same vehicle. It stands still and the road moves.
[node name="Car" parent="." instance=ExtResource("3_car")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, $CAR_X, 0, $CAR_Z)
start_point = Vector3($CAR_X, 0, $CAR_Z)
stop_point = Vector3($CAR_X, 0, $CAR_Z)

; One long slab each. They are uniform along their length, so nothing about
; them reveals that they are standing still, and a scrolling road surface
; would only add seams to hide.
[node name="Ground" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.02, $GROUND_Z)
mesh = SubResource("Mesh_ground")
cast_shadow = 0

[node name="Road" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, $GROUND_Z)
mesh = SubResource("Mesh_road")
cast_shadow = 0
FIXTURES
cat "$BODY"
cat <<'UI'

; The title track. It loops in the AUDIO THREAD at its beat count, which is
; 16.000 s exactly -- see Audio/menu_theme.mp3.import and tools/README.md.
; Starts near silence; MainMenu brings it up.
[node name="Music" type="AudioStreamPlayer" parent="."]
stream = ExtResource("5_music")
volume_db = -40.0
autoplay = true

[node name="UI" type="CanvasLayer" parent="."]
layer = 10

[node name="Shade" type="TextureRect" parent="UI"]
anchors_preset = 9
anchor_bottom = 1.0
offset_right = 1020.0
grow_vertical = 2
mouse_filter = 2
texture = SubResource("Tex_shade")
; stretch_mode 0 is SCALE. 1 is TILE, which repeated the 256 px ramp four
; times across the screen and turned the vignette into vertical banding.
expand_mode = 1
stretch_mode = 0

; Everything that slides away when "Drive on" is pressed lives under here, so
; the departure is one property on one node instead of four.
[node name="Panel" type="Control" parent="UI"]
anchors_preset = 0
offset_right = 1020.0
offset_bottom = 720.0
mouse_filter = 2

[node name="Title" type="Label" parent="UI/Panel"]
offset_left = 96.0
offset_top = 150.0
offset_right = 900.0
offset_bottom = 230.0
mouse_filter = 2
text = "CIRCUS TERMINUS"
theme_override_colors/font_color = Color(0.88, 0.89, 0.93, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.9)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 3
theme_override_font_sizes/font_size = 58

[node name="Sub" type="Label" parent="UI/Panel"]
offset_left = 100.0
offset_top = 218.0
offset_right = 700.0
offset_bottom = 250.0
mouse_filter = 2
text = "chapter one"
theme_override_colors/font_color = Color(0.45, 0.49, 0.56, 1)
theme_override_font_sizes/font_size = 22

[node name="Menu" type="VBoxContainer" parent="UI/Panel"]
offset_left = 100.0
offset_top = 320.0
offset_right = 520.0
offset_bottom = 522.0
theme_override_constants/separation = 6

[node name="Drive" type="Button" parent="UI/Panel/Menu"]
custom_minimum_size = Vector2(420, 46)
layout_mode = 2
text = "Drive on"
flat = true
alignment = 0
theme_override_colors/font_color = Color(0.62, 0.66, 0.74, 1)
theme_override_colors/font_focus_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_hover_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_pressed_color = Color(0.92, 0.78, 0.46, 1)
theme_override_font_sizes/font_size = 27

[node name="Controls" type="Button" parent="UI/Panel/Menu"]
custom_minimum_size = Vector2(420, 46)
layout_mode = 2
text = "Controls"
flat = true
alignment = 0
theme_override_colors/font_color = Color(0.62, 0.66, 0.74, 1)
theme_override_colors/font_focus_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_hover_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_pressed_color = Color(0.92, 0.78, 0.46, 1)
theme_override_font_sizes/font_size = 27

[node name="Settings" type="Button" parent="UI/Panel/Menu"]
custom_minimum_size = Vector2(420, 46)
layout_mode = 2
text = "Settings"
flat = true
alignment = 0
theme_override_colors/font_color = Color(0.62, 0.66, 0.74, 1)
theme_override_colors/font_focus_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_hover_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_pressed_color = Color(0.92, 0.78, 0.46, 1)
theme_override_font_sizes/font_size = 27

[node name="Leave" type="Button" parent="UI/Panel/Menu"]
custom_minimum_size = Vector2(420, 46)
layout_mode = 2
text = "Leave"
flat = true
alignment = 0
theme_override_colors/font_color = Color(0.62, 0.66, 0.74, 1)
theme_override_colors/font_focus_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_hover_color = Color(0.92, 0.78, 0.46, 1)
theme_override_colors/font_pressed_color = Color(0.92, 0.78, 0.46, 1)
theme_override_font_sizes/font_size = 27

[node name="Footnote" type="Label" parent="UI/Panel"]
offset_left = 100.0
offset_top = 566.0
offset_right = 760.0
offset_bottom = 626.0
mouse_filter = 2
text = "The same settings are in the character's own notebook,
once you are out of the car."
theme_override_colors/font_color = Color(0.45, 0.49, 0.56, 1)
theme_override_font_sizes/font_size = 14

[node name="ControlsSheet" type="Control" parent="UI"]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Dim" type="ColorRect" parent="UI/ControlsSheet"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.94)

[node name="Heading" type="Label" parent="UI/ControlsSheet"]
offset_left = 140.0
offset_top = 90.0
offset_right = 700.0
offset_bottom = 140.0
mouse_filter = 2
text = "CONTROLS"
theme_override_colors/font_color = Color(0.88, 0.89, 0.93, 1)
theme_override_font_sizes/font_size = 34

; The rebinding table, shared with the journal's CONTROLS page. It fills
; itself from the Input Map -- there is no other way to draw a list of what is
; currently bound -- but the frame it lives in is authored here.
[node name="Keybinds" type="Control" parent="UI/ControlsSheet"]
offset_left = 140.0
offset_top = 150.0
offset_right = 1320.0
offset_bottom = 910.0
mouse_filter = 1
script = ExtResource("2_keys")
ink = Color(0.88, 0.89, 0.93, 1)
ink_soft = Color(0.62, 0.66, 0.74, 1)
ink_accent = Color(0.92, 0.78, 0.46, 1)
footer = "Choose a binding, then press the key or button you want."

[node name="Back" type="Button" parent="UI/ControlsSheet"]
offset_left = 1400.0
offset_top = 88.0
offset_right = 1520.0
offset_bottom = 128.0
text = "  Back  "
theme_override_font_sizes/font_size = 20

; The same settings the journal shows, so a choice made before the drive is
; the one in force during it. The rows are SettingsPanel, shared with the
; book; they write to Scripts/Settings.gd, which is where they have to live
; because there is no player on this screen to hang them on.
[node name="SettingsSheet" type="Control" parent="UI"]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Dim" type="ColorRect" parent="UI/SettingsSheet"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.94)

[node name="Heading" type="Label" parent="UI/SettingsSheet"]
offset_left = 140.0
offset_top = 90.0
offset_right = 700.0
offset_bottom = 140.0
mouse_filter = 2
text = "SETTINGS"
theme_override_colors/font_color = Color(0.88, 0.89, 0.93, 1)
theme_override_font_sizes/font_size = 34

[node name="Rows" type="Control" parent="UI/SettingsSheet"]
offset_left = 140.0
offset_top = 180.0
offset_right = 1320.0
offset_bottom = 820.0
mouse_filter = 1
script = ExtResource("2_setpanel")
ink = Color(0.88, 0.89, 0.93, 1)
ink_soft = Color(0.62, 0.66, 0.74, 1)
font_size = 21
readout_size = 19
label_width = 430.0
control_width = 380.0
row_separation = 26

[node name="Note" type="Label" parent="UI/SettingsSheet"]
offset_left = 140.0
offset_top = 840.0
offset_right = 1320.0
offset_bottom = 890.0
mouse_filter = 2
text = "These last as long as the game is running. The character's own notebook has the same page in it."
theme_override_colors/font_color = Color(0.45, 0.49, 0.56, 1)
theme_override_font_sizes/font_size = 14

[node name="Back" type="Button" parent="UI/SettingsSheet"]
offset_left = 1400.0
offset_top = 88.0
offset_right = 1520.0
offset_bottom = 128.0
text = "  Back  "
theme_override_font_sizes/font_size = 20

; Last child, so it covers everything including the two sheets.
[node name="Blackout" type="ColorRect" parent="UI"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0, 0, 0, 0)

[connection signal="pressed" from="UI/Panel/Menu/Drive" to="." method="_on_drive_pressed"]
[connection signal="pressed" from="UI/Panel/Menu/Controls" to="." method="_on_controls_pressed"]
[connection signal="pressed" from="UI/Panel/Menu/Settings" to="." method="_on_settings_pressed"]
[connection signal="pressed" from="UI/Panel/Menu/Leave" to="." method="_on_leave_pressed"]
[connection signal="pressed" from="UI/ControlsSheet/Back" to="." method="_on_back_pressed"]
[connection signal="pressed" from="UI/SettingsSheet/Back" to="." method="_on_settings_back_pressed"]
UI
} > "$OUT"

printf 'wrote %s  (%s nodes)\n' "$OUT" "$(grep -c '^\[node' "$OUT")"
