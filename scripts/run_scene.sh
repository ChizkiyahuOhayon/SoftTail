#!/usr/bin/env bash
# Train, cut and evaluate one method on one scene.
#
#   bash scripts/run_scene.sh <method> <dataset_root> <scene> <out_root>
#
# <method> is one of
#   meshsplatting   the published baseline (terminal opacity 0.9999)
#   opacity_floor   + terminal opacity 0.8 with tail absorption      (ablation row)
#   softtail        + integrated survival in training and cleanup    (ours)
#
# Every evaluation writes <out_root>/<method>__<scene>/eval_<arm>/result.json,
# which scripts/collect.py turns into the paper's tables. Re-running the script
# skips every step that already finished.
set -euo pipefail

METHOD=${1:?usage: run_scene.sh <method> <dataset_root> <scene> <out_root>}
DATA_ROOT=${2:?dataset root}
SCENE=${3:?scene}
OUT_ROOT=${4:?output root}

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
source "$REPO/sota/ensure_environment.sh"
PY=$MESH_SPLATTING_PYTHON

case "$SCENE" in
  bicycle|flowers|garden|stump|treehill) IMAGES=images_4 ;;
  room|counter|kitchen|bonsai)           IMAGES=images_2 ;;
  train|truck|drjohnson|playroom)        IMAGES=images ;;
  *) echo "unknown scene '$SCENE'" >&2; exit 1 ;;
esac

export DATA_ROOT RUNS="$OUT_ROOT"
RUN="$OUT_ROOT/${METHOD}__${SCENE}"
DATA=(-s "$DATA_ROOT/$SCENE" -i "$IMAGES" --eval)

evaluate() {  # evaluate <model dir> <arm> <output name>
  local output="$RUN/$3"
  [ -f "$output/DONE" ] && return 0
  rm -rf "$output"
  (cd "$REPO" && "$PY" -u -m sota.main_table_eval "${DATA[@]}" -m "$1" \
      --scene "$SCENE" --arm "$2" --iteration 30000 --output "$output")
}

cd "$REPO"
case "$METHOD" in
  meshsplatting)
    bash sota/run.sh "$METHOD" "$SCENE"
    evaluate "$RUN" stock eval_stock
    ;;
  opacity_floor)
    bash sota/run.sh "$METHOD" "$SCENE" --final_opacity 0.8
    evaluate "$RUN" ours_quality eval_quality
    evaluate "$RUN" ours_speed eval_speed
    ;;
  softtail)
    bash sota/run.sh "$METHOD" "$SCENE" --final_opacity 0.8 \
      --integrated_importance --save_precleanup
    # The final cleanup, re-done offline on the saved pre-cleanup state: cut/oats
    # keeps faces by the integral, cut/v1 by the published peak rule, at the
    # same face count.
    [ -f "$RUN/cut/survival.json" ] || { rm -rf "$RUN/cut"; \
      "$PY" -u -m sota.survival_cleanup "${DATA[@]}" -m "$RUN" --out "$RUN/cut"; }
    evaluate "$RUN/cut/oats" ours_quality eval_quality
    evaluate "$RUN/cut/oats" ours_speed eval_speed
    evaluate "$RUN/cut/v1" ours_quality eval_train_only
    ;;
  *) echo "unknown method '$METHOD'" >&2; exit 1 ;;
esac
echo "== $METHOD/$SCENE done: $RUN"
