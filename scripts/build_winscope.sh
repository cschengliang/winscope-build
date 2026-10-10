#!/usr/bin/env bash
# Build Winscope from a tree prepared by fetch_sources.sh.
# Usage: scripts/build_winscope.sh [AOSP_ROOT]   (default: ./aosp)
#   NPM_REGISTRY  public registry used when package-lock pins Google's internal one
#                 (default https://registry.npmjs.org/)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "${1:-${AOSP_TOP:-$PWD/aosp}}" && pwd)"
PERFETTO="$TOP/external/perfetto"
WS="$TOP/development/tools/winscope"
REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org/}"
PRIVATE="https://us-npm.pkg.dev/artifact-foundry-prod/ah-3p-staging-npm/"

step() { echo "::group::$*"; }
end()  { echo "::endgroup::"; }

# 1. npm deps. Some release branches pin every `resolved` URL in package-lock.json to
#    Google's internal Artifact Registry (404 outside Google). Rewrite temporarily.
step "npm ci"
cd "$WS"
if grep -q "$PRIVATE" package-lock.json; then
  echo "package-lock.json pins $PRIVATE -> using $REGISTRY for this install"
  cp package-lock.json /tmp/winscope-package-lock.json.orig
  sed -i "s#${PRIVATE}#${REGISTRY}#g" package-lock.json
  trap 'cp /tmp/winscope-package-lock.json.orig "$WS/package-lock.json" 2>/dev/null || true' EXIT
fi
npm ci --no-audit --no-fund --registry="$REGISTRY"
end

# Older Winscope (no build:app script): its own build:prod works as-is.
if ! npm run | grep -q "^  build:app$"; then
  step "npm run build:prod (legacy Winscope)"
  npm run build:prod
  end
  echo "Built: $WS/dist/prod"; exit 0
fi

# 2. Perfetto build deps (clang, gn, ninja, node, emsdk...) without the test-data sync.
step "Perfetto build deps"
# buildtools/ mixes tracked files (BUILD.gn...) with downloaded deps; a restored CI cache
# from another Perfetto revision may carry stale tracked files, so reset them first.
git -C "$PERFETTO" checkout -- buildtools
python3 "$HERE/install_perfetto_deps.py" "$PERFETTO"
end

# 3. Trace processor wasm + engine bundle + generated TS protos.
step "Trace processor"
cd "$PERFETTO"
rm -rf trace_processor_build
./tools/gn gen trace_processor_build --args='is_debug=false skip_buildtools_check=true'
./ui/node ui/build.js --out trace_processor_build --no-depscheck --no-override-gn-args
end

# 4. Winscope protos, then copy the trace processor where Winscope expects it.
step "Winscope protos"
cd "$WS"
npm run build:protos
rm -rf deps_build/trace_processor && mkdir -p deps_build/trace_processor/to_be_served
cp -a "$PERFETTO/trace_processor_build/." deps_build/trace_processor/
cp deps_build/trace_processor/ui/dist_version/engine_bundle.js deps_build/trace_processor/to_be_served/
cp deps_build/trace_processor/wasm/trace_processor.wasm deps_build/trace_processor/to_be_served/
if [ -f deps_build/trace_processor/wasm_memory64/trace_processor_memory64.wasm ]; then
  cp deps_build/trace_processor/wasm_memory64/trace_processor_memory64.wasm deps_build/trace_processor/to_be_served/
fi
end

# 5. App bundle (Angular CLI production build).
step "Winscope app"
npm run build:app
# Make sure the served engine files are present either way.
cp -n deps_build/trace_processor/to_be_served/* dist/prod/ 2>/dev/null || true
[ -f dist/prod/winscope_proxy.py ] || cp src/adb/winscope_proxy.py dist/prod/
end
for f in index.html engine_bundle.js trace_processor.wasm; do test -f "dist/prod/$f" || { echo "missing dist/prod/$f"; exit 1; }; done
echo "Built: $WS/dist/prod"; ls -la dist/prod | head -40
