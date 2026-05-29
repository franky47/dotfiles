#!/usr/bin/env bash
# Build llama.cpp on echo from the franky47 fork's macos12-build branch.
# Upstream binaries link ILP64 BLAS symbols not present in macOS 12 Accelerate
# (added in macOS 13.3) and the upstream source needs a one-line include patch
# to compile on the Monterey Apple toolchain. The fork carries that patch.
#
# Idempotent: re-runs fetch + build incrementally. To pick up a new upstream
# tag, rebase macos12-build on the new tag in the fork, then re-run this.

set -euo pipefail

YELLOW=$'\033[33m'
GREEN=$'\033[32m'
RESET=$'\033[0m'

REPO_DIR="/Volumes/Storage/dev/franky47/llama.cpp"
FORK_URL="git@github.com:franky47/llama.cpp.git"
UPSTREAM_URL="https://github.com/ggml-org/llama.cpp.git"
BRANCH="macos12-build"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "${GREEN}Cloning${RESET} ${FORK_URL} into ${REPO_DIR}"
  git clone --branch "${BRANCH}" "${FORK_URL}" "${REPO_DIR}"
  git -C "${REPO_DIR}" remote add upstream "${UPSTREAM_URL}"
  git -C "${REPO_DIR}" remote set-url --add --push upstream no_push
else
  echo "${GREEN}Updating${RESET} ${REPO_DIR}"
  git -C "${REPO_DIR}" fetch origin --tags
  git -C "${REPO_DIR}" checkout "${BRANCH}"
  git -C "${REPO_DIR}" pull --ff-only origin "${BRANCH}"
fi

# CPU-only Release build. GGML_BLAS=OFF avoids the Accelerate ILP64 dependency
# that breaks load on macOS 12; GGML_METAL=OFF skips the Iris Pro Metal backend
# (Metal Family 1 is not worth the offload overhead at this scale).
echo "${GREEN}Configuring${RESET} CMake (CPU-only, static)"
cmake -S "${REPO_DIR}" -B "${REPO_DIR}/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_BLAS=OFF \
  -DGGML_METAL=OFF \
  -DGGML_NATIVE=ON \
  -DLLAMA_CURL=ON \
  -DBUILD_SHARED_LIBS=OFF

echo "${GREEN}Building${RESET} llama-server + llama-cli"
cmake --build "${REPO_DIR}/build" --config Release --target llama-server llama-cli -j 4

"${REPO_DIR}/build/bin/llama-server" --version | head -3
echo "${GREEN}Done${RESET} — binaries in ${REPO_DIR}/build/bin/"
echo "${YELLOW}Note:${RESET} config.echo.yml references this path; re-run if the fork moves."
