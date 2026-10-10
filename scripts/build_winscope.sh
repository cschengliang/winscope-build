#!/usr/bin/env bash
# Build Winscope from a tree prepared by fetch_sources.sh.
# Usage: scripts/build_winscope.sh [AOSP_ROOT]   (default: ./aosp)
# Runs Winscope's own `npm run build:prod`, which:
#   1. builds the Perfetto trace processor (wasm) + its generated TS protos
#      (external/perfetto: tools/install-build-deps --ui, ui/build.js)
#   2. compiles the trace protos (protos/build.js)
#   3. bundles the app with webpack into dist/prod
set -euo pipefail
TOP="$(cd "${1:-${AOSP_TOP:-$PWD/aosp}}" && pwd)"
WS="$TOP/development/tools/winscope"
cd "$WS"
npm ci --no-audit --no-fund
npm run build:prod
echo "Built: $WS/dist/prod"
