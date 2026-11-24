#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export SHINIGAMI_OMARCHY_BASELINE_PROFILE=installed-package
export SHINIGAMI_OMARCHY_BASELINE_VERSION=4.5.0
export OMARCHY_PATH=/usr/share/omarchy

exec "$repo_root/tests/contract-regression.sh"
