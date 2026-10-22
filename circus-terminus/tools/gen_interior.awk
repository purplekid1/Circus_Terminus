# Interior dressing: architectural trim, furniture and light fittings.
#
# Requires lib.awk and builtins.awk
#   awk -f lib.awk -f builtins.awk -f gen_interior.awk
# Repeated furniture is NOT built here: it is instanced from Scenes/props/,
# which gen_props.sh bakes out of props.awk.
#
# Room bounds are INTERIOR WALL FACES, taken from gen_shell.sh:
#   hall      x  -6.85.. 6.85  z -21.85.. -0.20   well x -2.5..2.5, z -4..-16
#   living    x   7.15..16.80  z -10.85.. -0.20
#   dining    x   7.15..16.80  z -21.85..-11.15
#   library   x -16.80..-7.15  z -10.85.. -0.20
#   kitchen   x -16.80..-7.15  z -21.85..-11.15
#   corridor  x -16.80..16.80  z -25.85..-22.15
#   scullery  x -16.80..-2.15  z -33.80..-26.15
#   bootroom  x  -1.85..16.80  z -33.80..-26.15   cellar well x 9.8..14.2, z -26.8..-33.2
#   landing / bed1 / office / bed2 / nursery mirror the floor below, +3.6
#   study     x  -6.85.. 6.85  z -29.85..-22.15
# Ground floor 0.0..3.4, upper 3.6..7.0, basement -3.6..-0.2.
#
# Three groups per room: built-in carcassing with collision, a dressing group
# without it, and a plain node holding instanced prop scenes. Rugs and clutter
# must not collide -- a 2cm rug lip would stop the player at the edge of every
# carpet in the house, because CharacterBody3D has no step-up. The ramps under
# the stairs exist for the same reason.

function GF() { return 0.0 }
function UF() { return 3.6 }
function BS() { return -3.6 }
function GCEIL() { return 3.4 }
function UCEIL() { return 7.0 }
function BCEIL() { return -0.2 }

# ---------------------------------------------------------------- trim ----

## Somewhere a wall is punched through, registered so trim can break around it.
## `axis` is whichever coordinate is CONSTANT along the wall -- "z" for a wall
## running east-west, "x" for one running north-south -- `at` its value, and
## lo..hi the hole's extent along the run. Widen past the opening itself to
## leave room for the architrave.
function opening(axis, at, lo, hi, lvl) {
  NOP++; OPAX[NOP] = axis; OPAT[NOP] = at; OPLO[NOP] = lo; OPHI[NOP] = hi; OPLV[NOP] = lvl
}

## Fills SEGA/SEGB with what is left of [a,b] once every opening on this wall is
## taken out, and returns the count. Without this the dado runs straight across
## every doorway in the house and you look into the next room over a solid
## panelled wall.
function wallsegs(side, a, b, at, lvl,   axis, i, n, j, tl, th, cur) {
  axis = sidevert(side) ? "z" : "x"
  n = 0
  for (i = 1; i <= NOP; i++) {
    if (OPAX[i] != axis) continue
    if (abs(OPAT[i] - at) > 0.45) continue      # wall centreline vs inner face
    if (abs(OPLV[i] - lvl) > 0.5) continue      # same storey only
    if (OPHI[i] <= a || OPLO[i] >= b) continue
    n++; SLO[n] = OPLO[i]; SHI[n] = OPHI[i]
  }
  for (i = 2; i <= n; i++) {                    # insertion sort by start
    tl = SLO[i]; th = SHI[i]; j = i - 1
    while (j >= 1 && SLO[j] > tl) { SLO[j + 1] = SLO[j]; SHI[j + 1] = SHI[j]; j-- }
    SLO[j + 1] = tl; SHI[j + 1] = th
  }
  NSEG = 0; cur = a
  for (i = 1; i <= n; i++) {
    if (SLO[i] > cur + 0.08) { NSEG++; SEGA[NSEG] = cur; SEGB[NSEG] = SLO[i] }
    if (SHI[i] > cur) cur = SHI[i]
  }
  if (b > cur + 0.08) { NSEG++; SEGA[NSEG] = cur; SEGB[NSEG] = b }
  return NSEG
}

## Yaw for trim on a given wall of a room, facing into the room. `side` names
## WHICH WALL it is, not which way it points -- the previous version took the
## facing direction and every north/south run in the house was labelled the
## wrong way round, which buried the skirting and the wainscot inside the wall.
##   N  wall at the low-z end of the room, trim faces +z
##   S  wall at the high-z end,            trim faces -z
##   W  wall at the low-x end,             trim faces +x
##   E  wall at the high-x end,            trim faces -x
function sideyaw(side) {
  return (side == "N") ? 0 : (side == "S") ? 180 : (side == "W") ? 90 : -90
}

function sidevert(side) { return (side == "N" || side == "S") }

## Skirting, chair rail, picture rail and cornice along one wall run.
## `at` is the wall's inner face, a..b the run along it, `lvl` the floor height.
##
## Cornice and picture rail run the full length: they sit above every door head,
## so nothing can be in their way. Only the low band has to dodge openings.
function wallrun(g, side, a, b, at, lvl, ceil, wains,   mid, len, xx, zz, yaw, k, ns) {
  mid = (a + b) / 2; len = b - a
  if (sidevert(side)) { xx = mid; zz = at } else { xx = at; zz = mid }
  yaw = sideyaw(side)
  open_prop(g, xx, lvl, zz, yaw)
  # cornice: the single cheapest thing that stops a room reading as a box
  pbox("Cornice", 0, ceil - lvl - 0.09, 0.055, len, 0.18, 0.11, "Mat_trim")
  pbox("CorniceBed", 0, ceil - lvl - 0.20, 0.025, len, 0.05, 0.05, "Mat_trim")
  if (!wains)
    pbox("PictureRail", 0, ceil - lvl - 0.65, 0.022, len, 0.05, 0.04, "Mat_trim")

  ns = wallsegs(side, a, b, at, lvl)
  for (k = 1; k <= ns; k++)
    lowtrim(g, side, SEGA[k], SEGB[k], at, lvl, wains)
}

## The band below the door head, emitted one unbroken stretch at a time.
## The chair rail sits at 0.82..0.90 so it lines up with the window sills
## rather than crossing the glazing.
function lowtrim(g, side, a, b, at, lvl, wains,   mid, len, xx, zz, yaw, i, n) {
  len = b - a
  if (len < 0.10) return
  mid = (a + b) / 2
  if (sidevert(side)) { xx = mid; zz = at } else { xx = at; zz = mid }
  yaw = sideyaw(side)
  open_prop(g, xx, lvl, zz, yaw)
  pbox("Skirt", 0, 0.09, 0.025, len, 0.18, 0.05, "Mat_trim")
  pbox("SkirtCap", 0, 0.19, 0.020, len, 0.03, 0.04, "Mat_trim")
  if (!wains) return
  pbox("ChairRail", 0, 0.86, 0.030, len, 0.08, 0.06, "Mat_trim")
  pbox("WainField", 0, 0.505, 0.012, len, 0.63, 0.024, "Mat_wainscot")
  n = int(len / 1.35); if (n < 1) n = 1
  for (i = 0; i <= n; i++)
    pbox("WainStile", -len / 2 + len * i / n, 0.505, 0.022, 0.10, 0.63, 0.03, "Mat_trim")
}

## Casing round a doorway: the reveal lining, and a moulded surround on one or
## both faces of the wall.
##
## `x, y, z` is the CENTRELINE of the wall, not either of its faces. `axis` is
## the wall's normal. `faces` picks which sides get a surround:
##
##   "both"   an internal doorway
##   "plus"   the +axis side only
##   "minus"  the -axis side only -- an external door whose outside is already
##            cased by something in gen_exterior.sh
##   "none"   lining only
##
## THERE MUST ONLY EVER BE ONE DOOR CASE PER OPENING. A second set was once
## added from builtins.awk in its own combiner, and every doorway in the house
## carried two interpenetrating architraves 20cm apart. Two solids from
## different combiners with faces on the same plane is a z-fight, and the front
## and back doors shimmered. tools/check_zfight.awk exists to catch that, and
## `build.sh` runs it.
function doorcase(g, x, y, z, axis, ow, oh, thick, faces,   d, yaw, s, w, h, lin) {
  if (faces == "") faces = "both"
  w = ow + 0.10
  h = oh + 0.05

  # The lining stops 3mm shy of each wall face. Run flush and its end cap
  # lands on exactly the plane of the plaster, facing the same way -- which
  # is the z-fight this whole comment block is about.
  lin = thick - 0.006

  yaw = (axis == "z") ? 0 : 90
  open_prop(g, x, y, z, yaw)
  pbox("CaseLining", -ow / 2 + 0.015, oh / 2, 0, 0.03, oh, lin, "Mat_trim")
  pbox("CaseLining",  ow / 2 - 0.015, oh / 2, 0, 0.03, oh, lin, "Mat_trim")
  pbox("CaseSoffit", 0, oh - 0.015, 0, ow - 0.06, 0.03, lin, "Mat_trim")

  for (s = -1; s <= 1; s += 2) {
    if (faces == "none") break
    if (s > 0 && faces == "minus") continue
    if (s < 0 && faces == "plus") continue

    d = thick / 2 * s
    yaw = (axis == "z") ? (s > 0 ? 0 : 180) : (s > 0 ? 90 : -90)
    if (axis == "z") open_prop(g, x, y, z + d, yaw)
    else             open_prop(g, x + d, y, z, yaw)
    pbox("CaseJamb", -w / 2 - 0.06, h / 2, 0.025, 0.12, h + 0.12, 0.05, "Mat_trim")
    pbox("CaseJamb",  w / 2 + 0.06, h / 2, 0.025, 0.12, h + 0.12, 0.05, "Mat_trim")
    pbox("CaseHead", 0, h + 0.06, 0.030, w + 0.24, 0.12, 0.06, "Mat_trim")
    pbox("CaseCap", 0, h + 0.15, 0.040, w + 0.36, 0.06, 0.08, "Mat_trim")
    # Plinth blocks, deeper than the skirting that dies into them. The Shell's
    # own skirting boards stand 0.11 off the wall, so a 0.05 block would be
    # swallowed whole and the skirting would run into the side of the jamb.
    pbox("CasePlinth", -w / 2 - 0.06, 0.13, 0.065, 0.17, 0.26, 0.13, "Mat_trim")
    pbox("CasePlinth",  w / 2 + 0.06, 0.13, 0.065, 0.17, 0.26, 0.13, "Mat_trim")
  }
}

## Interior lining, sill and architrave for a window opening, plus curtains.
## `axis` is the wall normal; `inw` is +1 if the room lies on the +axis side.
function windowcase(g, x, y, z, axis, inw, curtains,   yaw, w, h, xx, zz) {
  w = 1.6; h = 2.0
  yaw = (axis == "z") ? (inw > 0 ? 0 : 180) : (inw > 0 ? 90 : -90)
  xx = x; zz = z
  if (axis == "z") zz = z + 0.22 * inw; else xx = x + 0.22 * inw
  open_prop(g, xx, y, zz, yaw)
  pbox("WinSillIn", 0, -h / 2 - 0.04, 0.06, w + 0.34, 0.08, 0.22, "Mat_trim")
  pbox("WinApron", 0, -h / 2 - 0.16, 0.02, w + 0.18, 0.16, 0.05, "Mat_trim")
  pbox("WinArch", -w / 2 - 0.07, 0, 0.02, 0.14, h + 0.14, 0.05, "Mat_trim")
  pbox("WinArch",  w / 2 + 0.07, 0, 0.02, 0.14, h + 0.14, 0.05, "Mat_trim")
  pbox("WinArch", 0, h / 2 + 0.07, 0.02, w + 0.42, 0.14, 0.05, "Mat_trim")

  # Curtains go in their own node, NOT into `g`. `g` is the Trim combiner, and
  # p_curtains opens a group() -- a CSGCombiner3D inside a CSGCombiner3D is
  # just a brush, so the curtains were folded into the trim and could not be
  # moved or hidden on their own, which is the whole reason group() exists.
  #
  # The drop is 0.16 over the opening rather than 0.30. At 0.30 the pelmet
  # reached y 3.31 in a room whose cornice starts at 3.22, so every curtain in
  # the house had its pelmet buried in the cornice above it.
  if (curtains) p_curtains(CUR, xx, y - h / 2 - 0.10, zz, yaw, w + 0.2, h + 0.16)
}

## Rough ceiling joists. Service rooms and the basement only -- the principal
## rooms are plastered, and the contrast between the two is half the point.
## `inset` keeps the joist ends short of the cornice; run full-width and the
## ends poke through it, which reads as a mistake rather than as structure.
function joists(g, x0, x1, z0, z1, ceil, along_x,   i, n, p, inset) {
  inset = 0.26
  if (along_x) {
    n = int((z1 - z0) / 1.15)
    for (i = 1; i < n; i++) {
      p = z0 + (z1 - z0) * i / n
      box(g, "Joist", (x0 + x1) / 2, ceil - 0.13, p, x1 - x0 - inset * 2, 0.26, 0.16, "Mat_wood", 0)
    }
  } else {
    n = int((x1 - x0) / 1.15)
    for (i = 1; i < n; i++) {
      p = x0 + (x1 - x0) * i / n
      box(g, "Joist", p, ceil - 0.13, (z0 + z1) / 2, 0.16, 0.26, z1 - z0 - inset * 2, "Mat_wood", 0)
    }
  }
}

function ceilrose(g, x, z, ceil) {
  cyl(g, "CeilRose", x, ceil - 0.05, z, 0.46, 0.10, "Mat_trim", 0, 16)
  cyl(g, "CeilRose", x, ceil - 0.13, z, 0.30, 0.08, "Mat_trim", 0, 16)
}

# --------------------------------------------------------------- lights ----

function omni(name, x, y, z, energy, range, col, flick) {
  printf "\n[node name=\"%s\" type=\"OmniLight3D\" parent=\"Lights\"]\n", name
  printf "transform = %s\n", T(x, y, z)
  if (flick) printf "script = ExtResource(\"17_flick\")\n"
  printf "light_color = Color(%s)\n", col
  printf "light_energy = %.2f\n", energy
  printf "shadow_enabled = true\n"
  printf "shadow_bias = 0.06\n"
  printf "omni_range = %.1f\n", range
  if (flick) printf "base_energy = %.2f\n", energy
}

function WARM() { return "1, 0.84, 0.64, 1" }
function COLD() { return "0.74, 0.82, 1, 1" }

# ================================================================= MAIN ====

BEGIN {
  node3d("Interior", ".")
  G = "Interior"

  combiner("Trim", G, 0)
  TR = "Interior/Trim"

  # Curtains are dressing, not architecture: a plain node so each set is its
  # own combiner and its own baked mesh. See windowcase().
  node3d("Curtains", G)
  CUR = "Interior/Curtains"

  # ------------------------------------------------------------ openings ---
  # Every hole in an interior-facing wall, so the dado and skirting break
  # around it. Half-widths are the opening plus ~0.2 for the architrave: a
  # 1.2m door reserves 1.6m of wall. Mirrors the cut table in gen_shell.sh.
  opening("z",   0.0,  -0.8,   0.8, GF())   # front door
  opening("z", -34.0,   7.2,   8.8, GF())   # back door
  opening("x",   7.0,  -5.8,  -4.2, GF())   # hall / living
  opening("x",  -7.0,  -5.8,  -4.2, GF())   # hall / library
  opening("x",   7.0, -17.8, -16.2, GF())   # hall / dining
  opening("x",  -7.0, -17.8, -16.2, GF())   # hall / kitchen
  opening("z", -22.0,  -0.8,   0.8, GF())   # hall / corridor
  opening("z", -22.0,  11.2,  12.8, GF())   # dining / corridor
  opening("z", -22.0, -12.8, -11.2, GF())   # kitchen / corridor
  opening("z", -26.0,  -9.8,  -8.2, GF())   # corridor / scullery
  opening("z", -26.0,   7.2,   8.8, GF())   # corridor / boot room
  opening("z", -22.0,  -0.8,   0.8, UF())   # landing / study
  opening("x",   7.0,  -5.8,  -4.2, UF())   # landing / bed 1
  opening("x",  -7.0,  -5.8,  -4.2, UF())   # landing / bed 2
  opening("x",   7.0, -17.8, -16.2, UF())   # landing / office
  opening("x",  -7.0, -17.8, -16.2, UF())   # landing / nursery
  # Windows only matter to the low band where the sill drops into it; the
  # chair rail is set at sill height so the two meet instead of crossing.
  opening("z",   0.0,  10.2,  11.8, GF())
  opening("z",   0.0, -11.8, -10.2, GF())
  opening("x",  17.0,  -6.8,  -5.2, GF())
  opening("x",  17.0, -17.8, -16.2, GF())
  opening("x", -17.0,  -6.8,  -5.2, GF())
  opening("x", -17.0, -17.8, -16.2, GF())


  # ---------------------------------------------------------------- trim ---
  # Principal ground-floor rooms get wainscot; service rooms get a picture rail
  # and joists instead, so the two halves of the house read differently.

  # hall
  wallrun(TR, "W", -21.85, -0.20, -6.85, GF(), GCEIL(), 1)
  wallrun(TR, "E", -21.85, -0.20,  6.85, GF(), GCEIL(), 1)
  wallrun(TR, "S",  -6.85,  6.85,  -0.20, GF(), GCEIL(), 1)
  wallrun(TR, "N",  -6.85,  6.85, -21.85, GF(), GCEIL(), 1)
  # living
  wallrun(TR, "W", -10.85, -0.20,  7.15, GF(), GCEIL(), 0)
  wallrun(TR, "E", -10.85, -0.20, 16.80, GF(), GCEIL(), 0)
  wallrun(TR, "S",   7.15, 16.80,  -0.20, GF(), GCEIL(), 0)
  wallrun(TR, "N",   7.15, 16.80, -10.85, GF(), GCEIL(), 0)
  # dining
  wallrun(TR, "W", -21.85, -11.15,  7.15, GF(), GCEIL(), 1)
  wallrun(TR, "E", -21.85, -11.15, 16.80, GF(), GCEIL(), 1)
  wallrun(TR, "S",   7.15, 16.80, -11.15, GF(), GCEIL(), 1)
  wallrun(TR, "N",   7.15, 16.80, -21.85, GF(), GCEIL(), 1)
  # library
  wallrun(TR, "W", -10.85, -0.20, -16.80, GF(), GCEIL(), 1)
  wallrun(TR, "E", -10.85, -0.20,  -7.15, GF(), GCEIL(), 1)
  wallrun(TR, "S", -16.80, -7.15,  -0.20, GF(), GCEIL(), 1)
  wallrun(TR, "N", -16.80, -7.15, -10.85, GF(), GCEIL(), 1)
  # kitchen + corridor + service: picture rail only
  wallrun(TR, "W", -21.85, -11.15, -16.80, GF(), GCEIL(), 0)
  wallrun(TR, "E", -21.85, -11.15,  -7.15, GF(), GCEIL(), 0)
  wallrun(TR, "S", -16.80, -7.15, -11.15, GF(), GCEIL(), 0)
  wallrun(TR, "N", -16.80, -7.15, -21.85, GF(), GCEIL(), 0)
  wallrun(TR, "S", -16.80, 16.80, -22.15, GF(), GCEIL(), 0)
  wallrun(TR, "N", -16.80, 16.80, -25.85, GF(), GCEIL(), 0)

  # upper floor
  wallrun(TR, "W", -21.85, -0.20, -6.85, UF(), UCEIL(), 0)
  wallrun(TR, "E", -21.85, -0.20,  6.85, UF(), UCEIL(), 0)
  wallrun(TR, "S",  -6.85,  6.85,  -0.20, UF(), UCEIL(), 0)
  wallrun(TR, "W", -10.85, -0.20,  7.15, UF(), UCEIL(), 0)
  wallrun(TR, "E", -10.85, -0.20, 16.80, UF(), UCEIL(), 0)
  wallrun(TR, "S",   7.15, 16.80,  -0.20, UF(), UCEIL(), 0)
  wallrun(TR, "N",   7.15, 16.80, -10.85, UF(), UCEIL(), 0)
  wallrun(TR, "W", -21.85, -11.15,  7.15, UF(), UCEIL(), 0)
  wallrun(TR, "E", -21.85, -11.15, 16.80, UF(), UCEIL(), 0)
  wallrun(TR, "W", -10.85, -0.20, -16.80, UF(), UCEIL(), 0)
  wallrun(TR, "E", -10.85, -0.20,  -7.15, UF(), UCEIL(), 0)
  wallrun(TR, "S", -16.80, -7.15,  -0.20, UF(), UCEIL(), 0)
  wallrun(TR, "N", -16.80, -7.15, -10.85, UF(), UCEIL(), 0)
  wallrun(TR, "W", -21.85, -11.15, -16.80, UF(), UCEIL(), 0)
  wallrun(TR, "E", -21.85, -11.15,  -7.15, UF(), UCEIL(), 0)
  # study -- the room the whole demo points at, so it gets the full treatment
  wallrun(TR, "W", -29.85, -22.15, -6.85, UF(), UCEIL(), 1)
  wallrun(TR, "E", -29.85, -22.15,  6.85, UF(), UCEIL(), 1)
  wallrun(TR, "S",  -6.85,  6.85, -22.15, UF(), UCEIL(), 1)
  wallrun(TR, "N",  -6.85,  6.85, -29.85, UF(), UCEIL(), 1)

  # ---- door casings ----
  # The position is the wall CENTRELINE and the last number is the wall's full
  # thickness, both straight off the `u` table in gen_shell.sh. Internal
  # partitions are 0.3; the front and back walls are a pair of 0.2 skins
  # either side of the centreline and so are 0.4 through.
  #
  # The front door was cased at -0.20, which is the inner FACE of a wall
  # centred on 0 -- so its surround came out 0.2 adrift, one copy stranded
  # inside the siding and the other floating 0.2 proud into the hall.
  #
  # "minus" on the front door: gen_exterior.sh already builds a porch surround
  # out there, 2.3m wide and 0.5 deep, and a second architrave inside that one
  # interpenetrated its head.
  doorcase(TR,   0, GF(),   0.00, "z", 1.2, 2.15, 0.4, "minus")   # front door
  doorcase(TR,   8, GF(), -34.00, "z", 1.2, 2.15, 0.4, "both")    # back door
  doorcase(TR,   7, GF(),  -5.00, "x", 1.2, 2.15, 0.3, "both")
  doorcase(TR,  -7, GF(),  -5.00, "x", 1.2, 2.15, 0.3, "both")
  doorcase(TR,   7, GF(), -17.00, "x", 1.2, 2.15, 0.3, "both")
  doorcase(TR,  -7, GF(), -17.00, "x", 1.2, 2.15, 0.3, "both")
  doorcase(TR,   0, GF(), -22.00, "z", 1.2, 2.15, 0.3, "both")
  doorcase(TR,  12, GF(), -22.00, "z", 1.2, 2.15, 0.3, "both")
  doorcase(TR, -12, GF(), -22.00, "z", 1.2, 2.15, 0.3, "both")
  doorcase(TR,  -9, GF(), -26.00, "z", 1.2, 2.15, 0.3, "both")
  doorcase(TR,   8, GF(), -26.00, "z", 1.2, 2.15, 0.3, "both")
  doorcase(TR,   0, UF(), -22.00, "z", 1.2, 2.15, 0.3, "both")
  doorcase(TR,   7, UF(),  -5.00, "x", 1.2, 2.15, 0.3, "both")
  doorcase(TR,  -7, UF(),  -5.00, "x", 1.2, 2.15, 0.3, "both")
  doorcase(TR,   7, UF(), -17.00, "x", 1.2, 2.15, 0.3, "both")
  doorcase(TR,  -7, UF(), -17.00, "x", 1.2, 2.15, 0.3, "both")

  # window linings. Ground-floor principal rooms get curtains; service rooms
  # and the upper floor are bare, which reads as stripped rather than unfinished.
  windowcase(TR,  11, 1.9,   0.0, "z", -1, 1)
  windowcase(TR, -11, 1.9,   0.0, "z", -1, 1)
  windowcase(TR,  11, 5.5,   0.0, "z", -1, 0)
  windowcase(TR, -11, 5.5,   0.0, "z", -1, 0)
  windowcase(TR,  17, 1.9,  -6.0, "x", -1, 1)
  windowcase(TR,  17, 1.9, -17.0, "x", -1, 1)
  windowcase(TR,  17, 5.5,  -6.0, "x", -1, 0)
  windowcase(TR,  17, 5.5, -17.0, "x", -1, 0)
  windowcase(TR, -17, 1.9,  -6.0, "x",  1, 1)
  windowcase(TR, -17, 1.9, -17.0, "x",  1, 0)
  windowcase(TR, -17, 5.5,  -6.0, "x",  1, 0)
  windowcase(TR, -17, 5.5, -17.0, "x",  1, 0)
  windowcase(TR,  -8, 5.5, -34.0, "z",  1, 0)
  windowcase(TR,   2, 5.5, -34.0, "z",  1, 0)

  # exposed joists over the service wing and the cellar
  joists(TR, -16.80,  -7.15, -21.85, -11.15, GCEIL(), 1)
  joists(TR, -16.80,  -2.15, -33.80, -26.15, GCEIL(), 1)
  joists(TR,  -1.85,   9.60, -33.80, -26.15, GCEIL(), 1)
  joists(TR, -16.60,  -0.40, -21.60,  -0.40, BCEIL(), 1)
  joists(TR,   0.40,  16.60, -21.60,  -0.40, BCEIL(), 1)
  # The rear cellar run stops either side of the stair well (x 9.8..14.2): a
  # joist across it lands at head height halfway up the flight.
  joists(TR, -16.60,   9.50, -33.60, -22.40, BCEIL(), 1)
  joists(TR,  14.55,  16.60, -33.60, -22.40, BCEIL(), 1)
  joists(TR,  14.40,  16.60, -33.80, -26.15, GCEIL(), 1)

  ceilrose(TR,   0, -18.0, GCEIL())
  ceilrose(TR,  12,  -5.4, GCEIL())
  ceilrose(TR,  12, -16.5, GCEIL())
  ceilrose(TR, -11.8, -5.6, GCEIL())
  ceilrose(TR,   0, -26.0, UCEIL())

  # ---------------------------------------------------------------- rooms ---
  # Three groups per room:
  #   <Room>       built-in carcassing, collision on  (counters, chimney breasts)
  #   <Room>Dress  rugs, pictures, curtains -- no collision, because a 2cm rug
  #                lip with no step-up stops the player at every carpet
  #   <Room>Props  instances of the prop scenes. NOT the Dress combiner: an
  #                instance parented to a CSG node gets folded into it, and the
  #                bake step then swallows it whole.
  #
  # Furniture sizes come from the prop catalogue, not from this file. Where the
  # old free-size version wanted a 3.6m bookcase it now gets the 3.2m one.

  # ================================================================ HALL ===
  node3d("Hall", G);      H  = "Interior/Hall"
  node3d("HallDress", G); HD = "Interior/HallDress"
  node3d("HallProps", G);      HP = "Interior/HallProps"

  # entrance: a console each side of the door, facing each other
  inst(HP, "Console", "pf_table_console", -5.60, GF(), -1.50, 90)
  inst(HP, "Console", "pf_table_console",  5.60, GF(), -1.50, -90)
  p_picture(HD, -6.80, 1.85, -1.50, 90, 0.80, 1.10, "Mat_mirror")
  p_picture(HD,  6.80, 1.85, -1.50, -90, 0.80, 1.10, "Mat_canvas")
  inst(HP, "Candlestick", "pf_candlestick_tall", -5.60, GF() + TOP_console(), -1.50, 0)
  inst(HP, "OilLamp", "pf_oillamp", 5.60, GF() + TOP_console(), -1.50, 0)
  inst(HP, "BookStack", "pf_bookstack", -5.25, GF() + TOP_console(), -1.78, 12)
  p_rug(HD, 0, GF(), -1.90, 0, 3.0, 2.2)

  # side aisles past the stairs
  inst(HP, "HallChair", "pf_chair", -6.10, GF(), -8.40, 90)
  inst(HP, "HallChair", "pf_chair", -6.10, GF(), -12.60, 90)
  inst(HP, "Bust", "pf_bust", 6.10, GF(), -8.40, 0)
  inst(HP, "Pedestal", "pf_pedestal", 6.10, GF(), -12.60, 0)
  p_picture(HD, -6.80, 2.05, -8.40, 90, 1.10, 1.45, "Mat_canvas")
  p_picture(HD, -6.80, 2.05, -12.60, 90, 1.10, 1.45, "Mat_canvas")
  p_picture(HD,  6.80, 2.05, -10.50, -90, 1.30, 1.70, "Mat_canvas")
  inst(HP, "Sconce", "pf_sconce", -6.78, 2.05, -5.60, 90)
  inst(HP, "Sconce", "pf_sconce", -6.78, 2.05, -15.40, 90)
  inst(HP, "Sconce", "pf_sconce",  6.78, 2.05, -5.60, -90)
  inst(HP, "Sconce", "pf_sconce",  6.78, 2.05, -15.40, -90)

  # behind the stairs
  inst(HP, "Bookcase", "pf_bookcase_low", 5.20, GF(), -21.60, 0)
  inst(HP, "HallTable", "pf_table_console", -4.40, GF(), -21.60, 0)
  p_papers(HD, -4.40, GF() + TOP_console(), -21.60, 12, 0.34)
  inst(HP, "BookStack", "pf_bookstack", -3.85, GF() + TOP_console(), -21.65, -8)
  p_rug(HD, 0, GF(), -19.40, 0, 5.4, 3.8)
  inst(HP, "Chandelier", "pf_chandelier6", 0, GCEIL(), -18.00, 0)
  p_sheetpile(HD, 3.20, GF(), -21.00, 20, 0.7)

  # ============================================================== LIVING ===
  node3d("Living", G);      L  = "Interior/Living"
  node3d("LivingDress", G); LD = "Interior/LivingDress"
  node3d("LivingProps", G);      LP = "Interior/LivingProps"

  # the hearth is the anchor; everything else is arranged to face it
  p_fireplace(L, 16.80, GF(), -5.40, -90, 1)
  p_picture(LD, 16.55, 2.05, -5.40, -90, 1.10, 0.90, "Mat_mirror")
  inst(LP, "Candlestick", "pf_candlestick_tall", 16.42, GF() + TOP_mantel(), -6.10, 0)
  inst(LP, "Candlestick", "pf_candlestick_tall", 16.42, GF() + TOP_mantel(), -4.70, 0)
  p_rug(LD, 12.60, GF(), -5.40, 0, 6.4, 5.6)
  inst(LP, "Sofa", "pf_sofa", 10.10, GF(), -5.40, 90)
  inst(LP, "Armchair", "pf_armchair_cloth", 13.10, GF(), -3.30, 120)
  inst(LP, "Armchair", "pf_armchair_cloth", 13.10, GF(), -7.50, 60)
  inst(LP, "LowTable", "pf_table_low", 12.70, GF(), -5.40, 0)
  p_bottle(LD, 12.50, GF() + TOP_low(), -5.30, 1)
  inst(LP, "BookStack", "pf_bookstack", 12.95, GF() + TOP_low(), -5.58, 16)

  inst(LP, "Piano", "pf_piano", 12.00, GF(), -10.40, 0)
  inst(LP, "Candlestick", "pf_candlestick", 11.30, GF() + TOP_piano(), -10.40, 0)
  inst(LP, "Sideboard", "pf_dresser", 7.55, GF(), -9.00, 90)
  p_bottle(LD, 7.58, GF() + TOP_dresser(), -8.70, 0)
  p_bottle(LD, 7.72, GF() + TOP_dresser(), -9.20, 1)
  p_sheet(L, 8.40, GF(), -2.20, 30, 1.00, 0.95, 0.95)
  inst(LP, "Pedestal", "pf_pedestal", 16.20, GF(), -9.80, 0)

  # ============================================================== DINING ===
  node3d("Dining", G);      D  = "Interior/Dining"
  node3d("DiningDress", G); DD = "Interior/DiningDress"
  node3d("DiningProps", G);      DP = "Interior/DiningProps"

  p_rug(DD, 12.00, GF(), -16.50, 0, 6.8, 5.2)
  inst(DP, "DiningTable", "pf_table_dine", 12.00, GF(), -16.50, 0)
  inst(DP, "DiningChair", "pf_chair", 10.70, GF(), -15.25, 180)
  inst(DP, "DiningChair", "pf_chair", 12.00, GF(), -15.25, 180)
  inst(DP, "DiningChair", "pf_chair", 13.30, GF(), -15.25, 180)
  inst(DP, "DiningChair", "pf_chair", 10.70, GF(), -17.75, 0)
  inst(DP, "DiningChair", "pf_chair", 12.00, GF(), -17.75, 0)
  inst(DP, "DiningChair", "pf_chair", 13.30, GF(), -17.75, 14)
  inst(DP, "DiningChair", "pf_chair",  9.95, GF(), -16.50, 90)
  inst(DP, "DiningChair", "pf_chair", 14.05, GF(), -16.50, -90)
  inst(DP, "Candlestick", "pf_candlestick_tall", 11.30, GF() + TOP_dine(), -16.50, 0)
  inst(DP, "Candlestick", "pf_candlestick_tall", 12.00, GF() + TOP_dine(), -16.50, 0)
  inst(DP, "Candlestick", "pf_candlestick_tall", 12.70, GF() + TOP_dine(), -16.50, 0)
  p_papers(DD, 13.40, GF() + TOP_dine(), -16.20, 8, 0.30)
  inst(DP, "Chandelier", "pf_chandelier6", 12.00, GCEIL(), -16.50, 0)

  inst(DP, "Bookcase", "pf_bookcase_med", 16.45, GF(), -13.20, -90)
  p_counter(D, 12.00, GF(), -21.55, 180, 3.40, 0.56)
  p_bottle(DD, 10.90, GF() + TOP_counter(), -21.55, 1)
  p_bottle(DD, 11.25, GF() + TOP_counter(), -21.45, 0)
  inst(DP, "BookStack", "pf_bookstack", 13.20, GF() + TOP_counter(), -21.55, 6)
  inst(DP, "Sideboard", "pf_dresser", 7.52, GF(), -19.60, 90)
  # z -14.5, not -16.5: at -16.5 this hung straight across the hall doorway
  # and its canvas shared a plane with the door head.
  p_picture(DD, 7.18, 2.05, -14.50, 90, 1.20, 1.55, "Mat_canvas")
  inst(DP, "Sconce", "pf_sconce", 16.78, 2.05, -19.40, -90)
  inst(DP, "Sconce", "pf_sconce", 16.78, 2.05, -13.60, -90)

  # ============================================================= LIBRARY ===
  node3d("Library", G);      B  = "Interior/Library"
  node3d("LibraryDress", G); BD = "Interior/LibraryDress"
  node3d("LibraryProps", G);      BP = "Interior/LibraryProps"

  # west wall is solid bookcase; the bureau interactable sits at x-14 z-9.8
  inst(BP, "Bookcase", "pf_bookcase_tall", -16.50, GF(), -2.30, 90)
  inst(BP, "Bookcase", "pf_bookcase_tall", -16.50, GF(), -5.70, 90)
  inst(BP, "Bookcase", "pf_bookcase_tall", -11.40, GF(), -0.55, 180)
  inst(BP, "Bookcase", "pf_bookcase_med",   -7.55, GF(), -3.00, -90)
  inst(BP, "Bookcase", "pf_bookcase_low",   -7.55, GF(), -7.60, -90)
  p_rug(BD, -12.20, GF(), -5.60, 0, 6.2, 5.6)
  inst(BP, "Desk", "pf_desk", -12.20, GF(), -5.60, 0)
  inst(BP, "DeskChair", "pf_chair", -12.20, GF(), -4.25, 180)
  inst(BP, "OilLamp", "pf_oillamp", -12.90, GF() + TOP_desk(), -5.80, 0)
  p_papers(BD, -11.90, GF() + TOP_desk(), -5.60, 22, 0.40)
  inst(BP, "BookStack", "pf_bookstack", -12.60, GF() + TOP_desk(), -5.30, -12)
  inst(BP, "Armchair", "pf_armchair", -14.90, GF(), -8.60, 40)
  inst(BP, "SideTable", "pf_table_side", -13.40, GF(), -8.90, 0)
  inst(BP, "Candlestick", "pf_candlestick", -13.40, GF() + TOP_side(), -8.90, 0)
  inst(BP, "BookStack", "pf_bookstack", -10.30, GF(), -7.90, 24)
  inst(BP, "BookStack", "pf_bookstack", -10.05, GF(), -8.35, -9)
  p_picture(BD, -11.40, 2.30, -0.42, 0, 1.30, 0.95, "Mat_canvas")
  inst(BP, "Sconce", "pf_sconce", -16.78, 2.10, -9.20, 90)
  inst(BP, "Sconce", "pf_sconce",  -7.18, 2.10, -9.20, -90)
  inst(BP, "Chandelier", "pf_chandelier5", -11.80, GCEIL(), -5.60, 0)

  # ============================================================= KITCHEN ===
  node3d("Kitchen", G);      K  = "Interior/Kitchen"
  node3d("KitchenDress", G); KD = "Interior/KitchenDress"
  node3d("KitchenProps", G);      KP = "Interior/KitchenProps"

  # the KitchenCounter interactable holds the magnifier at x-15..-9, z-19
  inst(KP, "Range", "pf_range", -16.30, GF(), -14.20, 90)
  inst(KP, "Sink", "pf_sink", -16.35, GF(), -17.60, 90)
  p_counter(K, -12.00, GF(), -11.55, 180, 5.00, 0.62)
  p_counter(K,  -7.65, GF(), -15.60, 90, 3.20, 0.60)
  inst(KP, "PrepTable", "pf_table_work", -11.60, GF(), -16.30, 0)
  inst(KP, "KitchenChair", "pf_chair", -10.25, GF(), -16.30, -90)
  inst(KP, "KitchenChair", "pf_chair", -12.95, GF(), -16.30, 90)
  inst(KP, "BookStack", "pf_bookstack", -11.20, GF() + TOP_work(), -16.30, 8)
  p_bottle(KD, -12.20, GF() + TOP_work(), -16.10, 1)
  p_bottle(KD, -12.00, GF() + TOP_work(), -16.55, 0)
  inst(KP, "Rack", "pf_rack", -8.20, GF(), -20.40, 90)
  inst(KP, "Barrel", "pf_barrel", -16.20, GF(), -21.10, 0)
  inst(KP, "Barrel", "pf_barrel", -15.30, GF(), -21.20, 0)
  inst(KP, "Crate", "pf_crate_sm", -9.20, GF(), -12.60, 18)
  inst(KP, "Sconce", "pf_sconce", -7.18, 2.10, -13.60, -90)
  inst(KP, "Sconce", "pf_sconce", -7.18, 2.10, -20.40, -90)

  # ============================================================ CORRIDOR ===
  node3d("Corridor", G);      C  = "Interior/Corridor"
  node3d("CorridorDress", G); CD = "Interior/CorridorDress"
  node3d("CorridorProps", G);      CP = "Interior/CorridorProps"

  p_rug(CD, 0, GF(), -24.00, 0, 22.0, 2.0)
  inst(CP, "HallTable", "pf_table_console", -14.60, GF(), -22.70, 180)
  inst(CP, "HallTable", "pf_table_console",  14.60, GF(), -25.35, 0)
  inst(CP, "OilLamp", "pf_oillamp", -14.60, GF() + TOP_console(), -22.70, 0)
  inst(CP, "Candlestick", "pf_candlestick", 14.60, GF() + TOP_console(), -25.35, 0)
  p_picture(CD, -4.00, 2.05, -25.72, 0, 1.20, 0.90, "Mat_canvas")
  p_picture(CD,  4.00, 2.05, -25.72, 0, 1.20, 0.90, "Mat_canvas")
  p_picture(CD, -6.50, 2.05, -22.28, 180, 1.00, 1.30, "Mat_canvas")
  inst(CP, "Sconce", "pf_sconce", -2.00, 2.10, -25.80, 0)
  inst(CP, "Sconce", "pf_sconce",  2.00, 2.10, -25.80, 0)
  inst(CP, "Sconce", "pf_sconce",  9.00, 2.10, -22.20, 180)
  p_sheetpile(CD, -16.10, GF(), -25.10, 12, 0.8)

  # ============================================================ SCULLERY ===
  node3d("Scullery", G);      S  = "Interior/Scullery"
  node3d("ScullyDress", G);   SD = "Interior/ScullyDress"
  node3d("ScullyProps", G);        SP = "Interior/ScullyProps"

  # the crowbar pickup sits at (-14, 0.92, -27.2); keep a worktop under it
  p_counter(S, -14.00, GF(), -27.20, 180, 3.20, 0.60)
  inst(SP, "Sink", "pf_sink", -16.30, GF(), -30.40, 90)
  inst(SP, "Rack", "pf_rack", -16.40, GF(), -33.20, 0)
  inst(SP, "Rack", "pf_rack", -10.60, GF(), -26.55, 180)
  inst(SP, "Rack", "pf_rack",  -2.60, GF(), -29.40, -90)
  inst(SP, "Crate", "pf_crate_lg", -5.20, GF(), -32.60, 12)
  inst(SP, "Crate", "pf_crate_sm", -6.35, GF(), -31.75, -24)
  inst(SP, "Crate", "pf_crate_sm", -4.70, GF(), -31.25, 40)
  inst(SP, "Barrel", "pf_barrel", -3.40, GF(), -33.10, 0)
  inst(SP, "Barrel", "pf_barrel", -3.40, GF(), -31.90, 0)
  p_sheetpile(SD, -12.80, GF(), -32.30, 14, 1.0)
  p_bottle(SD, -13.20, GF() + TOP_counter(), -27.20, 1)
  p_bottle(SD, -12.90, GF() + TOP_counter(), -27.10, 0)

  # ============================================================ BOOTROOM ===
  node3d("Bootroom", G);   BR  = "Interior/Bootroom"
  node3d("BootDress", G);  BRD = "Interior/BootDress"
  node3d("BootProps", G);       BRP = "Interior/BootProps"

  # the cellar stairwell occupies x 9.8..14.2, z -26.8..-33.2 -- keep it clear
  inst(BRP, "Rack", "pf_rack", 0.00, GF(), -29.00, 90)
  inst(BRP, "BootTable", "pf_table_console", 4.60, GF(), -26.60, 180)
  inst(BRP, "Crate", "pf_crate_lg", 6.40, GF(), -32.60, -14)
  inst(BRP, "Crate", "pf_crate_sm", 7.45, GF(), -31.85, 22)
  p_counter(BR, 16.45, GF(), -30.00, -90, 4.20, 0.58)
  inst(BRP, "OilLamp", "pf_oillamp", 4.60, GF() + TOP_console(), -26.60, 0)
  inst(BRP, "Sconce", "pf_sconce", 8.60, 2.10, -26.25, 180)
  p_sheetpile(BRD, 2.30, GF(), -32.80, -26, 0.9)

  # ============================================================= LANDING ===
  node3d("Landing", G);      LA  = "Interior/Landing"
  node3d("LandingDress", G); LAD = "Interior/LandingDress"
  node3d("LandingProps", G);      LAP = "Interior/LandingProps"

  # portraits already hang on the east wall at x6.78, z -7/-10/-13
  inst(LAP, "Clock", "pf_clock", -6.50, UF(), -19.20, 90)
  inst(LAP, "Console", "pf_table_console", -5.90, UF(), -3.00, 90)
  inst(LAP, "Console", "pf_table_console",  5.90, UF(), -19.60, -90)
  inst(LAP, "OilLamp", "pf_oillamp", -5.90, UF() + TOP_console(), -3.00, 0)
  inst(LAP, "Candlestick", "pf_candlestick_tall", 5.90, UF() + TOP_console(), -19.60, 0)
  inst(LAP, "Bookcase", "pf_bookcase_low", 5.20, UF(), -21.60, 0)
  p_rug(LAD, 0, UF(), -19.20, 0, 5.2, 4.0)
  p_rug(LAD, -4.60, UF(), -10.00, 0, 3.0, 11.0)
  p_rug(LAD,  4.60, UF(), -10.00, 0, 3.0, 11.0)
  inst(LAP, "Sconce", "pf_sconce", -6.78, UF() + 2.05, -6.00, 90)
  inst(LAP, "Sconce", "pf_sconce", -6.78, UF() + 2.05, -14.00, 90)
  p_sheetpile(LAD, -6.00, UF(), -21.10, 8, 0.8)

  # ================================================================ BED1 ===
  node3d("Bed1", G);      B1  = "Interior/Bed1"
  node3d("Bed1Dress", G); B1D = "Interior/Bed1Dress"
  node3d("Bed1Props", G);      B1P = "Interior/Bed1Props"

  inst(B1P, "Bed", "pf_bed_poster", 11.60, UF(), -1.55, 180)
  p_rug(B1D, 11.60, UF(), -6.80, 0, 5.6, 4.6)
  inst(B1P, "Nightstand", "pf_table_side", 10.20, UF(), -1.60, 90)
  inst(B1P, "Nightstand", "pf_table_side", 13.00, UF(), -1.60, -90)
  inst(B1P, "Candlestick", "pf_candlestick", 10.20, UF() + TOP_side(), -1.60, 0)
  inst(B1P, "OilLamp", "pf_oillamp", 13.00, UF() + TOP_side(), -1.60, 0)
  inst(B1P, "Wardrobe", "pf_wardrobe", 16.10, UF(), -8.60, -90)
  inst(B1P, "Washstand", "pf_washstand", 8.00, UF(), -8.20, 90)
  inst(B1P, "Dresser", "pf_dresser", 12.60, UF(), -10.50, 0)
  p_picture(B1D, 12.60, UF() + 1.70, -10.72, 180, 1.00, 1.30, "Mat_mirror")
  p_sheet(B1, 9.10, UF(), -10.00, -20, 0.95, 0.90, 0.90)

  # ============================================================== OFFICE ===
  node3d("Office", G);      OF  = "Interior/Office"
  node3d("OfficeDress", G); OFD = "Interior/OfficeDress"
  node3d("OfficeProps", G);      OFP = "Interior/OfficeProps"

  # the wall safe is at x14, z-20.5 -- leave that wall face clear
  inst(OFP, "Desk", "pf_desk", 11.00, UF(), -13.60, 0)
  inst(OFP, "DeskChair", "pf_chair", 11.00, UF(), -12.20, 180)
  p_rug(OFD, 11.40, UF(), -16.00, 0, 5.8, 4.8)
  inst(OFP, "OilLamp", "pf_oillamp", 10.10, UF() + TOP_desk(), -13.80, 0)
  p_papers(OFD, 11.50, UF() + TOP_desk(), -13.55, 16, 0.42)
  inst(OFP, "BookStack", "pf_bookstack", 11.90, UF() + TOP_desk(), -13.90, -7)
  inst(OFP, "Bookcase", "pf_bookcase_med", 7.55, UF(), -18.20, 90)
  inst(OFP, "Bookcase", "pf_bookcase_med", 10.90, UF(), -21.60, 0)
  inst(OFP, "Dresser", "pf_dresser", 16.35, UF(), -14.80, -90)
  inst(OFP, "Crate", "pf_crate_sm", 8.60, UF(), -20.80, 26)
  inst(OFP, "Sconce", "pf_sconce", 16.78, UF() + 2.05, -15.20, -90)

  # ================================================================ BED2 ===
  node3d("Bed2", G);      B2  = "Interior/Bed2"
  node3d("Bed2Dress", G); B2D = "Interior/Bed2Dress"
  node3d("Bed2Props", G);      B2P = "Interior/Bed2Props"

  inst(B2P, "Bed", "pf_bed_plain", -11.80, UF(), -1.55, 180)
  p_rug(B2D, -11.80, UF(), -6.80, 0, 5.4, 4.4)
  inst(B2P, "Nightstand", "pf_table_side", -13.20, UF(), -1.60, -90)
  inst(B2P, "Candlestick", "pf_candlestick", -13.20, UF() + TOP_side(), -1.60, 0)
  inst(B2P, "Wardrobe", "pf_wardrobe", -16.10, UF(), -8.40, 90)
  inst(B2P, "Dresser", "pf_dresser", -8.00, UF(), -8.60, -90)
  inst(B2P, "Washstand", "pf_washstand", -12.60, UF(), -10.45, 0)
  p_picture(B2D, -12.60, UF() + 1.70, -10.72, 180, 0.90, 1.20, "Mat_mirror")
  p_sheet(B2, -15.30, UF(), -2.40, 14, 0.95, 0.95, 0.95)
  p_sheetpile(B2D, -9.40, UF(), -4.60, 32, 0.9)

  # ============================================================= NURSERY ===
  node3d("Nursery", G);      NU  = "Interior/Nursery"
  node3d("NurseryDress", G); NUD = "Interior/NurseryDress"
  node3d("NurseryProps", G);      NUP = "Interior/NurseryProps"

  inst(NUP, "Cot", "pf_bed_small", -15.70, UF(), -14.20, 90)
  p_rug(NUD, -12.40, UF(), -17.20, 0, 5.0, 4.6)
  inst(NUP, "Bookcase", "pf_bookcase_low", -7.55, UF(), -13.60, -90)
  inst(NUP, "Crate", "pf_crate_sm", -9.80, UF(), -20.40, 8)
  inst(NUP, "Crate", "pf_crate_sm", -10.75, UF(), -20.90, -22)
  inst(NUP, "Crate", "pf_crate_sm", -9.95, UF(), -19.70, 34)
  inst(NUP, "Table", "pf_table_small", -16.20, UF(), -18.60, -90)
  inst(NUP, "Candlestick", "pf_candlestick", -16.20, UF() + TOP_small(), -18.60, 0)
  inst(NUP, "Dresser", "pf_dresser", -12.00, UF(), -11.60, 180)
  p_sheet(NU, -13.80, UF(), -21.00, -12, 0.90, 0.85, 0.85)

  # =============================================================== STUDY ===
  node3d("Study", G);      ST  = "Interior/Study"
  node3d("StudyDress", G); STD = "Interior/StudyDress"
  node3d("StudyProps", G);      STP = "Interior/StudyProps"

  # where the grimoire is found. Books on every wall, one desk, one chair,
  # and nothing else competing for attention.
  inst(STP, "Bookcase", "pf_bookcase_tall", -6.55, UF(), -24.70, 90)
  inst(STP, "Bookcase", "pf_bookcase_tall", -6.55, UF(), -28.20, 90)
  inst(STP, "Bookcase", "pf_bookcase_tall",  6.55, UF(), -24.70, -90)
  inst(STP, "Bookcase", "pf_bookcase_tall",  6.55, UF(), -28.20, -90)
  inst(STP, "Bookcase", "pf_bookcase_med",  -3.40, UF(), -29.60, 0)
  p_rug(STD, 0, UF(), -26.60, 0, 6.4, 4.8)
  inst(STP, "Desk", "pf_desk", 0, UF(), -26.80, 0)
  inst(STP, "DeskChair", "pf_chair", 0, UF(), -25.30, 180)
  inst(STP, "OilLamp", "pf_oillamp", -0.80, UF() + TOP_desk(), -27.00, 0)
  p_papers(STD, 0.30, UF() + TOP_desk(), -26.70, 10, 0.44)
  inst(STP, "BookStack", "pf_bookstack", 0.85, UF() + TOP_desk(), -27.05, 18)
  inst(STP, "Candlestick", "pf_candlestick_tall", -0.95, UF() + TOP_desk(), -26.45, 0)
  inst(STP, "Armchair", "pf_armchair", 3.60, UF(), -28.60, 300)
  inst(STP, "SideTable", "pf_table_side", 2.40, UF(), -29.30, 0)
  inst(STP, "Candlestick", "pf_candlestick", 2.40, UF() + TOP_side(), -29.30, 0)
  inst(STP, "Chandelier", "pf_chandelier4", 0, UCEIL(), -26.00, 0)
  inst(STP, "Sconce", "pf_sconce", -6.78, UF() + 2.05, -26.40, 90)
  inst(STP, "Sconce", "pf_sconce",  6.78, UF() + 2.05, -26.40, -90)

  # ============================================================ BASEMENT ===
  node3d("Cellar", G);      CE  = "Interior/Cellar"
  node3d("CellarDress", G); CED = "Interior/CellarDress"
  node3d("CellarProps", G);      CEP = "Interior/CellarProps"

  # storage, coal and the generator at (11, -3.6, -18). The fuel can is at
  # (-12, -3.6, -30), so leave the floor there clear.
  inst(CEP, "Rack", "pf_rack", -16.40, BS(), -5.00, 90)
  inst(CEP, "Rack", "pf_rack", -16.40, BS(), -9.00, 90)
  inst(CEP, "Rack", "pf_rack", -16.40, BS(), -16.00, 90)
  inst(CEP, "Rack", "pf_rack", -11.60, BS(), -0.60, 0)
  inst(CEP, "Rack", "pf_rack",   4.40, BS(), -0.60, 0)
  inst(CEP, "Rack", "pf_rack",  16.40, BS(), -6.80, -90)
  inst(CEP, "Rack", "pf_rack",   0.80, BS(), -8.00, 90)
  inst(CEP, "Rack", "pf_rack",  -0.80, BS(), -18.00, -90)
  inst(CEP, "Crate", "pf_crate_lg", -13.10, BS(), -12.00, 16)
  inst(CEP, "Crate", "pf_crate_sm", -14.30, BS(), -12.85, -28)
  inst(CEP, "Crate", "pf_crate_sm", -11.90, BS(), -12.65, 38)
  inst(CEP, "Crate", "pf_crate_lg", 5.10, BS(), -8.00, -12)
  inst(CEP, "Crate", "pf_crate_sm", 6.35, BS(), -8.75, 24)
  inst(CEP, "Crate", "pf_crate_sm", 4.75, BS(), -9.55, -36)
  inst(CEP, "Crate", "pf_crate_lg", -13.00, BS(), -25.00, 8)
  inst(CEP, "Crate", "pf_crate_lg", 7.40, BS(), -25.20, -18)
  inst(CEP, "Crate", "pf_crate_sm", 8.65, BS(), -25.80, 30)
  inst(CEP, "Barrel", "pf_barrel", -15.60, BS(), -23.00, 0)
  inst(CEP, "Barrel", "pf_barrel", -15.60, BS(), -24.20, 0)
  inst(CEP, "Barrel", "pf_barrel",  15.60, BS(), -20.00, 0)
  p_counter(CE, 16.40, BS(), -13.00, -90, 3.60, 0.56)
  p_counter(CE, -16.40, BS(), -29.00, 90, 4.20, 0.56)
  # Coal, tipped under the chute. Its own group, because Cellar is a plain
  # Node3D now: a bare CSGBox3D under it would bake to a mesh with no
  # collision and the player would walk straight through the heap.
  COAL = group(CE, "CoalHeap", 1)
  box(COAL, "Heap", 15.20, BS() + 0.42, -31.60, 3.00, 0.84, 2.40, "Mat_ash", 0)
  box(COAL, "Heap", 14.30, BS() + 0.26, -30.60, 2.00, 0.52, 1.60, "Mat_ash", 0)
  p_bottle(CED, 16.20, BS() + TOP_counter(), -12.20, 1)
  p_bottle(CED, 16.35, BS() + TOP_counter(), -13.60, 0)
  p_sheetpile(CED, -9.00, BS(), -24.60, -18, 1.0)

  # ============================================================== LIGHTS ===
  printf "\n[node name=\"Lights\" type=\"Node3D\" parent=\".\"]\n"
  printf "visible = false\n"

  omni("L_HallFront",   0, 2.55,  -1.9, 1.05, 7.5, WARM(), 0)
  omni("L_HallStair",   0, 3.00,  -9.5, 1.45, 12.0, WARM(), 1)
  omni("L_HallRear",    0, 2.55, -18.0, 1.30, 10.0, WARM(), 0)
  omni("L_Living",     12, 2.60,  -5.4, 1.25, 9.5, WARM(), 0)
  omni("L_LivingFire", 16.1, 0.85, -5.4, 0.80, 4.5, "1, 0.52, 0.22, 1", 1)
  omni("L_Dining",     12, 2.60, -16.5, 1.30, 9.5, WARM(), 0)
  omni("L_Library",   -12, 2.60,  -5.6, 1.20, 9.5, WARM(), 0)
  omni("L_Kitchen",   -12, 2.95, -16.5, 1.15, 9.5, WARM(), 1)
  omni("L_KitchenEnd",-13, 2.95, -20.8, 0.75, 6.0, WARM(), 0)
  omni("L_Corridor",   -6, 2.95, -24.0, 0.95, 8.0, WARM(), 0)
  omni("L_CorridorE",   7, 2.95, -24.0, 0.95, 8.0, WARM(), 1)
  omni("L_Scullery",   -9, 2.95, -30.0, 1.00, 8.5, WARM(), 0)
  omni("L_Bootroom",    5, 2.95, -29.5, 1.05, 8.5, WARM(), 1)
  omni("L_CellarHead", 12, 0.40, -29.0, 0.90, 6.5, WARM(), 0)

  omni("L_Landing",     0, 6.30, -18.0, 1.25, 10.0, WARM(), 0)
  omni("L_LandingMid",  0, 6.30,  -8.0, 1.10, 10.0, WARM(), 1)
  omni("L_Bed1",       12, 6.20,  -5.0, 1.10, 9.0, WARM(), 0)
  omni("L_Office",     11, 6.20, -16.0, 1.10, 9.0, WARM(), 0)
  omni("L_Bed2",      -12, 6.20,  -5.0, 1.10, 9.0, WARM(), 1)
  omni("L_Nursery",   -12, 6.20, -16.0, 1.00, 9.0, WARM(), 0)
  omni("L_Study",       0, 6.30, -26.0, 1.35, 9.5, WARM(), 0)

  omni("L_CellarW",   -11, -0.65,  -8.0, 0.80, 8.0, COLD(), 1)
  omni("L_CellarE",    10, -0.65,  -9.0, 0.80, 8.0, COLD(), 0)
  omni("L_CellarMid",   0, -0.65, -18.0, 0.75, 8.0, COLD(), 1)
  omni("L_CellarRear", -6, -0.65, -29.0, 0.80, 9.0, COLD(), 0)
  omni("L_CellarGen",  11, -2.20, -18.0, 0.60, 5.0, "1, 0.62, 0.30, 1", 1)
  omni("L_Porch",       0, 2.90,   3.0, 1.00, 8.0, WARM(), 1)
}
