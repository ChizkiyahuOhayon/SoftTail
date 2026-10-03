#!/usr/bin/env bash
# Compact meshes: cut one trained SoftTail model to 10/25/50/75 % of the published face
# budget, once by the peak rule and once by the integral, and score both cuts.
#
#   bash scripts/compact.sh <dataset_root> <scene> <out_root>
#
# Needs <out_root>/softtail__<scene> from `scripts/run_scene.sh softtail ...` (it keeps the
# pre-cleanup mesh). Writes <out_root>/compact__<scene>/b<F>/eval_{peak,integral}/result.json
# and prints one line per cut. Same mesh, same face count per pair: only which faces
# survive differs. Resumable.
set -uo pipefail
DATA_ROOT=${1:?dataset root}; SCENE=${2:?scene}; OUT_ROOT=${3:?output root}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
source "$REPO/sota/ensure_environment.sh"
PY=$MESH_SPLATTING_PYTHON
cd "$REPO"
case "$SCENE" in
  bicycle|flowers|garden|stump|treehill) IMAGES=images_4 ;;
  room|counter|kitchen|bonsai)           IMAGES=images_2 ;;
  *)                                     IMAGES=images ;;
esac
RUN="$OUT_ROOT/softtail__$SCENE"; OUT="$OUT_ROOT/compact__$SCENE"
[ -f "$RUN/cut/survival.json" ] || { echo "run scripts/run_scene.sh softtail first ($RUN/cut missing)"; exit 1; }
FULL=$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))["faces_kept"]["v1"])' "$RUN/cut/survival.json")
for F in 10 25 50 75; do
  CUT=$OUT/b$F
  [ -d "$CUT/matched_oats/point_cloud" ] || { rm -rf "$CUT"; mkdir -p "$OUT"
    "$PY" -u -m sota.survival_cleanup -s "$DATA_ROOT/$SCENE" -i $IMAGES --eval -m "$RUN" \
      --out "$CUT" --budget $((FULL * F / 100)) --quiet || { echo "FAIL cut $F"; continue; }; }
  for RULE in peak integral; do
    M=$CUT/$([ $RULE = peak ] && echo matched || echo matched_oats); O=$CUT/eval_$RULE
    [ -f "$O/DONE" ] && continue; rm -rf "$O"
    "$PY" -u -m sota.main_table_eval -s "$DATA_ROOT/$SCENE" -i $IMAGES --eval -m "$M" --scene "$SCENE" \
      --arm ours_quality --iteration 30000 --output "$O" --quiet > /dev/null || echo "FAIL eval $F $RULE"
  done
  "$PY" - "$CUT" "$F" <<'PY'
import json, sys
cut, f = sys.argv[1], sys.argv[2]
r = {k: json.load(open(f"{cut}/eval_{k}/result.json")) for k in ("peak", "integral")}
p, i = r["peak"]["metrics"]["psnr"], r["integral"]["metrics"]["psnr"]
print(f"{f:>3}% of the budget, {r['peak']['triangles']:,} faces: peak {p:.2f} dB, integral {i:.2f} dB ({i - p:+.2f})")
PY
done
