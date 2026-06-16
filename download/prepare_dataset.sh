#!/usr/bin/env bash
# =============================================================================
# StyleDrive / NAVSIM dataset download + assembly  (see docs/install.md)
# -----------------------------------------------------------------------------
# Downloads the nuPlan maps, the OpenScene navtrain + test logs/sensor blobs,
# and the StyleDrive style JSONs, then moves everything into the final layout
# that the Docker image mounts at /data/dataset:
#
#   <DATA_ROOT>/
#     ├── extra_data/    (styletrain.json, styletest.json)
#     ├── maps/
#     ├── navsim_logs/   { trainval, test }
#     └── sensor_blobs/  { trainval, test }
#
# This runs on the HOST (not in the container) — the data stays out of the image
# and is bind-mounted at run time. It is RESUMABLE: every download uses `wget -c`
# and each step is skipped if its output already exists, so you can re-run after
# an interruption.
#
# Usage:
#   ./prepare_dataset.sh [maps|style|navtrain|test|all]      (default: all)
#   DATA_ROOT=/big/disk/dataset ./prepare_dataset.sh all     (override location)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Where the final, assembled dataset lives (mount this at /data/dataset).
DATA_ROOT="${DATA_ROOT:-$REPO_ROOT/dataset}"
# Scratch dir for downloads + extraction (kept out of git and the Docker image).
DL="$SCRIPT_DIR"

mkdir -p "$DATA_ROOT"/{maps,navsim_logs,sensor_blobs,extra_data} "$REPO_ROOT/exp"

log(){ printf '\n\033[1;34m[prepare_dataset]\033[0m %s\n' "$*"; }

# -----------------------------------------------------------------------------
step_maps(){
  if [ -f "$DATA_ROOT/maps/nuplan-maps-v1.0.json" ]; then
    log "maps: already in place — skipping"; return
  fi
  if [ ! -d "$DL/maps" ]; then
    log "maps: downloading nuPlan maps"
    cd "$DL"
    wget -c https://motional-nuplan.s3-ap-northeast-1.amazonaws.com/public/nuplan-v1.1/nuplan-maps-v1.1.zip
    unzip -q nuplan-maps-v1.1.zip
    rm -f nuplan-maps-v1.1.zip
    mv nuplan-maps-v1.0 maps
  fi
  log "maps: moving into $DATA_ROOT/maps"
  rsync -a --remove-source-files "$DL/maps/" "$DATA_ROOT/maps/"
  rm -rf "$DL/maps"
}

# -----------------------------------------------------------------------------
step_style(){
  cd "$DATA_ROOT/extra_data"
  for j in styletrain styletest; do
    # Validate it's real JSON — a file downloaded from the /blob/ URL is an HTML
    # page (starts with '<') that is non-empty but useless, so a size check alone
    # is not enough.
    if [ -s "$j.json" ] && [ "$(head -c 1 "$j.json")" != "<" ]; then
      log "style: $j.json present and looks like JSON — skipping"; continue
    fi
    log "style: (re)downloading $j.json"
    # NOTE: install.md uses a /blob/ URL which returns an HTML page; /resolve/
    # is the correct raw-file endpoint.
    wget -O "$j.json" "https://huggingface.co/datasets/Ryhn98/StyleDrive-Dataset/resolve/main/$j.json"
  done
}

# -----------------------------------------------------------------------------
step_navtrain(){
  if [ -d "$DATA_ROOT/navsim_logs/trainval" ] && [ -d "$DATA_ROOT/sensor_blobs/trainval" ]; then
    log "navtrain: already assembled — skipping"; return
  fi
  cd "$DL"

  if [ ! -d trainval_navsim_logs ]; then
    log "navtrain: downloading metadata (logs)"
    wget -c https://huggingface.co/datasets/OpenDriveLab/OpenScene/resolve/main/openscene-v1.1/openscene_metadata_trainval.tgz
    tar -xzf openscene_metadata_trainval.tgz
    rm -f openscene_metadata_trainval.tgz
    mv openscene-v1.1/meta_datas trainval_navsim_logs
    rm -rf openscene-v1.1
  fi

  mkdir -p trainval_sensor_blobs/trainval
  for kind in current history; do
    for split in 1 2 3 4; do
      f="navtrain_${kind}_${split}.tgz"
      log "navtrain: sensor $kind split $split"
      wget -c "https://s3.eu-central-1.amazonaws.com/avg-projects-2/navsim/$f"
      tar -xzf "$f" && rm -f "$f"
      rsync -a --remove-source-files "${kind}_split_${split}/" trainval_sensor_blobs/trainval/
      rm -rf "${kind}_split_${split}"
    done
  done

  log "navtrain: moving into final layout"
  # meta_datas already contains a `trainval/` subdir — copy its CONTENTS so the
  # .pkl logs land directly in navsim_logs/trainval (not navsim_logs/trainval/trainval).
  rsync -a --remove-source-files trainval_navsim_logs/trainval/  "$DATA_ROOT/navsim_logs/trainval/"  && rm -rf trainval_navsim_logs
  rsync -a --remove-source-files trainval_sensor_blobs/trainval/ "$DATA_ROOT/sensor_blobs/trainval/" && rm -rf trainval_sensor_blobs
}

# -----------------------------------------------------------------------------
step_test(){
  if [ -d "$DATA_ROOT/navsim_logs/test" ] && [ -d "$DATA_ROOT/sensor_blobs/test" ]; then
    log "test: already assembled — skipping"; return
  fi
  cd "$DL"

  if [ ! -d openscene-v1.1/meta_datas ]; then
    log "test: downloading metadata (logs)"
    wget -c https://huggingface.co/datasets/OpenDriveLab/OpenScene/resolve/main/openscene-v1.1/openscene_metadata_test.tgz
    tar -xzf openscene_metadata_test.tgz
    rm -f openscene_metadata_test.tgz
  fi

  for kind in camera lidar; do
    for split in $(seq 0 31); do
      f="openscene_sensor_test_${kind}_${split}.tgz"
      log "test: sensor $kind split $split / 31"
      wget -c "https://huggingface.co/datasets/OpenDriveLab/OpenScene/resolve/main/openscene-v1.1/openscene_sensor_test_${kind}/$f"
      tar -xzf "$f" && rm -f "$f"
    done
  done

  log "test: moving into final layout"
  # Both meta_datas and sensor_blobs contain a `test/` subdir — copy its CONTENTS
  # so logs/scenes land directly in navsim_logs/test and sensor_blobs/test
  # (not .../test/test).
  rsync -a --remove-source-files openscene-v1.1/meta_datas/test/   "$DATA_ROOT/navsim_logs/test/"  && true
  rsync -a --remove-source-files openscene-v1.1/sensor_blobs/test/ "$DATA_ROOT/sensor_blobs/test/" && true
  rm -rf openscene-v1.1
}

# -----------------------------------------------------------------------------
cmd="${1:-all}"
case "$cmd" in
  maps)     step_maps ;;
  style)    step_style ;;
  navtrain) step_navtrain ;;
  test)     step_test ;;
  all)      step_maps; step_style; step_navtrain; step_test ;;
  *) echo "usage: $0 [maps|style|navtrain|test|all]"; exit 1 ;;
esac
log "completed: $cmd"
log "DATA_ROOT = $DATA_ROOT"
