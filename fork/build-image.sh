#!/usr/bin/env bash
# Build the fork image from the current checkout.
#
#   fork/build-image.sh                # -> sonarr-fork:4.0.19.2979
#   SONARR_VERSION=4.0.20.1234 fork/build-image.sh
#
# Override BASE_IMAGE / TAG / FORK_VERSION through the environment if needed.
set -euo pipefail
cd "$(dirname "$0")/.."

SONARR_VERSION="${SONARR_VERSION:-4.0.19.2979}"
BASE_IMAGE="${BASE_IMAGE:-ghcr.io/linuxserver/sonarr:version-${SONARR_VERSION}}"
FORK_VERSION="${FORK_VERSION:-$(git rev-parse --short HEAD)}"
TAG="${TAG:-sonarr-fork:${SONARR_VERSION}}"

echo "Building ${TAG} (Sonarr ${SONARR_VERSION}, fork ${FORK_VERSION}) on ${BASE_IMAGE}"

docker build \
  -f fork/Dockerfile \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "SONARR_VERSION=${SONARR_VERSION}" \
  --build-arg "FORK_VERSION=${FORK_VERSION}" \
  -t "${TAG}" \
  .
