#!/bin/sh
set -eu
cd /work
if [ ! -f /work/build/python-source/setup.py ]; then sh /src/ci/musl/prepare-python.sh; fi
. /work/build/python-build-env/bin/activate
export MUJOCO_PATH=/work/prefix
mkdir -p /work/plugin-stage
for plugin_name in actuator elasticity sensor sdf_plugin; do
  cp /work/build/native/lib/lib${plugin_name}.so /work/plugin-stage/
  patchelf --set-rpath '$ORIGIN/..' /work/plugin-stage/lib${plugin_name}.so
done
export MUJOCO_PLUGIN_PATH=/work/plugin-stage
export CMAKE_BUILD_PARALLEL_LEVEL=2
export MUJOCO_CMAKE_ARGS='-DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF -DMUJOCO_SIMULATE_USE_SYSTEM_GLFW=ON'
python -m pip wheel /work/build/python-source --no-build-isolation --no-deps -w /work/wheels > /work/logs/python-build.log 2>&1
echo PYTHON_BUILD_COMPLETE
