# Emits the body of ONE item scene, chosen by -v WHICH=<name>.
#
# Requires lib.awk and items.awk. gen_items.sh wraps the output in a .tscn
# header listing whichever materials actually got used, exactly as gen_props.sh
# does for the furniture.

BEGIN {
  if      (WHICH == "crowbar")    i_crowbar()
  else if (WHICH == "magnifier")  i_magnifier()
  else if (WHICH == "fuse")       i_fuse()
  else if (WHICH == "battery")    i_battery()
  else if (WHICH == "fuelcan")    i_fuelcan()
  else if (WHICH == "grimoire")   i_grimoire()
  else if (WHICH == "token")      i_token()

  # Four keys off one builder. The brass hall and store keys are the pair the
  # player is most likely to confuse, so they differ in bow size as well as in
  # ward count -- colour alone is not enough in a torch-lit corridor.
  else if (WHICH == "key_store")  i_key(0.062, 0.017, 2, "Mat_brass")
  else if (WHICH == "key_hall")   i_key(0.070, 0.021, 3, "Mat_brass")
  else if (WHICH == "key_study")  i_key(0.054, 0.015, 2, "Mat_steel")
  else if (WHICH == "key_bureau") i_key(0.034, 0.010, 1, "Mat_steel")

  else {
    printf "gen_items.awk: unknown item %s\n", WHICH > "/dev/stderr"
    exit 1
  }
}
