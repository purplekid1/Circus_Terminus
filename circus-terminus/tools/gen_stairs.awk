# Staircases: treads, risers, stringers, ramp colliders and balustrades.
#
# Requires lib.awk.
#
# The visible treads and the collider are derived from ONE pair of endpoints, so
# they cannot drift apart. CharacterBody3D has no step-up, so the thing the
# player actually walks on is the ramp; the treads are decoration sitting
# exactly under its surface.
#
# Each flight is given as TOP then BOTTOM. The ramp is extended past the bottom
# end only: overhanging the top would raise the surface above the landing and
# put a lip in the middle of the floor.

## flight(group, x, width, z_top, y_top, z_bot, y_bot, steps, mat, rail_l, rail_r)
function flight(g, x, w, za, ya, zb, yb, n, mat, rail_l, rail_r,
                dz, dy, L0, sy, sz, ny, nz, phi, over, mz, my, cz, cy,
                i, tz, ty, rz, over2, going, rise) {
  dz = zb - za; dy = yb - ya
  L0 = hyp(dz, dy)
  sy = dy / L0; sz = dz / L0                 # unit vector down the slope
  if (sz > 0) { ny =  sz; nz = -sy }         # surface normal, y always positive
  else        { ny = -sz; nz =  sy }
  phi = atan2(nz, ny) * 180.0 / PI()
  over = 0.70                                # bottom-end overhang, under the floor
  mz = (za + zb) / 2; my = (ya + yb) / 2

  # ---- collider: a thick slab whose TOP face is the walking surface
  over2 = over / 2
  cz = mz + sz * over2 - nz * 2.0
  cy = my + sy * over2 - ny * 2.0
  printf "\n[node name=\"Ramp\" type=\"StaticBody3D\" parent=\"%s\"]\n", g
  printf "\n[node name=\"CollisionShape3D\" type=\"CollisionShape3D\" parent=\"%s/Ramp\"]\n", g
  printf "transform = %s\n", Tpitch(x, cy, cz, phi)
  printf "shape = SubResource(\"Box_ramp%s\")\n", g
  RAMPW[g] = w; RAMPL[g] = L0 + over

  # ---- treads and risers
  # `going` is the horizontal run per step and `rise` the vertical; both are
  # taken as magnitudes so a flight reads the same whichever way it points.
  going = abs(za - zb) / n
  rise = abs(ya - yb) / n
  printf "\n[node name=\"Steps\" type=\"CSGCombiner3D\" parent=\"%s\"]\n", g
  for (i = 0; i < n; i++) {
    ty = yb + (ya - yb) * (i + 1) / n      # tread surface
    tz = zb + (za - zb) * (i + 0.5) / n    # tread centre
    rz = zb + (za - zb) * (i + 1) / n      # riser plane, at the up-slope edge
    box(g "/Steps", "Tread", x, ty - 0.03, tz, w, 0.06, going + 0.06, mat, 0)
    box(g "/Steps", "Riser", x, ty - rise / 2 - 0.03, rz, w - 0.02, rise, 0.05, mat, 0)
  }
  # soffit and stringers, so the flight is solid from underneath
  box2p(g "/Steps", "Soffit", x, my - ny * 0.30, mz - nz * 0.30, w - 0.10, 0.34, L0, mat, phi)
  box2p(g "/Steps", "Stringer", x - w / 2 + 0.06, my - ny * 0.12, mz - nz * 0.12, 0.12, 0.52, L0 + 0.2, "Mat_walnut", phi)
  box2p(g "/Steps", "Stringer", x + w / 2 - 0.06, my - ny * 0.12, mz - nz * 0.12, 0.12, 0.52, L0 + 0.2, "Mat_walnut", phi)

  # ---- raking balustrades
  if (rail_l) rake_rail(g "/Steps", x - w / 2 + 0.10, za, ya, zb, yb, phi, L0)
  if (rail_r) rake_rail(g "/Steps", x + w / 2 - 0.10, za, ya, zb, yb, phi, L0)
}

## A pitched box, for anything that follows the rake.
function box2p(parent, name, x, y, z, sx, sy, sz, mat, phi) {
  N++
  printf "\n[node name=\"%s_%d\" type=\"CSGBox3D\" parent=\"%s\"]\n", name, N, parent
  printf "transform = %s\n", Tpitch(x, y, z, phi)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "size = Vector3(%.4f, %.4f, %.4f)\n", sx, sy, sz
}

## Handrail, newels and balusters up one side of a flight.
function rake_rail(parent, x, za, ya, zb, yb, phi, L0,   i, n, t, bz, by, h) {
  h = 0.92
  box2p(parent, "Handrail", x, (ya + yb) / 2 + h + 0.04, (za + zb) / 2, 0.09, 0.09, L0 + 0.24, "Mat_walnut", phi)
  cyl(parent, "Newel", x, yb + h / 2 + 0.16, zb, 0.075, h + 0.32, "Mat_walnut", 0, 8)
  box(parent, "NewelCap", x, yb + h + 0.36, zb, 0.22, 0.10, 0.22, "Mat_walnut", 0)
  cyl(parent, "Newel", x, ya + h / 2 + 0.16, za, 0.075, h + 0.32, "Mat_walnut", 0, 8)
  box(parent, "NewelCap", x, ya + h + 0.36, za, 0.22, 0.10, 0.22, "Mat_walnut", 0)
  n = int(L0 / 0.26)
  for (i = 1; i < n; i++) {
    t = i / n
    by = yb + (ya - yb) * t
    bz = zb + (za - zb) * t
    cyl(parent, "Baluster", x, by + h / 2, bz, 0.022, h, "Mat_walnut", 0, 6)
  }
}

## Level guard rail along a floor edge, for the sides of a stairwell.
## `axis` is "x" or "z"; the run goes from a to b at the fixed coordinate `at`.
##
## `na`/`nb` post a newel at the a / b end. Pass 0 at the end that meets a
## flight: the raking balustrade already has its own newel a few centimetres
## away, and two of them together read as a pile of timber rather than a post.
function guard(parent, axis, a, b, at, y, na, nb,   i, n, h, len, p) {
  h = 0.95; len = (b > a) ? b - a : a - b
  if (axis == "x") {
    box(parent, "GuardRail", (a + b) / 2, y + h + 0.04, at, len, 0.09, 0.09, "Mat_walnut", 0)
    box(parent, "GuardShoe", (a + b) / 2, y + 0.06, at, len, 0.12, 0.08, "Mat_walnut", 0)
    if (na) newel(parent, a, y, at, h)
    if (nb) newel(parent, b, y, at, h)
    n = int(len / 0.26)
    for (i = 1; i < n; i++) {
      p = a + (b - a) * i / n
      cyl(parent, "Baluster", p, y + h / 2, at, 0.022, h, "Mat_walnut", 0, 6)
    }
  } else {
    box(parent, "GuardRail", at, y + h + 0.04, (a + b) / 2, 0.09, 0.09, len, "Mat_walnut", 0)
    box(parent, "GuardShoe", at, y + 0.06, (a + b) / 2, 0.08, 0.12, len, "Mat_walnut", 0)
    if (na) newel(parent, at, y, a, h)
    if (nb) newel(parent, at, y, b, h)
    n = int(len / 0.26)
    for (i = 1; i < n; i++) {
      p = a + (b - a) * i / n
      cyl(parent, "Baluster", at, y + h / 2, p, 0.022, h, "Mat_walnut", 0, 6)
    }
  }
}

function newel(parent, x, y, z, h) {
  cyl(parent, "Newel", x, y + h / 2 + 0.16, z, 0.075, h + 0.32, "Mat_walnut", 0, 8)
  box(parent, "NewelCap", x, y + h + 0.36, z, 0.22, 0.10, 0.22, "Mat_walnut", 0)
}

BEGIN {
  # ---- main flight: hall floor up to the landing ------------------------
  # Top end sits exactly on the upper slab edge (CutMainWell runs z -4..-16.2),
  # so there is no gap to fall down where the flight meets the landing.
  printf "\n[node name=\"MainStairs\" type=\"Node3D\" parent=\".\"]\n"
  flight("MainStairs", 0, 5.0, -16.2, 3.6, -4.0, 0.0, 12, "Mat_floor", 1, 1)

  # The b end of each side run is the stair head, where the raking rail's own
  # newel already stands.
  printf "\n[node name=\"MainGuards\" type=\"CSGCombiner3D\" parent=\"MainStairs\"]\n"
  guard("MainStairs/MainGuards", "z", -4.10, -16.10, -2.60, 3.6, 1, 0)
  guard("MainStairs/MainGuards", "z", -4.10, -16.10,  2.60, 3.6, 1, 0)
  guard("MainStairs/MainGuards", "x", -2.60,  2.60, -4.10, 3.6, 0, 0)

  # ---- cellar flight: boot room down to the basement --------------------
  printf "\n[node name=\"CellarStairs\" type=\"Node3D\" parent=\".\"]\n"
  flight("CellarStairs", 12, 4.0, -26.8, 0.0, -33.0, -3.6, 10, "Mat_stone", 1, 1)

  # Here the a end is the stair head, so that is the newel to leave out.
  printf "\n[node name=\"CellarGuards\" type=\"CSGCombiner3D\" parent=\"CellarStairs\"]\n"
  guard("CellarStairs/CellarGuards", "z", -26.90, -33.30,  9.70, 0.0, 0, 1)
  guard("CellarStairs/CellarGuards", "z", -26.90, -33.30, 14.30, 0.0, 0, 1)
  guard("CellarStairs/CellarGuards", "x",   9.70, 14.30, -33.30, 0.0, 0, 0)
}

END {
  # Ramp shapes go to a sidecar that build.sh folds into the header: a .tscn
  # cannot declare sub_resources after the node list.
  if (shapes == "") shapes = "/dev/null"
  for (g in RAMPW)
    printf "\n[sub_resource type=\"BoxShape3D\" id=\"Box_ramp%s\"]\nsize = Vector3(%.4f, 4, %.4f)\n",
           g, RAMPW[g], RAMPL[g] > shapes
}
