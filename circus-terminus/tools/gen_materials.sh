#!/usr/bin/env bash
# Writes Materials/*.tres: the shared noise textures and every material in the
# house, one file each.
#
# These used to be sub_resources inside mansion.tscn, which meant nothing else
# could reference them. Now the prop scenes in Scenes/props/ and the generated
# mansion both point at the same files, so a material is changed in one place.
#
# A roughness_texture MULTIPLIES the roughness value, so a mid-grey noise map
# roughly halves it. Setting roughness 0.5 and then hanging a noise map off it
# lands near 0.25, which is lacquer -- under a close lamp every wooden surface
# blew out to pale cream. So: normal maps everywhere (they do the visual work),
# roughness maps only where patchy sheen is the point, and a base value chosen
# knowing it will be halved.

set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Materials
mkdir -p "$OUT"

# ---- noise textures -------------------------------------------------------

# Re-emits the uid a resource already carries, so regenerating never changes it.
#
# THIS SCRIPT USED TO DROP THE UID. It wrote every .tres with none; the editor
# assigned a fresh random one on the next import; and every already-baked mesh
# in Meshes/ went on referencing the PREVIOUS one, so Godot fell back to the
# text path and warned -- once per reference. A single run of this script was
# worth 120 warnings in the editor's error panel.
#
# Read BEFORE the output redirection opens. `{ ... } > file` truncates the file
# first, so a lookup from inside the block reads an empty one and the uid is
# lost anyway.
keep_uid() {
  [ -f "$OUT/$1.tres" ] || return 0
  head -1 "$OUT/$1.tres" | grep -o ' uid="uid://[a-z0-9]*"' || true
}

tex() { # file noise_type freq octaves [bump_strength]
  local f=$1 nt=$2 fr=$3 oc=$4 bump=${5:-}
  local uid; uid=$(keep_uid "$f")
  {
    echo "[gd_resource type=\"NoiseTexture2D\" load_steps=2 format=3$uid]"
    echo
    echo '[sub_resource type="FastNoiseLite" id="n"]'
    echo "noise_type = $nt"
    echo "frequency = $fr"
    echo "fractal_octaves = $oc"
    echo
    echo '[resource]'
    echo 'width = 256'
    echo 'height = 256'
    echo 'noise = SubResource("n")'
    echo 'seamless = true'
    if [ -n "$bump" ]; then echo 'as_normal_map = true'; echo "bump_strength = $bump"; fi
  } > "$OUT/$f.tres"
}

# noise_type 3 is cellular, 1 is simplex
tex tex_fineN   3 0.09  4 3.5    # plaster tooth, stone pitting
tex tex_medN    1 0.028 3 2.0    # boards, siding
tex tex_grainN  3 0.22  2 1.6    # cloth weave, paper
tex tex_woodN   1 0.004 2 2.6    # long stretched timber grain
tex tex_medR    1 0.028 3        # roughness break-up, mid
tex tex_coarseR 1 0.008 3        # roughness break-up, broad damp patches
tex tex_fineR   3 0.09  4        # roughness break-up, tight

# ---- materials ------------------------------------------------------------

mat() { # name albedo rough metal normal-tex normal-scale rough-tex uv [extra...]
  local id=$1 col=$2 rough=$3 metal=$4 ntex=$5 nscale=$6 rtex=$7 uv=$8
  shift 8
  local steps=1 refs=""
  if [ "$ntex" != "-" ]; then steps=$((steps + 1)); refs="$refs $ntex"; fi
  if [ "$rtex" != "-" ] && [ "$rtex" != "$ntex" ]; then steps=$((steps + 1)); refs="$refs $rtex"; fi
  local uid; uid=$(keep_uid "$id")
  {
    echo "[gd_resource type=\"StandardMaterial3D\" load_steps=$steps format=3$uid]"
    echo
    local t
    for t in $refs; do
      echo "[ext_resource type=\"Texture2D\" path=\"res://Materials/$t.tres\" id=\"$t\"]"
    done
    echo
    echo '[resource]'
    echo "albedo_color = Color($col)"
    echo "roughness = $rough"
    if [ "$metal" != "0" ]; then echo "metallic = $metal"; fi
    if [ "$rtex" != "-" ]; then echo "roughness_texture = ExtResource(\"$rtex\")"; fi
    if [ "$ntex" != "-" ]; then
      echo 'normal_enabled = true'
      echo "normal_scale = $nscale"
      echo "normal_texture = ExtResource(\"$ntex\")"
    fi
    echo "uv1_scale = Vector3($uv, $uv, $uv)"
    echo 'uv1_triplanar = true'
    local kv
    for kv in "$@"; do echo "$kv"; done
  } > "$OUT/$id.tres"
}

# ---- shell ----------------------------------------------------------------
mat Mat_shell    "0.44, 0.42, 0.385, 1"   0.94 0 tex_fineN  0.8 -          0.6
mat Mat_floor    "0.28, 0.195, 0.135, 1"  0.80 0 tex_woodN  1.1 -          0.85
# damp cellar stone and sooted brick DO want the patchy sheen
mat Mat_stone    "0.30, 0.30, 0.315, 1"   1.0  0 tex_fineN  1.2 tex_coarseR 0.5
mat Mat_brick    "0.34, 0.22, 0.18, 1"    1.0  0 tex_fineN  1.4 tex_coarseR 0.7
mat Mat_siding   "0.36, 0.38, 0.36, 1"    0.90 0 tex_medN   1.3 -          0.8
mat Mat_roof     "0.17, 0.17, 0.18, 1"    0.88 0 tex_medN   1.5 -          1.1
mat Mat_deck     "0.30, 0.26, 0.21, 1"    0.90 0 tex_woodN  1.2 -          0.9

# ---- interior trim --------------------------------------------------------
mat Mat_trim     "0.70, 0.685, 0.63, 1"   0.66 0 tex_fineN  0.35 -         1.2
mat Mat_wainscot "0.235, 0.20, 0.175, 1"  0.70 0 tex_woodN  0.6 -          1.0

# ---- furniture ------------------------------------------------------------
mat Mat_wood     "0.33, 0.24, 0.16, 1"    0.86 0 tex_woodN  1.0 -          1.0
mat Mat_walnut   "0.175, 0.115, 0.075, 1" 0.70 0 tex_woodN  0.8 -          1.3
mat Mat_mahog    "0.235, 0.105, 0.065, 1" 0.62 0 tex_woodN  0.7 -          1.3
mat Mat_book     "0.26, 0.135, 0.105, 1"  0.90 0 tex_grainN 0.6 -          2.2
mat Mat_book2    "0.115, 0.165, 0.135, 1" 0.90 0 tex_grainN 0.6 -          2.2
mat Mat_book3    "0.315, 0.245, 0.135, 1" 0.88 0 tex_grainN 0.6 -          2.2

# The bookshelf model brings 148 individual books and every one of them wears
# the same dark red. Mat_bookspine is how they come out different colours
# WITHOUT 148 materials: tools/bake_bookshelf.gd writes a per-book tint into
# the vertex colours and this multiplies it into a white albedo, so a whole
# shelf of covers stays ONE surface and one draw call however many colours are
# on it. Mat_bookpage is the block of paper behind them.
mat Mat_bookspine "1.0, 1.0, 1.0, 1"       0.90 0 tex_grainN 0.6 -          2.2 \
  'vertex_color_use_as_albedo = true'
mat Mat_bookpage  "0.545, 0.540, 0.475, 1" 0.94 0 tex_grainN 0.5 -          2.6

# ---- soft -----------------------------------------------------------------
mat Mat_cloth    "0.235, 0.155, 0.135, 1" 0.96 0 tex_grainN 1.0 -          2.0
mat Mat_velvet   "0.115, 0.145, 0.115, 1" 0.90 0 tex_grainN 1.2 -          2.4
mat Mat_linen    "0.62, 0.60, 0.545, 1"   0.95 0 tex_grainN 1.1 -          2.2
mat Mat_dust     "0.60, 0.585, 0.545, 1"  0.98 0 tex_grainN 1.4 -          1.6
mat Mat_rug      "0.30, 0.125, 0.115, 1"  0.96 0 tex_grainN 0.9 -          2.6
mat Mat_rugedge  "0.20, 0.145, 0.085, 1"  0.96 0 tex_grainN 0.9 -          2.6
mat Mat_paper    "0.72, 0.695, 0.60, 1"   0.92 0 tex_grainN 0.5 -          3.0

# ---- metal and stone ------------------------------------------------------
# Metals keep a roughness map: uneven sheen is exactly what tarnish looks like.
mat Mat_brass     "0.62, 0.47, 0.20, 1"    0.62 0.85 tex_fineN 0.3 tex_fineR 1.6
mat Mat_iron      "0.115, 0.115, 0.125, 1" 0.90 0.75 tex_fineN 0.7 tex_medR  1.2
mat Mat_gild      "0.58, 0.45, 0.19, 1"    0.70 0.70 tex_fineN 0.5 tex_fineR 2.0
mat Mat_marble    "0.30, 0.295, 0.30, 1"   0.42 0    tex_fineN 0.3 -         0.6
mat Mat_frame     "0.26, 0.25, 0.26, 1"    0.85 0.55 tex_fineN 0.5 -         1.2
mat Mat_porcelain "0.74, 0.735, 0.71, 1"   0.22 0    -         0   -         1.0
mat Mat_ash       "0.105, 0.10, 0.095, 1"  1.0  0    tex_fineN 1.3 tex_coarseR 1.4
mat Mat_canvas    "0.24, 0.20, 0.155, 1"   0.92 0    tex_grainN 0.6 -        1.8

# ---- glass, light, mirror -------------------------------------------------
mat Mat_glass "0.55, 0.62, 0.66, 0.3" 0.08 0.30 - 0 - 1.0 'transparency = 1'
# Foxed, not new: a clean mirror with nothing to reflect renders black.
mat Mat_mirror "0.52, 0.53, 0.50, 1" 0.34 0.55 tex_coarseR 0.3 - 0.8
mat Mat_candle "0.86, 0.82, 0.70, 1" 0.60 0 - 0 - 1.0 \
  'emission_enabled = true' 'emission = Color(1, 0.72, 0.36, 1)' 'emission_energy_multiplier = 0.9'
mat Mat_shade "0.78, 0.66, 0.44, 1" 0.85 0 tex_grainN 0.5 - 1.6 \
  'emission_enabled = true' 'emission = Color(1, 0.78, 0.46, 1)' 'emission_energy_multiplier = 0.55'


# ---- carried items --------------------------------------------------------
# Hand props are seen from 30cm away in the journal viewport, so they get their
# own materials rather than borrowing the architectural ones: at that range
# Mat_iron's 1.2 uv scale tiles into visible noise across a key bit.
mat Mat_steel   "0.46, 0.47, 0.50, 1"    0.38 0.90 tex_fineN 0.25 tex_fineR 6.0
mat Mat_rust    "0.28, 0.155, 0.095, 1"  0.95 0.35 tex_fineN 1.1  tex_coarseR 5.0
mat Mat_copper  "0.55, 0.30, 0.16, 1"    0.45 0.90 tex_fineN 0.3  tex_fineR 6.0
mat Mat_enamel  "0.52, 0.16, 0.08, 1"    0.35 0.10 tex_fineN 0.2  tex_fineR 5.0
mat Mat_leather "0.16, 0.115, 0.085, 1"  0.82 0    tex_grainN 0.8 -          5.0
mat Mat_bake    "0.90, 0.88, 0.82, 1"    0.30 0    -          0   -          1.0
mat Mat_label   "0.80, 0.77, 0.66, 1"    0.90 0    tex_grainN 0.4 -          6.0

# ---- the grimoire ---------------------------------------------------------
# The one book in the house that is lit from inside. Emission on the leaves is
# what makes the page-light read before the particles do.
mat Mat_grimoire "0.11, 0.055, 0.045, 1" 0.68 0 tex_grainN 1.0 - 3.0
mat Mat_leaf "0.84, 0.79, 0.66, 1" 0.90 0 tex_grainN 0.5 - 4.0 \
  'emission_enabled = true' 'emission = Color(1, 0.74, 0.34, 1)' 'emission_energy_multiplier = 0.55'
mat Mat_sigil "0.90, 0.60, 0.25, 1" 0.55 0 - 0 - 1.0 \
  'emission_enabled = true' 'emission = Color(1, 0.55, 0.18, 1)' 'emission_energy_multiplier = 2.2'


# ---- outdoors -------------------------------------------------------------
# Everything in the yard, on Scripts/ground.gdshader. These are ShaderMaterial
# rather than StandardMaterial3D, so they take a different writer.
#
# `tile_size` is the one number that sets the apparent scale of the ground.
# Get it wrong and the garden reads as a model of a garden.

gmat() { # name pattern tile joint a b joint_tint rough_lo rough_hi bump weather weather_tint
  local uid; uid=$(keep_uid "$1")
  {
    echo "[gd_resource type=\"ShaderMaterial\" load_steps=2 format=3$uid]"
    echo
    echo '[ext_resource type="Shader" path="res://Scripts/ground.gdshader" id="1_g"]'
    echo
    echo '[resource]'
    echo "resource_name = \"$1\""
    echo 'shader = ExtResource("1_g")'
    echo "shader_parameter/pattern = $2"
    echo "shader_parameter/tile_size = $3"
    echo "shader_parameter/joint_width = $4"
    echo "shader_parameter/tint_a = Color($5)"
    echo "shader_parameter/tint_b = Color($6)"
    echo "shader_parameter/joint_tint = Color($7)"
    echo "shader_parameter/roughness_lo = $8"
    echo "shader_parameter/roughness_hi = $9"
    echo "shader_parameter/bump = ${10}"
    echo "shader_parameter/weathering = ${11}"
    echo "shader_parameter/weather_scale = ${12}"
    echo "shader_parameter/weather_tint = Color(${13})"
  } > "$OUT/$1.tres"
}

#    name          pat tile joint  tint_a                    tint_b                     joint                    rlo  rhi  bump weath wscale wtint
gmat Mat_asphalt     0 1.0  0.00 "0.055, 0.056, 0.060, 1" "0.085, 0.086, 0.092, 1" "0.04, 0.04, 0.045, 1"   0.62 0.95 0.35 0.45 0.035 "0.05, 0.055, 0.06, 1"
gmat Mat_paving      1 0.95 0.045 "0.30, 0.295, 0.275, 1"  "0.235, 0.235, 0.225, 1" "0.085, 0.085, 0.075, 1" 0.55 0.95 1.2  0.40 0.07  "0.13, 0.155, 0.11, 1"
gmat Mat_kerb        1 0.60 0.030 "0.36, 0.355, 0.335, 1"  "0.315, 0.31, 0.295, 1"  "0.10, 0.10, 0.09, 1"    0.70 0.98 0.8  0.30 0.09  "0.14, 0.15, 0.12, 1"
gmat Mat_drive       4 0.42 0.030 "0.215, 0.20, 0.175, 1"  "0.165, 0.155, 0.14, 1"  "0.075, 0.07, 0.06, 1"   0.75 1.0  1.6  0.45 0.05  "0.11, 0.125, 0.09, 1"
gmat Mat_lawn        3 1.0  0.0   "0.055, 0.105, 0.045, 1" "0.085, 0.135, 0.055, 1" "0.03, 0.05, 0.025, 1"   0.92 1.0  0.6  0.55 0.025 "0.10, 0.09, 0.05, 1"
gmat Mat_estatewall  5 0.85 0.045 "0.245, 0.238, 0.222, 1" "0.195, 0.19, 0.180, 1"  "0.09, 0.09, 0.082, 1"   0.72 1.0  1.4  0.50 0.05  "0.12, 0.14, 0.10, 1"


# ---- the woods ------------------------------------------------------------
# Seen only as silhouette against the sky at a hundred metres, so what matters
# is that they are DARK and not quite black -- a true black tree line reads as
# a hole cut in the sky rather than as trees.
mat Mat_bark     "0.085, 0.072, 0.062, 1" 0.95 0 tex_woodN  1.6 -          1.4
mat Mat_foliage  "0.048, 0.072, 0.045, 1" 1.0  0 tex_grainN 1.2 tex_coarseR 1.8
# The hand-modelled pine, which needs its own because IT IS BUILT FROM FLAT
# PLANES. Every frond is a single sheet of triangles with one winding, so with
# normal back-face culling the whole canopy disappears the moment you are under
# it or behind it -- you stand in the woods and look up at a bare trunk through
# a hole in the tree. cull_mode 2 is CULL_DISABLED: both faces draw.
#
# Only the pine gets this. The cone trees on the title screen and the scrub in
# the clearings are CLOSED shapes, and drawing their insides is fill rate spent
# on faces no one can ever see.
# NO ROUGHNESS MAP, and the specular pulled right down. A roughness texture
# MULTIPLIES the value, so the mid-grey tex_coarseR that suits damp stone was
# halving this to about 0.5 -- and a frond is a flat plane facing the sky, so
# every one of them caught the moon square on and the treeline came out
# glossy white. Needles do not shine.
mat Mat_pine     "0.048, 0.072, 0.045, 1" 1.0  0 tex_grainN 1.2 -          1.8 \
  'cull_mode = 2' 'metallic_specular = 0.05'


# ---- the car --------------------------------------------------------------
# Mat_carnavy is the hand-modelled car's own paint, kept from the FBX so the
# vehicle in the game is the one that was modelled. Mat_carpaint is the
# near-black it wears on its wings, running boards and lamp housings.
mat Mat_carnavy  "0.022, 0.043, 0.234, 1" 0.30 0.40 tex_fineN 0.2 tex_fineR 3.0
mat Mat_carpaint "0.055, 0.062, 0.075, 1" 0.28 0.35 tex_fineN 0.2 tex_fineR 3.0
mat Mat_chrome   "0.62, 0.64, 0.68, 1"    0.18 1.0  tex_fineN 0.15 tex_fineR 4.0
mat Mat_tyre     "0.030, 0.030, 0.033, 1" 0.95 0    tex_grainN 1.1 -         6.0
mat Mat_carglass "0.10, 0.12, 0.15, 0.55" 0.05 0.4  -          0   -         1.0 'transparency = 1'
mat Mat_lamp "0.96, 0.94, 0.86, 1" 0.15 0 - 0 - 1.0 \
  'emission_enabled = true' 'emission = Color(1, 0.96, 0.86, 1)' 'emission_energy_multiplier = 8.0'
mat Mat_taillamp "0.55, 0.06, 0.05, 1" 0.20 0 - 0 - 1.0 \
  'emission_enabled = true' 'emission = Color(1, 0.12, 0.08, 1)' 'emission_energy_multiplier = 3.0'

printf 'wrote %s material and texture files to %s/\n' "$(ls "$OUT" | wc -l | tr -d ' ')" "$OUT"
