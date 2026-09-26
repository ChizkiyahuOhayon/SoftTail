#!/usr/bin/env bash
# Re-cut a trained SoftTail run to the opacity-floor run's exact face count and
# score it: the "gain is not extra capacity" control. Evaluation only.
#
#   bash scripts/equal_budget.sh <dataset_root> <scene> <out_root>
set -euo pipefail

DATA_ROOT=${1:?dataset root}; SCENE=${2:?scene}; OUT_ROOT=${3:?output root}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
source "$REPO/sota/ensure_environment.sh"
PY=$MESH_SPLATTING_PYTHON

case "$SCENE" in
  bicycle|flowers|garden|stump|treehill) IMAGES=images_4 ;;
  room|counter|kitchen|bonsai)           IMAGES=images_2 ;;
  *) IMAGES=images ;;
esac
RUN="$OUT_ROOT/softtail__${SCENE}"
CONTROL="$OUT_ROOT/opacity_floor__${SCENE}/eval_quality/result.json"
OUTPUT="$RUN/eval_equal_budget"
[ -f "$OUTPUT/DONE" ] && exit 0

BUDGET=$("$PY" -c 'import json, sys; print(json.load(open(sys.argv[1]))["triangles"])' "$CONTROL")
cd "$REPO"
[ -d "$RUN/cut_matched/matched_oats" ] || { rm -rf "$RUN/cut_matched"; \
  "$PY" -u -m sota.survival_cleanup -s "$DATA_ROOT/$SCENE" -i "$IMAGES" --eval \
    -m "$RUN" --out "$RUN/cut_matched" --budget "$BUDGET"; }
rm -rf "$OUTPUT"
"$PY" -u -m sota.main_table_eval -s "$DATA_ROOT/$SCENE" -i "$IMAGES" --eval \
  -m "$RUN/cut_matched/matched_oats" --scene "$SCENE" --arm ours_quality \
  --iteration 30000 --output "$OUTPUT"
