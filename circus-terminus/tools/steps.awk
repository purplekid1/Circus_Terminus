# Stone steps: the front stoop and the flight down into the cellar pit.
#
# Requires lib.awk.
#
# These are NOT gen_stairs.awk. That file builds the two staircases inside the
# house -- painted timber treads, walnut stringers, turned balusters -- and
# they are joinery. These are masonry: bluestone slabs with a projecting
# nosing, laid on brick, with solid cheek walls capped in stone. The brief was
# that the way into the house should not look like the way up to the landing,
# and the cheapest way to make two flights of steps read as different things
# is to build them out of different materials with different details.
#
# What they share with gen_stairs.awk is the rule that matters:
#
#   CharacterBody3D HAS NO STEP-UP. The thing the player walks on is a RAMP,
#   and the treads are decoration sitting exactly under its surface.
#
# Both are derived here from one pair of endpoints -- the top nosing and the
# bottom nosing -- so they cannot drift apart. A flight whose treads are 3 cm
# proud of its ramp is a flight the player trips over on every step.

## The lip a bluestone tread throws past the riser under it. Small, but it is
## most of what separates "steps" from "a pile of boxes": it puts a hard
## shadow line under every nosing.
function NOSING() { return 0.035 }

## Tread slab thickness.
function SLAB() { return 0.075 }

## masonry_flight(parent, x, width, z_top, y_top, z_bot, y_bot, steps,
##                tread_mat, riser_mat, cheeks, ramp_name)
##
## The flight runs from (z_top, y_top) -- which is the FINISHED LEVEL it
## arrives at, i.e. the deck or the doorstep, not the last tread -- down and
## out to (z_bot, y_bot), the ground it starts from. z_bot is the more
## positive of the two for a flight facing +Z.
##
## `cheeks` > 0 emits solid side walls that width, capped along the rake.
function masonry_flight(parent, x, w, zt, yt, zb, yb, n, tread, riser, cheeks, ramp,
                        dz, dy, L0, sy, sz, ny, nz, phi, over, mz, my, cz, cy,
                        i, ty, tz, rz, going, rise, side, cx, g) {
  dz = zb - zt; dy = yb - yt
  L0 = hyp(dz, dy)
  sy = dy / L0; sz = dz / L0                 # unit vector down the slope
  if (sz > 0) { ny =  sz; nz = -sy }         # surface normal, y always positive
  else        { ny = -sz; nz =  sy }
  phi = atan2(nz, ny) * 180.0 / PI()

  # ---- the collider: a thick slab whose TOP FACE is the walking surface.
  # Overhung at the BOTTOM end only. Extending the top end would raise the
  # surface above the deck it arrives at and leave an invisible lip in the
  # middle of the porch -- the same trap the house staircases document.
  over = 0.55
  mz = (zt + zb) / 2; my = (yt + yb) / 2
  cz = mz + sz * (over / 2) - nz * 1.5
  cy = my + sy * (over / 2) - ny * 1.5
  #
  # An EMPTY `ramp` means something else already owns the walking surface --
  # the cellar flight is laid over CellarPit/Ramp, which was in the mansion
  # scene long before these steps were, and emitting a second collider on the
  # same plane would be two sources of truth for one slope.
  if (ramp != "") {
    printf "\n[node name=\"%s\" type=\"StaticBody3D\" parent=\"%s\"]\n", ramp, parent
    printf "\n[node name=\"CollisionShape3D\" type=\"CollisionShape3D\" parent=\"%s\"]\n", kid(parent, ramp)
    printf "transform = %s\n", Tpitch(x, cy, cz, phi)
    printf "shape = SubResource(\"Box_%s\")\n", ramp
    RAMPW[ramp] = w
    RAMPL[ramp] = L0 + over
  }

  # ONE combiner for all the masonry. A loose CSGBox3D under a Node3D is its
  # own CSG root as far as bake.gd is concerned, and this flight would have
  # come out as seventeen separate mesh files with seventeen draw calls.
  # use_collision stays OFF: the ramp above is the walking surface, and giving
  # the treads collision too is how you get a lip on every step.
  printf "\n[node name=\"Steps\" type=\"CSGCombiner3D\" parent=\"%s\"]\n", parent
  g = kid(parent, "Steps")

  going = abs(zt - zb) / n
  rise = abs(yt - yb) / n

  # ---- treads and risers.
  # i = 0 is the bottom step. The TOP tread is deliberately not emitted: at
  # i = n the tread would be the deck itself, and laying a second slab on the
  # porch boards is how you get a 75 mm lip across the front door.
  for (i = 0; i < n; i++) {
    ty = yb + (yt - yb) * (i + 1) / n        # this tread's walking surface
    tz = zb + (zt - zb) * (i + 0.5) / n      # its centre
    rz = zb + (zt - zb) * (i + 1) / n        # the riser behind it

    if (i < n - 1)
      sbox2(g, "Tread", x, ty - SLAB() / 2, tz + NOSING() / 2,
            w + NOSING() * 2, SLAB(), going + NOSING(), tread)
    # The riser is set BACK from the nosing by the overhang, which is what
    # throws the shadow.
    sbox2(g, "Riser", x, ty - SLAB() - rise / 2, rz - NOSING(),
          w, rise, 0.12, riser)
  }

  # A plinth under the bottom step, so the flight sits on something instead of
  # ending in a slab floating on the grass.
  sbox2(g, "Plinth", x, yb - 0.12, (zb + zt) / 2,
        w + NOSING() * 2 + 0.06, 0.26, abs(zb - zt) + 0.2, riser)

  if (cheeks > 0) {
    for (side = -1; side <= 1; side += 2) {
      cx = x + side * (w / 2 + NOSING() + cheeks / 2)
      # The wall itself: a plain brick box from below ground to the top level,
      # squared off rather than raked. A raked cheek needs a triangular brush
      # and CSG has no wedge; a square one is also what a stone stoop of this
      # period actually has.
      sbox2(g, "Cheek", cx, (yt + yb) / 2 - 0.10,
            (zt + zb) / 2, cheeks, abs(yt - yb) + 0.50, abs(zb - zt) + 0.10, riser)
      # Stone coping along the top of it, following the rake.
      pbox2(g, "Coping", cx, my + ny * 0.055, mz + nz * 0.055,
            cheeks + 0.07, 0.11, L0 + 0.12, tread, phi)
      # A pier at the foot, which is where a stoop puts a lamp or an urn.
      sbox2(g, "Pier", cx, yb + 0.16, zb - 0.02, cheeks + 0.12, 0.60, 0.46, riser)
      sbox2(g, "PierCap", cx, yb + 0.48, zb - 0.02, cheeks + 0.22, 0.09, 0.56, tread)
    }
  }
}


## The pitch of a flight, in the degrees Tpitch wants. Derived rather than
## typed, so a rail and the flight it runs beside cannot end up at different
## angles because somebody worked one of them out with a calculator.
function flight_phi(zt, yt, zb, yb,   dz, dy, L0, sy, sz, ny, nz) {
  dz = zb - zt; dy = yb - yt
  L0 = hyp(dz, dy)
  sy = dy / L0; sz = dz / L0
  if (sz > 0) { ny =  sz; nz = -sy }
  else        { ny = -sz; nz =  sy }
  return atan2(nz, ny) * 180.0 / PI()
}


## An iron handrail on standards, for the cellar flight. The house's own
## staircases get turned walnut balusters; this gets a scaffold pole, because
## it is a cellar and because it has to read as different at a glance.
function rake_pipe(parent, x, zt, yt, zb, yb,   i, n, t, pz, py, h, phi, L0, g) {
  phi = flight_phi(zt, yt, zb, yb)
  L0 = hyp(zb - zt, yb - yt)
  h = 0.95
  printf "\n[node name=\"Rail\" type=\"CSGCombiner3D\" parent=\"%s\"]\n", parent
  g = kid(parent, "Rail")
  pbox2(g, "Handrail", x, (yt + yb) / 2 + h, (zt + zb) / 2,
        0.055, 0.055, L0 + 0.10, "Mat_iron", phi)
  n = int(L0 / 1.15)
  if (n < 2) n = 2
  for (i = 0; i <= n; i++) {
    t = i / n
    py = yb + (yt - yb) * t
    pz = zb + (zt - zb) * t
    cyl(g, "Standard", x, py + h / 2, pz, 0.026, h, "Mat_iron", 0, 6)
  }
}


## One BoxShape3D per ramp this file emitted, sized from what it recorded.
## Printed after the nodes and split out by gen_steps.sh, so the collider and
## the flight come from a single pass.
function emit_ramp_shapes(   r) {
  for (r in RAMPW) {
    printf "; The walking surface. The treads themselves carry no collision.\n"
    printf "[sub_resource type=\"BoxShape3D\" id=\"Box_%s\"]\n", r
    printf "size = Vector3(%.4f, 3, %.4f)\n\n", RAMPW[r], RAMPL[r]
  }
}


## A child node path. Godot writes a scene-root child as "Name", not "./Name",
## and a path with the dot in it is not resolved on load -- the node simply
## does not appear.
function kid(parent, name) {
  return (parent == "." ? name : parent "/" name)
}


## An axis-aligned box. Named apart from lib.awk's box() only because these
## scenes have no yaw anywhere in them and the extra argument was noise.
function sbox2(parent, name, x, y, z, sx, sy, sz, mat) {
  box(parent, name, x, y, z, sx, sy, sz, mat, 0)
}


## A pitched box, for anything that follows the rake.
function pbox2(parent, name, x, y, z, sx, sy, sz, mat, phi) {
  N++
  printf "\n[node name=\"%s_%d\" type=\"CSGBox3D\" parent=\"%s\"]\n", name, N, parent
  printf "transform = %s\n", Tpitch(x, y, z, phi)
  if (mat != "") printf "material = ExtResource(\"%s\")\n", mat
  printf "size = Vector3(%.4f, %.4f, %.4f)\n", sx, sy, sz
}
