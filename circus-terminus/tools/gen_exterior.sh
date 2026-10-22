#!/usr/bin/env bash
# Roof, porch, trim and chimney. These sit OUTSIDE the Shell combiner, because
# the Shell subtracts the two roof planes to square off its gables and would
# eat the roof slabs along with everything else above them.
#
# They are their OWN combiner rather than loose boxes, so the bake step folds
# 125 pieces of trim into one mesh instead of 125.


N=0
box() { # name x y z sx sy sz mat [collide]
  N=$((N+1))
  printf '\n[node name="%s_%d" type="CSGBox3D" parent="Exterior"]\n' "$1" "$N"
  printf 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n' "$2" "$3" "$4"
  printf 'material = ExtResource("%s")\n' "$8"
  printf 'size = Vector3(%s, %s, %s)\n' "$5" "$6" "$7"
}
slab() { # name basis-rows x y z sx sy sz mat
  N=$((N+1))
  printf '\n[node name="%s_%d" type="CSGBox3D" parent="Exterior"]\n' "$1" "$N"
  printf 'transform = Transform3D(%s, %s, %s, %s)\n' "$2" "$3" "$4" "$5"
  printf 'material = ExtResource("%s")\n' "$9"
  printf 'size = Vector3(%s, %s, %s)\n' "$6" "$7" "$8"
}

# Collision on the combiner covers the lot. The per-box flag is gone: roof,
# porch and sills all want to be solid, and the ones that did not have it were
# outdoors anyway.
printf '\n[node name="Exterior" type="CSGCombiner3D" parent="."]\nuse_collision = true\n'

# --- pitched roof. 25.2 degrees, ridge along X at z=-17, eaves overhanging.
slab RoofSouth "1, 0, 0, 0, 0.9047, -0.4257, 0, 0.4257, 0.9047" "0" "10.549" "-7.702" 36 0.5 20.79 Mat_roof
slab RoofNorth "1, 0, 0, 0, 0.9047, 0.4257, 0, -0.4257, 0.9047" "0" "10.549" "-26.298" 36 0.5 20.79 Mat_roof
box RidgeCap 0 15.35 -17 36.2 0.4 0.9 Mat_roof
# --- eave fascia
box FasciaFront 0 6.35 1.9 36 0.5 0.3 Mat_trim
box FasciaBack 0 6.35 -35.9 36 0.5 0.3 Mat_trim

# --- foundation course, so the house sits on something.
# A RING, not a slab. A solid 34.8x34.8 block here reaches from y-0.9 to y0 and
# plugs the cellar stairwell, because the well is cut out of the Shell combiner
# and a standalone box outside it never sees that cut. That is what sealed the
# basement off. It is also only ever seen edge-on from outside, so the middle
# was never doing any work.
# Tops at -0.01, not 0. The deck boards and the ground slab are both at 0, so
# a foundation topping out level with them put three surfaces on one plane --
# twenty square metres of it right at the front steps. The course is buried
# under the deck anyway.
box FoundFront 0 -0.455 0.1 34.8 0.89 0.8 Mat_stone 1
box FoundBack 0 -0.455 -34.1 34.8 0.89 0.8 Mat_stone 1
# 0.35 across, not 0.4: at 0.4 the inner face of the plinth course landed on
# exactly the same plane as the inner face of the wall skin above it, and the
# two fought over 30 square metres of the cellar wall.
box FoundWest -17.225 -0.455 -17 0.35 0.89 34.8 Mat_stone 1
box FoundEast 17.225 -0.455 -17 0.35 0.89 34.8 Mat_stone 1

# --- corner boards and a belt course between the storeys
for c in "-17.2 0.2" "17.2 0.2" "-17.2 -34.2" "17.2 -34.2"; do
  set -- $c
  # 7.2 tall, topping out at y=7.0. At 7.4 they reached 7.2, and the roof
  # surface at the corners of the house is 7.11 -- so all four corner boards
  # poked out through the tiles.
  box CornerBoard "$1" 3.4 "$2" 0.5 7.2 0.5 Mat_trim
done
box BeltFront 0 3.45 0.22 34.6 0.3 0.24 Mat_trim
box BeltBack 0 3.45 -34.22 34.6 0.3 0.24 Mat_trim
box BeltWest -17.22 3.45 -17 0.24 0.3 34.6 Mat_trim
box BeltEast 17.22 3.45 -17 0.24 0.3 34.6 Mat_trim

# --- front porch: roof on columns, over the deck
box PorchRoof 0 3.35 2.1 21 0.3 4.8 Mat_roof 1
box PorchBeam 0 3.05 4.3 21 0.35 0.35 Mat_trim
for x in -9.5 -5.5 5.5 9.5; do
  box PorchCol "$x" 1.5 4.1 0.34 3.1 0.34 Mat_trim 1
done

# --- chimney
box ChimneyStack 13.6 12.4 -28 1.9 11 1.9 Mat_brick 1
box ChimneyCap 13.6 18.1 -28 2.3 0.4 2.3 Mat_stone

# --- window trim + shutters + glass, per opening
# Sill, head and jambs are all centred on the wall, which for the 0.4 outside
# wall means they tunnel right through it. The JAMBS are shifted 50mm outward
# so that no face of theirs lands on a wall skin plane, and so that their
# inner end stops inside the wall instead of into the room, where the jamb was
# sharing an edge with the interior architrave from windowcase() and the sill
# was sharing one with the living-room fireplace surround.
win() { # x y z facing(z|x)
  local x=$1 y=$2 z=$3 f=$4
  if [ "$f" = "z" ]; then
    box WinSill "$x" "$(awk -v y=$y 'BEGIN{print y-1.1}')" "$(awk -v z=$z 'BEGIN{print z+(z<-17?-0.12:0.12)}')" 2.1 0.18 0.6 Mat_trim
    box WinHead "$x" "$(awk -v y=$y 'BEGIN{print y+1.1}')" "$(awk -v z=$z 'BEGIN{print z+(z<-17?-0.11:0.11)}')" 2.1 0.18 0.5 Mat_trim
    box WinJambL "$(awk -v x=$x 'BEGIN{print x-0.9}')" "$y" "$(awk -v z=$z 'BEGIN{print z+(z<-17?-0.05:0.05)}')" 0.2 2.2 0.45 Mat_trim
    box WinJambR "$(awk -v x=$x 'BEGIN{print x+0.9}')" "$y" "$(awk -v z=$z 'BEGIN{print z+(z<-17?-0.05:0.05)}')" 0.2 2.2 0.45 Mat_trim
    box WinGlass "$x" "$y" "$z" 1.55 1.95 0.06 Mat_glass
    box ShutterL "$(awk -v x=$x 'BEGIN{print x-1.35}')" "$y" "$(awk -v z=$z 'BEGIN{print z+(z<-17?-0.2:0.2)}')" 0.7 2.1 0.08 Mat_wood
    box ShutterR "$(awk -v x=$x 'BEGIN{print x+1.35}')" "$y" "$(awk -v z=$z 'BEGIN{print z+(z<-17?-0.2:0.2)}')" 0.7 2.1 0.08 Mat_wood
  else
    box WinSill "$(awk -v x=$x 'BEGIN{print x+(x<0?-0.12:0.12)}')" "$(awk -v y=$y 'BEGIN{print y-1.1}')" "$z" 0.6 0.18 2.1 Mat_trim
    box WinHead "$(awk -v x=$x 'BEGIN{print x+(x<0?-0.11:0.11)}')" "$(awk -v y=$y 'BEGIN{print y+1.1}')" "$z" 0.5 0.18 2.1 Mat_trim
    box WinJambL "$(awk -v x=$x 'BEGIN{print x+(x<0?-0.05:0.05)}')" "$y" "$(awk -v z=$z 'BEGIN{print z-0.9}')" 0.45 2.2 0.2 Mat_trim
    box WinJambR "$(awk -v x=$x 'BEGIN{print x+(x<0?-0.05:0.05)}')" "$y" "$(awk -v z=$z 'BEGIN{print z+0.9}')" 0.45 2.2 0.2 Mat_trim
    box WinGlass "$x" "$y" "$z" 0.06 1.95 1.55 Mat_glass
    box ShutterL "$(awk -v x=$x 'BEGIN{print x+(x<0?-0.2:0.2)}')" "$y" "$(awk -v z=$z 'BEGIN{print z-1.35}')" 0.08 2.1 0.7 Mat_wood
    box ShutterR "$(awk -v x=$x 'BEGIN{print x+(x<0?-0.2:0.2)}')" "$y" "$(awk -v z=$z 'BEGIN{print z+1.35}')" 0.08 2.1 0.7 Mat_wood
  fi
}
win 11 1.9 0 z
win -11 1.9 0 z
win 11 5.5 0 z
win -11 5.5 0 z
win 17 1.9 -6 x
win 17 1.9 -17 x
win 17 5.5 -6 x
win 17 5.5 -17 x
win -17 1.9 -6 x
win -17 1.9 -17 x
win -17 5.5 -6 x
win -17 5.5 -17 x
win -8 5.5 -34 z
win 2 5.5 -34 z

# --- front door surround
# The head is 2.3 wide, not 2.2: the jambs stand at +-1.0 and are 0.25 across,
# so their outer faces are at 1.125 and a 2.2 head left a 25mm step at each top
# corner. This is the only surround the front door gets -- gen_interior.awk
# passes "minus" for it, so there is no architrave out here to fight with.
box DoorHead 0 2.35 0.24 2.3 0.3 0.5 Mat_trim
box DoorJambL -1.0 1.1 0.24 0.25 2.5 0.5 Mat_trim
box DoorJambR 1.0 1.1 0.24 0.25 2.5 0.5 Mat_trim

# --- porch lanterns either side of the door
box LanternL -1.7 2.0 0.35 0.22 0.4 0.22 Mat_frame
box LanternR 1.7 2.0 0.35 0.22 0.4 0.22 Mat_frame
