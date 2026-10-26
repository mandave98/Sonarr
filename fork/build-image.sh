#!/usr/bin/env bash
# Build the fork image from the current checkout.
#
#   fork/build-image.sh                # -> sonarr-fork:5.0.0.2800
#   SONARR_VERSION=5.0.0.NNNN fork/build-image.sh
#
# Override BASE_IMAGE / BRANCH / TAG / FORK_VERSION through the environment if
# needed. The .NET SDK version is read from global.json.
set -euo pipefail
cd "$(dirname "$0")/.."

SONARR_VERSION="${SONARR_VERSION:-5.0.0.2800}"
# LinuxServer tags v5 beta builds develop-version-<version>; stable lines use version-<version>.
BASE_IMAGE="${BASE_IMAGE:-ghcr.io/linuxserver/sonarr:develop-version-${SONARR_VERSION}}"
BRANCH="${BRANCH:-develop}"
DOTNET_SDK_VERSION="${DOTNET_SDK_VERSION:-$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' global.json)}"
FORK_VERSION="${FORK_VERSION:-$(git rev-parse --short HEAD)}"
TAG="${TAG:-sonarr-fork:${SONARR_VERSION}}"

echo "Building ${TAG} (Sonarr ${SONARR_VERSION} ${BRANCH}, SDK ${DOTNET_SDK_VERSION}, fork ${FORK_VERSION}) on ${BASE_IMAGE}"

docker build \
  -f fork/Dockerfile \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "SONARR_VERSION=${SONARR_VERSION}" \
  --build-arg "BRANCH=${BRANCH}" \
  --build-arg "DOTNET_SDK_VERSION=${DOTNET_SDK_VERSION}" \
  --build-arg "FORK_VERSION=${FORK_VERSION}" \
  -t "${TAG}" \
  .
