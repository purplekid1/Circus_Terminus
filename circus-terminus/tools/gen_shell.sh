#!/usr/bin/env bash
# Emits the mansion shell. Columns: kind name x y z sx sy sz material
#   u = union, c = cut
#
# Per-box materials rather than one override on the combiner, so floors read
# as boards, walls as plaster and the outside as siding. Outer walls are two
# skins for that reason -- siding facing out, plaster facing in.

emit() {
  while read -r kind name x y z sx sy sz mat; do
    [ -z "$kind" ] && continue
    case "$kind" in \#*) continue ;; esac
    echo ""
    echo "[node name=\"$name\" type=\"CSGBox3D\" parent=\"Shell\"]"
    echo "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, $x, $y, $z)"
    [ "$kind" = "c" ] && echo "operation = 2"
    [ -n "$mat" ] && [ "$kind" = "u" ] && echo "material = ExtResource(\"$mat\")"
    echo "size = Vector3($sx, $sy, $sz)"
  done
}

printf '\n[node name="Shell" type="CSGCombiner3D" parent="."]\nuse_collision = true\n'

emit <<'TABLE'
# ---- slabs ---------------------------------------------------------------
u SlabBasement     0   -3.7  -17    34    0.2   34    Mat_stone
u SlabGround       0   -0.1  -17    34    0.2   34    Mat_floor
u SlabUpper        0    3.5  -17    34    0.2   34    Mat_floor
u SlabRoof         0    7.1  -17    34    0.2   34    Mat_shell
# ---- outer walls: siding outside, plaster inside -------------------------
u SkinFrontOut     0    1.7    0.1  34   10.6    0.2  Mat_siding
u SkinFrontIn      0    1.7   -0.1  34   10.6    0.2  Mat_shell
u SkinBackOut      0    1.7  -34.1  34   10.6    0.2  Mat_siding
u SkinBackIn       0    1.7  -33.9  34   10.6    0.2  Mat_shell
u SkinWestOut    -17.1  1.7  -17     0.2 10.6   34    Mat_siding
u SkinWestIn     -16.9  1.7  -17     0.2 10.6   34    Mat_shell
u SkinEastOut     17.1  1.7  -17     0.2 10.6   34    Mat_siding
u SkinEastIn      16.9  1.7  -17     0.2 10.6   34    Mat_shell
# ---- gables, trimmed to the roof pitch by the cuts further down ----------
u GableWest      -17    11.2 -17     0.36  8     34   Mat_siding
u GableEast       17    11.2 -17     0.36  8     34   Mat_siding
# ---- ground floor --------------------------------------------------------
u GF_HallWest     -7    1.7  -11     0.3   3.4   22   Mat_shell
u GF_HallEast      7    1.7  -11     0.3   3.4   22   Mat_shell
u GF_EastMid      12    1.7  -11    10     3.4    0.3 Mat_shell
u GF_WestMid     -12    1.7  -11    10     3.4    0.3 Mat_shell
u GF_Rear1         0    1.7  -22    34     3.4    0.3 Mat_shell
u GF_Rear2         0    1.7  -26    34     3.4    0.3 Mat_shell
u GF_BackDiv      -2    1.7  -30     0.3   3.4    8   Mat_shell
# ---- upper floor ---------------------------------------------------------
u UF_LandWest     -7    5.3  -11     0.3   3.4   22   Mat_shell
u UF_LandEast      7    5.3  -11     0.3   3.4   22   Mat_shell
u UF_EastMid      12    5.3  -11    10     3.4    0.3 Mat_shell
u UF_WestMid     -12    5.3  -11    10     3.4    0.3 Mat_shell
u UF_Rear1         0    5.3  -22    34     3.4    0.3 Mat_shell
u UF_StudyBack     0    5.3  -30    14.4   3.4    0.3 Mat_shell
u UF_StudyWest    -7    5.3  -26     0.3   3.4    8   Mat_shell
u UF_StudyEast     7    5.3  -26     0.3   3.4    8   Mat_shell
# ---- basement ------------------------------------------------------------
# Runs the FULL depth now -- front wall to the inner face of the back wall at
# z=-33.8 -- not stopping at z=-28 as it used to. Those last six metres were
# open right across x=0, which was the second way round to the generator and
# the reason the iron gate at z=-31 could simply be walked around. The gate's
# own opening is cut back out of it below.
u BS_Mid           0   -1.9  -16.9   0.3   3.4   33.8 Mat_stone
u BS_Cross         0   -1.9  -22    34     3.4    0.3 Mat_stone
# ---- skirting, so wall meets floor with a line instead of a seam ---------
u SkirtHallW      -6.8  0.08 -11     0.12  0.16  22   Mat_trim
u SkirtHallE       6.8  0.08 -11     0.12  0.16  22   Mat_trim
u SkirtFront       0    0.08  -0.25 34     0.16   0.12 Mat_trim
u SkirtRear        0    0.08 -21.8  34     0.16   0.12 Mat_trim
u SkirtUpW        -6.8  3.68 -11     0.12  0.16  22   Mat_trim
u SkirtUpE         6.8  3.68 -11     0.12  0.16  22   Mat_trim
# ---- stairwells ----------------------------------------------------------
c CutMainWell      0    3.5  -10     5     0.8   12.4
c CutCellarWell   12   -0.1  -30     4.4   0.8    6.4
# ---- roof planes ---------------------------------------------------------
# These two live outside the table because they have to be ROTATED, and
# emit() only writes axis-aligned boxes. See the cutslab() calls below the
# table for what they are and why the axis-aligned version was wrong.
# ---- ground floor doorways ----------------------------------------------
c CutFrontDoor     0    1.075   0    1.2   2.15   1.4
c CutBackDoor      8    1.075 -34    1.2   2.15   1.4
c CutHallLiving    7    1.075  -5    1.4   2.15   1.2
c CutHallLibrary  -7    1.075  -5    1.4   2.15   1.2
c CutHallDining    7    1.075 -17    1.4   2.15   1.2
c CutHallKitchen  -7    1.075 -17    1.4   2.15   1.2
c CutHallRear      0    1.075 -22    1.2   2.15   1.4
c CutDiningRear   12    1.075 -22    1.2   2.15   1.4
c CutKitchenRear -12    1.075 -22    1.2   2.15   1.4
c CutRearScullery -9    1.075 -26    1.2   2.15   1.4
c CutRearBoot      8    1.075 -26    1.2   2.15   1.4
# ---- upper doorways ------------------------------------------------------
c CutStudyDoor     0    4.675 -22    1.2   2.15   1.4
c CutLandBed1      7    4.675  -5    1.4   2.15   1.2
c CutLandOffice    7    4.675 -17    1.4   2.15   1.2
c CutLandBed2     -7    4.675  -5    1.4   2.15   1.2
c CutLandNursery  -7    4.675 -17    1.4   2.15   1.2
# ---- basement openings ---------------------------------------------------
c CutCellarDoor  -10   -2.525 -34    1.4   2.15   1.4
# The iron gate stands in the mid wall here, so this IS its doorway. 4.4 wide
# against the gate's 4.6 jamb-to-jamb, so its two fixed side panels bury 0.1 m
# into the masonry rather than meeting it face to face -- flush faces in the
# same plane are what check_zfight.awk exists to complain about.
#
# z is -30.99, not -31: that is where the gate actually sits in mansion.tscn
# after being placed by hand. Match the scene rather than rounding it, or the
# jamb and the panel end up 9 mm apart on one side.
c CutCellarGate    0   -2.525 -30.99 1.4   2.15   4.4
c CutBasementMid   0   -2.525 -14    1.4   2.15   1.2
c CutBasementCross2 -9 -2.525 -22    1.2   2.15   1.4
# CutBasementMid2 (0, -26) and CutBasementCross (9, -22) are DELIBERATELY GONE.
# Between them they made the cellar a ring, with two ways round to the
# generator and a five-metre bypass of the gate:
#
#   Mid2   let you cross x=0 five metres south of the gate, so the gate barred
#          nothing at all.
#   Cross  joined the north-east quarter straight down to the generator, which
#          was the short second path.
#
# What is left is one route -- in at the cellar door, west and south through
# CutBasementCross2, then east through CutBasementMid to the generator -- and
# one locked gate standing between that route and the stairs up to the house.
# ---- windows -------------------------------------------------------------
c WinFrontE1      11    1.9    0     1.6   2.0    1.4
c WinFrontW1     -11    1.9    0     1.6   2.0    1.4
c WinFrontE2      11    5.5    0     1.6   2.0    1.4
c WinFrontW2     -11    5.5    0     1.6   2.0    1.4
c WinEastA        17    1.9   -6     1.4   2.0    1.6
c WinEastB        17    1.9  -17     1.4   2.0    1.6
c WinEastC        17    5.5   -6     1.4   2.0    1.6
c WinEastD        17    5.5  -17     1.4   2.0    1.6
c WinWestA       -17    1.9   -6     1.4   2.0    1.6
c WinWestB       -17    1.9  -17     1.4   2.0    1.6
c WinWestC       -17    5.5   -6     1.4   2.0    1.6
c WinWestD       -17    5.5  -17     1.4   2.0    1.6
c WinBackA        -8    5.5  -34     1.6   2.0    1.4
c WinBackB         2    5.5  -34     1.6   2.0    1.4
TABLE

# ---- the roof planes, as CUTTERS -----------------------------------------
#
# Everything the Shell puts above the roof is sliced off along the roof's own
# pitch. This has to be a rotated box, which is why it is here and not in the
# table above: emit() writes an axis-aligned Transform3D, so the previous
# version of these two could only cut a HORIZONTAL plane at y=10.203.
#
# The result was that the gable walls, which run the full 34m length of the
# house from y=7.2 to y=15.2, came out flat-topped at 10.203 instead of cut
# to a triangle. The roof surface is only above 10.203 between z=-27.6 and
# z=-6.4, so outside that the gable stood proud of the roof -- three metres
# of bare wall sticking out of the tiles at all four corners of the house.
#
# Geometry: the roof slabs are pitched 25.2 degrees about X, ridge on z=-17.
# Each cutter shares its slab's basis and is pushed 7.25m along that slab's
# own normal, so its underside lands exactly on the slab's top face and it
# extends well clear above.
#
# They are 24 long against the slabs' 20.79, which overhangs both ends. Past
# the RIDGE that is harmless: an extended south plane keeps climbing while
# the north roof descends, so it stays above it. Past the EAVE it continues
# down to y~5.7 at z=3.15, which clears the porch roof at 3.5.
cutslab() { # name basis x y z sx sy sz
  echo ""
  echo "[node name=\"$1\" type=\"CSGBox3D\" parent=\"Shell\"]"
  echo "transform = Transform3D($2, $3, $4, $5)"
  echo "operation = 2"
  echo "size = Vector3($6, $7, $8)"
}
cutslab CutRoofSouth "1, 0, 0, 0, 0.9047, -0.4257, 0, 0.4257, 0.9047" \
        0 17.108 -4.616   44 14 24
cutslab CutRoofNorth "1, 0, 0, 0, 0.9047, 0.4257, 0, -0.4257, 0.9047" \
        0 17.108 -29.384  44 14 24
