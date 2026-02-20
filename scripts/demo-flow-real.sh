#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "[demo-flow-real] Stopping any existing demo processes"
./scripts/demo-flow-stop.sh || true

echo "[demo-flow-real] Starting real build/deploy flow"
DEFAULT_BUILD_SCRIPT="${ROOT_DIR}/scripts/build-deploy-local.sh"
MOCK_DEPLOY=false BUILD_DEPLOY_SCRIPT="${BUILD_DEPLOY_SCRIPT:-${DEFAULT_BUILD_SCRIPT}}" ./scripts/demo-flow.sh
