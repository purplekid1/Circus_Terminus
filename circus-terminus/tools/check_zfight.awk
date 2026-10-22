# Finds coplanar, same-facing, overlapping box faces in the assembled scene.
#
#   awk -f tools/check_zfight.awk <node list>
#
# Run by build.sh before the scene is written. This is a lint for exactly one
# bug, and it is the bug that produced the shimmering front and back doors:
# two solids from DIFFERENT combiners whose faces land on the same plane. The
# depth buffer cannot separate them, so which one wins is decided by floating
# point noise and flips as the camera moves.
#
# What counts as a hit, and why each condition is there:
#
#   same plane      two faces within 1mm of each other
#   same sense      both are +X faces, or both are -X faces. Two boxes that
#                   ABUT (one's max on the other's min) are fine: each of
#                   those faces is buried inside the other solid and never
#                   drawn.
#   overlapping     they share real area in the other two axes -- boxes that
#                   merely line up edge to edge are how every run of trim in
#                   the house is built
#   different parents
#                   two brushes in the SAME CSGCombiner3D are unioned before
#                   they are ever rasterised, so the boolean resolves the
#                   coincidence and nothing fights. Only cross-combiner pairs
#                   reach the depth buffer as separate geometry.
#
# Rotated boxes are skipped. Everything this is meant to catch -- wall trim,
# door cases, skirting, the porch surround -- is axis-aligned or yawed by a
# multiple of 90 degrees, and handling arbitrary orientations would mean
# separating-axis tests for a class of clash the generators cannot produce.

function abs2(v) { return v < 0 ? -v : v }

## Is this basis axis-aligned? True for identity and for yaws of 90/180/270,
## which is every box the generators emit through box() and pbox().
function axis_aligned(m,   i, j, seen, v) {
  for (i = 0; i < 3; i++) {
    seen = 0
    for (j = 0; j < 3; j++) {
      v = abs2(m[i, j])
      if (v > 0.999 && v < 1.001) seen++
      else if (v > 0.001) return 0
    }
    if (seen != 1) return 0
  }
  return 1
}

function attr(line, key,   s, e) {
  s = index(line, key "=\"");  if (!s) return ""
  s += length(key) + 2
  e = index(substr(line, s), "\"")
  return substr(line, s, e - 1)
}

BEGIN {
  EPS = 0.001          # how close two planes must be to count as one
  MIN_AREA = 0.004     # 64mm square: below this nobody will ever see it
  N = 0
}

/^\[node /{
  flush_node()
  NAME = attr($0, "name")
  PARENT = attr($0, "parent")
  TYPE = attr($0, "type")
  have_xf = 0; have_size = 0; is_cut = 0
  next
}

/^operation = 2/ { is_cut = 1; next }

/^transform = Transform3D\(/ {
  line = $0
  gsub(/^transform = Transform3D\(|\)$/, "", line)
  gsub(/ /, "", line)
  n = split(line, t, ",")
  if (n == 12) {
    for (i = 0; i < 3; i++)
      for (j = 0; j < 3; j++) B[i, j] = t[i * 3 + j + 1] + 0
    OX = t[10] + 0; OY = t[11] + 0; OZ = t[12] + 0
    have_xf = 1
  }
  next
}

/^size = Vector3\(/ {
  line = $0
  gsub(/^size = Vector3\(|\)$/, "", line)
  gsub(/ /, "", line)
  split(line, s, ",")
  SX = s[1] + 0; SY = s[2] + 0; SZ = s[3] + 0
  have_size = 1
  next
}

END {
  flush_node()
  report()
}

## Commits the node just parsed, if it was a usable box.
function flush_node(   hx, hy, hz, i) {
  if (TYPE != "CSGBox3D" || !have_xf || !have_size || is_cut) { TYPE = ""; return }
  if (!axis_aligned(B)) { TYPE = ""; return }

  # Half-extents in world axes: an axis-aligned basis just permutes them.
  hx = (abs2(B[0, 0]) * SX + abs2(B[0, 1]) * SY + abs2(B[0, 2]) * SZ) / 2
  hy = (abs2(B[1, 0]) * SX + abs2(B[1, 1]) * SY + abs2(B[1, 2]) * SZ) / 2
  hz = (abs2(B[2, 0]) * SX + abs2(B[2, 1]) * SY + abs2(B[2, 2]) * SZ) / 2

  N++
  LO[N, 0] = OX - hx; HI[N, 0] = OX + hx
  LO[N, 1] = OY - hy; HI[N, 1] = OY + hy
  LO[N, 2] = OZ - hz; HI[N, 2] = OZ + hz
  PATH[N] = (PARENT == "." ? "" : PARENT "/") NAME
  OWNER[N] = PARENT

  # Bucket every face by its plane, so the pair search never goes quadratic
  # over ten thousand boxes.
  for (i = 0; i < 3; i++) {
    key = i ":lo:" sprintf("%.3f", LO[N, i]); BUCKET[key] = BUCKET[key] " " N
    key = i ":hi:" sprintf("%.3f", HI[N, i]); BUCKET[key] = BUCKET[key] " " N
  }
  TYPE = ""
}

## Overlap of two boxes along one axis, negative when they do not touch.
function span(a, b, axis,   lo, hi) {
  lo = LO[a, axis] > LO[b, axis] ? LO[a, axis] : LO[b, axis]
  hi = HI[a, axis] < HI[b, axis] ? HI[a, axis] : HI[b, axis]
  return hi - lo
}

function report(   key, ids, n, i, j, a, b, axis, u, v, area, hits, seen) {
  hits = 0
  for (key in BUCKET) {
    n = split(BUCKET[key], ids, " ")
    if (n < 2) continue
    split(key, parts, ":")
    axis = parts[1] + 0
    u = (axis + 1) % 3
    v = (axis + 2) % 3

    # Undersides. Everything in the house stands on a floor, so the bottom
    # faces of the skirting, the door linings, the joists and the counters all
    # land on the same plane -- and every one of them is pressed against the
    # slab, pointing down, and never rasterised. Reporting them buried the
    # eleven clashes that mattered under a hundred and twenty that did not.
    if (axis == 1 && parts[2] == "lo") continue

    for (i = 1; i < n; i++)
      for (j = i + 1; j <= n; j++) {
        a = ids[i]; b = ids[j]
        # Same combiner: CSG unions them before anything is drawn.
        if (OWNER[a] == OWNER[b]) continue
        area = span(a, b, u) * span(a, b, v)
        if (span(a, b, u) <= EPS || span(a, b, v) <= EPS) continue
        if (area < MIN_AREA) continue
        pair = (a < b ? a "," b : b "," a)
        if (pair in seen) continue
        seen[pair] = 1
        hits++
        if (hits <= 500)
          printf "z-fight: %s\n         %s\n         coplanar on %s, %.3f m2 overlap\n",
                 PATH[a], PATH[b], substr("xyz", axis + 1, 1), area
      }
  }
  if (hits > 500) printf "... and %d more\n", hits - 40
  if (hits) printf "check_zfight: %d coplanar face pair(s)\n", hits
}
