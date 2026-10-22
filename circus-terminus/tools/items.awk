# Geometry for the things the player carries.
#
# Emitted into Scenes/items/it_*.tscn by gen_items.sh, one CSGCombiner3D per
# item, and baked to a single mesh by bake.gd like any other prop scene.
#
# These are held to different rules than the furniture in props.awk. A chair is
# only ever seen from two metres away in the dark; a key is seen filling half
# the journal page. So the box counts are higher, the materials are the tight-uv
# ones from the "carried items" block of gen_materials.sh, and CSG subtraction
# is used where a silhouette needs a real hole in it -- the bow of a key, the
# fork of a crowbar claw. A painted-on hole reads as a smudge at that range.
#
# Every item is modelled AT REST on a horizontal surface: origin on the table,
# +Y up, long axis along X. The pickup scene, the dropped item and the journal
# icon all reuse that one pose, so an item never lies on its side in one place
# and stands on end in another.
#
# Requires lib.awk.

# ---- transforms -----------------------------------------------------------
# lib.awk gives one rotation at a time. Items need two at once (a bar that is
# both laid down and swept round), so compose here. R = Ry * Rx * Rz, and the
# result is serialised ROW-major exactly as lib.awk does it.

# The rotation maths that used to live here -- mmul, mrotx/y/z and TR -- moved
# to lib.awk. It was needed by cyl(), which is in lib.awk and which every prop
# in the house is built from, and which until then could only be yawed. See the
# note above cyl() for what that cost.


# ---- emitters -------------------------------------------------------------
# The last argument of each is the CSG operation: empty for additive, "sub" to
# cut the shape out of everything before it in the combiner.

function OPLINE(op) { return (op == "sub" ? "operation = 2\n" : "") }

## Where the i-emitters hang their nodes. "." is right for an item scene --
## there the root IS the combiner -- and it is what everything got before this
## existed.
##
## The car is not like that. Its root is a plain Node3D with a `Body` combiner
## under it, so writing the brushes to "." left BODY EMPTY: that is why the
## car's wheels have never turned in the intro (CarArrival collects them from
## Body's children) and why ninety brushes were ninety separate CSG roots
## rather than the single draw call gen_car.sh's own header claims. Set it with
## `-v IPARENT=Body`.
function IPAR() { return (IPARENT != "" ? IPARENT : ".") }


function ibox(name, x, y, z, sx, sy, sz, mat, rx, ry, rz, op) {
  IN++
  printf "\n[node name=\"%s_%d\" type=\"CSGBox3D\" parent=\"%s\"]\n", name, IN, IPAR()
  printf "transform = %s\n", TR(x, y, z, rx + 0, ry + 0, rz + 0)
  printf "%s", OPLINE(op)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "size = Vector3(%.4f, %.4f, %.4f)\n", sx, sy, sz
}

## A cylinder whose axis is its own local +Y. Pass rz=90 to lay it along X,
## rx=90 to lay it along Z.
function icyl(name, x, y, z, r, h, mat, sides, rx, ry, rz, op) {
  IN++
  printf "\n[node name=\"%s_%d\" type=\"CSGCylinder3D\" parent=\"%s\"]\n", name, IN, IPAR()
  printf "transform = %s\n", TR(x, y, z, rx + 0, ry + 0, rz + 0)
  printf "%s", OPLINE(op)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "radius = %.4f\n", r
  printf "height = %.4f\n", h
  printf "sides = %d\n", (sides > 0 ? sides : 12)
}

function isphere(name, x, y, z, r, mat, op) {
  IN++
  printf "\n[node name=\"%s_%d\" type=\"CSGSphere3D\" parent=\"%s\"]\n", name, IN, IPAR()
  printf "transform = %s\n", T(x, y, z)
  printf "%s", OPLINE(op)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "radius = %.4f\n", r
  printf "radial_segments = 12\n"
  printf "rings = 6\n"
}

## A flat ring in the XZ plane: a disc with a smaller disc cut out of it. The
## cutter is deliberately taller than the ring so their end faces cannot land
## coplanar, which is what leaves z-fighting speckle around the hole.
function iring(name, x, y, z, outer, inner, thick, mat, sides) {
  icyl(name, x, y, z, outer, thick, mat, sides, 0, 0, 0, "")
  icyl(name "Eye", x, y, z, inner, thick * 3, mat, sides, 0, 0, 0, "sub")
}

# ---- keys -----------------------------------------------------------------
# One builder, four keys. What distinguishes them is the bow (the handle loop)
# and the wards, because that is all you can actually read of a key held up in
# a dark corridor -- the shank is the same 4mm rod on every one of them.
#
#   len    shank length
#   bow    radius of the handle loop
#   wards  how many steps are cut into the bit
#   mat    the metal it was cut from
function i_key(len, bow, wards, mat,   x0, x1, i, sy, rod, bw, bh, step) {
  x0 = -len / 2
  x1 =  len / 2
  sy = bow * 0.80

  # EVERYTHING SCALES WITH len. The first version used fixed 19mm-by-22mm
  # wards on every key, which on the 34mm bureau key made the bit more than
  # half the length of the whole thing -- in the journal, where a key fills
  # the page, it read as a cleaver rather than a key.
  rod = len * 0.055
  bw = len * 0.30
  bh = len * 0.36
  step = bw * 0.45

  # The bow stands UP off the surface: a key dropped on a table lands on its
  # side, and the loop is the part that catches a torch beam.
  iring("KeyBow", x0 - bow * 0.85, sy, 0, bow, bow * 0.54, rod * 1.6, mat, 16)
  ibox("KeyBowFoot", x0 - bow * 0.05, sy, 0, bow * 0.7, rod * 2.6, rod * 1.6, mat, 0, 0, 0, "")

  icyl("KeyShank", 0, sy, 0, rod, len, mat, 10, 0, 0, 90, "")
  icyl("KeyCollar", x1 - len * 0.32, sy, 0, rod * 1.6, len * 0.12, mat, 10, 0, 0, 90, "")

  # the flag, then the wards cut out of it
  ibox("KeyBit", x1 - bw * 0.45, sy - bh * 0.42, 0, bw, bh, rod * 1.6, mat, 0, 0, 0, "")
  for (i = 0; i < wards; i++)
    ibox("KeyWard", x1 - bw * 0.80 + i * step, sy - bh * 0.70 - (i % 2) * bh * 0.18, 0,
         step * 0.42, bh * 0.45, rod * 4.0, mat, 0, 0, 0, "sub")
  icyl("KeyTip", x1 + len * 0.05, sy, 0, rod, len * 0.16, mat, 8, 0, 0, 90, "")
}

# ---- crowbar --------------------------------------------------------------
# Laid on its side, so the goose-neck sweeps in the XY plane and the claw is
# the only part off the surface. The bend is ten short segments rather than one
# angled box: the curve is the entire silhouette of a crowbar, and a single
# mitre reads as a bent nail.
function i_crowbar(   i, n, a, r, cx, cy, ang, sw, seg, tx, ty) {
  icyl("BarShaft", 0.06, 0.0115, 0, 0.0115, 0.48, "Mat_steel", 6, 0, 0, 90, "")

  # chisel end: flattened, then tapered by cutting a wedge off the underside
  ibox("BarChisel", 0.325, 0.0100, 0, 0.075, 0.019, 0.026, "Mat_steel", 0, 0, -4, "")
  ibox("BarBevel", 0.372, -0.006, 0, 0.044, 0.022, 0.044, "Mat_steel", 0, 0, 15, "sub")

  # The bend. Ten segments at 10 sides each and generously overlapped: at six
  # sides the flats of neighbouring segments never lined up and the goose neck
  # came out looking like a caterpillar in the journal render.
  n = 10; r = 0.075; sw = 120.0
  cx = -0.18; cy = 0.0115 + r
  seg = rad(sw / n) * r * 2.1
  for (i = 0; i < n; i++) {
    ang = 270.0 - sw * (i + 0.5) / n
    a = rad(ang)
    icyl("BarBend", cx + cos(a) * r, cy + sin(a) * r, 0, 0.0105, seg, "Mat_steel", 10, 0, 0, ang + 90, "")
  }

  # The claw carries on along the TANGENT at the end of the bend, so it grows
  # out of the curve instead of floating beside it. Placing it by eye left a
  # visible gap between the two from every angle but head on.
  ang = 270.0 - sw
  a = rad(ang)
  cx = cx + cos(a) * r
  cy = cy + sin(a) * r
  tx = sin(a)
  ty = -cos(a)
  ibox("BarClaw", cx + tx * 0.030, cy + ty * 0.030, 0, 0.070, 0.014, 0.030,
       "Mat_steel", 0, 0, ang - 90, "")
  ibox("BarFork", cx + tx * 0.058, cy + ty * 0.058, 0, 0.044, 0.034, 0.008,
       "Mat_steel", 0, 0, ang - 90, "sub")
}

# ---- the rest -------------------------------------------------------------

function i_fuse() {
  icyl("FuseBody", 0, 0.014, 0, 0.0135, 0.054, "Mat_porcelain", 14, 0, 0, 90, "")
  icyl("FuseRib", 0, 0.014, 0, 0.0160, 0.008, "Mat_porcelain", 14, 0, 0, 90, "")
  icyl("FuseCap", -0.031, 0.014, 0, 0.0146, 0.013, "Mat_brass", 14, 0, 0, 90, "")
  icyl("FuseCap", 0.031, 0.014, 0, 0.0146, 0.013, "Mat_brass", 14, 0, 0, 90, "")
  ibox("FuseWindow", 0, 0.026, 0, 0.024, 0.006, 0.011, "Mat_glass", 0, 0, 0, "")
}

function i_battery() {
  icyl("CellBody", 0, 0.025, 0, 0.0130, 0.050, "Mat_steel", 14, 0, 0, 0, "")
  # Dark enamel, not the pale paper label: next to the porcelain fuse in the
  # journal grid a cream-coloured cylinder read as a second fuse.
  icyl("CellLabel", 0, 0.023, 0, 0.0134, 0.030, "Mat_enamel", 14, 0, 0, 0, "")
  icyl("CellBand", 0, 0.036, 0, 0.0136, 0.005, "Mat_label", 14, 0, 0, 0, "")
  icyl("CellRim", 0, 0.0485, 0, 0.0127, 0.005, "Mat_steel", 14, 0, 0, 0, "")
  icyl("CellStud", 0, 0.0530, 0, 0.0052, 0.005, "Mat_copper", 10, 0, 0, 0, "")
}

## Pressed-steel can: shoulders, a screw cap and the X brace on each face. The
## brace is what makes it read as a fuel can rather than a lunchbox.
function i_fuelcan(   w, h, d, i, s) {
  w = 0.17; h = 0.28; d = 0.115
  ibox("CanBody", 0, h / 2, 0, w, h, d, "Mat_enamel", 0, 0, 0, "")
  ibox("CanShoulder", 0, h - 0.012, 0, w - 0.028, 0.032, d - 0.026, "Mat_enamel", 0, 0, 0, "")
  ibox("CanSeam", 0, h / 2, 0, w + 0.008, h * 0.97, 0.010, "Mat_enamel", 0, 0, 0, "")

  for (i = -1; i <= 1; i += 2)
    for (s = -1; s <= 1; s += 2)
      ibox("CanBrace", 0, h * 0.48, s * (d / 2 + 0.002), 0.013, h * 0.72, 0.008,
           "Mat_enamel", 0, 0, i * 32, "")

  icyl("CanCap", -w / 2 + 0.038, h + 0.013, 0, 0.022, 0.020, "Mat_brass", 12, 0, 0, 0, "")
  icyl("CanCapNut", -w / 2 + 0.038, h + 0.026, 0, 0.012, 0.010, "Mat_brass", 6, 0, 0, 0, "")

  # three-bar military handle
  ibox("CanHandle", 0.014, h + 0.032, 0, 0.090, 0.012, 0.014, "Mat_enamel", 0, 0, 0, "")
  ibox("CanHandleLeg", -0.028, h + 0.016, 0, 0.012, 0.036, 0.014, "Mat_enamel", 0, 0, 0, "")
  ibox("CanHandleLeg", 0.056, h + 0.016, 0, 0.012, 0.036, 0.014, "Mat_enamel", 0, 0, 0, "")
  ibox("CanGrip", 0.014, h + 0.032, 0, 0.052, 0.016, 0.018, "Mat_leather", 0, 0, 0, "")
}

## The lens, lying flat on a counter with the handle running off to -X. The
## glass stands a hair proud of the rim on both faces so it catches a specular
## highlight instead of disappearing into the brass.
function i_magnifier(   rr) {
  rr = 0.058
  iring("LensRim", 0.030, 0.009, 0, rr, rr - 0.009, 0.017, "Mat_brass", 24)
  icyl("LensGlass", 0.030, 0.009, 0, rr - 0.008, 0.020, "Mat_glass", 24, 0, 0, 0, "")
  ibox("LensNeck", -0.036, 0.009, 0, 0.032, 0.015, 0.021, "Mat_brass", 0, 0, 0, "")
  icyl("LensFerrule", -0.059, 0.009, 0, 0.013, 0.020, "Mat_brass", 12, 0, 0, 90, "")
  icyl("LensHandle", -0.099, 0.009, 0, 0.0115, 0.064, "Mat_walnut", 12, 0, 0, 90, "")
  icyl("LensSwell", -0.114, 0.009, 0, 0.0145, 0.022, "Mat_walnut", 12, 0, 0, 90, "")
  isphere("LensButt", -0.133, 0.009, 0, 0.0125, "Mat_brass", "")
}

## The grimoire, lying open. Not a pickup: it stays on the office desk, and the
## particle emitter in grimoire.tscn sits in the gutter between the two leaves.
function i_grimoire(   w, d, t, i) {
  w = 0.36; d = 0.27; t = 0.055
  ibox("BookBoard", 0, t / 2, 0, w, t, d, "Mat_grimoire", 0, 0, 0, "")
  ibox("BookSpine", 0, t / 2 + 0.004, 0, 0.055, t + 0.012, d + 0.012, "Mat_leather", 0, 0, 0, "")

  # the two open leaves, each tilted a couple of degrees out of the gutter
  ibox("BookLeaf", -w / 4 - 0.008, t + 0.010, 0, w / 2 - 0.030, 0.020, d - 0.026, "Mat_leaf", 0, 0, 2.5, "")
  ibox("BookLeaf", w / 4 + 0.008, t + 0.010, 0, w / 2 - 0.030, 0.020, d - 0.026, "Mat_leaf", 0, 0, -2.5, "")
  ibox("BookEdge", 0, t + 0.004, 0, w - 0.020, 0.009, d - 0.018, "Mat_paper", 0, 0, 0, "")

  # corner bosses and two clasps, so the closed-book silhouette still works
  for (i = -1; i <= 1; i += 2) {
    icyl("BookBoss", i * (w / 2 - 0.026), t + 0.002, d / 2 - 0.026, 0.012, t + 0.010, "Mat_brass", 8, 0, 0, 0, "")
    icyl("BookBoss", i * (w / 2 - 0.026), t + 0.002, -d / 2 + 0.026, 0.012, t + 0.010, "Mat_brass", 8, 0, 0, 0, "")
    ibox("BookClasp", i * (w / 2 + 0.004), t / 2, 0, 0.016, 0.017, 0.050, "Mat_brass", 0, 0, 0, "")
  }

  # the sigil burnt into the right-hand leaf: a ring and four spokes, emissive
  iring("Sigil", w / 4 + 0.008, t + 0.023, 0, 0.052, 0.041, 0.004, "Mat_sigil", 20)
  for (i = 0; i < 4; i++)
    ibox("SigilSpoke", w / 4 + 0.008, t + 0.023, 0, 0.090, 0.003, 0.006, "Mat_sigil", 0, i * 45, 0, "")
}

## A fairground token. A brass disc with a milled rim, a square hole punched
## through the middle and a stamped ring of letters nobody can read.
##
## Lying flat rather than standing on edge: three of these are found on the
## ground in a dark fairground, and a disc face-up catches what little light
## there is. On edge it is a line and the player walks past it.
function i_token(   r) {
  r = 0.028
  icyl("TokenBody", 0, 0.0025, 0, r, 0.005, "Mat_brass", 20, 0, 0, 0, "")
  # Milled rim: a slightly proud ring, so the edge catches a highlight.
  icyl("TokenRim", 0, 0.0025, 0, r, 0.0062, "Mat_brass", 20, 0, 0, 0, "")
  icyl("TokenField", 0, 0.0025, 0, r - 0.0035, 0.0075, "Mat_brass", 20, 0, 0, 0, "sub")
  icyl("TokenFace", 0, 0.0025, 0, r - 0.0035, 0.0044, "Mat_brass", 20, 0, 0, 0, "")
  # The square hole. What makes it a token and not a coin.
  ibox("TokenHole", 0, 0.0025, 0, 0.008, 0.02, 0.008, "Mat_brass", 0, 0, 0, "sub")
  # Two struck marks, so the face is not blank at journal-icon size.
  ibox("TokenMark", 0, 0.0052, 0.013, 0.012, 0.0012, 0.003, "Mat_label", 0, 0, 0, "")
  ibox("TokenMark", 0, 0.0052, -0.013, 0.012, 0.0012, 0.003, "Mat_label", 0, 0, 0, "")
}
