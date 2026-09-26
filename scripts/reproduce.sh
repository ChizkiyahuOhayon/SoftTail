#!/usr/bin/env bash
# Reproduce one benchmark of the paper end to end on a single GPU.
#
#   bash scripts/reproduce.sh mipnerf360   /data/mipnerf360    runs/m360
#   bash scripts/reproduce.sh tandt        /data/tandt         runs/tandt
#   bash scripts/reproduce.sh deepblending /data/deep_blending runs/db
#
# Trains the three methods on every scene of the benchmark (about 2 h per run on
# an A40), runs the equal-budget control on Mip-NeRF 360, and prints the tables.
# Interrupt it at any time: re-running resumes where it stopped.
set -euo pipefail

BENCH=${1:?usage: reproduce.sh <mipnerf360|tandt|deepblending> <dataset_root> <out_root>}
DATA_ROOT=${2:?dataset root}; OUT_ROOT=${3:?output root}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$BENCH" in
  mipnerf360)   SCENES=(bicycle flowers garden stump treehill room counter kitchen bonsai) ;;
  tandt)        SCENES=(train truck) ;;
  deepblending) SCENES=(drjohnson playroom) ;;
  *) echo "unknown benchmark '$BENCH'" >&2; exit 1 ;;
esac

for SCENE in "${SCENES[@]}"; do
  for METHOD in meshsplatting opacity_floor softtail; do
    bash "$HERE/run_scene.sh" "$METHOD" "$DATA_ROOT" "$SCENE" "$OUT_ROOT"
  done
  [ "$BENCH" = mipnerf360 ] && bash "$HERE/equal_budget.sh" "$DATA_ROOT" "$SCENE" "$OUT_ROOT"
done

python "$HERE/collect.py" "$OUT_ROOT" "${SCENES[@]}"
