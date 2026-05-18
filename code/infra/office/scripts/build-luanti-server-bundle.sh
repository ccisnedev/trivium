#!/bin/bash
set -euo pipefail

LUANTI_VERSION="${1:-5.16.1}"
OUTPUT_PATH="${2:-$PWD/luanti-server-${LUANTI_VERSION}-linux-amd64.tar.gz}"
WORK_ROOT="$(mktemp -d)"
SOURCE_ROOT="${WORK_ROOT}/luanti"

cleanup() {
  rm -rf "${WORK_ROOT}"
}

trap cleanup EXIT

git clone --branch "${LUANTI_VERSION}" --depth 1 https://github.com/luanti-org/luanti.git "${SOURCE_ROOT}"

cmake -S "${SOURCE_ROOT}" -B "${SOURCE_ROOT}/build" \
  -DRUN_IN_PLACE=TRUE \
  -DBUILD_SERVER=TRUE \
  -DBUILD_CLIENT=FALSE \
  -DBUILD_UNITTESTS=FALSE \
  -DBUILD_DOCUMENTATION=FALSE \
  -DCMAKE_BUILD_TYPE=Release

cmake --build "${SOURCE_ROOT}/build" -j"$(nproc)"

rm -rf "${SOURCE_ROOT}/.git"

mkdir -p "$(dirname "${OUTPUT_PATH}")"
tar -C "${SOURCE_ROOT}" -czf "${OUTPUT_PATH}" .

echo "Created Luanti server bundle: ${OUTPUT_PATH}"