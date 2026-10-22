#!/usr/bin/env bash
# Writes Scenes/surroundings.tscn -- everything outside the estate wall.
#
# The level stopped at the wall. Past it was the void: the ground ran out, the
# road ran out, and the sky came all the way down to the horizon with nothing
# in front of it, so the mansion read as a model on a table.
#
# The brief offered two ways out of that -- build the rest of the
# neighbourhood, or make the house seem alone. This takes the second. There
# are no other houses. The road arrives out of the woods, passes the gate and
# goes back into the woods, and everything else is trees. It is cheaper, it
# suits a game about being the only person for miles, and it means the fog can
# do most of the work.
#
# Three combiners and a ground plane, so the whole thing is four draw calls:
#
#   Ground     one big plate under everything, so there is no edge of world
#   Treeline   ~200 spruces in a ring, seen only as silhouette
#   NearTrees  ~20 bare trees close enough to read, along the road and wall
#   Hedges     inside the wall, breaking up its base
#
# The ring deliberately has a GAP where the road runs through it, east and
# west, so the road disappears into fog rather than into a wall of trunks.

set -euo pipefail
cd "$(dirname "$0")/.."

AWK=${AWK:-awk}
OUT=Scenes/surroundings.tscn
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

"$AWK" -f tools/lib.awk -f tools/items.awk -f tools/surroundings.awk -e '
BEGIN {
  # The estate: wall at x +-43.8, z 0..-103. Road along z=+6.
  CX = 0; CZ = -48          # centre of the property
  ROAD_Z = 6.3

  # ---- the woods -------------------------------------------------------
  #
  # A JITTERED GRID, not a ring. This used to be two thin arcs of spruce at
  # radius 118 and 178 -- 330 trees seen edge-on as a line of tips on the
  # horizon, with open ground between them and the wall. From the gate the
  # skyline was bare and the house read as a model on a table, which is the
  # exact thing this file exists to prevent.
  #
  # Now the woods FILL the plate: every cell of an 11.5 m grid gets a tree
  # unless something says otherwise, which is what makes it read as forest
  # rather than as scenery standing in a circle. Jitter is nearly half the
  # step, so no two ranks line up and there is no grid to see.
  #
  # tools/pines.pl turns all of it into ONE MultiMeshInstance3D afterwards, so
  # the whole wood costs one draw call. They are emitted as CSG spruces here
  # only because that is the shape that tool knows how to read.
  printf "\n[node name=\"Treeline\" type=\"CSGCombiner3D\" parent=\".\"]\n"
  EDGE = 52.8
  k = 0
  for (gx2 = -285; gx2 <= 285; gx2 += 11.5) {
    for (gz2 = -335; gz2 <= 235; gz2 += 11.5) {
      k++
      jx = gx2 + jit("fx" k, 5.0)
      jz = gz2 + jit("fz" k, 5.0)

      # The estate: wall at x +-43.8, z 0..-103, plus nine metres of breathing
      # room. A tree inside this is standing in the garden.
      if (jx > -EDGE && jx < EDGE && jz < 15 && jz > -113) continue

      # THE ROAD KEEPS ITS CORRIDOR. It arrives out of the woods, passes the
      # gate and goes back into the woods; planting across it would end the
      # road in a wall of trunks instead of in fog.
      #
      # WIDER ON THE NORTH SIDE, and that is not symmetry for its own sake.
      # The opening cutscene shoots from Shot0A and Shot0B at z 22 and 24 --
      # the far verge, looking back across the road at the gate -- and at the
      # even 13 both markers stood inside the wood. The first shot of the game
      # opened on the inside of a trunk. The bare trees in NearTrees live out
      # here too, at ROAD_Z + 19, and they are meant to stand alone against
      # open ground rather than be buried in pines.
      if (jz > ROAD_Z - 13 && jz < ROAD_Z + 23) continue

      # Round the far edge off. The ground plate is square, and a square plate
      # planted to its corners gives the horizon four visible corners.
      d = sqrt(jx * jx + (jz + 48) * (jz + 48) * 1.15)
      if (d > 288) continue

      # Thin the outermost band so the treeline dissolves into fog rather than
      # ending on a hard rank.
      if (d > 250 && (k % 3) != 0) continue

      h = 15 + jit("fh" k, 17)
      tree_conifer("Treeline", jx, jz, h, "f" k)
    }
  }

  # ---- the ones you can actually see ----
  printf "\n[node name=\"NearTrees\" type=\"CSGCombiner3D\" parent=\".\"]\n"
  # along the far verge of the road, opposite the gate
  split("-46 -33 -21 17 29 41 54", vx, " ")
  for (k in vx) {
    x = vx[k] + jit("vx" k, 2.5)
    # z+19, clear of SideWalk2 (which runs z 13.7..21.6). At +13 they were
    # planted in the pavement.
    tree_bare("NearTrees", x, ROAD_Z + 19 + jit("vz" k, 2.5), 12 + jit("vh" k, 4), "v" k)
  }
  # and a few inside the grounds, well clear of the drive and the house
  split("-34 -30 33 36 -37 35", gx, " ")
  split("-16 -60 -22 -66 -88 -84", gz, " ")
  for (k in gx) {
    tree_bare("NearTrees", gx[k] + jit("gx" k, 2), gz[k] + jit("gz" k, 2),
              12 + jit("gh" k, 4), "g" k)
  }

  # ---- hedging inside the wall ----
  printf "\n[node name=\"Hedges\" type=\"CSGCombiner3D\" parent=\".\"]\n"
  hedge("Hedges", -26, -9.2, 32, 1, "hw")
  hedge("Hedges",  26, -9.2, 32, 1, "he")
  hedge("Hedges", -41.4, -50, 78, 0, "hwv")
  hedge("Hedges",  41.4, -50, 78, 0, "hev")
}' > "$BODY"

mats=$(grep -o 'ExtResource("Mat_[A-Za-z0-9_]*")' "$BODY" \
       | sed 's/ExtResource("//;s/")//' | sort -u)
mats="$mats Mat_lawn"
steps=$(printf '%s\n' "$mats" | tr ' ' '\n' | grep -c . || true)

{
  echo "[gd_scene load_steps=$((steps + 2)) format=3 uid=\"uid://csurround001\"]"
  echo
  echo "; OUTSIDE THE WALL. Generated by tools/gen_surroundings.sh."
  echo ";"
  echo "; No neighbours. The road comes out of the woods, passes the gate and"
  echo "; goes back into the woods. See the script for why it is built this way."
  echo
  for m in $mats; do
    echo "[ext_resource type=\"Material\" path=\"res://Materials/$m.tres\" id=\"$m\"]"
  done
  echo
  echo '[node name="Surroundings" type="Node3D"]'
  echo
  echo '; The edge of the world. Big enough that the fog swallows it long before'
  echo '; it ends, and 2cm below the level"s own lawn so the two cannot z-fight.'
  echo ';'
  echo '; IT HAS A HOLE IN IT. The cellar pit and the storm doors that lead down'
  echo '; into it are outside the house, at world (-10, -81.5), and a solid plate'
  echo '; here roofed the pit over -- the doors opened onto ground. The level"s'
  echo '; own Lawn already carries the same cut as Lawn/CellarCut; this matches'
  echo '; it, with 10cm of margin so the two edges cannot land on one plane.'
  echo '[node name="Ground" type="CSGCombiner3D" parent="."]'
  echo 'use_collision = true'
  echo ''
  echo '[node name="Plate" type="CSGBox3D" parent="Ground"]'
  echo 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.12, -48)'
  echo 'material = ExtResource("Mat_lawn")'
  echo 'size = Vector3(620, 0.2, 620)'
  echo ''
  echo '[node name="CellarCut" type="CSGBox3D" parent="Ground"]'
  echo 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10, -0.12, -81.5)'
  echo 'operation = 2'
  echo 'size = Vector3(4.6, 1.4, 3.6)'
  echo ''
  echo '; AND A HOLE UNDER THE HOUSE. This plate sits at y -0.22..-0.02, which'
  echo '; is not "the ground" as far as the building is concerned -- it is three'
  echo '; metres ABOVE the cellar floor and a third of a metre BELOW the ground'
  echo '; storey. Without this cut it laid a solid 20cm slab straight through'
  echo '; the middle of the cellar and across the flight of stairs that leads up'
  echo '; out of it, and the player climbing them ran out of headroom about two'
  echo '; thirds of the way up. The cellar was the only way into the house, so'
  echo '; that made the house unenterable.'
  echo ';'
  echo '; 34.8, not the 34.0 the level"s own Lawn/HouseCut uses. The lawn only'
  echo '; has to stop at the wall line because it is buried under the foundation'
  echo '; anyway; this one has to clear the foundation ring at x +-17.225 as'
  echo '; well, or a rib of it is left standing inside the cellar wall.'
  echo '[node name="HouseCut" type="CSGBox3D" parent="Ground"]'
  echo 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.12, -58.5)'
  echo 'operation = 2'
  echo 'size = Vector3(34.8, 1.4, 34.8)'
  cat "$BODY"
} > "$OUT"

printf 'wrote %s  (%s nodes)\n' "$OUT" "$(grep -c '^\[node' "$OUT")"

# CSG is how this is described, not how it should ship: 1200 brushes is many
# seconds of boolean work at load. Bake it to four meshes straight away.
if [ -n "${GODOT:-}" ]; then
  BAKE_ONLY="res://$OUT" "$GODOT" --headless --path . --script tools/bake.gd \
    2>&1 | grep -E "mesh\(es\)|baked" || true
else
  echo "gen_surroundings.sh: set GODOT= to bake; leaving live CSG for now." >&2
fi
