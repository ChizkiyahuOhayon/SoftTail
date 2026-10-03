#!/usr/bin/env bash
# Train, render and score Triangle Splatting+ with and without the integrated survival rule.
#
#   bash run_tsplus.sh <triangle-splatting2 checkout> <dataset root> <scene> <out dir>
#
# <dataset root> holds mipnerf360/<scene>, tandt/<scene> and db/<scene> (COLMAP layout).
# Both arms use the same binary; only --integrated_importance differs. Resumable: a
# finished arm has a DONE marker and is skipped.
set -uo pipefail
TSPLUS=$(cd "$1" && pwd); DATA=$(cd "$2" && pwd); SCENE=$3; OUT=$(mkdir -p "$4" && cd "$4" && pwd)
PY=${PYTHON:-python}

args_for() {
  case "$1" in
    bicycle|flowers|garden|stump|treehill) echo "-s $DATA/mipnerf360/$1 -i images_4" ;;
    room|counter|kitchen|bonsai)           echo "-s $DATA/mipnerf360/$1 -i images_2" ;;
    train|truck)                           echo "-s $DATA/tandt/$1" ;;
    drjohnson|playroom)                    echo "-s $DATA/db/$1" ;;
    *) echo "unknown scene $1" >&2; exit 2 ;;
  esac
}
indoor_for() {  # --indoor is a training option only; render.py does not accept it
  case "$1" in room|counter|kitchen|bonsai|drjohnson|playroom) echo "--indoor" ;; esac
}

run() {  # run <arm> [extra train args]
  local arm=$1; shift
  local model="$OUT/${arm}__${SCENE}"
  [ -f "$model/DONE" ] && { echo "== $arm/$SCENE done"; return 0; }
  rm -rf "$model"; mkdir -p "$model"
  # shellcheck disable=SC2046
  (cd "$TSPLUS" && START=$SECONDS &&
   "$PY" -u train.py $(args_for "$SCENE") $(indoor_for "$SCENE") -m "$model" --eval --quiet \
       --test_iterations -1 "$@" > "$model/train.log" 2>&1 &&
   echo $((SECONDS - START)) > "$model/train_seconds.txt" &&
   "$PY" -u render.py $(args_for "$SCENE") -m "$model" --eval --skip_train --iteration 30000 --quiet \
       > "$model/render.log" 2>&1 &&
   "$PY" -u metrics.py -m "$model" > "$model/metrics.log" 2>&1) &&
  test -s "$model/results.json" && echo complete > "$model/DONE" && echo "== $arm/$SCENE ok" ||
    { echo "FAILED $arm/$SCENE, see $model"; return 1; }
}

run tsplus
run tsplus_int --integrated_importance
"$PY" - "$OUT" "$SCENE" <<'PY'
import json, sys
out, scene = sys.argv[1], sys.argv[2]
rows = {}
for arm in ("tsplus", "tsplus_int"):
    r = json.load(open(f"{out}/{arm}__{scene}/results.json"))
    rows[arm] = next(iter(r.values()))
a, b = rows["tsplus"], rows["tsplus_int"]
print(f"{scene}: TS+ {a['PSNR']:.3f} -> {b['PSNR']:.3f} ({b['PSNR'] - a['PSNR']:+.3f} dB), "
      f"SSIM {a['SSIM']:.4f} -> {b['SSIM']:.4f}, LPIPS {a['LPIPS']:.4f} -> {b['LPIPS']:.4f}")
PY
