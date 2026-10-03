# SoftTail reproducibility guide

This document maps every paper-facing result to code, data, and release
artifacts. It complements the concise commands in the root README.

## Formal configuration

All reported checkpoints train for 30,000 iterations. The matched baseline and
SoftTail use the same scene inputs, the same base training code and the same
face budget. Two things change: the terminal opacity of the hardening schedule,
and the statistic that decides which faces survive pruning, densification and
the final cleanup (`--integrated_importance`, `sota/survival.py`). The published
rule still decides *how many* faces are removed at every step, so the mesh sizes
remain comparable by construction.

| Configuration | Terminal opacity | Supersampling | Transmittance cutoff | Tail absorption |
|---|---:|---:|---:|:---:|
| Matched MeshSplatting | 0.9999 | 4× | 0.0001 | no |
| SoftTail-Quality | 0.8 | 4× | 0.01 | yes |
| SoftTail-Speed | 0.8 | 3× | 0.01 | yes |

Quality and Speed evaluate the same SoftTail checkpoint. Supersampling and tail
termination are deployment settings, not separately trained models.

## Dataset acquisition

SoftTail does not distribute third-party raw images. Obtain each dataset from
its owner and retain its original licence and citation.

### Mip-NeRF 360

- Official page: <https://jonbarron.info/mipnerf360/>
- Download both dataset parts linked on that page.
- Evaluated scenes: `bicycle`, `flowers`, `garden`, `stump`, `treehill`,
  `room`, `counter`, `kitchen`, `bonsai`.
- Outdoor scenes use `images_4`; indoor scenes use `images_2` and the upstream
  `--indoor` configuration.

Expected structure:

```text
mipnerf360/
├── bicycle/
│   ├── images_4/
│   └── sparse/0/
├── garden/
│   ├── images_4/
│   └── sparse/0/
└── room/
    ├── images_2/
    └── sparse/0/
```

### Tanks & Temples

- Official download page: <https://www.tanksandtemples.org/download/>
- Licence terms: <https://www.tanksandtemples.org/license/>
- Evaluated scenes: `train`, `truck`.
- The formal protocol uses maximum primitive counts of 2.5M and 2.0M for Train
  and Truck, respectively; `sota/run.sh` applies these values automatically.

Expected structure:

```text
tandt/
├── train/
│   ├── images/
│   └── sparse/0/
└── truck/
    ├── images/
    └── sparse/0/
```

### Deep Blending

- Author release and data links: <https://github.com/Phog/DeepBlending#usage>
- Evaluated scenes: `drjohnson`, `playroom`.
- Both scenes use the upstream `--indoor` configuration.

Expected structure:

```text
deep_blending/
├── drjohnson/
│   ├── images/
│   └── sparse/0/
└── playroom/
    ├── images/
    └── sparse/0/
```

## Result-to-code map

| Evidence | Reproduce with | Archived JSON in `results/formal/` |
|---|---|---|
| Mip-NeRF 360 main table (9 scenes) | `scripts/reproduce.sh mipnerf360` | `softtail_nine_scene_main_table.json` |
| Equal-budget control (9 scenes) | `scripts/equal_budget.sh` (called by `reproduce.sh`) | `softtail_nine_scene_equal_budget.json` |
| Tanks & Temples + Deep Blending | `scripts/reproduce.sh tandt` / `deepblending` | `softtail_tandt_deep_blending_table.json` |
| Component ablation (9 scenes) | `eval_train_only` of `scripts/run_scene.sh softtail` | `softtail_nine_scene_ablation.json` |
| Baseline and opacity-floor rows | `scripts/run_scene.sh meshsplatting` / `opacity_floor` | `mipnerf360_main_table.json`, `tanks_and_temples_main_table.json`, `deep_blending_main_table.json` |
| Terminal-opacity ablation and sensitivity | `sota/opacity_ablation.py`, `sota/opacity_sensitivity.py` | `opacity_ablation.json`, `opacity_sensitivity.json` |
| Three-scene development runs | `scripts/run_scene.sh` on bicycle, garden, room | `softtail_integrated_importance_gate.json`, `softtail_integrated_importance_equal_budget.json`, `softtail_oats_integrated_survival_gate.json` |
| Survival-statistic measurement | `python -m sota.survival_statistic` | `softtail_survival_statistic_{room,bicycle,garden}.json` |
| Compact meshes (10/25/50/75% of the budget, 4 scenes) | `scripts/compact.sh` after `scripts/run_scene.sh softtail` | `softtail_compact_frontier.json` |
| Survival rule inside Triangle Splatting+ (13 scenes) | `integrations/triangle_splatting_plus/run_tsplus.sh` | `tsplus_integrated_survival_table.json`, `tsplus_integrated_survival_size.json` |
| Compact-cut renders and per-face light maps | `python -m sota.figure_renders compact` / `contrib` | figure inputs only |

Regenerate the paper's tables from those files with:

```bash
shasum -a 256 -c results/SHA256SUMS
python results/make_tables.py
```

The compact-mesh and Triangle Splatting+ experiments ran on one RTX 4090 D;
all other rows on one NVIDIA A40.

Every formal launcher records the Git source revision. Each evaluation result
records scene, arm, checkpoint size, triangle count, vertex count, PyTorch
version, GPU, and image metrics. 

## Release bundle

Machine-readable results ship **inside this repository**, under
`results/formal/` with hashes in `results/SHA256SUMS`. Only the checkpoints,
which are about 8.9 GB for the 13 released scenes, live in the external bundle:

```text
SoftTail Release/                 https://drive.google.com/drive/folders/1Gj7ykZadiJ2IuTUrN046vAEGZMSnA_PY
├── README.md
└── checkpoints/
    ├── softtail_bicycle.tar      # cfg_args, cameras.json,
    ├── ...                       # point_cloud/iteration_30000/
    ├── softtail_playroom.tar
    └── SHA256SUMS
```

Build the archives with `bash sota/package_release.sh [destination]`; each one
untars into a model directory that `sota/main_table_eval.py` can score directly.

Every evaluation result carries its own provenance — scene, arm, checkpoint
size, triangle and vertex counts, PyTorch version, GPU and the Git source
revision — so a downloaded checkpoint can be traced back to the row it produced.

## Data Availability

The checkpoints, processed evaluation outputs, machine-readable aggregate
tables, and figure evidence generated in this study are available in the
SoftTail release bundle linked from the project README. The source code and
formal experiment launchers are available in this GitHub repository. The study
reuses the publicly available Mip-NeRF 360 dataset from its official project
page, Tanks & Temples from the benchmark website, and Deep Blending from the
authors' release. Raw third-party images are not redistributed by the SoftTail
authors; users should obtain them from the respective providers and comply with
their terms.

## 中文核对

- 公开包包含我们生成的 checkpoints、结果 JSON、图像证据和校验和。
- Mip-NeRF 360、Tanks & Temples、Deep Blending 原始图片不由本仓库二次分发。
- 正式发布前，应从一个未登录作者账号的浏览器测试 GitHub 与模型下载链接。
- 若后续建立 Zenodo/Hugging Face 等带永久标识符的归档，应把该 DOI/永久链接替换为首选引用地址。
