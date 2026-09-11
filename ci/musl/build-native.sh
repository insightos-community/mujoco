#!/bin/sh
set -eu
cd /work
mkdir -p prefix build logs
git config --global --add safe.directory '*'
cmake -S mujoco -B build/native -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=OFF -DCMAKE_C_FLAGS=-D_POSIX_C_SOURCE=200809L -DCMAKE_INSTALL_PREFIX=/work/prefix -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DMUJOCO_BUILD_EXAMPLES=OFF \
  -DMUJOCO_BUILD_SIMULATE=OFF -DMUJOCO_BUILD_TESTS=ON -DBUILD_TESTING=ON \
  -DMUJOCO_TEST_PYTHON_UTIL=OFF > logs/native-configure.log 2>&1
cmake --build build/native --parallel 2 > logs/native-build.log 2>&1
ctest --test-dir build/native --output-on-failure --timeout 180 > logs/native-tests.log 2>&1
cmake --install build/native > logs/native-install.log 2>&1
echo NATIVE_COMPLETE
