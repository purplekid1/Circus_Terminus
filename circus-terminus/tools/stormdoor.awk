# The cellar doors in the ground, and the frame they sit in.
#
# Emitted into Scenes/storm_door.tscn by gen_stormdoor.sh. Requires lib.awk
# and items.awk (for TR and the ibox/icyl emitters, which take a parent here
# rather than always writing to ".").
#
# LOCAL FRAME. The scene is placed in the world by a transform that maps
# local (x, y, z) to world (y, z, x), which is what lays it flat on the
# ground. In local terms:
#
#   x   0 at the west hinge, 3.0 at the east hinge -- the way the doors open
#   y   -2.1 to 2.1, the width of the opening
#   z   thickness; +z is UP out of the ground
#
# Do not "simplify" that by rotating the geometry: the placement transform is
# in a hand-edited mansion.tscn and cannot be changed from here.

function SD_SPAN()  { return 3.0 }    # hinge to hinge
function SD_WIDE()  { return 4.2 }    # across the opening
function SD_LEAF()  { return 1.5 }    # each leaf is half the span
function SD_THICK() { return 0.10 }

function dbox(parent, name, x, y, z, sx, sy, sz, mat, rx, ry, rz) {
  DN++
  printf "\n[node name=\"%s_%d\" type=\"CSGBox3D\" parent=\"%s\"]\n", name, DN, parent
  printf "transform = %s\n", TR(x, y, z, rx + 0, ry + 0, rz + 0)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "size = Vector3(%.4f, %.4f, %.4f)\n", sx, sy, sz
}

function dcyl(parent, name, x, y, z, r, h, mat, sides, rx, ry, rz) {
  DN++
  printf "\n[node name=\"%s_%d\" type=\"CSGCylinder3D\" parent=\"%s\"]\n", name, DN, parent
  printf "transform = %s\n", TR(x, y, z, rx + 0, ry + 0, rz + 0)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "radius = %.4f\n", r
  printf "height = %.4f\n", h
  printf "sides = %d\n", (sides > 0 ? sides : 10)
}

## A ring, for the pull handles and the padlock shackle.
function dring(parent, name, x, y, z, outer, inner, thick, mat, sides, rx, ry, rz) {
  dcyl(parent, name, x, y, z, outer, thick, mat, sides, rx, ry, rz)
  DN++
  printf "\n[node name=\"%sEye_%d\" type=\"CSGCylinder3D\" parent=\"%s\"]\n", name, DN, parent
  printf "transform = %s\n", TR(x, y, z, rx + 0, ry + 0, rz + 0)
  printf "operation = 2\n"
  printf "radius = %.4f\n", inner
  printf "height = %.4f\n", thick * 3
  printf "sides = %d\n", sides
}

## One leaf, built in its own hinge space: x runs 0 at the hinge to `dir` *
## SD_LEAF() at the meeting edge, so the same code makes both by flipping dir.
##
## Ledged and braced, which is the cheapest joinery that reads as old: boards
## laid across, three ledges behind them holding them together, and a diagonal
## brace in each half stopping the whole thing racking into a parallelogram.
## A modern door has none of that on the outside; this one is all outside.
function sd_leaf(parent, dir,   i, n, bw, gap, y, t, lx, braceL, braceA) {
  t = SD_THICK()

  # ---- boards ----
  # Laid across the leaf, so each one is SD_LEAF() long rather than the full
  # 4.2m -- nobody planks a hatch with four-metre boards.
  n = 15
  bw = SD_WIDE() / n
  gap = 0.012
  for (i = 0; i < n; i++) {
    y = -SD_WIDE() / 2 + bw * (i + 0.5)
    # each board sits a hair differently: cupped, proud, or sunk
    dbox(parent, "Board", dir * SD_LEAF() / 2, y, jit("sb" i, 0.006),
         SD_LEAF(), bw - gap, t * (1.0 + jit("st" i, 0.18)), "Mat_deck", 0, 0, 0)
  }

  # ---- ledges, underneath ----
  for (i = -1; i <= 1; i++) {
    y = i * (SD_WIDE() / 2 - 0.55)
    dbox(parent, "Ledge", dir * SD_LEAF() * 0.5, y, -t * 0.9,
         SD_LEAF() - 0.10, 0.22, t * 0.9, "Mat_wood", 0, 0, 0)
  }

  # ---- braces ----
  # Two diagonals, each spanning half the width between ledges. The angle is
  # worked out from the run so the brace actually lands on the ledges rather
  # than crossing them at a guess.
  braceL = sqrt((SD_LEAF() - 0.20) * (SD_LEAF() - 0.20) + (SD_WIDE() / 2 - 0.66) * (SD_WIDE() / 2 - 0.66))
  braceA = atan2(SD_WIDE() / 2 - 0.66, SD_LEAF() - 0.20) * 180.0 / PI()
  for (i = -1; i <= 1; i += 2) {
    dbox(parent, "Brace", dir * SD_LEAF() * 0.5, i * (SD_WIDE() / 4 - 0.1), -t * 0.88,
         braceL, 0.17, t * 0.8, "Mat_wood", 0, 0, i * dir * braceA)
  }

  # ---- ironwork ----
  # Strap hinges: the long tapered plates that run from the pintle out across
  # the boards. On a door this old they are the only thing holding it on.
  for (i = -1; i <= 1; i += 2) {
    y = i * (SD_WIDE() / 2 - 0.70)
    dbox(parent, "Strap", dir * 0.52, y, t * 0.62, 1.00, 0.16, t * 0.36, "Mat_rust", 0, 0, 0)
    dbox(parent, "StrapTip", dir * 1.10, y, t * 0.62, 0.30, 0.09, t * 0.30, "Mat_rust", 0, 0, 0)
    # the knuckle, on the hinge line, axis along the hinge (local Y)
    dcyl(parent, "Knuckle", 0, y, t * 0.30, 0.075, 0.30, "Mat_rust", 10, 90, 0, 0)
    # three bolt heads down each strap
    for (n = 0; n < 3; n++)
      dcyl(parent, "Bolt", dir * (0.18 + n * 0.38), y, t * 0.80, 0.030, 0.035,
           "Mat_iron", 6, 0, 0, 0)
  }

  # ---- pull ring on the meeting edge ----
  lx = dir * (SD_LEAF() - 0.18)
  dbox(parent, "RingPlate", lx, 0, t * 0.60, 0.20, 0.20, t * 0.30, "Mat_rust", 0, 0, 0)
  dcyl(parent, "RingStem", lx, 0, t * 0.82, 0.026, 0.10, "Mat_rust", 8, 0, 0, 0)
  dring(parent, "PullRing", lx, 0, t * 1.30, 0.135, 0.100, 0.034, "Mat_rust", 16, 90, 0, 0)

  # a length of board sawn short and nailed over a split -- a repair
  if (dir > 0)
    dbox(parent, "Patch", dir * 0.85, SD_WIDE() / 2 - 1.25, t * 0.75,
         0.62, 0.26, t * 0.40, "Mat_wood", 0, 0, 0)
}

## The timber kerb the leaves close onto, plus the stone coping around it.
## Static -- it does not swing, so it lives outside both hinges.
function sd_frame(parent,   i, t) {
  t = SD_THICK()
  # stone coping, a course all round the mouth of the pit
  dbox(parent, "CopeLong", SD_SPAN() / 2, SD_WIDE() / 2 + 0.22, -0.02,
       SD_SPAN() + 0.88, 0.44, 0.30, "Mat_stone", 0, 0, 0)
  dbox(parent, "CopeLong", SD_SPAN() / 2, -SD_WIDE() / 2 - 0.22, -0.02,
       SD_SPAN() + 0.88, 0.44, 0.30, "Mat_stone", 0, 0, 0)
  dbox(parent, "CopeEnd", -0.22, 0, -0.02, 0.44, SD_WIDE() + 0.88, 0.30, "Mat_stone", 0, 0, 0)
  dbox(parent, "CopeEnd", SD_SPAN() + 0.22, 0, -0.02, 0.44, SD_WIDE() + 0.88, 0.30,
       "Mat_stone", 0, 0, 0)

  # the timber rebate the leaves rest on, set down inside the coping
  dbox(parent, "Kerb", SD_SPAN() / 2, SD_WIDE() / 2 + 0.05, -0.09,
       SD_SPAN() + 0.20, 0.14, 0.16, "Mat_wood", 0, 0, 0)
  dbox(parent, "Kerb", SD_SPAN() / 2, -SD_WIDE() / 2 - 0.05, -0.09,
       SD_SPAN() + 0.20, 0.14, 0.16, "Mat_wood", 0, 0, 0)
  dbox(parent, "KerbEnd", -0.05, 0, -0.09, 0.14, SD_WIDE(), 0.16, "Mat_wood", 0, 0, 0)
  dbox(parent, "KerbEnd", SD_SPAN() + 0.05, 0, -0.09, 0.14, SD_WIDE(), 0.16, "Mat_wood", 0, 0, 0)

  # the hasp and staple at the centre, and the padlock somebody broke off it
  dbox(parent, "Staple", SD_SPAN() / 2, -0.62, t * 0.9, 0.10, 0.22, 0.16, "Mat_rust", 0, 0, 0)
  dring(parent, "Shackle", SD_SPAN() / 2, -0.62, t * 0.9 + 0.20, 0.085, 0.055, 0.030,
        "Mat_rust", 14, 0, 90, 0)
  dbox(parent, "Padlock", SD_SPAN() / 2, -0.62, t * 0.9 + 0.09, 0.085, 0.13, 0.11,
       "Mat_rust", 0, 0, 0)
}
