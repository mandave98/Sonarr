# syntax=docker/dockerfile:1

# Builds this fork from source and layers the result onto the stock LinuxServer.io
# Sonarr image, so PUID/PGID handling, s6 init and the docker update lock all keep
# working exactly as they do upstream. See fork/README.md for the full workflow.
#
#   docker build -f fork/Dockerfile -t sonarr-fork:4.0.19.2979 .
#
# BASE_IMAGE must be the LinuxServer image for the same Sonarr version this branch
# is based on, otherwise the UI/database expectations drift from the binaries.

ARG BASE_IMAGE=ghcr.io/linuxserver/sonarr:version-4.0.19.2979

# ---------------------------------------------------------------------------
# Build stage. package.json "engines" pins Node 20.11.1 and Yarn 1.22.19
# exactly (yarn refuses to install otherwise), and that node image ships both.
# The .NET SDK is the exact version global.json pins and upstream CI uses.
# Newer 6.0.4xx SDKs publish a different System.Text.Encoding.CodePages.dll
# than Sonarr.deps.json expects and the app crashes on startup, so keep the
# pin in sync with global.json when rebasing. Everything else runs through
# the repo's own build.sh.
# ---------------------------------------------------------------------------
FROM node:20.11.1-bookworm AS build

ARG DOTNET_SDK_VERSION=6.0.405
ENV DOTNET_ROOT=/usr/share/dotnet \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PATH=$PATH:/usr/share/dotnet

RUN apt-get update \
    && apt-get install -y --no-install-recommends libicu-dev \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && bash /tmp/dotnet-install.sh --version "${DOTNET_SDK_VERSION}" --install-dir /usr/share/dotnet \
    && rm /tmp/dotnet-install.sh \
    && dotnet --version

WORKDIR /src
COPY . .

# Stamped into the assemblies and shown in System > About. Keep it equal to the
# upstream version the branch is based on so version checks behave normally.
ARG SONARR_VERSION=4.0.19.2979
ARG BRANCH=main
ENV SONARR_VERSION=${SONARR_VERSION} \
    BRANCH=${BRANCH}

RUN ./build.sh --backend --frontend --packages -r linux-musl-x64 -f net6.0

# ---------------------------------------------------------------------------
# Test stage (opt-in: docker build --target test). Runs the published unit
# tests the same way upstream CI does, on musl because that is what the build
# above targeted. Running `dotnet test` on the csproj files instead trips
# StyleCop rules that upstream only enforces through the solution build.
# ---------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine AS test

# sqlite-libs: the database tests load the system libsqlite3, like the LSIO image does.
RUN apk add --no-cache icu-libs icu-data-full sqlite-libs && mkdir -p ~/.config/Sonarr
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0

COPY --from=build /src/_tests/net6.0/linux-musl-x64/publish /tests
WORKDIR /tests

# Narrow the run to the areas this fork touches; drop the filter to run everything.
ARG TEST_FILTER="Category!=ManualTest&Category!=WINDOWS&Category!=IntegrationTest&Category!=AutomationTest&(FullyQualifiedName~NzbDrone.Core.Test.Profiles|FullyQualifiedName~CleanupQualityProfileFormatItems|FullyQualifiedName~CustomFormat|FullyQualifiedName~NzbDrone.Api.Test)"
RUN dotnet test Sonarr.Core.Test.dll Sonarr.Api.Test.dll --filter "${TEST_FILTER}"

# ---------------------------------------------------------------------------
# Runtime stage: stock LinuxServer image with only /app/sonarr/bin replaced.
# Mirrors what their Dockerfile does after extracting the upstream tarball.
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG SONARR_VERSION=4.0.19.2979
ARG FORK_VERSION=local

RUN rm -rf /app/sonarr/bin
COPY --from=build /src/_artifacts/linux-musl-x64/net6.0/Sonarr /app/sonarr/bin
RUN rm -rf /app/sonarr/bin/Sonarr.Update \
    && printf 'UpdateMethod=docker\nBranch=main\nPackageVersion=%s\nPackageAuthor=[mandave98/Sonarr](https://github.com/mandave98/Sonarr)\n' \
        "${SONARR_VERSION}-fork-${FORK_VERSION}" > /app/sonarr/package_info
