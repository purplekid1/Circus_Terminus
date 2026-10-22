#!/usr/bin/env bash
# Writes the three model-backed bookcase props. See tools/bookcase.awk for what
# the numbers mean; the sizes here are the OUTER dimensions of the CSG props in
# Scenes/props/pf_bookcase_{low,med,tall}.tscn that these replace.
set -euo pipefail
cd "$(dirname "$0")/.."
AWK=${AWK:-awk}

# The books meshes are baked per size by tools/bake_bookshelf.gd -- re-run
# that if the model changes, or these will point at stale geometry.
emit() { # size name W H D
  "$AWK" -v SIZE="$1" -v NAME="$2" -v W="$3" -v H="$4" -v D="$5" -f tools/bookcase.awk \
    > "Scenes/props/pf_bookcase_model_$1.tscn"
}

emit low  BookcaseModelLow  2.4 1.9 0.42
emit med  BookcaseModelMed  3.0 2.2 0.42
emit tall BookcaseModelTall 3.2 2.6 0.44

echo "wrote 3 bookcase props to Scenes/props/"
