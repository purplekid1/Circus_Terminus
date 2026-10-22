#!/usr/bin/env bash
# Writes the audio bus layout and Scenes/audio.tscn -- the zone volumes and the
# ambience bed that make the house sound like the inside of a house.
#
# Both are generated for the same reason every other scene here is: so the
# numbers live in one readable place with the reasoning next to them, rather
# than in a binary-ish .tres nobody can diff. Both are still real engine
# resources afterwards -- the buses show up in the editor's Audio panel and the
# zones are Area3Ds you can select and drag.
#
# THE EDITOR WILL OVERWRITE default_bus_layout.tres if anyone touches the Audio
# panel and saves. That is the same trap as project.godot; re-run this script to
# put it back.

set -euo pipefail
cd "$(dirname "$0")/.."

# ---- where the floors are -------------------------------------------------
# Measured, not guessed -- tools/probe_floors.gd casts down through the house
# and prints every surface it passes. Re-run it if the shell ever moves.
#
#   lawn                 0.05
#   ground floor         0.35
#   upper floors         3.95, 7.55
#   cellar floor        -3.25
#   storm-door pit      -3.00
#
# The split between "in the cellar" and "in the house" therefore goes anywhere
# between -3.25 and 0.35; -0.30 puts it just under the ground-floor slab, so
# the player is upstairs the moment their feet are on it.
SPLIT=-0.30

# Shell footprint, from tools/probe_bounds.gd: x -17.2..17.2, z -75.7..-41.3.
# The zone boxes are a touch wider than the walls so that standing in a doorway
# is unambiguously inside.

cat > default_bus_layout.tres <<'EOF'
[gd_resource type="AudioBusLayout" load_steps=3 format=3 uid="uid://bqterminus0aud"]

; Five buses, so that each kind of sound can be ducked, filtered or muted
; without touching the others. The filter and the reverb sit on Ambience alone:
; muffling the footsteps as well would be wrong, because the player is in the
; room WITH their own feet -- it is the weather that is outside.

[sub_resource type="AudioEffectLowPassFilter" id="amb_lp"]
; Opens to 20500 outdoors and closes down to a few hundred Hz in the cellar.
; Scripts/Ambience.gd drives this; the value here is the outdoor one, so the
; scene sounds right the moment it is opened in the editor.
cutoff_hz = 20500.0
; NOT ZERO. A resonance of 0 over-damps this filter and costs 27 dB of
; insertion loss even wide open at 20.5 kHz -- measured, not guessed. It is why
; the ambience had to be pushed to +21 dB to be audible at all, and why every
; indoor cutoff had to be dragged upwards to stop "muffled" becoming "silent".
; At 0.5, the engine default, the filter is transparent when open.
resonance = 0.5
db = 0

[sub_resource type="AudioEffectReverb" id="amb_verb"]
; Almost entirely dry outdoors. Wetness comes up indoors, which is what turns
; "weather" into "weather heard through a wall in a big empty house".
room_size = 0.65
damping = 0.55
spread = 1.0
hipass = 0.15
dry = 1.0
wet = 0.0

[resource]
bus/0/name = &"Master"
bus/0/solo = false
bus/0/mute = false
bus/0/bypass_fx = false
bus/0/volume_db = 0.0
bus/0/send = &""
bus/1/name = &"Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"Ambience"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
bus/2/effect/0/effect = SubResource("amb_lp")
bus/2/effect/0/enabled = true
bus/2/effect/1/effect = SubResource("amb_verb")
bus/2/effect/1/enabled = true
bus/3/name = &"Steps"
bus/3/solo = false
bus/3/mute = false
bus/3/bypass_fx = false
bus/3/volume_db = 0.0
bus/3/send = &"Master"
bus/5/name = &"Interior"
bus/5/solo = false
bus/5/mute = false
bus/5/bypass_fx = false
; Deliberately CLEAN -- no low-pass, no reverb. The room you are standing in
; is not on the other side of a wall. Only the outdoor bed is filtered, and it
; cannot be both at once on one bus, which is why there are two.
bus/5/volume_db = 0.0
bus/5/send = &"Master"
bus/4/name = &"Sfx"
bus/4/solo = false
bus/4/mute = false
bus/4/bypass_fx = false
; Effects sit WELL under everything else. They are incidental -- a latch, a
; tick, a machine two rooms away -- and at unity they shouted over the
; footsteps, the ambience and the dialogue all at once. One place to trim
; them all, rather than eleven call sites to keep in step.
bus/4/volume_db = -14.0
bus/4/send = &"Master"
EOF

# ---- the scene ------------------------------------------------------------

zone() { # name zone_id  cx cy cz  sx sy sz
  cat <<EOF

[node name="$1" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, $3, $4, $5)
monitorable = false
collision_layer = 0
collision_mask = 1
script = ExtResource("zone")
zone = $2

[node name="Shape" type="CollisionShape3D" parent="$1"]
shape = SubResource("box_$1")
EOF
}

shape() { # name sx sy sz
  printf '\n[sub_resource type="BoxShape3D" id="box_%s"]\nsize = Vector3(%s, %s, %s)\n' "$1" "$2" "$3" "$4"
}

{
  echo '[gd_scene load_steps=9 format=3]'
  echo
  echo '; GENERATED by tools/gen_audio.sh -- re-run it rather than editing here.'
  echo ';'
  echo '; The zone volumes and the ambience bed. Instanced into demo_level.tscn.'
  echo ';'
  echo '; A zone is an Area3D on the player body layer, and AudioZone.gd checks the'
  echo '; "player" group as well -- the layer alone is the default one, so a crate'
  echo '; or a door leaf would otherwise count as the player walking in. The boxes'
  echo '; do not overlap: House starts above the ground slab, Cellar and StormPit'
  echo '; sit below it, and everywhere else is outdoors by default.'
  echo
  echo '[ext_resource type="Script" path="res://Scripts/AudioZone.gd" id="zone"]'
  echo '[ext_resource type="Script" path="res://Scripts/Ambience.gd" id="amb"]'
  echo '[ext_resource type="AudioStream" path="res://Audio/amb_outside.mp3" id="bed_out"]'
  echo '[ext_resource type="AudioStream" path="res://Audio/amb_house.mp3" id="bed_house"]'
  echo '[ext_resource type="AudioStream" path="res://Audio/amb_cellar.mp3" id="bed_cellar"]'

  # House: the whole shell footprint from just under the ground slab to well
  # above the ridge, so the attic counts as indoors too.
  shape House 34.4 20.3 34.4
  # Cellar: the same footprint, below the slab. Anything under the house is the
  # cellar -- there is nothing else down there to be.
  shape Cellar 34.4 4.0 34.4
  # The sunken stairwell outside the north wall. Open to the sky, but by the
  # time you are at the bottom you are in a stone box, and it should sound like
  # one before the gate rather than after it.
  shape StormPit 6.0 3.7 8.2

  echo
  echo '[node name="Audio" type="Node3D"]'

  zone House   1  0    9.85  -58.5
  zone Cellar  2  0   -2.30  -58.5
  zone StormPit 2 -10  -2.15  -79.5

  cat <<'EOF'

; Three beds -- night outside, room tone indoors, water in the cellar. The
; players are made by Scripts/Ambience.gd rather than authored here, because
; which bus each one belongs on is part of how the muffling works and is
; better stated once in the script than duplicated in the scene.
[node name="Ambience" type="Node" parent="."]
script = ExtResource("amb")
outside = ExtResource("bed_out")
house = ExtResource("bed_house")
cellar = ExtResource("bed_cellar")
EOF
} > Scenes/audio.tscn

echo "wrote default_bus_layout.tres and Scenes/audio.tscn ($(grep -c '^\[node' Scenes/audio.tscn) nodes)"
