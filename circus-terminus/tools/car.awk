# The car the character arrives in.
#
# Emitted into Scenes/car.tscn by gen_car.sh. Requires lib.awk and items.awk
# (for TR, which does two rotation axes at once -- a windscreen is raked and
# a wheel is laid on its side).
#
# A 1950s saloon in profile: long bonnet, upright cabin, separate wings over
# the wheels and a boot. It is only ever seen from outside, at night, at
# fifteen metres, in a cutscene -- so it is shaped for its SILHOUETTE and its
# lights, and there is no interior.
#
# Built facing -Z, nose first, origin between the front wheels at road level,
# so a script can drive it along a road by moving it and pointing it.

function CARW()  { return 1.86 }   # body width
function CARL()  { return 4.90 }   # bumper to bumper
function WHEELR(){ return 0.36 }
function TRACK() { return 0.80 }   # half the distance between the wheels

## `zz` runs 0 at the nose to CARL() at the tail, which is easier to lay a car
## out in than signed offsets from the middle.
function cz(zz) { return -CARL() / 2 + zz }

function c_wheel(name, zz, side,   x) {
  x = side * TRACK()
  # laid on its side: rz=90 puts the cylinder axis along X
  icyl(name, x, WHEELR(), cz(zz), WHEELR(), 0.24, "Mat_tyre", 16, 0, 0, 90, "")
  icyl(name "Hub", x + side * 0.055, WHEELR(), cz(zz), WHEELR() * 0.54, 0.16,
       "Mat_chrome", 14, 0, 0, 90, "")
  icyl(name "Cap", x + side * 0.10, WHEELR(), cz(zz), WHEELR() * 0.22, 0.10,
       "Mat_chrome", 10, 0, 0, 90, "")
}

function c_arch(name, zz, side,   x) {
  # A wing over each wheel, as a wide flattened cylinder. Separate wings are
  # the single detail that dates the shape: a modern car has none.
  x = side * (TRACK() + 0.02)
  icyl(name, x, WHEELR() + 0.06, cz(zz), WHEELR() + 0.20, 0.30,
       "Mat_carpaint", 14, 0, 0, 90, "")
}

function c_car(   i, y) {
  # ---- body ----
  # sills and the main tub
  ibox("Sill", 0, 0.30, cz(CARL() / 2), CARW() - 0.10, 0.22, CARL() - 0.45, "Mat_carpaint", 0, 0, 0, "")
  ibox("Tub", 0, 0.56, cz(CARL() / 2), CARW(), 0.42, CARL() - 0.30, "Mat_carpaint", 0, 0, 0, "")
  ibox("Waist", 0, 0.86, cz(CARL() / 2), CARW() - 0.04, 0.24, CARL() - 0.55, "Mat_carpaint", 0, 0, 0, "")

  # bonnet, falling away towards the nose
  ibox("Bonnet", 0, 0.99, cz(1.05), CARW() - 0.18, 0.16, 1.85, "Mat_carpaint", -3, 0, 0, "")
  ibox("Nose", 0, 0.84, cz(0.14), CARW() - 0.30, 0.42, 0.34, "Mat_carpaint", 0, 0, 0, "")
  # boot
  ibox("Boot", 0, 1.00, cz(4.28), CARW() - 0.22, 0.18, 1.05, "Mat_carpaint", 4, 0, 0, "")

  # ---- cabin ----
  ibox("Cabin", 0, 1.28, cz(2.85), CARW() - 0.22, 0.46, 1.70, "Mat_carpaint", 0, 0, 0, "")
  ibox("Roof", 0, 1.52, cz(2.90), CARW() - 0.30, 0.10, 1.66, "Mat_carpaint", 0, 0, 0, "")
  # raked screens
  ibox("Screen", 0, 1.30, cz(1.98), CARW() - 0.34, 0.60, 0.06, "Mat_carglass", 28, 0, 0, "")
  ibox("Rear", 0, 1.32, cz(3.74), CARW() - 0.36, 0.52, 0.06, "Mat_carglass", -26, 0, 0, "")
  for (i = -1; i <= 1; i += 2) {
    ibox("SideGlass", i * (CARW() / 2 - 0.13), 1.31, cz(2.88), 0.05, 0.40, 1.44,
         "Mat_carglass", 0, 0, 0, "")
    ibox("Pillar", i * (CARW() / 2 - 0.12), 1.30, cz(3.62), 0.07, 0.44, 0.12,
         "Mat_carpaint", 0, 0, 0, "")
  }

  # ---- wheels and wings ----
  c_wheel("WheelFront", 1.05, -1); c_wheel("WheelFront", 1.05, 1)
  c_wheel("WheelRear", 3.85, -1);  c_wheel("WheelRear", 3.85, 1)
  c_arch("WingFront", 1.05, -1);   c_arch("WingFront", 1.05, 1)
  c_arch("WingRear", 3.85, -1);    c_arch("WingRear", 3.85, 1)

  # ---- brightwork ----
  ibox("Grille", 0, 0.80, cz(-0.02), CARW() - 0.52, 0.34, 0.10, "Mat_chrome", 0, 0, 0, "")
  for (i = 0; i < 5; i++)
    ibox("GrilleBar", 0, 0.68 + i * 0.06, cz(-0.06), CARW() - 0.46, 0.025, 0.06,
         "Mat_chrome", 0, 0, 0, "")
  ibox("BumperF", 0, 0.52, cz(-0.10), CARW() - 0.06, 0.14, 0.14, "Mat_chrome", 0, 0, 0, "")
  ibox("BumperR", 0, 0.54, cz(CARL() + 0.06), CARW() - 0.06, 0.14, 0.14, "Mat_chrome", 0, 0, 0, "")
  ibox("Strip", 0, 0.80, cz(CARL() / 2), CARW() + 0.02, 0.035, CARL() - 0.9, "Mat_chrome", 0, 0, 0, "")

  # ---- lamps ----
  # The headlamps are the whole point of the arrival shot, so they are proper
  # emissive discs with a chrome bezel rather than a painted-on rectangle.
  for (i = -1; i <= 1; i += 2) {
    icyl("HeadlampRim", i * 0.62, 0.86, cz(-0.04), 0.17, 0.12, "Mat_chrome", 14, 90, 0, 0, "")
    icyl("Headlamp", i * 0.62, 0.86, cz(-0.10), 0.135, 0.10, "Mat_lamp", 14, 90, 0, 0, "")
    icyl("TailRim", i * 0.66, 0.86, cz(CARL() + 0.02), 0.085, 0.10, "Mat_chrome", 10, 90, 0, 0, "")
    icyl("Taillamp", i * 0.66, 0.86, cz(CARL() + 0.06), 0.062, 0.08, "Mat_taillamp", 10, 90, 0, 0, "")
  }

  # mirrors, and an aerial, because a silhouette needs something breaking its
  # top edge or it reads as a bar of soap
  for (i = -1; i <= 1; i += 2)
    ibox("Mirror", i * (CARW() / 2 + 0.06), 1.22, cz(2.05), 0.16, 0.09, 0.07,
         "Mat_chrome", 0, 0, 0, "")
  icyl("Aerial", CARW() / 2 - 0.12, 1.42, cz(2.10), 0.012, 1.00, "Mat_chrome", 4, 12, 0, 0, "")
}
