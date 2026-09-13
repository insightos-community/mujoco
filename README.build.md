# mujoco: reproducible platform builds

This guide describes the InsightOS fork/import and the scripts in this checkout.
The validated distribution from this repository is **Linux x86_64 musl**. glibc
and macOS source recipes below are native development builds, not a claim that
this fork publishes or has requalified those binaries. The complete installer
selects different binary formats and dependency locks for each platform.

## Source and tools

Validated musl tag: [`musl-v3.4.0-4`](https://github.com/insightos-community/mujoco/releases/tag/musl-v3.4.0-4);
source commit: `90b2103196b4e25a883b56599f0cdb54c48d3130`. Use a normal clone so container packaging can read `.git`.

```bash
git clone https://github.com/insightos-community/mujoco.git mujoco-repro
cd mujoco-repro
git checkout --detach musl-v3.4.0-4
test "$(git rev-parse HEAD)" = 90b2103196b4e25a883b56599f0cdb54c48d3130
```

Native build prerequisites: C/C++ compiler, CMake, Ninja and Git; CMake fetches pinned build dependencies. The commands below build the C/C++ library and tests. Python bindings are a separate build described below.

## Linux glibc

Run on a native Linux x86_64 glibc build host (Ubuntu 24.04 is the project CI
baseline). Install the prerequisites above. This native recipe uses the host
compiler and libraries; it does not apply the musl-only patches or emit a
portable/manylinux wheel.

```bash
cmake -S . -B build-glibc -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="$PWD/prefix-glibc" -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -DMUJOCO_BUILD_TESTS=ON -DMUJOCO_BUILD_EXAMPLES=OFF -DMUJOCO_BUILD_SIMULATE=OFF
cmake --build build-glibc --parallel 2
ctest --test-dir build-glibc --output-on-failure --timeout 600
cmake --install build-glibc
```

## Linux musl: reproduce the Release

The authoritative pipeline is [musl-release.yml](.github/workflows/musl-release.yml),
with [build.sh](ci/musl/build.sh) as its local entry point. Run from the checked-out
repository root on a Linux x86_64 Docker host. Building requires network access
for pinned sources and package downloads; the output directory must be fresh.

```bash
REPRO_IMAGE='python:3.13-alpine3.23@sha256:75f27d686432419c9d42420b2b9ef605868c7a0682a6be10a6601fad46c2df01'
REPRO_WORK="$(mktemp -d "${TMPDIR:-/tmp}/mujoco-musl.XXXXXXXX")"
docker run --rm --platform linux/amd64 --cpus=2 --memory=12g --memory-swap=12g --pids-limit=1024 \
  --mount "type=bind,src=$PWD,dst=/src,readonly" \
  --mount "type=bind,src=$REPRO_WORK,dst=/work" \
  "$REPRO_IMAGE" sh /src/ci/musl/build.sh
```

Repeat the published relocation/install probe in a clean container without network:

```bash
docker run --rm --platform linux/amd64 --network none \
  --mount "type=bind,src=$PWD,dst=/src,readonly" \
  --mount "type=bind,src=$REPRO_WORK,dst=/work" \
  "$REPRO_IMAGE" sh /src/ci/musl/clean.sh
```

Outputs are in `$REPRO_WORK/dist/`; build/test logs and package inventories are
in `$REPRO_WORK/logs/`. Retain `build-manifest.json` and `SHA256SUMS` alongside:

- `glfw-2.10.2-py3-none-any.whl`
- `mujoco-3.4.0-cp313-cp313-musllinux_1_2_x86_64.whl`
- `mujoco-3.4.0-musl-x86_64-prefix.tar.gz`

```bash
(cd "$REPRO_WORK/dist" && sha256sum -c SHA256SUMS)
```

Repository-local input/metadata manifests: [`project.json`](ci/musl/project.json).

The pinned Python/Alpine image does not freeze every subsequently installed APK
or pip package. Preserve the emitted package inventory; the result is a musl
build, not a completely static application or a bit-for-bit reproducibility claim.

## macOS / macosx

Use a fresh checkout on Apple Silicon, Xcode Command Line Tools and native arm64
versions of the prerequisites. Do not reuse Linux build directories or `$ORIGIN`
RPATHs. The following is a source-development recipe; it is not the macOS installer
release recipe or a universal/x86_64 qualification.

```bash
cmake -S . -B build-macos -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="$PWD/prefix-macos" -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DMUJOCO_BUILD_TESTS=ON -DMUJOCO_BUILD_EXAMPLES=OFF -DMUJOCO_BUILD_SIMULATE=OFF
cmake --build build-macos --parallel 2
ctest --test-dir build-macos --output-on-failure --timeout 600
cmake --install build-macos
```

The installer uses the upstream `mujoco==3.4.0` CPython 3.13 macOS wheel with system CGL. Physical Mac rendering qualification remains pending.

To reproduce the **complete macOS Python distribution** (including native wheels,
all dependency versions and load-path relocation), use the [installer recipe](https://github.com/insightos-community/quick-start/blob/main/artifacts/macos/README.md) and `artifacts/macos/installer-requirements.lock` in quick-start.
The musl Python build is implemented by [build-native.sh](ci/musl/build-native.sh),
[prepare-python.sh](ci/musl/prepare-python.sh), [build-python.sh](ci/musl/build-python.sh)
and the audit/test steps in `build.sh`; it sets `MUJOCO_PATH` and `MUJOCO_PLUGIN_PATH`
before building CPython 3.13 bindings. The native CMake commands above produce
the C/C++ library, not a Python wheel.

## Run the same build on GitHub

A manual dispatch builds/tests artifacts without publishing. Select the immutable
release tag to reproduce its scripts (GitHub CLI and workflow permission required):

```bash
gh workflow run musl-release.yml --repo insightos-community/mujoco --ref musl-v3.4.0-4
gh run list --repo insightos-community/mujoco --workflow musl-release.yml --limit 5
# Set REPRO_RUN_ID to the run ID printed above.
gh run watch "$REPRO_RUN_ID" --repo insightos-community/mujoco --exit-status
gh run download "$REPRO_RUN_ID" --repo insightos-community/mujoco --name musl-dist --dir downloaded-dist
```

## Reproduction evidence

Build in a fresh checkout and a separate output directory for each ABI. Preserve
source commits, compiler/tool versions, dependency locks, package inventories and
test logs. Fixed source revisions and a container digest reproduce the recipe;
unlocked OS packages, runner images, timestamps and build tools can still change
archive bytes. Compare a downloaded release against its published `SHA256SUMS`;
do not expect a local rebuild to have the same digest.

See the [complete installer and repository index](https://github.com/insightos-community/quick-start/blob/main/README.build.md) for assembly order,
platform locks and end-to-end validation. Local build commands do not publish a
Release. Publishing requires repository write access and a new version tag;
existing release tags/assets should not be replaced.
