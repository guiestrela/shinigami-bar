#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_path=${SHINIGAMI_INSTALLED_SOURCE_OMARCHY_PATH:-}

if [[ $source_path != /* || ! -d $source_path ]]; then
  printf '%s\n' \
    'installed-source-parity contract regression failed: SHINIGAMI_INSTALLED_SOURCE_OMARCHY_PATH must be an absolute checkout path' >&2
  exit 1
fi

export SHINIGAMI_OMARCHY_BASELINE_PROFILE=installed-source-parity
export SHINIGAMI_OMARCHY_BASELINE_VERSION=4.5.0
export OMARCHY_PATH=$source_path

exec "$repo_root/tests/contract-regression.sh"
