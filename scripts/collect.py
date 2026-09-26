"""Print the paper's tables from the result.json files that run_scene.sh wrote.

    python scripts/collect.py <out_root> <scene> [<scene> ...]
"""

import json
import sys
from pathlib import Path

# (row label, run directory prefix, evaluation name)
ROWS = (
    ("MeshSplatting", "meshsplatting", "eval_stock"),
    ("+ opacity floor", "opacity_floor", "eval_quality"),
    ("+ integral in training", "softtail", "eval_train_only"),
    ("SoftTail (quality)", "softtail", "eval_quality"),
    ("SoftTail (speed)", "softtail", "eval_speed"),
    ("SoftTail, equal budget", "softtail", "eval_equal_budget"),
)
METRICS = (("PSNR", "psnr", "{:.2f}"), ("SSIM", "ssim", "{:.3f}"),
           ("LPIPS", "lpips_vgg", "{:.3f}"), ("FPS", "fps", "{:.1f}"))


def load(root, method, name, scene):
    path = root / f"{method}__{scene}" / name / "result.json"
    return json.loads(path.read_text()) if path.is_file() else None


def main():
    root, scenes = Path(sys.argv[1]), sys.argv[2:]
    header = "| Method | " + " | ".join(m for m, _, _ in METRICS) + " | Faces |"
    print(header)
    print("|---" + "|---:" * (len(METRICS) + 1) + "|")
    for label, method, name in ROWS:
        results = [load(root, method, name, scene) for scene in scenes]
        if any(r is None for r in results):
            continue  # not run for this benchmark (e.g. equal budget off M360)
        cells = [fmt.format(sum(r["metrics"][key] for r in results) / len(results))
                 for _, key, fmt in METRICS]
        faces = sum(r["triangles"] for r in results) / len(results)
        print(f"| {label} | " + " | ".join(cells) + f" | {faces / 1e6:.2f}M |")

    print("\nPer-scene PSNR")
    print("| Scene | " + " | ".join(label for label, _, _ in ROWS) + " |")
    print("|---" + "|---:" * len(ROWS) + "|")
    for scene in scenes:
        cells = []
        for _, method, name in ROWS:
            result = load(root, method, name, scene)
            cells.append("—" if result is None else f"{result['metrics']['psnr']:.2f}")
        print(f"| {scene} | " + " | ".join(cells) + " |")


if __name__ == "__main__":
    main()
