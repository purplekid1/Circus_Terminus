# Shared emitters for the mansion generators.
#
# Godot writes a Transform3D basis ROW-major in .tscn: the three serialised
# triples are the matrix ROWS, not the axis vectors. A yaw about Y therefore
# comes out as (c,0,s / 0,1,0 / -s,0,c). Getting this backwards transposes the
# rotation, which is what made the first staircase slope the wrong way.
#
# Props are emitted in prop-local space and rotated about their own origin by
# open_prop(), so a chair or a table is written once and then placed facing any
# wall.

function PI() { return 3.14159265358979 }
function rad(d) { return d * PI() / 180.0 }
function sq(a) { return a * a }
function abs(a) { return a < 0 ? -a : a }
function hyp(a, b) { return sqrt(sq(a) + sq(b)) }

# ---- transforms -----------------------------------------------------------

function T(x, y, z) {
  return sprintf("Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f)", x, y, z)
}

## Yaw about +Y, serialised row-major.
function Tyaw(x, y, z, deg,   r, c, s) {
  if (deg == 0) return T(x, y, z)
  r = rad(deg); c = cos(r); s = sin(r)
  return sprintf("Transform3D(%.6f, 0, %.6f, 0, 1, 0, %.6f, 0, %.6f, %.4f, %.4f, %.4f)",
                 c, s, -s, c, x, y, z)
}

## Pitch about +X, serialised row-major. Used for stair ramps and roof planes.
function Tpitch(x, y, z, deg,   r, c, s) {
  r = rad(deg); c = cos(r); s = sin(r)
  return sprintf("Transform3D(1, 0, 0, 0, %.6f, %.6f, 0, %.6f, %.6f, %.4f, %.4f, %.4f)",
                 c, -s, s, c, x, y, z)
}

## Roll about +Z. Used for leaning debris.
function Troll(x, y, z, deg,   r, c, s) {
  r = rad(deg); c = cos(r); s = sin(r)
  return sprintf("Transform3D(%.6f, %.6f, 0, %.6f, %.6f, 0, 0, 0, 1, %.4f, %.4f, %.4f)",
                 c, -s, s, c, x, y, z)
}

# ---- full rotations -------------------------------------------------------
# Moved here from items.awk so that cyl() can use it. Composition is
# M = Y * X * Z, so Z is applied first and Y last.

function mmul(a, b, out,   i, j, k, s) {
  for (i = 0; i < 3; i++)
    for (j = 0; j < 3; j++) {
      s = 0
      for (k = 0; k < 3; k++) s += a[i, k] * b[k, j]
      out[i, j] = s
    }
}

function mrotx(d, out,   c, s) {
  c = cos(rad(d)); s = sin(rad(d))
  out[0,0]=1; out[0,1]=0; out[0,2]=0
  out[1,0]=0; out[1,1]=c; out[1,2]=-s
  out[2,0]=0; out[2,1]=s; out[2,2]=c
}

function mroty(d, out,   c, s) {
  c = cos(rad(d)); s = sin(rad(d))
  out[0,0]=c;  out[0,1]=0; out[0,2]=s
  out[1,0]=0;  out[1,1]=1; out[1,2]=0
  out[2,0]=-s; out[2,1]=0; out[2,2]=c
}

function mrotz(d, out,   c, s) {
  c = cos(rad(d)); s = sin(rad(d))
  out[0,0]=c; out[0,1]=-s; out[0,2]=0
  out[1,0]=s; out[1,1]=c;  out[1,2]=0
  out[2,0]=0; out[2,1]=0;  out[2,2]=1
}

## Full transform for a node rotated (rx, ry, rz) and placed at (x, y, z).
function TR(x, y, z, rx, ry, rz,   X, Y, Z, T1, M) {
  mrotx(rx, X); mroty(ry, Y); mrotz(rz, Z)
  mmul(Y, X, T1)
  mmul(T1, Z, M)
  return sprintf("Transform3D(%.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.5f, %.5f, %.5f)",
                 M[0,0], M[0,1], M[0,2],
                 M[1,0], M[1,1], M[1,2],
                 M[2,0], M[2,1], M[2,2], x, y, z)
}

# ---- node emitters --------------------------------------------------------

## A CSGBox3D in absolute coordinates. Always `material`, never
## `material_override`: the override is a render-time thing that the CSG bake
## does not carry into the mesh, so anything using it comes out untextured.
function box(parent, name, x, y, z, sx, sy, sz, mat, yaw) {
  N++
  printf "\n[node name=\"%s_%d\" type=\"CSGBox3D\" parent=\"%s\"]\n", name, N, parent
  printf "transform = %s\n", Tyaw(x, y, z, yaw + 0)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "size = Vector3(%.4f, %.4f, %.4f)\n", sx, sy, sz
}

## A CSGCylinder3D -- legs, candles, pipes, balusters. Cheaper to read as round
## than faking it with a box, and CSG gives us cylinders for free.
##
## A CSGCylinder3D POINTS ALONG ITS OWN Y AXIS, and for a long time the only
## rotation this took was `yaw` -- which spins a cylinder about the very axis it
## already points down, and therefore does precisely nothing to its orientation.
## Every cylinder in the house was structurally forced to stand upright, and
## anything that should have lain across -- chandelier arms, sconce arms, the
## handle on the range -- came out as a post sticking up through the fitting.
##
## So `rx` and `rz` tip it over:
##
##     rx = 90   lays it along +Z
##     rz = 90   lays it along -X
##
## Both are optional and default to nothing, so the hundred existing upright
## calls are untouched.
function cyl(parent, name, x, y, z, radius, height, mat, yaw, sides, rx, rz) {
  N++
  printf "\n[node name=\"%s_%d\" type=\"CSGCylinder3D\" parent=\"%s\"]\n", name, N, parent
  printf "transform = %s\n", TR(x, y, z, rx + 0, yaw + 0, rz + 0)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "radius = %.4f\n", radius
  printf "height = %.4f\n", height
  printf "sides = %d\n", (sides > 0 ? sides : 10)
}

## Places a prop scene from Scenes/props/. `res` is its ExtResource id, which
## gen_header.sh resolves from the filename.
##
## There are no size arguments: a baked scene is one fixed size, and the layout
## picks whichever variant fits. That constraint is the point -- a house has
## three kinds of table in it, not seventeen.
function inst(parent, name, res, x, y, z, yaw) {
  N++
  printf "\n[node name=\"%s_%d\" parent=\"%s\" instance=ExtResource(\"%s\")]\n", name, N, parent, res
  printf "transform = %s\n", Tyaw(x, y, z, yaw + 0)
}

function combiner(name, parent, collide) {
  printf "\n[node name=\"%s\" type=\"CSGCombiner3D\" parent=\"%s\"]\n", name, parent
  if (collide) printf "use_collision = true\n"
}

function node3d(name, parent) {
  printf "\n[node name=\"%s\" type=\"Node3D\" parent=\"%s\"]\n", name, parent
}

## A combiner for ONE piece of dressing, returning its node path.
##
## Rooms used to be three big combiners each, so a room's every rug, picture,
## paper pile and dust sheet baked into a single mesh. That was fast and it
## was unusable: you could not move one candle, hide one picture or delete one
## pile of sheets without regenerating the house, and in the editor the whole
## room selected as one object.
##
## Now `<Room>` and `<Room>Dress` are plain Node3Ds and every item underneath
## opens one of these. The bake still collapses each item to a single mesh --
## a rug is one mesh, not three boxes -- but the room is thirty movable
## objects instead of one welded lump. The cost is thirty draw calls a room
## where there was one, which at this scene's scale is not the bottleneck; the
## CSG count, which is what actually made the editor crawl, is unchanged.
##
## MUST NOT be called with a CSG parent. A combiner nested inside a combiner
## is just a brush: it gets folded into the parent and baked away.
function group(parent, name, collide,   path) {
  GRP++
  path = sprintf("%s/%s_%d", parent, name, GRP)
  printf "\n[node name=\"%s_%d\" type=\"CSGCombiner3D\" parent=\"%s\"]\n", name, GRP, parent
  if (collide) printf "use_collision = true\n"
  return path
}

# ---- prop frame -----------------------------------------------------------
# open_prop() fixes an origin and a facing; pbox()/pcyl() then take offsets in
# prop-local space where +Z is the way the prop FACES and -Z is its back.
# Rotating a whole arrangement is a one-number change instead of retyping every
# coordinate. Yaw 0 faces +Z, 90 faces +X.


function open_prop(parent, x, y, z, yaw) {
  PP = parent; PX = x; PY = y; PZ = z; PYAW = yaw + 0
  PC = cos(rad(PYAW)); PS = sin(rad(PYAW))
}

function px(ox, oz) { return PX + ox * PC + oz * PS }
function pz(ox, oz) { return PZ - ox * PS + oz * PC }

function pbox(name, ox, oy, oz, sx, sy, sz, mat) {
  box(PP, name, px(ox, oz), PY + oy, pz(ox, oz), sx, sy, sz, mat, PYAW)
}

## `rx` and `rz` tip the cylinder over -- see the note on cyl(). They are
## applied in the prop's OWN frame, so an arm laid along +Z points out of the
## front of the prop whichever way the prop has been turned in the room.
function pcyl(name, ox, oy, oz, radius, height, mat, sides, rx, rz) {
  cyl(PP, name, px(ox, oz), PY + oy, pz(ox, oz), radius, height, mat, PYAW, sides, rx, rz)
}

# ---- deterministic jitter -------------------------------------------------
# An abandoned house should not look like it was laid out on graph paper, but a
# generator that used rand() would reshuffle the whole interior on every run and
# make diffs useless. This hashes the caller's key instead, so "the chair by the
# window" keeps its exact nudge forever.

function jit(key, spread,   h, i, c) {
  h = 5381
  for (i = 1; i <= length(key); i++) {
    c = index(" abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-", substr(key, i, 1))
    h = (h * 33 + c) % 1000003
  }
  return ((h % 2000) / 1000.0 - 1.0) * spread
}
