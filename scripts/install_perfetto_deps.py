#!/usr/bin/env python3
"""Run Perfetto's tools/install-build-deps --ui, but skip the //test/data sync.

install-build-deps always checks (and otherwise downloads) Perfetto's large test
data, which Winscope doesn't need. Usage: install_perfetto_deps.py <perfetto_dir>
"""
import importlib.machinery, importlib.util, subprocess, sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
installer = root / "tools" / "install-build-deps"
test_data = (root / "tools" / "test_data").resolve()
loader = importlib.machinery.SourceFileLoader("perfetto_install_build_deps", str(installer))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = mod
loader.exec_module(mod)

_call = subprocess.call
def call(cmd, *a, **kw):
    if isinstance(cmd, (list, tuple)) and len(cmd) >= 3 and Path(str(cmd[1])).resolve() == test_data and cmd[2] == "status":
        return 0  # pretend test data is in sync
    return _call(cmd, *a, **kw)
subprocess.call = call
sys.argv = [str(installer), "--ui", "--no-dev-tools", *sys.argv[2:]]
raise SystemExit(mod.Main())
