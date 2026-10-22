# Bespoke interior geometry -- the pieces that are a different size in every
# place they appear, so there is nothing to gain from baking them into a scene.
# A run of kitchen cabinetry is as long as its wall; a rug fits its room; a
# chimney breast is part of the building.
#
# Used by gen_interior.awk while laying the house out. Requires lib.awk.
#
# EVERY FUNCTION HERE OPENS ITS OWN group(). That is what makes each fireplace,
# rug, picture and dust sheet a separate node with a separate baked mesh, so
# one of them can be moved, hidden or deleted in the editor. The room groups
# they are passed are plain Node3Ds for exactly that reason -- see group() in
# lib.awk for why nesting a combiner in a combiner would undo it.
#
# The `collide` argument to group() decides whether the bake gives the item a
# trimesh body. Anything under 20cm tall gets 0: CharacterBody3D has no
# step-up, so a rug lip or a stack of paper stops the player dead.

# ---- surface heights ------------------------------------------------------
#
# What each surface in the house stands at, so a candlestick is placed with
# TOP_mantel() and not with 1.19 typed from memory.
#
# Four things were out before this existed, all by the thickness of the piece
# of the furniture they were computed from: the mantel candlesticks were 4cm
# INTO the marble, the piano candlestick 3cm into the lid, the cellar bottle
# floated 9cm above its shelf, and the kitchen bottles sat 1cm off the
# worktop. Every one of them is the same mistake -- taking the height a
# tabletop is CENTRED at instead of the height its face lands at.

function TOP_console()  { return 0.79 }   # pf_table_console
function TOP_dine()     { return 0.76 }   # pf_table_dine
function TOP_work()     { return 0.86 }   # pf_table_work
function TOP_small()    { return 0.70 }   # pf_table_small
function TOP_side()     { return 0.60 }   # pf_table_side
function TOP_low()      { return 0.46 }   # pf_table_low
## p_desk lays a leather over the top, which is the surface things rest on.
function TOP_desk()     { return 0.795 }
function TOP_dresser()  { return 0.92 }   # p_dresser: top at 0.90, 0.04 thick
function TOP_washstand(){ return 0.86 }
function TOP_piano()    { return 1.30 }   # p_piano: lid at 1.27, 0.06 thick
function TOP_counter()  { return 0.92 }   # p_counter: top at 0.89, 0.06 thick
function TOP_range()    { return 0.98 }
function TOP_mantel()   { return 1.23 }   # p_fireplace: shelf 1.19, 0.08 thick
## p_shelfrack: shelf i is centred at 0.30 + i*0.52 and is 0.04 thick.
function TOP_rack(i)    { return 0.32 + i * 0.52 }


## Kitchen/scullery cabinetry: a plinth set back under a worktop, so it reads
## as built-in rather than as a crate with a lid.
function p_counter(parent, x, y, z, yaw, w, d,   h, g) {
  g = group(parent, "Counter", 1)
  open_prop(g, x, y, z, yaw)
  # Sized so the worktop face lands at TOP_counter(), which is where the
  # hand-placed pickups (the magnifier, the bureau key, the crowbar) sit.
  h = 0.86
  pbox("CounterBody", 0, h / 2 + 0.06, 0, w, h - 0.12, d, "Mat_wood")
  pbox("CounterPlinth", 0, 0.06, 0, w - 0.10, 0.12, d - 0.12, "Mat_wood")
  pbox("CounterTop", 0, h + 0.03, 0, w + 0.04, 0.06, d + 0.05, "Mat_stone")
}

## Chimney breast, surround and mantel, built against a wall. A fireplace
## anchors a room harder than any amount of furniture, so every principal room
## gets one.
function p_fireplace(parent, x, y, z, yaw, wide,   w, br, mh, op, g) {
  g = group(parent, "Fireplace", 1)
  open_prop(g, x, y, z, yaw)
  w = (wide ? 2.4 : 1.9)
  br = 0.42                     # how far the breast stands proud of the wall
  mh = 1.14                     # mantel height
  op = w * 0.44                 # opening width
  # Breast: full height to the ceiling, otherwise it reads as a cupboard.
  #
  # It stands 2cm proud of the wall. At -br/2 - 0.30 its front face landed on
  # exactly the plane of the plaster and the two fought over ten square metres
  # of the living room's east wall. It cannot come much further forward than
  # this either -- the marble surround below only projects 0.10, and a breast
  # in front of that would swallow the fireplace opening.
  pbox("ChimBreast", 0, 1.70, -br / 2 - 0.28, w + 0.5, 3.40, br + 0.60, "Mat_brick")
  pbox("HearthStone", 0, 0.03, 0.34, w + 0.1, 0.06, 0.70, "Mat_marble")
  pbox("SurroundJamb", -(op / 2 + (w - op) / 4), mh / 2, 0.02, (w - op) / 2, mh, 0.16, "Mat_marble")
  pbox("SurroundJamb",  (op / 2 + (w - op) / 4), mh / 2, 0.02, (w - op) / 2, mh, 0.16, "Mat_marble")
  pbox("SurroundLintel", 0, mh - 0.12, 0.02, w, 0.24, 0.16, "Mat_marble")
  # mantel: shelf centred at mh + 0.05, 0.08 thick -- hence TOP_mantel()
  pbox("MantelShelf", 0, mh + 0.05, 0.06, w + 0.22, 0.08, 0.34, "Mat_marble")
  pbox("FireBack", 0, 0.44, -0.16, op, 0.88, 0.10, "Mat_ash")
  pbox("FireAsh", 0, 0.06, 0.02, op - 0.10, 0.12, 0.30, "Mat_ash")
  pbox("FireGrate", 0, 0.20, 0.04, op - 0.22, 0.14, 0.26, "Mat_iron")
  pcyl("FireIron", op / 2 - 0.06, 0.34, 0.30, 0.018, 0.68, "Mat_iron", 6)
  pcyl("FireIron", op / 2 + 0.02, 0.32, 0.30, 0.018, 0.64, "Mat_iron", 6)
}

## Over-mantel portrait. Separate from p_fireplace so a room can hang a mirror,
## a clock or nothing at all above the shelf.
function p_picture(parent, x, y, z, yaw, w, h, mat,   g) {
  if (mat == "") mat = "Mat_canvas"
  g = group(parent, "Picture", 0)
  open_prop(g, x, y, z, yaw)
  pbox("PicCanvas", 0, 0, 0.015, w, h, 0.03, mat)
  pbox("PicFrame", 0, h / 2 + 0.035, 0.03, w + 0.14, 0.07, 0.05, "Mat_gild")
  pbox("PicFrame", 0, -h / 2 - 0.035, 0.03, w + 0.14, 0.07, 0.05, "Mat_gild")
  pbox("PicFrame", -w / 2 - 0.035, 0, 0.03, 0.07, h, 0.05, "Mat_gild")
  pbox("PicFrame",  w / 2 + 0.035, 0, 0.03, 0.07, h, 0.05, "Mat_gild")
}


## Rugs carry no collision -- a 2cm lip with no step-up would stop the player
## dead at the edge of every carpet in the house.
function p_rug(parent, x, y, z, yaw, w, d,   g) {
  g = group(parent, "Rug", 0)
  open_prop(g, x, y, z, yaw)
  pbox("RugField", 0, 0.008, 0, w - 0.36, 0.016, d - 0.36, "Mat_rug")
  pbox("RugBorder", 0, 0.006, 0, w, 0.012, d, "Mat_rugedge")
}

## Curtains hang past the reveal on both sides, as drawn-back curtains do; a
## pelmet hides the top. `h` is the drop from the rod.
function p_curtains(parent, x, y, z, yaw, w, h,   g) {
  g = group(parent, "Curtains", 0)
  open_prop(g, x, y, z, yaw)
  pbox("Pelmet", 0, h + 0.10, 0.06, w + 0.44, 0.22, 0.16, "Mat_cloth")
  pcyl("CurtainRod", 0, h + 0.02, 0.10, 0.018, w + 0.50, "Mat_brass", 8)
  pbox("Curtain", -w / 2 - 0.16, h / 2, 0.08, 0.30, h, 0.16, "Mat_cloth")
  pbox("Curtain",  w / 2 + 0.16, h / 2, 0.08, 0.30, h, 0.16, "Mat_cloth")
}

## A dust sheet thrown over furniture. Cheapest possible way to say "nobody has
## lived here for years" while still filling the room with shapes.
function p_sheet(parent, x, y, z, yaw, w, h, d,   g) {
  g = group(parent, "DustSheet", 1)
  open_prop(g, x, y, z, yaw)
  pbox("SheetBody", 0, h / 2, 0, w, h, d, "Mat_dust")
  pbox("SheetDrape", 0, h * 0.72, 0, w + 0.10, h * 0.42, d + 0.10, "Mat_dust")
  pbox("SheetFold", 0, h * 0.30, d / 2 + 0.02, w + 0.06, h * 0.30, 0.06, "Mat_dust")
}


function p_papers(parent, x, y, z, yaw, w,   g) {
  g = group(parent, "Papers", 0)
  open_prop(g, x, y, z, yaw)
  pbox("Papers", 0, 0.006, 0, w, 0.012, w * 0.72, "Mat_paper")
  pbox("Papers", jit(parent x "p", 0.05), 0.016, jit(parent z "q", 0.05), w * 0.8, 0.008, w * 0.6, "Mat_paper")
}

function p_bottle(parent, x, y, z, tall,   h, g) {
  h = (tall ? 0.30 : 0.22)
  g = group(parent, "Bottle", 0)
  open_prop(g, x, y, z, 0)
  pcyl("BottleBody", 0, h * 0.35, 0, 0.038, h * 0.7, "Mat_glass", 8)
  pcyl("BottleNeck", 0, h * 0.85, 0, 0.014, h * 0.3, "Mat_glass", 6)
}

function p_sheetpile(parent, x, y, z, yaw, w,   g) {
  g = group(parent, "ClothPile", 0)
  open_prop(g, x, y, z, yaw)
  pbox("ClothPile", 0, 0.09, 0, w, 0.18, w * 0.8, "Mat_dust")
  pbox("ClothPile", jit(parent x "c", 0.06), 0.24, jit(parent z "d", 0.06), w * 0.7, 0.14, w * 0.55, "Mat_dust")
}

