# Reusable furniture geometry, baked into Scenes/props/*.tscn by gen_props.sh.
#
# Every prop is written facing -Z at the origin, because that is where an
# instanced scene's own transform puts it. The box counts are kept deliberately
# low -- what sells a silhouette at eye height in a dark house is legs, an apron
# and a back, not chamfered edges nobody will see.
#
# Nothing here is called while laying out the house: gen_interior.awk places
# instances of the baked scenes instead. Requires lib.awk.

## Four legs and an apron. The apron is what stops a table reading as a plank
## on sticks; it is the piece the eye uses to judge weight.
function p_table(parent, x, y, z, yaw, w, d, h,   lx, lz, t) {
  open_prop(parent, x, y, z, yaw)
  t = 0.06
  pbox("TableTop", 0, h - t / 2, 0, w, t, d, "Mat_walnut")
  pbox("TableApron", 0, h - t - 0.06, 0, w - 0.22, 0.10, d - 0.22, "Mat_walnut")
  lx = w / 2 - 0.10; lz = d / 2 - 0.10
  pcyl("TableLeg", -lx, (h - t) / 2, -lz, 0.045, h - t, "Mat_walnut", 8)
  pcyl("TableLeg",  lx, (h - t) / 2, -lz, 0.045, h - t, "Mat_walnut", 8)
  pcyl("TableLeg", -lx, (h - t) / 2,  lz, 0.045, h - t, "Mat_walnut", 8)
  pcyl("TableLeg",  lx, (h - t) / 2,  lz, 0.045, h - t, "Mat_walnut", 8)
}

## Dining chair. Back posts run past the seat to the floor, which is what makes
## a chair look like a chair from behind.
function p_chair(parent, x, y, z, yaw,   sh) {
  open_prop(parent, x, y, z, yaw)
  sh = 0.45
  pbox("Seat", 0, sh, 0, 0.46, 0.05, 0.44, "Mat_walnut")
  pbox("SeatPad", 0, sh + 0.045, 0, 0.40, 0.05, 0.38, "Mat_velvet")
  pbox("ChairBack", 0, sh + 0.34, -0.20, 0.40, 0.52, 0.04, "Mat_walnut")
  pcyl("ChairPost", -0.21, sh + 0.22, -0.20, 0.025, 0.96, "Mat_walnut", 8)
  pcyl("ChairPost",  0.21, sh + 0.22, -0.20, 0.025, 0.96, "Mat_walnut", 8)
  pcyl("ChairLeg", -0.20, sh / 2, 0.19, 0.025, sh, "Mat_walnut", 8)
  pcyl("ChairLeg",  0.20, sh / 2, 0.19, 0.025, sh, "Mat_walnut", 8)
}

function p_armchair(parent, x, y, z, yaw, mat,   sh) {
  if (mat == "") mat = "Mat_velvet"
  open_prop(parent, x, y, z, yaw)
  sh = 0.40
  pbox("ChairBase", 0, sh - 0.08, 0, 0.86, 0.22, 0.84, mat)
  pbox("ChairCushion", 0, sh + 0.08, 0.04, 0.70, 0.16, 0.68, mat)
  pbox("ChairBack", 0, sh + 0.40, -0.36, 0.86, 0.80, 0.18, mat)
  pbox("ChairArm", -0.37, sh + 0.20, -0.02, 0.16, 0.34, 0.80, mat)
  pbox("ChairArm",  0.37, sh + 0.20, -0.02, 0.16, 0.34, 0.80, mat)
  pcyl("ChairFoot", -0.34, 0.07, -0.32, 0.035, 0.14, "Mat_walnut", 6)
  pcyl("ChairFoot",  0.34, 0.07, -0.32, 0.035, 0.14, "Mat_walnut", 6)
  pcyl("ChairFoot", -0.34, 0.07,  0.32, 0.035, 0.14, "Mat_walnut", 6)
  pcyl("ChairFoot",  0.34, 0.07,  0.32, 0.035, 0.14, "Mat_walnut", 6)
}

function p_sofa(parent, x, y, z, yaw, w, mat,   sh, i, n, cw) {
  if (mat == "") mat = "Mat_velvet"
  open_prop(parent, x, y, z, yaw)
  sh = 0.38
  pbox("SofaBase", 0, sh - 0.09, 0, w, 0.24, 0.92, mat)
  pbox("SofaBack", 0, sh + 0.38, -0.40, w, 0.80, 0.16, mat)
  pbox("SofaArm", -w / 2 + 0.09, sh + 0.19, -0.02, 0.18, 0.36, 0.88, mat)
  pbox("SofaArm",  w / 2 - 0.09, sh + 0.19, -0.02, 0.18, 0.36, 0.88, mat)
  n = 3; cw = (w - 0.30) / n
  for (i = 0; i < n; i++)
    pbox("SofaCushion", -w / 2 + 0.15 + cw * (i + 0.5), sh + 0.09, 0.03, cw - 0.04, 0.16, 0.72, mat)
  pcyl("SofaFoot", -w / 2 + 0.14, 0.06, -0.34, 0.035, 0.12, "Mat_walnut", 6)
  pcyl("SofaFoot",  w / 2 - 0.14, 0.06, -0.34, 0.035, 0.12, "Mat_walnut", 6)
  pcyl("SofaFoot", -w / 2 + 0.14, 0.06,  0.34, 0.035, 0.12, "Mat_walnut", 6)
  pcyl("SofaFoot",  w / 2 - 0.14, 0.06,  0.34, 0.035, 0.12, "Mat_walnut", 6)
}


## Carcass plus visible shelves. `fill` 0 leaves it empty, which is how a
## ransacked room reads; 1 packs every shelf.
function p_bookcase(parent, x, y, z, yaw, w, d, h, fill,   i, n, sy, bw) {
  open_prop(parent, x, y, z, yaw)
  pbox("CaseSide", -w / 2 + 0.03, h / 2, 0, 0.06, h, d, "Mat_walnut")
  pbox("CaseSide",  w / 2 - 0.03, h / 2, 0, 0.06, h, d, "Mat_walnut")
  pbox("CaseBack", 0, h / 2, -d / 2 + 0.02, w, h, 0.04, "Mat_walnut")
  pbox("CasePlinth", 0, 0.07, 0, w, 0.14, d, "Mat_walnut")
  pbox("CaseCornice", 0, h - 0.05, 0.02, w + 0.08, 0.10, d + 0.04, "Mat_walnut")
  n = int((h - 0.30) / 0.36)
  if (n > 5) n = 5
  bw = w - 0.14
  for (i = 1; i <= n; i++) {
    sy = 0.14 + (h - 0.30) * i / (n + 1)
    pbox("CaseShelf", 0, sy, 0, bw, 0.03, d - 0.05, "Mat_walnut")
    if (fill && i <= n) {
      pbox("CaseBooks", -bw * 0.22 + jit(parent i "a", 0.05), sy + 0.15, -0.02,
           bw * 0.44, 0.26, d * 0.55, BOOKMAT(parent i "L"))
      if (i != 2)
        pbox("CaseBooks", bw * 0.26 + jit(parent i "b", 0.05), sy + 0.13, -0.02,
             bw * 0.36, 0.22, d * 0.55, BOOKMAT(parent i "R"))
    }
  }
}

function p_wardrobe(parent, x, y, z, yaw,   w, d, h) {
  open_prop(parent, x, y, z, yaw)
  w = 1.5; d = 0.66; h = 2.2
  pbox("WardBody", 0, h / 2, 0, w, h, d, "Mat_walnut")
  pbox("WardDoor", -w / 4, h / 2 + 0.04, d / 2, w / 2 - 0.05, h - 0.34, 0.04, "Mat_mahog")
  pbox("WardDoor",  w / 4, h / 2 + 0.04, d / 2, w / 2 - 0.05, h - 0.34, 0.04, "Mat_mahog")
  pbox("WardCornice", 0, h + 0.05, 0, w + 0.12, 0.12, d + 0.10, "Mat_walnut")
  pbox("WardPlinth", 0, 0.07, 0, w + 0.06, 0.14, d + 0.04, "Mat_walnut")
  pcyl("WardKnob", -0.06, h / 2, d / 2 + 0.03, 0.022, 0.06, "Mat_brass", 8)
  pcyl("WardKnob",  0.06, h / 2, d / 2 + 0.03, 0.022, 0.06, "Mat_brass", 8)
}

function p_dresser(parent, x, y, z, yaw, w,   d, h, i) {
  if (w == 0) w = 1.4
  open_prop(parent, x, y, z, yaw)
  d = 0.55; h = 0.88
  pbox("DresserBody", 0, h / 2, 0, w, h, d, "Mat_walnut")
  pbox("DresserTop", 0, h + 0.02, 0, w + 0.06, 0.04, d + 0.05, "Mat_walnut")
  for (i = 0; i < 3; i++) {
    pbox("DresserDrawer", 0, 0.18 + i * 0.24, d / 2 + 0.01, w - 0.12, 0.20, 0.03, "Mat_mahog")
    pcyl("DresserPull", -w / 4, 0.18 + i * 0.24, d / 2 + 0.04, 0.02, 0.05, "Mat_brass", 8)
    pcyl("DresserPull",  w / 4, 0.18 + i * 0.24, d / 2 + 0.04, 0.02, 0.05, "Mat_brass", 8)
  }
}

function p_shelfrack(parent, x, y, z, yaw, w, d,   i, h) {
  open_prop(parent, x, y, z, yaw)
  h = 1.9
  pcyl("RackPost", -w / 2 + 0.04, h / 2, -d / 2 + 0.04, 0.025, h, "Mat_iron", 6)
  pcyl("RackPost",  w / 2 - 0.04, h / 2, -d / 2 + 0.04, 0.025, h, "Mat_iron", 6)
  pcyl("RackPost", -w / 2 + 0.04, h / 2,  d / 2 - 0.04, 0.025, h, "Mat_iron", 6)
  pcyl("RackPost",  w / 2 - 0.04, h / 2,  d / 2 - 0.04, 0.025, h, "Mat_iron", 6)
  for (i = 0; i < 4; i++)
    pbox("RackShelf", 0, 0.30 + i * 0.52, 0, w, 0.04, d, "Mat_wood")
}


## Four-poster. The posts are the whole point: they break up the ceiling void
## and throw long shadows, which is most of what a bedroom contributes here.
function p_bed(parent, x, y, z, yaw, w, l, posts,   fh, ph) {
  open_prop(parent, x, y, z, yaw)
  fh = 0.34
  pbox("BedFrame", 0, fh / 2 + 0.12, 0, w, fh, l, "Mat_walnut")
  pbox("Mattress", 0, fh + 0.24, 0, w - 0.08, 0.24, l - 0.10, "Mat_linen")
  pbox("Blanket", 0, fh + 0.38, 0.18, w - 0.04, 0.06, l * 0.62, "Mat_cloth")
  pbox("Pillow", -w / 4, fh + 0.42, -l / 2 + 0.34, w / 2 - 0.12, 0.14, 0.40, "Mat_linen")
  pbox("Pillow",  w / 4, fh + 0.42, -l / 2 + 0.34, w / 2 - 0.12, 0.14, 0.40, "Mat_linen")
  pbox("Headboard", 0, fh + 0.70, -l / 2 - 0.04, w + 0.10, 1.30, 0.08, "Mat_walnut")
  pbox("Footboard", 0, fh + 0.28, l / 2 + 0.04, w + 0.10, 0.60, 0.08, "Mat_walnut")
  pcyl("BedLeg", -w / 2 + 0.08, 0.06, -l / 2 + 0.08, 0.05, 0.12, "Mat_walnut", 8)
  pcyl("BedLeg",  w / 2 - 0.08, 0.06, -l / 2 + 0.08, 0.05, 0.12, "Mat_walnut", 8)
  pcyl("BedLeg", -w / 2 + 0.08, 0.06,  l / 2 - 0.08, 0.05, 0.12, "Mat_walnut", 8)
  pcyl("BedLeg",  w / 2 - 0.08, 0.06,  l / 2 - 0.08, 0.05, 0.12, "Mat_walnut", 8)
  if (posts) {
    ph = 2.05
    pcyl("BedPost", -w / 2 - 0.02, ph / 2, -l / 2 - 0.02, 0.055, ph, "Mat_walnut", 8)
    pcyl("BedPost",  w / 2 + 0.02, ph / 2, -l / 2 - 0.02, 0.055, ph, "Mat_walnut", 8)
    pcyl("BedPost", -w / 2 - 0.02, ph / 2,  l / 2 + 0.02, 0.055, ph, "Mat_walnut", 8)
    pcyl("BedPost",  w / 2 + 0.02, ph / 2,  l / 2 + 0.02, 0.055, ph, "Mat_walnut", 8)
    pbox("BedTester", 0, ph + 0.05, 0, w + 0.16, 0.10, l + 0.16, "Mat_walnut")
    pbox("BedDrape", -w / 2 - 0.04, ph * 0.62, -l / 2 + 0.30, 0.08, ph * 0.7, 0.46, "Mat_cloth")
    pbox("BedDrape",  w / 2 + 0.04, ph * 0.62, -l / 2 + 0.30, 0.08, ph * 0.7, 0.46, "Mat_cloth")
  }
}


## Hangs DOWN from its own origin, so the origin is the ceiling fixing point.
## A hanging chandelier: chain, hub, and `arms` arms radiating out to a candle
## each.
##
## THE ARMS LIE ACROSS, which sounds obvious and was wrong here for a long time.
## A CSGCylinder3D points along its own Y, cyl() could only be yawed, and yaw
## spins a cylinder about the axis it already points down -- so every arm came
## out as a 42 cm brass post standing on top of the hub. See the note on cyl()
## in lib.awk.
##
## To lay a cylinder along a horizontal bearing `adeg` measured from +X:
##
##     rx = 90, rz = adeg - 90
##
## which is worth writing down because every radial fitting in the house wants
## it -- and it is not guessable from the two rotations on their own.
function p_chandelier(parent, x, y, z, arms,   i, a, adeg, r, ax, az, drop) {
  open_prop(parent, x, y, z, 0)
  drop = 0.80
  pcyl("ChandChain", 0, -drop / 2, 0, 0.012, drop, "Mat_brass", 6)
  pcyl("ChandHub", 0, -drop, 0, 0.13, 0.16, "Mat_brass", 10)
  # A weight on the bottom of the hub. Every real one has something there, and
  # without it the hub reads as an unfinished stub.
  pcyl("ChandFinial", 0, -drop - 0.14, 0, 0.055, 0.16, "Mat_brass", 8)
  r = 0.42
  for (i = 0; i < arms; i++) {
    adeg = i * 360.0 / arms
    a = rad(adeg)
    ax = cos(a) * r; az = sin(a) * r
    pcyl("ChandArm", ax / 2, -drop + 0.06, az / 2, 0.016, r, "Mat_brass", 6, 90, adeg - 90)
    # A short upright between the arm and the cup, so the candle sits ON the
    # arm rather than floating at the end of it.
    pcyl("ChandRiser", ax, -drop + 0.09, az, 0.014, 0.10, "Mat_brass", 6)
    pcyl("ChandCup", ax, -drop + 0.15, az, 0.05, 0.05, "Mat_brass", 8)
    pcyl("ChandCandle", ax, -drop + 0.27, az, 0.022, 0.20, "Mat_candle", 8)
  }
}

function p_sconce(parent, x, y, z, yaw) {
  open_prop(parent, x, y, z, yaw)
  pbox("SconcePlate", 0, 0, 0.03, 0.16, 0.30, 0.05, "Mat_brass")
  # Out of the wall, not up it. rx=90 lays it along the prop own +Z,
  # which is the direction a wall fitting projects.
  pcyl("SconceArm", 0, 0.06, 0.13, 0.014, 0.22, "Mat_brass", 6, 90, 0)
  pcyl("SconceCup", 0, 0.12, 0.22, 0.045, 0.05, "Mat_brass", 8)
  pcyl("SconceCandle", 0, 0.24, 0.22, 0.020, 0.18, "Mat_candle", 8)
}

function p_oillamp(parent, x, y, z) {
  open_prop(parent, x, y, z, 0)
  pcyl("LampFoot", 0, 0.02, 0, 0.07, 0.04, "Mat_brass", 10)
  pcyl("LampStem", 0, 0.10, 0, 0.022, 0.14, "Mat_brass", 8)
  pcyl("LampFount", 0, 0.21, 0, 0.065, 0.10, "Mat_brass", 10)
  pcyl("LampChimney", 0, 0.34, 0, 0.045, 0.18, "Mat_glass", 10)
  pcyl("LampShade", 0, 0.47, 0, 0.11, 0.12, "Mat_shade", 10)
}

function p_candlestick(parent, x, y, z, tall,   h) {
  h = (tall ? 0.26 : 0.16)
  open_prop(parent, x, y, z, 0)
  pcyl("StickFoot", 0, 0.012, 0, 0.045, 0.024, "Mat_brass", 8)
  pcyl("StickStem", 0, h / 2, 0, 0.014, h, "Mat_brass", 6)
  pcyl("Candle", 0, h + 0.09, 0, 0.018, 0.18, "Mat_candle", 8)
}

# Horizontal surfaces left bare are the single loudest "unfinished level" tell.
# These are all tiny and all non-colliding, so they cost nothing to scatter.

## A stack of n books. n is clamped because a stack is a pile on a table, not a
## tower -- an unclamped count tapers to a point and reads as a traffic cone.
function p_bookstack(parent, x, y, z, yaw, n,   i, w) {
  if (n < 1) n = 1
  if (n > 7) n = 7
  open_prop(parent, x, y, z, yaw)
  for (i = 0; i < n; i++) {
    w = 0.23 - i * 0.008 + jit(parent x i "w", 0.015)
    pbox("Book", jit(parent x i "s", 0.02), 0.022 + i * 0.045, jit(parent z i "t", 0.02),
         w, 0.042, w * 0.72, BOOKMAT(parent i))
  }
}

## Books come in three colourways. One material for every book in the house
## makes a filled bookcase read as a solid brown slab at any distance.
function BOOKMAT(key,   h) {
  h = int((jit(key "m", 1000) + 1000) / 667)
  return (h == 0) ? "Mat_book" : (h == 1) ? "Mat_book2" : "Mat_book3"
}

function p_crate(parent, x, y, z, yaw, s) {
  open_prop(parent, x, y, z, yaw)
  pbox("CrateBody", 0, s / 2, 0, s, s, s, "Mat_wood")
  pbox("CrateBatten", 0, s * 0.18, 0, s + 0.03, 0.05, s + 0.03, "Mat_wood")
  pbox("CrateBatten", 0, s * 0.82, 0, s + 0.03, 0.05, s + 0.03, "Mat_wood")
}

function p_barrel(parent, x, y, z,   h) {
  h = 0.86
  open_prop(parent, x, y, z, 0)
  pcyl("BarrelBody", 0, h / 2, 0, 0.32, h, "Mat_wood", 12)
  pcyl("BarrelHoop", 0, h * 0.20, 0, 0.335, 0.05, "Mat_iron", 12)
  pcyl("BarrelHoop", 0, h * 0.80, 0, 0.335, 0.05, "Mat_iron", 12)
}

function p_range(parent, x, y, z, yaw,   w, d, h) {
  open_prop(parent, x, y, z, yaw)
  w = 1.5; d = 0.72; h = 0.92
  pbox("RangeBody", 0, h / 2, 0, w, h, d, "Mat_iron")
  pbox("RangeTop", 0, h + 0.03, 0, w + 0.06, 0.06, d + 0.04, "Mat_iron")
  pbox("RangeDoor", 0, 0.42, d / 2 + 0.02, w * 0.6, 0.44, 0.04, "Mat_iron")
  # A rail ACROSS the oven door. rz = -90 lays it along +X.
  pcyl("RangeHandle", 0, 0.66, d / 2 + 0.06, 0.018, w * 0.5, "Mat_brass", 8, 90, -90)
  pbox("RangeHood", 0, h + 0.95, -0.10, w + 0.5, 0.90, d + 0.20, "Mat_brick")
  pbox("RangeMantel", 0, h + 0.52, 0.06, w + 0.6, 0.14, d + 0.30, "Mat_iron")
  pcyl("Flue", 0, h + 1.70, -0.10, 0.16, 0.60, "Mat_iron", 10)
}

function p_sink(parent, x, y, z, yaw,   w, d) {
  open_prop(parent, x, y, z, yaw)
  w = 1.05; d = 0.58
  pbox("SinkBasin", 0, 0.74, 0, w, 0.36, d, "Mat_porcelain")
  pbox("SinkWell", 0, 0.86, 0, w - 0.14, 0.16, d - 0.14, "Mat_ash")
  pcyl("SinkLeg", -w / 2 + 0.10, 0.28, 0, 0.03, 0.56, "Mat_iron", 6)
  pcyl("SinkLeg",  w / 2 - 0.10, 0.28, 0, 0.03, 0.56, "Mat_iron", 6)
  # A riser and then a spout that reaches out OVER the basin. As two uprights
  # this was a pair of brass pins standing behind the sink.
  pcyl("SinkTap", 0, 1.06, -d / 2 + 0.06, 0.018, 0.28, "Mat_brass", 8)
  pcyl("SinkSpout", 0, 1.19, -d / 2 + 0.17, 0.016, 0.24, "Mat_brass", 8, 90, 0)
  pcyl("SinkNose", 0, 1.14, -d / 2 + 0.27, 0.014, 0.10, "Mat_brass", 8)
  pcyl("SinkHandle", 0, 1.21, -d / 2 + 0.06, 0.012, 0.11, "Mat_brass", 6, 90, -90)
}

## Upright piano, closed. Reads instantly and fills a wall.
function p_piano(parent, x, y, z, yaw,   w, d, h) {
  open_prop(parent, x, y, z, yaw)
  w = 1.5; d = 0.62; h = 1.24
  pbox("PianoBody", 0, h / 2, -0.04, w, h, d - 0.08, "Mat_mahog")
  pbox("PianoLid", 0, h + 0.03, -0.04, w + 0.06, 0.06, d, "Mat_mahog")
  pbox("PianoKeybed", 0, 0.72, d / 2 - 0.02, w - 0.14, 0.10, 0.28, "Mat_mahog")
  pbox("PianoKeys", 0, 0.775, d / 2 + 0.02, w - 0.26, 0.02, 0.20, "Mat_linen")
  pbox("PianoFall", 0, 0.90, d / 2 - 0.04, w - 0.14, 0.24, 0.05, "Mat_mahog")
  pcyl("PianoLeg", -w / 2 + 0.12, 0.30, d / 2 - 0.10, 0.045, 0.60, "Mat_mahog", 8)
  pcyl("PianoLeg",  w / 2 - 0.12, 0.30, d / 2 - 0.10, 0.045, 0.60, "Mat_mahog", 8)
  pcyl("PianoPedal", 0, 0.08, d / 2 - 0.02, 0.012, 0.16, "Mat_brass", 6)
}

## Writing desk with a pedestal of drawers on one side.
function p_desk(parent, x, y, z, yaw, w, d,   h, i) {
  open_prop(parent, x, y, z, yaw)
  h = 0.76
  pbox("DeskTop", 0, h, 0, w, 0.06, d, "Mat_mahog")
  pbox("DeskLeather", 0, h + 0.035, 0, w - 0.22, 0.01, d - 0.16, "Mat_velvet")
  pbox("DeskPed", -w / 2 + 0.26, h / 2 - 0.03, 0, 0.48, h - 0.06, d - 0.10, "Mat_mahog")
  pbox("DeskPed",  w / 2 - 0.26, h / 2 - 0.03, 0, 0.48, h - 0.06, d - 0.10, "Mat_mahog")
  for (i = 0; i < 3; i++) {
    pbox("DeskDrawer", -w / 2 + 0.26, 0.18 + i * 0.20, d / 2 - 0.04, 0.42, 0.16, 0.03, "Mat_walnut")
    pbox("DeskDrawer",  w / 2 - 0.26, 0.18 + i * 0.20, d / 2 - 0.04, 0.42, 0.16, 0.03, "Mat_walnut")
    pcyl("DeskPull", -w / 2 + 0.26, 0.18 + i * 0.20, d / 2 - 0.01, 0.018, 0.05, "Mat_brass", 8)
    pcyl("DeskPull",  w / 2 - 0.26, 0.18 + i * 0.20, d / 2 - 0.01, 0.018, 0.05, "Mat_brass", 8)
  }
}

function p_washstand(parent, x, y, z, yaw) {
  open_prop(parent, x, y, z, yaw)
  pbox("WashBody", 0, 0.40, 0, 0.86, 0.80, 0.46, "Mat_walnut")
  pbox("WashTop", 0, 0.83, 0, 0.92, 0.06, 0.50, "Mat_marble")
  pbox("WashSplash", 0, 1.00, -0.22, 0.92, 0.28, 0.05, "Mat_marble")
  pcyl("WashBasin", -0.16, 0.92, 0.02, 0.17, 0.12, "Mat_porcelain", 12)
  pcyl("WashJug", 0.22, 0.98, 0.02, 0.09, 0.24, "Mat_porcelain", 10)
}

function p_pedestal(parent, x, y, z, top,   h) {
  h = 1.05
  open_prop(parent, x, y, z, 0)
  pbox("PedBase", 0, 0.06, 0, 0.34, 0.12, 0.34, "Mat_marble")
  pcyl("PedShaft", 0, h / 2, 0, 0.11, h, "Mat_marble", 10)
  pbox("PedCap", 0, h + 0.04, 0, 0.32, 0.08, 0.32, "Mat_marble")
  if (top) {
    pcyl("BustNeck", 0, h + 0.15, 0, 0.07, 0.14, "Mat_marble", 8)
    pbox("BustHead", 0, h + 0.32, 0, 0.20, 0.24, 0.22, "Mat_marble")
    pbox("BustShoulder", 0, h + 0.12, 0, 0.34, 0.14, 0.22, "Mat_marble")
  }
}

## Long-case clock. The hall already has one as an interactable; this is the
## dressing version for the landing.
function p_clock(parent, x, y, z, yaw) {
  open_prop(parent, x, y, z, yaw)
  pbox("ClockTrunk", 0, 1.05, 0, 0.44, 2.10, 0.26, "Mat_walnut")
  pbox("ClockHood", 0, 2.28, 0.02, 0.56, 0.46, 0.32, "Mat_walnut")
  pbox("ClockCrest", 0, 2.56, 0.02, 0.60, 0.12, 0.34, "Mat_walnut")
  pbox("ClockDial", 0, 2.28, 0.17, 0.36, 0.36, 0.03, "Mat_linen")
  pbox("ClockGlass", 0, 1.30, 0.14, 0.22, 0.70, 0.02, "Mat_glass")
  pcyl("ClockBob", 0, 1.10, 0.10, 0.06, 0.02, "Mat_brass", 10)
  pbox("ClockPlinth", 0, 0.12, 0, 0.50, 0.24, 0.30, "Mat_walnut")
}
