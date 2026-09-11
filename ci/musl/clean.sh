#!/bin/sh
set -eu
exec > /work/logs/clean-install.log 2>&1
mkdir -p /opt/check /opt/runtime
tar -xzf /work/dist/*-musl-x86_64-prefix.tar.gz -C /opt/check
cp /work/runtime/* /opt/runtime/ 2>/dev/null || test -z "$(ls -A /work/runtime)"
export LD_LIBRARY_PATH=/opt/check/prefix/lib:/opt/runtime
python /src/ci/musl/smoke.py /opt/check/prefix
python -m pip install --no-index --no-deps /work/dist/*.whl /work/wheelhouse/*.whl
python - <<'PY'
import mujoco, numpy as np
m=mujoco.MjModel.from_xml_string('<mujoco><worldbody><body pos="0 0 1"><freejoint/><geom type="sphere" size="0.1"/></body></worldbody></mujoco>')
d=mujoco.MjData(m)
for _ in range(10): mujoco.mj_step(m,d)
assert d.qpos[2]<1 and np.isfinite(d.qpos).all()
assert mujoco.__version__=='3.4.0'
print('PASS: repaired CPython 3.13 wheel and physical integration in clean offline musl container')
PY
