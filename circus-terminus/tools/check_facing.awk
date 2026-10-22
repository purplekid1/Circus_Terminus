# Warns about prop instances that face into a wall.
#
# Props are modelled facing +Z (props.awk), so an instance's world facing is the
# Z column of its basis. A prop standing against a wall should have its BACK to
# it; if the space just in front of it is solid, the yaw is a quarter or a half
# turn out. Sixteen of them were, and the only way to notice was to walk the
# house and look at a bookcase's back panel.
#
# Reads an assembled .tscn on stdin. Advisory only -- a prop deliberately close
# to a wall and facing it (a chair pushed under a shelf) will show up too.

BEGIN {
  # Props with no meaningful front. A barrel has no back to put against a wall,
  # and a table against a wall facing it is just a table against a wall.
  split("pf_oillamp pf_candlestick pf_candlestick_tall pf_bookstack pf_barrel " \
        "pf_crate_lg pf_crate_sm pf_pedestal pf_bust pf_rack pf_chandelier4 " \
        "pf_chandelier5 pf_chandelier6 pf_table_dine pf_table_work " \
        "pf_table_console pf_table_small pf_table_side pf_table_low", s, " ")
  for (i in s) if (s[i] != "") SYM[s[i]] = 1
}

function nums(line,  s, p, q) {
  p = index(line, "("); q = index(line, ")")
  s = substr(line, p + 1, q - p - 1); gsub(/ /, "", s); return s
}

/^\[node /{
  name = ""; par = ""; res = ""
  if (match($0, /name="[^"]*"/))   name = substr($0, RSTART + 6, RLENGTH - 7)
  if (match($0, /parent="[^"]*"/)) par  = substr($0, RSTART + 8, RLENGTH - 9)
  if (match($0, /instance=ExtResource\("pf_[^"]*"\)/))
    res = substr($0, RSTART + 22, RLENGTH - 24)
  isprop = (res != "" && !(res in SYM))
  isshell = (par == "Shell" && $0 ~ /type="CSGBox3D"/)
  pend = 0; cut = 0
  next
}

/^operation = 2/ { cut = 1; next }

/^transform = Transform3D\(/ {
  if (!isprop && !isshell) next
  split(nums($0), a, ",")
  tx = a[10] + 0; ty = a[11] + 0; tz = a[12] + 0
  if (isprop) {
    # facing = the basis Z column, which the file stores row-major
    P[++NP] = name; PX[NP] = tx; PY[NP] = ty; PZ[NP] = tz
    FX[NP] = a[3] + 0; FZ[NP] = a[9] + 0; PR[NP] = res
  } else {
    pend = 1
  }
  next
}

/^size = Vector3\(/ {
  if (!isshell || !pend || cut) { pend = 0; next }
  split(nums($0), b, ",")
  NW++
  WX0[NW] = tx - b[1] / 2; WX1[NW] = tx + b[1] / 2
  WY0[NW] = ty - b[2] / 2; WY1[NW] = ty + b[2] / 2
  WZ0[NW] = tz - b[3] / 2; WZ1[NW] = tz + b[3] / 2
  pend = 0
}

function solid(x, y, z,   i) {
  for (i = 1; i <= NW; i++)
    if (x > WX0[i] && x < WX1[i] && y > WY0[i] && y < WY1[i] && z > WZ0[i] && z < WZ1[i])
      return 1
  return 0
}

END {
  for (i = 1; i <= NP; i++) {
    hit = 0
    for (d = 0.30; d <= 0.75; d += 0.15)
      if (solid(PX[i] + FX[i] * d, PY[i] + 1.0, PZ[i] + FZ[i] * d)) hit = 1
    if (hit)
      printf "facing: %s (%s) at %.2f,%.2f faces a wall\n", P[i], PR[i], PX[i], PZ[i]
  }
  if (NP == 0) print "facing: no prop instances found -- check ran against the wrong file"
}
