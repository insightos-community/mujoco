#!/bin/sh
set -eu
cd /work
python -m venv --system-site-packages /work/build/python-build-env
. /work/build/python-build-env/bin/activate
bash /work/mujoco/python/make_sdist.sh > /work/logs/python-sdist.log 2>&1
mkdir -p /work/build/python-source /work/wheels
archive=$(find /work/mujoco/python/dist -name 'mujoco-3.4.0.tar.gz')
tar -xzf "$archive" -C /work/build/python-source --strip-components=1
echo PYTHON_SOURCE_READY
