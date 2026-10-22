# One leaf of the estate gate, as wrought ironwork.
#
# Emitted into Scenes/gate_leaf.tscn by gen_gate.sh. Requires lib.awk and
# items.awk -- it borrows ibox/icyl/iring and the TR() transform builder from
# there, because a gate needs the same two-axis rotations an item does.
#
# The leaf is built in HINGE SPACE: x runs 0 (the hanging stile, where it
# pivots) to W (the meeting stile, where the two leaves come together), y runs
# 0 at the ground to the top of the arch. Gate.tscn parents it so that lines
# up with where the old flat slab hung, so the gate still fits its piers.
#
# It stays a CSGCombiner3D rather than being baked. A combiner is ONE draw
# call no matter how many brushes are in it, the whole thing is evaluated once
# at load, and there are only two of them in the level -- so there is nothing
# to gain from putting it through the bake pipeline, and it stays readable.

function GW()    { return 8.05 }   # leaf width, hinge to meeting stile
function GEAVE() { return 4.85 }   # top of the arch at the hanging stile
function GRISE() { return 0.56 }   # how much higher the arch is at the middle
function GTH()   { return 0.05 }   # bar thickness
function GRAIL() { return 0.12 }   # rails are deeper, so they read as a frame

## Height of the top of the arch at x. Quadratic rather than circular: it
## keeps the rail flat where it meets the pier and lifts it towards the centre
## of the carriageway, which is the way an estate gate is actually shaped.
function arch(x) { return GEAVE() + GRISE() * (x / GW()) * (x / GW()) }

## Slope of that arch in degrees, for laying a rail segment along it.
function archslope(x,   d) {
  d = 2.0 * GRISE() * x / (GW() * GW())
  return atan2(d, 1.0) * 180.0 / PI()
}

function g_leaf(   i, n, x, x0, x1, step, y, h, seg, m, top) {
  # ---- frame ----
  # Hanging stile is heavier than the meeting stile: it carries the weight.
  ibox("StileHang", 0.09, arch(0.09) / 2, 0, 0.18, arch(0.09), 0.16, "Mat_iron", 0, 0, 0, "")
  ibox("StileMeet", GW() - 0.07, arch(GW()) / 2, 0, 0.14, arch(GW()), 0.14, "Mat_iron", 0, 0, 0, "")

  # Three horizontal rails. The bottom pair box in the close-spaced dog bars
  # that stop a dog -- or a person -- slipping through at the foot of a gate.
  ibox("RailFoot", GW() / 2, 0.11, 0, GW(), 0.22, GRAIL(), "Mat_iron", 0, 0, 0, "")
  ibox("RailDog", GW() / 2, 1.16, 0, GW(), 0.16, GRAIL(), "Mat_iron", 0, 0, 0, "")
  ibox("RailMid", GW() / 2, 2.92, 0, GW(), 0.18, GRAIL(), "Mat_iron", 0, 0, 0, "")

  # ---- the arched head rail, as segments along the curve ----
  n = 22
  for (i = 0; i < n; i++) {
    x0 = GW() * i / n
    x1 = GW() * (i + 1) / n
    x = (x0 + x1) / 2
    seg = (x1 - x0) / cos(rad(archslope(x)))
    ibox("RailHead", x, arch(x) - 0.09, 0, seg * 1.08, 0.18, GRAIL(),
         "Mat_iron", 0, 0, archslope(x), "")
  }

  # ---- pickets ----
  # Every bar runs from the foot rail to the arch. Where it crosses a rail the
  # two simply interpenetrate; this is one combiner, so the union cleans that
  # up and there is no coplanar face anywhere to fight.
  n = 19
  for (i = 1; i < n; i++) {
    x = GW() * i / n
    top = arch(x) - 0.18
    ibox("Picket", x, (0.22 + top) / 2, 0, GTH(), top - 0.22, GTH(), "Mat_iron", 0, 0, 0, "")

    # spear head, on every bar, standing above the head rail
    y = arch(x) + 0.10
    ibox("SpearCollar", x, arch(x) + 0.01, 0, GTH() * 1.9, 0.05, GTH() * 1.9, "Mat_iron", 0, 0, 0, "")
    icyl("SpearBlade", x, y + 0.11, 0, GTH() * 1.15, 0.30, "Mat_iron", 4, 0, 45, 0, "")
    icyl("SpearTip", x, y + 0.30, 0, GTH() * 0.30, 0.10, "Mat_gild", 4, 0, 45, 0, "")
  }

  # ---- dog bars: halve the spacing below the dog rail ----
  for (i = 1; i < n * 2; i++) {
    if (i % 2 == 0) continue        # already a full picket there
    x = GW() * i / (n * 2)
    ibox("DogBar", x, 0.69, 0, GTH() * 0.8, 0.94, GTH() * 0.8, "Mat_iron", 0, 0, 0, "")
  }

  # ---- scrollwork in the head panel ----
  # A run of quatrefoil rings between the middle rail and the arch. Rings,
  # not scrolls: a ring is one subtraction and reads as ironwork at fifty
  # metres, where a hand-drawn scroll would be six boxes and read as noise.
  n = 9
  for (i = 0; i < n; i++) {
    x = GW() * (i + 0.5) / n
    y = (2.92 + arch(x) - 0.18) / 2
    h = arch(x) - 0.18 - 2.92
    if (h < 1.2) continue
    m = (h * 0.30 < 0.40 ? h * 0.30 : 0.40)
    iring("Scroll", x, y, 0, m, m - GTH() * 0.8, GTH() * 0.9, "Mat_iron", 16)
  }

  # ---- meeting edge ----
  # Half a medallion on the closing stile. Shut, the two leaves make a whole
  # one; open, each takes half of it with them, which is the detail that says
  # these are a pair rather than two gates that happen to be next to each
  # other.
  iring("Medallion", GW() - 0.02, 2.92, 0, 0.62, 0.50, GTH() * 1.4, "Mat_gild", 24)
  ibox("MedallionCut", GW() + 0.62, 2.92, 0, 1.24, 1.40, 0.4, "Mat_iron", 0, 0, 0, "sub")
  for (i = 0; i < 4; i++)
    ibox("MedallionSpoke", GW() - 0.02, 2.92, 0, 1.18, GTH() * 0.7, GTH() * 1.2,
         "Mat_iron", 0, 0, 45 + i * 45, "")
  ibox("MedallionSpokeCut", GW() + 0.62, 2.92, 0, 1.24, 1.60, 0.4, "Mat_iron", 0, 0, 0, "sub")
}
