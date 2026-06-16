# syntax=docker/dockerfile:1.7
# =============================================================================
# StyleDrive / NAVSIM devkit — DGX Spark (GB10, Grace-Blackwell, aarch64)
# -----------------------------------------------------------------------------
# Base image: NVIDIA NGC PyTorch. It is multi-arch (ships linux/arm64) and the
# PyTorch inside it is built against CUDA 12.8+, so it carries Blackwell kernels
# (sm_120/sm_121). The repo's pinned torch==2.0.1 (CUDA 11.x, x86_64) CANNOT run
# on this GPU — that pin is dropped below and replaced by the base image's torch.
#
# Pick the newest tag that matches your host driver from the NGC support matrix:
#   https://docs.nvidia.com/deeplearning/frameworks/support-matrix/
# Default below: 25.04-py3  ->  torch 2.7 / CUDA 12.9 / Python 3.12.
# Override at build time with:  --build-arg NGC_TAG=25.06-py3
#
# NOTE: data (maps, navsim_logs, sensor_blobs, style JSONs, pretrained weights)
# is intentionally NOT baked in. It is mounted at /data at run time (see below).
# =============================================================================
ARG NGC_TAG=25.04-py3
FROM nvcr.io/nvidia/pytorch:${NGC_TAG}

ENV DEBIAN_FRONTEND=noninteractive

# --- System libraries required by the geo / vision Python deps ---------------
#   geopandas / fiona / rasterio -> GDAL ;  rtree -> libspatialindex ;
#   opencv-python                -> libGL / libglib
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        libgl1 \
        libglib2.0-0 \
        libspatialindex-dev \
        gdal-bin \
        libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/StyleDrive

# The base image already ships /etc/pip/constraint.txt (via $PIP_CONSTRAINT),
# which pins its entire CUDA/Blackwell stack — torch, torchvision, numpy, etc.
# pip honours it automatically, so the old CUDA-11 torch can never be pulled in.
# Our only job below is to stop requirements.txt from fighting those locks.

# --- Dependency metadata first, for better Docker layer caching --------------
COPY requirements.txt setup.py ./

# --- Patch the pins that collide with the NGC base image ---------------------
#   * drop torch / torchvision  -> provided (and locked) by the base image
#   * numpy   1.23.4 -> <2       -> defer to NGC's numpy 1.26.4
#   * setuptools 65.x -> latest  -> defer to NGC's 78.1.0 (65.x predates py3.12)
#   * scikit-learn 1.2.2 -> any  -> defer to NGC's 1.6.1 (no 1.2.2 py3.12 wheel)
#   * protobuf 4.25.3 -> any     -> defer to NGC's 4.24.4
#   * drop opencv-python         -> NGC already provides cv2 via its `opencv` build
RUN sed -i -E \
        -e '/^torch==/d' \
        -e '/^torchvision==/d' \
        -e '/^opencv-python==/d' \
        -e 's/^numpy==.*/numpy<2/' \
        -e 's/^setuptools==.*/setuptools/' \
        -e 's/^scikit-learn==.*/scikit-learn/' \
        -e 's/^protobuf==.*/protobuf/' \
        -e 's/^guppy3==.*/guppy3/' \
        -e 's/^hydra-core==.*/hydra-core>=1.3.2/' \
        requirements.txt

# --- Install the Python deps (NGC's $PIP_CONSTRAINT guards the torch stack) ---
RUN pip install --no-cache-dir -r requirements.txt

# --- Copy the rest of the devkit ---------------------------------------------
COPY . .

# --- Re-apply the requirements patch (COPY . . overwrote the patched copy) ---
# so that `pip install -e .` reads the relaxed pins from setup.py too.
RUN sed -i -E \
        -e '/^torch==/d' \
        -e '/^torchvision==/d' \
        -e '/^opencv-python==/d' \
        -e 's/^numpy==.*/numpy<2/' \
        -e 's/^setuptools==.*/setuptools/' \
        -e 's/^scikit-learn==.*/scikit-learn/' \
        -e 's/^protobuf==.*/protobuf/' \
        -e 's/^guppy3==.*/guppy3/' \
        -e 's/^hydra-core==.*/hydra-core>=1.3.2/' \
        requirements.txt

# --- Install the devkit + StyleDrive baseline extras -------------------------
RUN pip install --no-cache-dir -e . && \
    pip install --no-cache-dir diffusers einops

# --- Wire StyleDrive's style-config paths to the runtime data mount ----------
# (install.md step 4 — done automatically here instead of by hand.)
RUN sed -i 's#YourStyleDrivePath/dataset#/data/dataset#g' \
        navsim/planning/script/config/common/agent/transfuser_style_agent.yaml \
        navsim/planning/script/config/common/agent/diffusiondrive_style_agent.yaml \
        navsim/planning/script/config/common/agent/ego_status_mlp_style_agent.yaml

# --- NAVSIM / nuPlan environment variables -----------------------------------
# Everything under /data is provided by a volume mount at run time.
ENV NUPLAN_MAP_VERSION="nuplan-maps-v1.0" \
    NUPLAN_MAPS_ROOT="/data/dataset/maps" \
    NAVSIM_EXP_ROOT="/data/exp" \
    NAVSIM_DEVKIT_ROOT="/workspace/StyleDrive" \
    OPENSCENE_DATA_ROOT="/data/dataset"

CMD ["/bin/bash"]
