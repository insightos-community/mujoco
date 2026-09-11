#!/bin/sh
set -eu
cd /work
mkdir -p logs build prefix dist repaired-wheels python-tests
exec > logs/build.log 2>&1
apk add --no-cache build-base cmake ninja git curl linux-headers binutils patchelf bash glfw-dev mesa-egl mesa-dri-gallium
apk info -v > logs/apk-packages.txt
python -m pip install numpy==2.3.5 pytest==8.3.5 build setuptools wheel pybind11 absl-py 'etils[epath]' glfw PyOpenGL auditwheel pillow==11.2.1
git config --global --add safe.directory '*'
cp -a /src /work/mujoco
sh /src/ci/musl/build-native.sh
sh /src/ci/musl/prepare-python.sh
sh /src/ci/musl/build-python.sh
auditwheel repair --plat musllinux_1_2_x86_64 -w repaired-wheels wheels/*.whl > logs/auditwheel.log 2>&1
python /src/ci/musl/audit_wheel.py > logs/wheel-audit.log 2>&1
python -m pip install --no-index --no-deps repaired-wheels/*.whl
for test in bindings render renderer rollout; do cp "/src/python/mujoco/${test}_test.py" python-tests/; done
export MUJOCO_GL=egl LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
python -m pytest -p no:cacheprovider -q python-tests > logs/python-tests.log 2>&1
RENDER_OUTPUT=/work/render-test python /src/ci/musl/test_render.py > logs/render-test.log 2>&1
cat logs/native-tests.log logs/python-tests.log > logs/tests.log
cp repaired-wheels/*.whl dist/
python /src/ci/musl/package.py
mkdir -p wheelhouse
python -m pip download --only-binary=:all: --dest wheelhouse numpy==2.3.5 pillow==11.2.1 absl-py 'etils[epath]' glfw PyOpenGL
python -m pip freeze > logs/python-packages.txt
