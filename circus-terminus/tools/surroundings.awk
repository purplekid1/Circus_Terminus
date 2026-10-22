# Trees and the ground beyond the estate wall.
#
# Emitted into Scenes/surroundings.tscn by gen_surroundings.sh. Requires
# lib.awk and items.awk (for TR(), which can rotate on two axes at once --
# a leaning branch needs both).
#
# Everything here is SILHOUETTE. It is seen at night, across a hundred
# metres, against a sky that is the brightest thing in the frame; the only
# property of a tree that survives that is its outline. So a conifer is three
# stacked cones and a bare oak is a trunk with six sticks in it, and both
# read perfectly from the road. Modelling foliage would cost thousands of
# triangles nobody can resolve.
#
# The whole treeline is ONE CSGCombiner3D, which is one draw call for two
# hundred trees. That is the reason it is CSG and not a pile of meshes.

function TAU2() { return 6.28318530717959 }

function sbox(parent, name, x, y, z, sx, sy, sz, mat, rx, ry, rz) {
  SN++
  printf "\n[node name=\"%s_%d\" type=\"CSGBox3D\" parent=\"%s\"]\n", name, SN, parent
  printf "transform = %s\n", TR(x, y, z, rx + 0, ry + 0, rz + 0)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "size = Vector3(%.3f, %.3f, %.3f)\n", sx, sy, sz
}

## A CSGSphere3D at world scale. Wanted often enough -- bulbs, finials, knobs --
## that faking one with a short fat cylinder was showing.
function ssphere(parent, name, x, y, z, r, mat, rings) {
  SN++
  printf "\n[node name=\"%s_%d\" type=\"CSGSphere3D\" parent=\"%s\"]\n", name, SN, parent
  printf "transform = %s\n", TR(x, y, z, 0, 0, 0)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "radius = %.3f\n", r
  printf "radial_segments = %d\n", (rings > 0 ? rings : 8)
  printf "rings = %d\n", (rings > 0 ? int(rings / 2) : 4)
}

function scyl(parent, name, x, y, z, r, h, mat, sides, rx, ry, rz, cone) {

  SN++
  printf "\n[node name=\"%s_%d\" type=\"CSGCylinder3D\" parent=\"%s\"]\n", name, SN, parent
  printf "transform = %s\n", TR(x, y, z, rx + 0, ry + 0, rz + 0)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "radius = %.3f\n", r
  printf "height = %.3f\n", h
  printf "sides = %d\n", (sides > 0 ? sides : 8)
  if (cone) printf "cone = true\n"
}

## A spruce: bare trunk, then three cones of decreasing size. Six sides each,
## because at this distance the facets are smaller than a pixel.
function tree_conifer(parent, x, z, h, key,   trunk, r, i, cy, ch, cr) {
  trunk = h * 0.16
  r = h * 0.155 * (1.0 + jit(key "r", 0.25))
  scyl(parent, "Trunk", x, trunk / 2, z, h * 0.028, trunk, "Mat_bark", 5, 0, 0, 0, 0)
  for (i = 0; i < 3; i++) {
    ch = (h - trunk) * (0.52 - i * 0.10)
    cr = r * (1.0 - i * 0.26)
    cy = trunk + (h - trunk) * (i * 0.30) + ch / 2
    scyl(parent, "Bough", x + jit(key i "x", 0.3), cy, z + jit(key i "z", 0.3),
         cr, ch, "Mat_foliage", 6, 0, 0, 0, 1)
  }
}

## A bare deciduous tree: a tapered trunk and six limbs that fork once. These
## are the ones close enough to catch the moonlight, so they get the detail.
function tree_bare(parent, x, z, h, key,   i, a, lean, bx, by, bz, bl, j) {
  scyl(parent, "Trunk", x, h * 0.30, z, h * 0.040, h * 0.60, "Mat_bark", 6, 0, 0, 0, 0)
  scyl(parent, "Root", x, h * 0.04, z, h * 0.075, h * 0.08, "Mat_bark", 6, 0, 0, 0, 1)

  for (i = 0; i < 6; i++) {
    a = TAU2() * i / 6 + jit(key i "a", 0.5)
    lean = 34 + jit(key i "l", 14)
    bl = h * (0.36 + jit(key i "b", 0.10))
    # Place the limb's midpoint out along its own lean, so the base meets the
    # top of the trunk instead of floating beside it.
    bx = x + sin(a) * sin(rad(lean)) * bl / 2
    bz = z + cos(a) * sin(rad(lean)) * bl / 2
    by = h * 0.55 + cos(rad(lean)) * bl / 2
    # +a, not -a. TR composes Ry*Rx, so a cylinder leaned by `lean` about X
    # and then swung by `a` about Y points along
    #   (sin a * sin lean, cos lean, cos a * sin lean)
    # -- the same direction the offset above moves it. With the sign flipped
    # the limbs pointed the opposite way in x from where they were placed and
    # every tree came out as a starburst of loose sticks.
    scyl(parent, "Limb", bx, by, bz, h * 0.017, bl, "Mat_bark", 5,
         lean, a * 180.0 / PI(), 0, 0)

    # one fork near the end of each limb
    for (j = 0; j < 2; j++) {
      bl = h * 0.20
      a = a + (j == 0 ? 0.5 : -0.5)
      lean = lean + (j == 0 ? 22 : -18)
      scyl(parent, "Twig",
           bx + sin(a) * sin(rad(lean)) * bl * 0.9,
           by + cos(rad(lean)) * bl * 0.75,
           bz + cos(a) * sin(rad(lean)) * bl * 0.9,
           h * 0.008, bl, "Mat_bark", 4, lean, a * 180.0 / PI(), 0, 0)
    }
  }
}

## A hedge run along the inside of the wall: a long box with a lumpy top.
function hedge(parent, x, z, len, along_x, key,   i, n, seg, hx, hz, hh) {
  n = int(len / 2.0)
  if (n < 1) n = 1
  seg = len / n
  for (i = 0; i < n; i++) {
    hh = 1.55 + jit(key i "h", 0.30)
    if (along_x) { hx = x - len / 2 + seg * (i + 0.5); hz = z }
    else         { hx = x; hz = z - len / 2 + seg * (i + 0.5) }
    sbox(parent, "Hedge", hx, hh / 2, hz, seg * 1.05, hh, 1.30 + jit(key i "d", 0.2),
         "Mat_foliage", 0, 0, 0)
  }
}
