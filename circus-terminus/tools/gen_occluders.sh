#!/usr/bin/env bash
# Writes Scenes/occluders.tscn -- the boxes Godot's occlusion culler uses to
# throw away geometry the player cannot possibly see.
#
# Standing in the entrance hall the renderer was submitting ~2900 draw calls,
# most of them rooms on the other side of a floor slab. Occlusion culling is
# a CPU-side software rasteriser: it needs a handful of big solid boxes that
# approximate what actually blocks the view, and then it drops everything
# behind them before they reach the GPU.
#
# THE ONLY RULE THAT MATTERS: an occluder must never cover a hole you can see
# through. Put one across a doorway and the room beyond it pops out of
# existence when you walk up to it. So the floor slabs are split around their
# stairwells, and the interior spine walls are split around their doorways,
# both from the same numbers gen_shell.sh cuts them with.
#
# Outer walls are deliberately NOT occluders. They have fourteen windows in
# them and splitting round every one buys a cull of the garden, which is a
# handful of meshes.
#
# Coordinates are mansion-local, matching the `u` and `c` tables in
# gen_shell.sh, and occluders.tscn is instanced by mansion.tscn so it travels
# with the house.

set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Scenes/occluders.tscn
N=0
BODY=$(mktemp)
HEAD=$(mktemp)
trap 'rm -f "$BODY" "$HEAD"' EXIT

## slab name  x z sx sz  y   -- a horizontal plate
## wall name  x z sx sz  y h -- a vertical one, h tall, centred on y
box() { # name cx cy cz sx sy sz
  N=$((N+1))
  {
    printf '\n[sub_resource type="BoxOccluder3D" id="Occ_%d"]\n' "$N"
    printf 'size = Vector3(%s, %s, %s)\n' "$5" "$6" "$7"
  } >> "$HEAD"
  {
    printf '\n[node name="%s_%d" type="OccluderInstance3D" parent="."]\n' "$1" "$N"
    printf 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n' "$2" "$3" "$4"
    printf 'occluder = SubResource("Occ_%d")\n' "$N"
  } >> "$BODY"
}

## A slab with a rectangular hole in it, emitted as the four strips around the
## hole. Arguments are the slab's extent and the hole's, in x/z.
slab_with_hole() { # name y  x0 x1 z0 z1  hx0 hx1 hz0 hz1
  local n=$1 y=$2 x0=$3 x1=$4 z0=$5 z1=$6 hx0=$7 hx1=$8 hz0=$9 hz1=${10}
  local t=0.2
  awk -v n="$n" -v y="$y" -v x0="$x0" -v x1="$x1" -v z0="$z0" -v z1="$z1" \
      -v hx0="$hx0" -v hx1="$hx1" -v hz0="$hz0" -v hz1="$hz1" -v t="$t" '
  function strip(ax0, ax1, az0, az1) {
    if (ax1 - ax0 < 0.3 || az1 - az0 < 0.3) return
    printf "%s %.3f %.3f %.3f %.3f %.3f %.3f\n",
           n, (ax0 + ax1) / 2, y, (az0 + az1) / 2, ax1 - ax0, t, az1 - az0
  }
  BEGIN {
    strip(x0, x1, z0, hz0)      # before the hole
    strip(x0, x1, hz1, z1)      # after it
    strip(x0, hx0, hz0, hz1)    # beside it, low side
    strip(hx1, x1, hz0, hz1)    # beside it, high side
  }'
}

## A wall with door openings in it, emitted as the pieces between them. The
## openings are given as a space-separated list of lo:hi along the run.
wall_with_doors() { # name axis at  y h  a b  "lo:hi lo:hi ..."
  local n=$1 axis=$2 at=$3 y=$4 h=$5 a=$6 b=$7 holes=$8
  awk -v n="$n" -v axis="$axis" -v at="$at" -v y="$y" -v h="$h" \
      -v a="$a" -v b="$b" -v holes="$holes" '
  BEGIN {
    m = split(holes, hs, " ")
    for (i = 1; i <= m; i++) { split(hs[i], p, ":"); lo[i] = p[1] + 0; hi[i] = p[2] + 0 }
    # insertion sort, so the gaps come out in order along the wall
    for (i = 2; i <= m; i++) {
      tl = lo[i]; th = hi[i]; j = i - 1
      while (j >= 1 && lo[j] > tl) { lo[j+1] = lo[j]; hi[j+1] = hi[j]; j-- }
      lo[j+1] = tl; hi[j+1] = th
    }
    cur = a + 0
    for (i = 1; i <= m; i++) {
      if (lo[i] > cur + 0.4) emit(cur, lo[i])
      if (hi[i] > cur) cur = hi[i]
    }
    if (b + 0 > cur + 0.4) emit(cur, b + 0)
  }
  function emit(s, e,   mid, len) {
    mid = (s + e) / 2; len = e - s
    if (axis == "x") printf "%s %.3f %.3f %.3f %.3f %.3f %.3f\n", n, at, y, mid, 0.3, h, len
    else             printf "%s %.3f %.3f %.3f %.3f %.3f %.3f\n", n, mid, y, at, len, h, 0.3
  }'
}

{
  # ---- floors -----------------------------------------------------------
  # SlabUpper, hole = CutMainWell  x -2.5..2.5  z -16.2..-3.8
  slab_with_hole SlabUpper 3.5 -17 17 -34 0 -2.5 2.5 -16.2 -3.8
  # SlabGround, hole = CutCellarWell  x 9.8..14.2  z -33.2..-26.8
  slab_with_hole SlabGround -0.1 -17 17 -34 0 9.8 14.2 -33.2 -26.8
  # roof and basement slabs are solid
  echo "SlabRoof 0 7.1 -17 34 0.2 34"
  echo "SlabBasement 0 -3.7 -17 34 0.2 34"

  # ---- the two spine walls, ground floor and upper -----------------------
  # Openings from the `c` table: doorways are 1.6 wide allowing for architrave.
  wall_with_doors GF_HallWest  x -7  1.7 3.4 -22 -0.2 "-5.8:-4.2 -17.8:-16.2"
  wall_with_doors GF_HallEast  x  7  1.7 3.4 -22 -0.2 "-5.8:-4.2 -17.8:-16.2"
  wall_with_doors UF_LandWest  x -7  5.3 3.4 -22 -0.2 "-5.8:-4.2 -17.8:-16.2"
  wall_with_doors UF_LandEast  x  7  5.3 3.4 -22 -0.2 "-5.8:-4.2 -17.8:-16.2"
  # the rear cross walls
  wall_with_doors GF_Rear1 z -22 1.7 3.4 -17 17 "-12.8:-11.2 -0.8:0.8 11.2:12.8"
  wall_with_doors UF_Rear1 z -22 5.3 3.4 -17 17 "-0.8:0.8"
  wall_with_doors GF_Rear2 z -26 1.7 3.4 -17 17 "-9.8:-8.2 7.2:8.8"
} | while read -r name cx cy cz sx sy sz; do
  [ -z "$name" ] && continue
  box "$name" "$cx" "$cy" "$cz" "$sx" "$sy" "$sz"
done

# The while-read loop above runs in a subshell, so N did not survive it.
# Count from the file it wrote instead.
N=$(grep -c "^\[sub_resource" "$HEAD")

{
  printf '[gd_scene load_steps=%d format=3 uid="uid://c0occluders01"]\n' "$((N + 1))"
  printf '\n; OCCLUDERS. Generated by tools/gen_occluders.sh -- do not hand-edit.\n'
  printf '; These are invisible. They exist so the renderer can drop the half of the\n'
  printf '; house you are not looking at. Every one is split around the holes you can\n'
  printf '; actually see through; see the script for why that matters.\n'
  cat "$HEAD"
  printf '\n[node name="Occluders" type="Node3D"]\n'
  cat "$BODY"
} > "$OUT"

printf 'wrote %s  (%s occluders)\n' "$OUT" "$N"
