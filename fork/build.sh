#!/usr/bin/env bash
# Builds the frontend, the backend and the linux-musl-x64 package the way
# upstream CI does. Upstream dropped its build.sh in v5; the steps below mirror
# .github/actions/build/action.yml (version stamp, msbuild publish, packaging)
# and the frontend job in .github/workflows/build_v5.yml. Re-check both after
# a rebase and keep this file in step with them.
#
#   SONARR_VERSION=5.0.0.2785 BRANCH=develop fork/build.sh
#
# Output: _artifacts/<runtime>/<framework>/Sonarr (binaries plus UI/) and the
# published test assemblies in _tests/<framework>/<runtime>/publish.
set -euo pipefail
cd "$(dirname "$0")/.."

RUNTIME="${RUNTIME:-linux-musl-x64}"
FRAMEWORK="${FRAMEWORK:-net10.0}"
SONARR_VERSION="${SONARR_VERSION:?set SONARR_VERSION, e.g. 5.0.0.2785}"
BRANCH="${BRANCH:-develop}"

echo "==> Stamping version ${SONARR_VERSION} (${BRANCH})"
sed -i'' -e "s/<AssemblyVersion>[0-9.*]\+<\/AssemblyVersion>/<AssemblyVersion>${SONARR_VERSION}<\/AssemblyVersion>/g" src/Directory.Build.props
sed -i'' -e "s/<AssemblyConfiguration>[\$()A-Za-z-]\+<\/AssemblyConfiguration>/<AssemblyConfiguration>${BRANCH}<\/AssemblyConfiguration>/g" src/Directory.Build.props

rm -rf _output _tests _artifacts

echo "==> Building frontend"
yarn install --frozen-lockfile
yarn build

echo "==> Building backend for ${RUNTIME} / ${FRAMEWORK}"
dotnet msbuild -restore src/Sonarr.sln \
  -p:SelfContained=true \
  -p:Configuration=Release \
  -p:Platform=Posix \
  -p:RuntimeIdentifiers="${RUNTIME}" \
  -p:EnableWindowsTargeting=true \
  -t:PublishAllRids

echo "==> Packaging"
folder="_artifacts/${RUNTIME}/${FRAMEWORK}/Sonarr"
mkdir -p "${folder}"
cp -r "_output/${FRAMEWORK}/${RUNTIME}/publish/." "${folder}"
cp -r "_output/Sonarr.Update/${FRAMEWORK}/${RUNTIME}/publish" "${folder}/Sonarr.Update"
cp -r _output/UI "${folder}/UI"
cp LICENSE.md "${folder}"

# Linux packages carry neither the Windows service helpers nor Sonarr.Windows.
rm -f "${folder}"/ServiceUninstall.* "${folder}"/ServiceInstall.* "${folder}"/Sonarr.Windows.*

echo "==> Done: ${folder}"
