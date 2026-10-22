## Geometry for the circus level. Sourced after lib.awk, items.awk and
## surroundings.awk, which is where sbox/scyl and the two tree functions come
## from -- the woods here are the same woods as the estate's, because they are
## meant to be.

## The path the player walks, as a polyline from the spawn to the tent. Trees
## are kept clear of it and nothing else is built on it.
##
## This is the LEVEL, not decoration. Everything else is placed relative to it:
## the forest fills what the path does not use, the stalls line it where it
## opens out, and the chase walls narrow it again afterwards.
function path_point(i, which) {
  # x, then z, for each waypoint. Kept as a flat list because awk has no
  # structs and a pair of parallel arrays reads worse than this does.
  if (which == "x") return PX[i]
  return PZ[i]
}

## The route, as a polyline from where the player lands to the fairground.
##
## THREE PLATFORMS, and the word is the user's: two of forest and one of
## fairground, each about 130 m deep. The whole walk is around 450 m, which is
## a long way in a game where you move at 3.4 m/s -- and it is deliberately
## more than a straight line, because a forest you can see the end of is a
## corridor with trees painted on it.
##
##   z +190 .. +60   platform one. Dense, no landmarks, the tent barely visible.
##   z +60 .. -70    platform two. Thinner, clearings, the tent above the trees.
##   z -70 .. -200   platform three. The fairground, abandoned.
##
## Everything else is placed against this: the forest fills what it does not
## use, the fencing is laid along it, and the probe walks it. Move a waypoint
## and all three follow.
function path_init(   i) {
  i = 0
  # --- platform one: landing, then wandering. No sight lines. ---
  PX[i] = 0;     PZ[i] = 190; i++
  PX[i] = -11;   PZ[i] = 174; i++
  PX[i] = 6;     PZ[i] = 158; i++
  PX[i] = 20;    PZ[i] = 146; i++
  PX[i] = 12;    PZ[i] = 128; i++
  PX[i] = -8;    PZ[i] = 118; i++
  PX[i] = -24;   PZ[i] = 104; i++
  PX[i] = -18;   PZ[i] = 86;  i++
  PX[i] = 2;     PZ[i] = 76;  i++
  PX[i] = 14;    PZ[i] = 62;  i++
  # --- platform two: it opens out, and the tent starts showing. ---
  PX[i] = 6;     PZ[i] = 44;  i++
  PX[i] = -14;   PZ[i] = 32;  i++
  PX[i] = -26;   PZ[i] = 14;  i++
  PX[i] = -16;   PZ[i] = -4;  i++
  PX[i] = 4;     PZ[i] = -14; i++
  PX[i] = 18;    PZ[i] = -30; i++
  PX[i] = 8;     PZ[i] = -46; i++
  PX[i] = -6;    PZ[i] = -60; i++
  # --- platform three: the approach. Straighter; you can see where you are
  # going now, and that is the point of it. It ends at the tent.
  PX[i] = -2;    PZ[i] = -80; i++
  PX[i] = 0;     PZ[i] = -104; i++
  PX[i] = 0;     PZ[i] = -128; i++
  PX[i] = 0;     PZ[i] = -152; i++
  PX[i] = 0;     PZ[i] = -178; i++
  # The last stretch. The fairground that used to stand between here and the
  # big top is gone -- see tent_yard() below for why -- so the walk now runs to
  # the canvas and in through the door in it.
  PX[i] = 0;     PZ[i] = -196; i++
  PX[i] = 0;     PZ[i] = -220; i++
  PN = i
}

## Distance from (x, z) to the nearest point on the path. Used to decide where
## trees may stand: anything inside `width` of the route is left clear.
function path_dist(x, z,   i, ax, az, bx, bz, dx, dz, t, cx, cz, d, best) {
  best = 1e9
  for (i = 0; i < PN - 1; i++) {
    ax = PX[i]; az = PZ[i]; bx = PX[i + 1]; bz = PZ[i + 1]
    dx = bx - ax; dz = bz - az
    t = ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)
    if (t < 0) t = 0
    if (t > 1) t = 1
    cx = ax + dx * t; cz = az + dz * t
    d = sqrt((x - cx) * (x - cx) + (z - cz) * (z - cz))
    if (d < best) best = d
  }
  return best
}

## The forest. Dense everywhere the path is not, thinning at the edges so the
## boundary does not read as a wall.
##
## Trees are placed on a JITTERED GRID rather than at random. Pure random
## clumps and leaves holes you can see through; a grid with noise on it fills
## evenly and still looks unplanned.
function forest(parent, x0, x1, z0, z1, step, clear,   x, z, jx, jz, d, g, h, k) {
  k = 0
  for (x = x0; x <= x1; x += step) {
    for (z = z0; z <= z1; z += step) {
      k++
      jx = x + jit("fx" k, step * 0.45)
      jz = z + jit("fz" k, step * 0.45)
      d = path_dist(jx, jz)
      if (d < clear) continue
      # Thin out right at the clearing edge so the treeline has a soft margin.
      if (d < clear + 2.0 && (k % 3) != 0) continue
      # Glades, by the same rule: hard edge, then a thinned margin, so the
      # boundary reads as woodland opening out and not as a mown circle.
      g = glade_dist(jx, jz)
      if (g < 0) continue
      if (g < 2.5 && (k % 3) != 1) continue
      h = 11 + jit("fh" k, 5)
      tree_conifer(parent, jx, jz, h, "f" k)
    }
  }
}

## A concession stall: a counter, a back wall, a striped awning on two posts.
## Read from the front, which is the only side the player ever sees.
function stall(parent, x, z, yaw, key,   w, d, hgt, i) {
  w = 3.6; d = 2.2; hgt = 2.4
  sbox(parent, "StallBack", x, hgt / 2, z - d / 2, w, hgt, 0.16, "Mat_wood", 0, yaw, 0)
  sbox(parent, "StallCounter", x, 0.55, z + d / 2 - 0.2, w, 1.1, 0.5, "Mat_wood", 0, yaw, 0)
  sbox(parent, "StallShelf", x, 1.5, z - d / 2 + 0.3, w - 0.6, 0.08, 0.5, "Mat_wood", 0, yaw, 0)
  # Posts and awning.
  for (i = -1; i <= 1; i += 2) {
    scyl(parent, "StallPost", x + i * (w / 2 - 0.15), hgt / 2, z + d / 2,
         0.07, hgt, "Mat_iron", 6, 0, yaw, 0, 0)
  }
  sbox(parent, "StallAwning", x, hgt + 0.12, z + d / 2 - 0.3, w + 0.5, 0.1, d + 0.6,
       "Mat_canvas", -12, yaw, 0)
}

## A run of bunting posts with a sagging wire between them. Cheap, and it does
## more for "fairground" than another stall would.
function bunting(parent, x0, z0, x1, z1, posts, key,   i, t, px, pz, h) {
  for (i = 0; i <= posts; i++) {
    t = i / posts
    px = x0 + (x1 - x0) * t
    pz = z0 + (z1 - z0) * t
    h = 4.2
    scyl(parent, "BuntPost", px, h / 2, pz, 0.09, h, "Mat_iron", 6, 0, 0, 0, 0)
    if (i < posts) {
      # The wire, as a thin box leaning between this post and the next. A real
      # catenary would need a mesh; at night this is a line of light and the
      # sag is not what anybody is looking at.
      sbox(parent, "BuntWire",
           px + (x1 - x0) / posts / 2, h - 0.35, pz + (z1 - z0) / posts / 2,
           0.04, 0.04, sqrt(((x1 - x0) / posts) ^ 2 + ((z1 - z0) / posts) ^ 2),
           "Mat_iron", 0, atan2((x1 - x0) / posts, (z1 - z0) / posts) * 180 / 3.14159265, 0)
    }
  }
}

## The big top. A cylindrical wall with a cone on it, a valance where they
## meet, and a mouth cut through the wall on the +Z side.
##
## Built from a combiner with a SUBTRACTION for the doorway, because a tent you
## cannot walk into is a painted backdrop.
function tent(parent, x, z, r, wall_h, cone_h,   i, a) {
  scyl(parent, "TentWall", x, wall_h / 2, z, r, wall_h, "Mat_canvas", 24, 0, 0, 0, 0)
  scyl(parent, "TentRoof", x, wall_h + cone_h / 2, z, r * 1.06, cone_h,
       "Mat_canvas", 24, 0, 0, 0, 1)
  # Valance: a shallow ring where the roof meets the wall.
  scyl(parent, "TentValance", x, wall_h + 0.35, z, r * 1.12, 0.7, "Mat_velvet", 24, 0, 0, 0, 0)
  # Pennant on the peak.
  scyl(parent, "TentMast", x, wall_h + cone_h + 1.1, z, 0.08, 2.2, "Mat_iron", 6, 0, 0, 0, 0)
  # Guy ropes, angled out to the ground.
  for (i = 0; i < 10; i++) {
    a = i * 36
    sbox(parent, "TentGuy",
         x + sin(a * 3.14159265 / 180) * (r + 1.6),
         wall_h * 0.5,
         z + cos(a * 3.14159265 / 180) * (r + 1.6),
         0.05, wall_h * 1.25, 0.05, "Mat_iron", 22, a, 0)
  }
}

## Fencing laid ALONG the path rather than placed by eye.
##
## The first version of the chase was a dozen boards positioned by hand, and one
## of them sat straight across the route at (-6, -25): the player would have run
## the concessions, turned the corner and hit a wall. tools/probe_circus.gd
## caught it. Deriving the corridor from the same polyline the trees avoid means
## it cannot happen again -- move a waypoint and the fencing moves with it.
##
## `gap_a` and `gap_b` are segment indices where one side is left open, which is
## how a junction gets made.
function corridor(parent, i0, i1, halfw, gap_a, gap_b, key,
                  i, ax, az, bx, bz, dx, dz, len, ang, nx, nz, mx, mz, s) {
  for (i = i0; i < i1; i++) {
    ax = PX[i]; az = PZ[i]; bx = PX[i + 1]; bz = PZ[i + 1]
    dx = bx - ax; dz = bz - az
    len = sqrt(dx * dx + dz * dz)
    if (len < 0.1) continue
    ang = atan2(dx, dz) * 180 / 3.14159265
    # Left-hand normal of the segment.
    nx = dz / len; nz = -dx / len
    mx = (ax + bx) / 2; mz = (az + bz) / 2
    for (s = -1; s <= 1; s += 2) {
      # A gap on one side turns a corridor into a junction.
      if (i == gap_a && s < 0) continue
      if (i == gap_b && s > 0) continue
      sbox(parent, "Board", mx + nx * halfw * s, 1.5, mz + nz * halfw * s,
           0.3, 3.0, len, "Mat_wood", 0, ang, 0)
    }
  }
}

## A dead end hanging off the corridor: three boards making a pocket you can run
## into and have to come back out of. Placed on the OUTSIDE of a gap left by
## corridor(), so the mouth lines up with the opening.
function pocket(parent, x, z, w, d, yaw, key) {
  sbox(parent, "Board", x, 1.5, z - d / 2, w, 3.0, 0.3, "Mat_wood", 0, yaw, 0)
  sbox(parent, "Board", x - w / 2, 1.5, z, 0.3, 3.0, d, "Mat_wood", 0, yaw, 0)
  sbox(parent, "Board", x + w / 2, 1.5, z, 0.3, 3.0, d, "Mat_wood", 0, yaw, 0)
}

## Emits the path as Marker3D nodes so it exists in the SCENE as well as here.
##
## tools/probe_circus.gd used to carry a copy of the waypoints, kept in step by
## hand, which is exactly the kind of duplication that is correct until the day
## it is not. Now the probe reads these and the two cannot disagree.
function path_markers(parent,   i) {
  printf "\n[node name=\"%s\" type=\"Node3D\" parent=\".\"]\n", parent
  for (i = 0; i < PN; i++) {
    printf "\n[node name=\"P%02d\" type=\"Marker3D\" parent=\"%s\"]\n", i, parent
    printf "transform = %s\n", TR(PX[i], 0, PZ[i], 0, 0, 0)
  }
}

# ---- the hunt -------------------------------------------------------------

## A point `along` metres further down the route from waypoint i, and `side`
## metres to its right. Returns the x or the z depending on `which`.
##
## Patrol markers have to land in the corridor forest() leaves clear, and
## picking those coordinates by eye means a creature wedged in a trunk that
## nobody notices until playtest. Anchoring every one of them to the route
## makes staying in the clear a property of the maths rather than of my
## arithmetic: |side| under the clearance is always walkable.
function path_off(i, along, side, which,   dx, dz, l, ux, uz) {
  if (i >= PN - 1) i = PN - 2
  dx = PX[i + 1] - PX[i]; dz = PZ[i + 1] - PZ[i]
  l = sqrt(dx * dx + dz * dz); if (l < 1e-6) l = 1
  ux = dx / l; uz = dz / l
  # Right of the direction of travel, on the ground plane, is (uz, -ux).
  if (which == "x") return PX[i] + ux * along + uz * side
  return PZ[i] + uz * along - ux * side
}

## A patrol loop straddling the route near waypoint i.
##
## Four markers, laid ACROSS the way you have to go rather than along it: the
## creature paces from one side of the corridor to the other, so the player's
## problem is a timing one -- wait, or go now -- instead of a race it cannot
## win. A patrol that walked the path lengthways would either never meet the
## player or never leave them.
##
## `reach` is how far up and down the route it strays, `side` how far off it.
function patrol(parent, name, i, reach, side, key,   n) {
  printf "\n[node name=\"%s\" type=\"Node3D\" parent=\"%s\"]\n", name, parent
  n = 0
  patrol_mark(parent, name, n++, path_off(i, -reach,  side, "x"), path_off(i, -reach,  side, "z"))
  patrol_mark(parent, name, n++, path_off(i,  0.0,   -side, "x"), path_off(i,  0.0,   -side, "z"))
  patrol_mark(parent, name, n++, path_off(i,  reach,  side, "x"), path_off(i,  reach,  side, "z"))
  patrol_mark(parent, name, n++, path_off(i,  0.0,    side * 1.6, "x"), path_off(i, 0.0, side * 1.6, "z"))
}

function patrol_mark(parent, name, n, x, z) {
  printf "\n[node name=\"P%02d\" type=\"Marker3D\" parent=\"%s/%s\"]\n", n, parent, name
  printf "transform = %s\n", T(x, 0, z)
}

## Cover. A clump of low scrub you can crouch inside, and the ConcealArea that
## makes doing so mean something.
##
## The foliage goes in a NON-COLLIDING combiner on purpose. A bush you cannot
## walk into is a wall with leaves on it, and the whole point of these is that
## the player dives off the path into one.
function thicket(parent, x, z, key,   i, a, r, bx, bz, h) {
  for (i = 0; i < 7; i++) {
    a = i * 0.8975 + jit("ta" key i, 0.4)
    r = 0.7 + jit("tr" key i, 0.9)
    bx = x + cos(a) * r
    bz = z + sin(a) * r
    h = 1.05 + jit("th" key i, 0.35)
    scyl(parent, "Bush" key i, bx, h / 2, bz, 0.62 + jit("tw" key i, 0.2), h, "Mat_foliage", 6, 0, 0, 0)
  }
}

## The volume that makes a thicket count. Separate from the leaves so the two
## can be sized independently -- the area is what the game reads, the scrub is
## only what sells it.
function thicket_area(parent, x, z, key) {
  printf "\n[node name=\"Hide%s\" type=\"Area3D\" parent=\"%s\"]\n", key, parent
  printf "transform = %s\n", T(x, 0.8, z)
  printf "script = ExtResource(\"9_conceal\")\n"
  printf "\n[node name=\"Shape\" type=\"CollisionShape3D\" parent=\"%s/Hide%s\"]\n", parent, key
  printf "shape = SubResource(\"Box_thicket\")\n"
}

## Clearings, registered BEFORE forest() runs and honoured by it.
##
## A stealth encounter needs two things a corridor cannot give: room to go
## round, and a sight line long enough to see what you are going round. Without
## these the woods are one continuous 9 m gap and every creature in them is a
## tollbooth -- wait for it to face away, walk past, repeat. A glade turns the
## same creature into a choice about which side to take.
function glade(x, z, r) {
  GX[GN] = x; GZ[GN] = z; GR[GN] = r; GN++
}

## Metres of clear ground between (x, z) and the nearest glade edge. Negative
## inside one. 1e9 when no glades are registered at all.
function glade_dist(x, z,   i, dx, dz, d, best) {
  best = 1e9
  for (i = 0; i < GN; i++) {
    dx = x - GX[i]; dz = z - GZ[i]
    d = sqrt(dx * dx + dz * dz) - GR[i]
    if (d < best) best = d
  }
  return best
}

## One creature, standing on the first marker of its own patrol. Lifted a
## little so it settles onto the ground instead of starting inside it.
function stalker(parent, name, route, i, reach, side) {
  printf "\n[node name=\"%s\" parent=\"%s\" instance=ExtResource(\"11_stalker\")]\n", name, parent
  printf "transform = %s\n", T(path_off(i, -reach, side, "x"), 0.1, path_off(i, -reach, side, "z"))
  printf "route = NodePath(\"../%s\")\n", route
}

## Cuts an opening in whatever has already been emitted into `parent`.
##
## A CSG subtraction, so it MUST come after the geometry it takes a bite out of
## -- CSG is evaluated in child order, and a subtraction emitted first has
## nothing in front of it to remove. That is also why this is a function rather
## than an argument to tent(): the doorway is a decision about the level, not
## about the tent, and it belongs next to the door that fills it.
function cut_opening(parent, name, x, y, z, w, h, d) {
  SN++
  printf "\n[node name=\"%s_%d\" type=\"CSGBox3D\" parent=\"%s\"]\n", name, SN, parent
  printf "transform = %s\n", TR(x, y, z, 0, 0, 0)
  printf "size = Vector3(%.3f, %.3f, %.3f)\n", w, h, d
  printf "operation = 2\n"
}

## The ground outside a big top.
##
## This replaces the fairground that used to stand here. A midway was always a
## second place grafted onto the front of the first one -- you walked 400 m of
## woods to reach a circus and then had to walk a fair before you got to it.
## Cutting it means the tent is what the whole level has been steering toward
## since the trees first thinned, and arriving is arriving.
##
## So what is here is BACK OF HOUSE, not a show: the stakes the guys are pegged
## to, the crates the rigging came out of, and the cable that feeds whatever is
## lit inside. Nobody sells anything at the back of a tent.
function tent_yard(parent, x, z, r, key,   i, a, sx, sz, cx, cz) {
  # Stakes in an arc across the front, where the guy lines come down. The tent
  # emits the ropes; these are what they are tied to.
  for (i = 0; i < 11; i++) {
    a = 200 + i * 14
    sx = x + sin(a * 3.14159265 / 180) * (r + 3.0)
    sz = z + cos(a * 3.14159265 / 180) * (r + 3.0)
    sbox(parent, "Stake", sx, 0.55, sz, 0.3, 1.5, 0.3, "Mat_iron", jit(key "s" i, 9), 0, jit(key "t" i, 9))
    sbox(parent, "Mallet", sx + 1.2, 0.18, sz + 0.6, 1.4, 0.3, 0.3, "Mat_wood", 0, jit(key "m" i, 70), 0)
  }

  # Flight cases by the door, stacked because they were carried in and put
  # down rather than scattered.
  for (i = 0; i < 6; i++) {
    cx = x + 9.5 + (i % 2) * 2.4
    cz = z + r - 4.0 - int(i / 2) * 2.2
    sbox(parent, "Case", cx, 0.75 + (i % 2) * 1.5, cz, 2.2, 1.5, 2.0, "Mat_wood",
         0, jit(key "c" i, 12), 0)
    sbox(parent, "CaseBand", cx, 0.75 + (i % 2) * 1.5, cz, 2.3, 0.2, 2.1, "Mat_iron",
         0, jit(key "c" i, 12), 0)
  }

  # The feed: a drum, and cable going in under the canvas. The one thing out
  # here that says something inside is running.
  scyl(parent, "Drum", x - 11.0, 0.9, z + r - 6.0, 0.9, 1.8, "Mat_wood", 14, 90, 24, 0, 0)
  sbox(parent, "Feed", x - 6.0, 0.08, z + r - 3.0, 12.0, 0.16, 0.3, "Mat_rust", 0, 62, 0)
  sbox(parent, "Feed", x - 2.0, 0.08, z + r - 1.0, 9.0, 0.16, 0.3, "Mat_rust", 0, 88, 0)
}
