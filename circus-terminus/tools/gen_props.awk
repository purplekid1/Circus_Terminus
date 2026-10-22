# Emits the body of ONE prop scene, chosen by -v WHICH=<name>.
#
# Requires lib.awk and props.awk. gen_props.sh wraps the output in a .tscn
# header listing whichever materials actually got used.
#
# Everything is built at the origin facing -Z, because that is where an
# instanced scene's own transform puts it. Sizes are deliberately a short menu
# rather than free parameters: a house has three or four kinds of table in it,
# not seventeen, and fixed sizes are what make the scenes reusable at all.

BEGIN {
  P = "."

  # ---- seating ----
  if      (WHICH == "chair")            p_chair(P, 0, 0, 0, 0)
  else if (WHICH == "armchair")         p_armchair(P, 0, 0, 0, 0, "Mat_velvet")
  else if (WHICH == "armchair_cloth")   p_armchair(P, 0, 0, 0, 0, "Mat_cloth")
  else if (WHICH == "sofa")             p_sofa(P, 0, 0, 0, 0, 2.30, "Mat_velvet")

  # ---- casework ----
  else if (WHICH == "bookcase_tall")    p_bookcase(P, 0, 0, 0, 0, 3.20, 0.44, 2.60, 1)
  else if (WHICH == "bookcase_med")     p_bookcase(P, 0, 0, 0, 0, 3.00, 0.42, 2.20, 1)
  else if (WHICH == "bookcase_low")     p_bookcase(P, 0, 0, 0, 0, 2.40, 0.42, 1.90, 0)
  else if (WHICH == "wardrobe")         p_wardrobe(P, 0, 0, 0, 0)
  else if (WHICH == "dresser")          p_dresser(P, 0, 0, 0, 0, 1.40)
  else if (WHICH == "rack")             p_shelfrack(P, 0, 0, 0, 0, 3.00, 0.50)

  # ---- tables ----
  else if (WHICH == "table_dine")       p_table(P, 0, 0, 0, 0, 3.20, 1.30, 0.76)
  else if (WHICH == "table_work")       p_table(P, 0, 0, 0, 0, 2.30, 1.05, 0.86)
  else if (WHICH == "table_console")    p_table(P, 0, 0, 0, 0, 1.40, 0.50, 0.79)
  else if (WHICH == "table_small")      p_table(P, 0, 0, 0, 0, 0.95, 0.52, 0.70)
  else if (WHICH == "table_side")       p_table(P, 0, 0, 0, 0, 0.60, 0.55, 0.60)
  else if (WHICH == "table_low")        p_table(P, 0, 0, 0, 0, 1.10, 0.70, 0.46)
  else if (WHICH == "desk")             p_desk(P, 0, 0, 0, 0, 2.00, 1.00)

  # ---- beds ----
  else if (WHICH == "bed_poster")       p_bed(P, 0, 0, 0, 0, 1.80, 2.20, 1)
  else if (WHICH == "bed_plain")        p_bed(P, 0, 0, 0, 0, 1.70, 2.15, 0)
  else if (WHICH == "bed_small")        p_bed(P, 0, 0, 0, 0, 1.10, 1.80, 0)

  # ---- fixtures ----
  else if (WHICH == "washstand")        p_washstand(P, 0, 0, 0, 0)
  else if (WHICH == "piano")            p_piano(P, 0, 0, 0, 0)
  else if (WHICH == "range")            p_range(P, 0, 0, 0, 0)
  else if (WHICH == "sink")             p_sink(P, 0, 0, 0, 0)
  else if (WHICH == "clock")            p_clock(P, 0, 0, 0, 0)
  else if (WHICH == "pedestal")         p_pedestal(P, 0, 0, 0, 0)
  else if (WHICH == "bust")             p_pedestal(P, 0, 0, 0, 1)

  # ---- storage ----
  else if (WHICH == "crate_lg")         p_crate(P, 0, 0, 0, 0, 1.00)
  else if (WHICH == "crate_sm")         p_crate(P, 0, 0, 0, 0, 0.75)
  else if (WHICH == "barrel")           p_barrel(P, 0, 0, 0)

  # ---- light fittings (no collision: you should never bump a candle) ----
  else if (WHICH == "sconce")           p_sconce(P, 0, 0, 0, 0)
  else if (WHICH == "chandelier6")      p_chandelier(P, 0, 0, 0, 6)
  else if (WHICH == "chandelier5")      p_chandelier(P, 0, 0, 0, 5)
  else if (WHICH == "chandelier4")      p_chandelier(P, 0, 0, 0, 4)
  else if (WHICH == "oillamp")          p_oillamp(P, 0, 0, 0)
  else if (WHICH == "candlestick")      p_candlestick(P, 0, 0, 0, 0)
  else if (WHICH == "candlestick_tall") p_candlestick(P, 0, 0, 0, 1)
  else if (WHICH == "bookstack")        p_bookstack(P, 0, 0, 0, 0, 4)

  else {
    printf "gen_props.awk: unknown prop %s\n", WHICH > "/dev/stderr"
    exit 1
  }
}
