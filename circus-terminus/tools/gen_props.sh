#!/usr/bin/env bash
# Writes Scenes/props/*.tscn -- one reusable scene per repeated piece of
# furniture, each a CSGCombiner3D whose children merge into a single mesh.
#
# These used to be emitted inline, so the house carried sixteen separate copies
# of a bookcase and seventeen of a table. Now mansion.tscn instances them, which
# means editing a bookcase is one file instead of sixteen search-and-replaces,
# and swapping a primitive prop for a modelled mesh later is a per-prop job
# rather than a scene-wide one.
#
# Collision lives on the combiner, so a prop is one static body. Light fittings
# are built without it: nobody should collide with a candle flame.
#

set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Scenes/props
mkdir -p "$OUT"

AWK=${AWK:-awk}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# id                which              root node name     collide
CATALOGUE='
pf_chair            chair              Chair              1
pf_armchair         armchair           Armchair           1
pf_armchair_cloth   armchair_cloth     ArmchairCloth      1
pf_sofa             sofa               Sofa               1
pf_bookcase_tall    bookcase_tall      BookcaseTall       1
pf_bookcase_med     bookcase_med       BookcaseMed        1
pf_bookcase_low     bookcase_low       BookcaseLow        1
pf_wardrobe         wardrobe           Wardrobe           1
pf_dresser          dresser            Dresser            1
pf_rack             rack               ShelfRack          1
pf_table_dine       table_dine         TableDining        1
pf_table_work       table_work         TableWork          1
pf_table_console    table_console      TableConsole       1
pf_table_small      table_small        TableSmall         1
pf_table_side       table_side         TableSide          1
pf_table_low        table_low          TableLow           1
pf_desk             desk               Desk               1
pf_bed_poster       bed_poster         BedFourPoster      1
pf_bed_plain        bed_plain          BedPlain           1
pf_bed_small        bed_small          BedSmall           1
pf_washstand        washstand          Washstand          1
pf_piano            piano              Piano              1
pf_range            range              Range              1
pf_sink             sink               Sink               1
pf_clock            clock              LongCaseClock      1
pf_pedestal         pedestal           Pedestal           1
pf_bust             bust               PedestalBust       1
pf_crate_lg         crate_lg           CrateLarge         1
pf_crate_sm         crate_sm           CrateSmall         1
pf_barrel           barrel             Barrel             1
pf_sconce           sconce             Sconce             0
pf_chandelier6      chandelier6        Chandelier6        0
pf_chandelier5      chandelier5        Chandelier5        0
pf_chandelier4      chandelier4        Chandelier4        0
pf_oillamp          oillamp            OilLamp            0
pf_candlestick      candlestick        Candlestick        0
pf_candlestick_tall candlestick_tall   CandlestickTall    0
pf_bookstack        bookstack          BookStack          0
'

count=0
while read -r id which root collide; do
  [ -z "$id" ] && continue
  case "$id" in \#*) continue ;; esac

  "$AWK" -f tools/lib.awk -f tools/props.awk -v WHICH="$which" -f tools/gen_props.awk > "$TMP/body"

  # Only list materials the prop actually uses, so the editor does not prune
  # dead ext_resources out from under the generator.
  mats=$(grep -o 'ExtResource("Mat_[A-Za-z0-9_]*")' "$TMP/body" \
         | sed 's/ExtResource("//;s/")//' | sort -u)
  steps=$(printf '%s\n' "$mats" | grep -c . || true)

  {
    echo "[gd_scene load_steps=$((steps + 1)) format=3]"
    echo
    for m in $mats; do
      echo "[ext_resource type=\"Material\" path=\"res://Materials/$m.tres\" id=\"$m\"]"
    done
    echo
    echo "[node name=\"$root\" type=\"CSGCombiner3D\"]"
    [ "$collide" = "1" ] && echo 'use_collision = true'
    cat "$TMP/body"
  } > "$OUT/$id.tscn"

  count=$((count + 1))
done <<EOF
$CATALOGUE
EOF

printf 'wrote %d prop scenes to %s/\n' "$count" "$OUT"
