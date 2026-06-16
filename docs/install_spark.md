# Running StyleDrive on NVIDIA DGX Spark (GB10 / Grace-Blackwell / ARM64)

The default [install.md](install.md) targets x86_64 + CUDA 11 and pins `torch==2.0.1`.
That stack **cannot run on the DGX Spark**: the GB10 GPU is Blackwell (compute
capability `sm_121`), which needs CUDA 12.8+ / PyTorch ≥2.7, and the pinned wheels
are x86_64-only while the Spark's Grace CPU is `aarch64`. This guide uses a
container built on NVIDIA's NGC PyTorch ARM64 image instead.

Verified on: DGX Spark, GB10 (`sm_121`), 20 cores, 128 GB unified memory,
driver 580 / CUDA 13, Docker 28 with the NVIDIA container runtime.

## 1. Build the image

```bash
docker login nvcr.io          # NGC images are free but gated; one-time
docker build -t styledrive .
```

The [`Dockerfile`](../Dockerfile) starts from `nvcr.io/nvidia/pytorch:25.04-py3`
(ARM64, torch 2.7 / CUDA 12.9 with Blackwell kernels) and relaxes the pins that
collide with that base image (`numpy`, `setuptools`, `scikit-learn`, `protobuf`,
`opencv-python`, `guppy3`) and bumps `hydra-core` (1.2.0 cannot import on
Python ≥3.11). Data is **not** baked into the image — it is bind-mounted at runtime.

## 2. Download and assemble the dataset

Data lives on the host and is mounted into the container at `/data`. Use the
helper (resumable; see [`download/prepare_dataset.sh`](../download/prepare_dataset.sh)):

```bash
# maps + style JSONs (small) and the navtrain split (~450 GB)
./download/prepare_dataset.sh maps
./download/prepare_dataset.sh style
./download/prepare_dataset.sh navtrain
# evaluation split (~220 GB) — only if you need to run PDM scoring
./download/prepare_dataset.sh test
```

This assembles `dataset/` into the layout the container expects:

```
dataset/
├── extra_data/   styletrain.json, styletest.json
├── maps/
├── navsim_logs/  { trainval, test }
└── sensor_blobs/ { trainval, test }
```

## 3. Cache features, then train

```bash
docker run --gpus all -it --rm --shm-size=16g \
  -v "$PWD/dataset:/data/dataset" \
  -v "$PWD/exp:/data/exp" \
  styledrive

# inside the container:
bash scripts/caching/caching_training_tran_diff.sh      # builds exp/training_cache
bash scripts/training/run_diffusiondrive_style_training.sh
```

`--shm-size=16g` is required: the default 64 MB `/dev/shm` cripples the Ray
workers used during caching. Checkpoints and the cache are written to the mounted
`exp/`, so they persist on the host.

## Spark-specific notes

- **Caching memory (important).** Ray dataset-caching spawns one worker per CPU
  thread, and each worker loads the agent model + the ~89 MB style JSON. With
  `worker.threads_per_node: null` (auto), the Spark's 20 cores keep peak RAM
  around 35 GB — fine. If you ever hit OOM (Ray "killed due to memory pressure"),
  cap it: append `worker.threads_per_node=8` to the caching command.
- **Single vs multi-GPU.** The training scripts default to `CUDA_VISIBLE_DEVICES=0`
  (the Spark has one GPU) and pass `trainer.params.strategy=auto`. `auto` selects
  the single-device strategy on one GPU (avoiding an NCCL shared-memory bug on
  `sm_121`) and DDP on multiple GPUs. On a multi-GPU host, override e.g.
  `CUDA_VISIBLE_DEVICES=0,1 bash scripts/training/...`.
- **ResNet-34 backbone** is downloaded from HuggingFace on first run (the
  container needs network). Offline, mount a prepopulated cache to
  `/root/.cache/huggingface`.
- **File ownership.** The container runs as root, so files written to `exp/` are
  root-owned on the host. Add `--user $(id -u):$(id -g) -e HOME=/tmp` to the
  `docker run` if you want host-user ownership.
