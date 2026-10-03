# The survival rule inside Triangle Splatting+

Triangle Splatting+ prunes its triangles by the same peak blending weight as
MeshSplatting. These two patches add the integrated accumulator `S_f = Σ α·T`
next to its `atomicMax` and a flag `--integrated_importance`: every pruning step
still deletes the number of triangles the published rule would delete, but
deletes the ones with the lowest `S_f`. Densification, the opacity schedule and
all hyperparameters are untouched.

| Mip-NeRF 360 (9 scenes) | PSNR ↑ | SSIM ↑ | LPIPS ↓ | Triangles |
|---|---:|---:|---:|---:|
| Triangle Splatting+ (retrained) | 25.20 | 0.750 | 0.291 | 1.29M |
| **+ integrated survival** | **25.54** | **0.760** | **0.272** | **1.07M** |

On all 13 scenes (Mip-NeRF 360, Tanks & Temples, Deep Blending): **+0.32 dB**,
11/13 scenes better in PSNR, 12/13 in LPIPS, **20% fewer triangles**, 5% faster
training. Per-scene numbers:
[`results/formal/tsplus_integrated_survival_table.json`](../../results/formal/tsplus_integrated_survival_table.json)
and [`..._size.json`](../../results/formal/tsplus_integrated_survival_size.json).

## Apply

```bash
git clone --recursive https://github.com/trianglesplatting2/triangle-splatting2.git
cd triangle-splatting2
git checkout fcde03dd0c3953ce1d47b210485a5e8a9e14b016
git am /path/to/SoftTail/integrations/triangle_splatting_plus/0001-triangle-splatting-plus-integrated-survival.patch

cd submodules/diff-triangle2-rasterization
git checkout 42e62aaf03f87835105ed84dd8ed513efd458716
git am /path/to/SoftTail/integrations/triangle_splatting_plus/0002-rasterizer-integrated-accumulator.patch
cd ../..
```

Then install Triangle Splatting+ as its README describes (the rasterizer must be
rebuilt after the patch).

## Run

```bash
# both arms for one scene: trains, renders, scores, prints the difference
bash run_tsplus.sh /path/to/triangle-splatting2 /path/to/data garden runs/tsplus

# or by hand
python train.py -s <scene> -i images_4 -m <out> --eval --integrated_importance
```

`/path/to/data` holds `mipnerf360/<scene>`, `tandt/<scene>` and `db/<scene>`.
Each arm takes about 30 min on one RTX 4090 D.

Note: `--indoor` is a training option of Triangle Splatting+; its `render.py`
rejects it, so `run_tsplus.sh` passes it to training only.
