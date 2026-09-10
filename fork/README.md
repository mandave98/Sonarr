# Fork notes: "Always Show" custom formats

This fork of [Sonarr/Sonarr](https://github.com/Sonarr/Sonarr) carries one small
feature on top of the exact release we run in Docker. This file is the map for
future-us: what the patch does, where it lives, how to move it to the next
release, and how to build and ship the image.

## What the feature does

- Every custom format inside a Quality Profile gets an **Always Show** checkbox
  (Settings > Profiles > edit profile > Custom Formats, next to the score).
- On a series page, an episode row shows the checked formats that actually
  match the episode's file as small tags next to the title, right where the
  "Season Finale" tag already goes. Nothing shows for episodes without a file or
  without a matching format.
- Nothing else changes. The hidden "Formats" column still lists every matching
  format, scoring is untouched, and there is no language-specific logic. The
  flag is generic and works with any custom format.

## Where the patch lives

Backend (C#)

| File | Change |
| --- | --- |
| `src/NzbDrone.Core/Profiles/ProfileFormatItem.cs` | `AlwaysShow` bool on the profile's format item. |
| `src/Sonarr.Api.V3/Profiles/Quality/QualityProfileResource.cs` | `alwaysShow` on the API resource (nullable), mapping both ways, and `PreserveOmittedAlwaysShow`. |
| `src/Sonarr.Api.V3/Profiles/Quality/QualityProfileController.cs` | `Update` keeps stored flags for items the client omitted. |
| `src/Sonarr.Api.V3/openapi.json` | Hand-added `alwaysShow` property. |
| `src/NzbDrone.Core/Localization/Core/en.json` | `CustomFormatAlwaysShow` and `CustomFormatAlwaysShowHelpText`. |
| `src/NzbDrone.Core.Test/Profiles/ProfileRepositoryFixture.cs` | Round-trip persistence test. |
| `src/NzbDrone.Api.Test/v3/Profiles/QualityProfileResourceFixture.cs` | Mapping and preservation tests. |

Frontend (v4 UI, redux + class components)

| File | Change |
| --- | --- |
| `frontend/src/typings/CustomFormat.ts` | `alwaysShow` on `QualityProfileFormatItem`. |
| `frontend/src/Settings/Profiles/Quality/QualityProfileFormatItem.js` (+ css) | The checkbox in each format row. |
| `frontend/src/Settings/Profiles/Quality/QualityProfileFormatItems.js` (+ css) | Header cell, help text, handler pass-through. |
| `frontend/src/Settings/Profiles/Quality/EditQualityProfileModalContentConnector.js` | `onQualityProfileFormatItemAlwaysShowChange`, a copy of the score handler. |
| `frontend/src/Series/Details/EpisodeRowConnector.js` | Reads the series' profile from redux and filters the file's `customFormats` to the flagged ids. |
| `frontend/src/Series/Details/EpisodeRow.js` (+ css) | Renders the filtered list with the existing `EpisodeFormats` labels. |

Fork tooling: everything under `fork/` (this file, `Dockerfile`,
`Dockerfile.dockerignore`, `build-image.sh`). Upstream has no `fork/`
directory, so it never conflicts.

Search for `Fork:` comments in the source to find the touch points quickly.

## Design notes worth remembering

- **No database migration.** `FormatItems` is stored as one JSON column, so the
  new bool just appears in that JSON. Old rows deserialize with `false`.
  Rolling back to stock Sonarr is safe: the unknown key is ignored and dropped
  on the next save.
- **The episode row recalculates nothing.** The file's `customFormats` are
  already computed by the API, and quality profiles are already in redux. The
  connector only intersects the two lists.
- **`alwaysShow` is nullable on the V3 API on purpose.** Tools like Recyclarr
  PUT whole profiles without knowing about the field. When an item arrives
  without it, `Update` copies the stored value instead of resetting it to
  false. The web UI always sends an explicit value, so unticking still works.
- `openapi.json` and the `*.css.d.ts` files are generated upstream. We edited
  them by hand to keep the diff honest; a webpack build regenerates the css
  typings anyway.
- Only `en.json` has the new strings. Other UI languages fall back to English
  for those two keys.

## Branching model

- `origin` is `mandave98/Sonarr`, `upstream` is `Sonarr/Sonarr`.
- The feature branch is `feature/always-show-custom-formats`, based on tag
  `v4.0.19.2979`. That tag is what the LinuxServer `version-4.0.19.2979`
  image runs, so the branch is "the binary we run plus the patch".
- Upstream tags every release as `v4.x.y.build`. The `v4-stable` channel
  (LinuxServer's `latest`) only ever points at tags on `main`. Builds from
  `develop` are tagged too but show up as `v4-nightly` / `v4-preview`. To see
  what stable is right now:

  ```bash
  curl -s http://services.sonarr.tv/v1/releases | jq -r '."v4-stable".version'
  ```

Moving to the next release, tag to tag:

```bash
git fetch upstream --tags
git checkout feature/always-show-custom-formats
git rebase --onto v4.0.20.NNNN v4.0.19.2979
# fix conflicts if any (see hotspots below), then
git push --force-with-lease origin feature/always-show-custom-formats
```

Then update the version defaults in `fork/Dockerfile` (`BASE_IMAGE`,
`SONARR_VERSION`) and `fork/build-image.sh`, replace `4.0.19.2979` in this
file, rebuild, and redeploy.

Likely conflict hotspots when rebasing: `en.json` (huge, alphabetical, churns
constantly), `openapi.json` (regenerated by an upstream bot), and
`EditQualityProfileModalContentConnector.js` if upstream reworks the profile
editor. All of them are a few lines to re-apply.

## Building the image

Requirements: Docker with BuildKit. No local .NET or Node needed; the build
stage pins Node 20.11.1 / Yarn 1.22.19 (the exact versions `package.json`
demands) and installs the exact .NET SDK that `global.json` pins.

**The SDK pin is not cosmetic.** The first build used the newest 6.0.4xx SDK
(6.0.428) and produced an image that crashed on startup with
`Could not load file or assembly 'System.Text.Encoding.CodePages, Version=8.0.0.0'`.
That SDK's self-contained publish shipped the runtime pack's 6.0.0.0 copy of
that assembly while `Sonarr.deps.json` still referenced the NuGet 8.0.0.0
one. Building with 6.0.405, exactly what upstream CI uses, reproduces the
stock binary set file for file (only our own assemblies and `en.json` differ
in size). When upstream bumps `global.json`, bump `DOTNET_SDK_VERSION` in
`fork/Dockerfile` to the same value.

```bash
fork/build-image.sh                       # -> sonarr-fork:4.0.19.2979
SONARR_VERSION=4.0.20.NNNN fork/build-image.sh
```

What it does:

1. `node:20.11.1-bookworm` + .NET 6 SDK, then the repo's own
   `./build.sh --backend --frontend --packages -r linux-musl-x64 -f net6.0`.
2. Starts from the stock LinuxServer image for the same version and replaces
   only `/app/sonarr/bin` with `_artifacts/linux-musl-x64/net6.0/Sonarr`.
   `Sonarr.Update` is removed and `package_info` is rewritten exactly like the
   LinuxServer Dockerfile does, so in-app updates stay disabled and
   System > About shows the fork as the package source.

Expect the first build to take a while (full .NET restore, `yarn install`,
webpack). Later builds reuse the toolchain layers but redo the source build
whenever anything in the repo changes. The build context includes `.git` on
purpose: SourceLink runs during the build and warnings are errors there.

The image is roughly twice the size of the stock one because the stock
`/app/sonarr/bin` layer is still underneath ours. Harmless, just not pretty.

To keep the image somewhere other than the build machine:

```bash
docker tag sonarr-fork:4.0.19.2979 ghcr.io/mandave98/sonarr-fork:4.0.19.2979
docker push ghcr.io/mandave98/sonarr-fork:4.0.19.2979   # after docker login ghcr.io
```

## Deploying

Swap the image in the compose file and keep everything else:

```yaml
services:
  sonarr:
    image: sonarr-fork:4.0.19.2979   # was lscr.io/linuxserver/sonarr:latest
    # same environment, volumes and ports as before
```

The `/config` volume is fully compatible, in both directions. Going back to
the LinuxServer image is just changing the line back.

## Verifying a build

Backend unit tests run from the published test assemblies, on musl, the same
way upstream CI runs them. The `test` stage in `fork/Dockerfile` does that:

```bash
docker build -f fork/Dockerfile --target test .
# everything instead of the fork-focused subset:
docker build -f fork/Dockerfile --target test --build-arg TEST_FILTER="Category!=ManualTest&Category!=WINDOWS&Category!=IntegrationTest&Category!=AutomationTest" .
```

Do not run `dotnet test` against the `.csproj` files directly. Without the
solution context `stylecop.json` is not picked up, so hundreds of unrelated
StyleCop warnings become errors and nothing builds.

Frontend checks run inside the build stage image:

```bash
docker build -f fork/Dockerfile --target build -t sonarr-fork-build:dev .
docker run --rm sonarr-fork-build:dev yarn lint
```

Two known quirks at this tag, neither caused by the fork:

- `yarn stylelint` crashes on load (`string-width` v5 is ESM, stylelint 15
  requires it as CommonJS). To lint CSS anyway, swap the package inside a
  throwaway container: `mv node_modules/string-width node_modules/string-width-v5 && cp -r node_modules/string-width-cjs node_modules/string-width`,
  then run `yarn stylelint`. The fork's CSS passes that way.
- `npx tsc --noEmit` reports about 230 errors in `node_modules/@types`
  packages. They are identical with and without the fork; upstream CI does
  not run tsc on v4.

Running any of this on the Windows host is unreliable: the machine's .NET SDK
does not match `global.json`, and yarn refuses to install under Node 24.

`fork/smoke-test.sh <image>` starts a throwaway container from the built
image and drives the API end to end: the container boots and reports the
fork package info, the two new translation strings are served, a custom
format is created, the profile picks it up with `alwaysShow: false`, a PUT
with `true` sticks, a PUT that omits the field (what Recyclarr sends) keeps
`true`, and an explicit `false` clears it. It needs docker, curl and node;
see the header of the script for the Windows Git Bash incantation.

Manual check after deploying:

1. Settings > Profiles > edit a profile, tick **Always Show** on a format,
   save. Reopen the profile; the tick must still be there.
2. Open a series using that profile. Episodes whose file matches the format
   show the tag next to the title.
3. `GET /api/v3/qualityprofile` lists `"alwaysShow": true` on that item.
4. If Recyclarr is in use, run a sync and repeat step 1. The tick must survive.

## Upstream etiquette

Upstream's `AGENTS.md` and `CONTRIBUTING.md` require human-reviewed
submissions with no AI attribution in commits or PR text. This fork is for our
own deployment. If any of it ever goes upstream, rewrite the commit messages
and description in your own words and follow their PR template honestly.

## If we ever move to Sonarr v5

v5 has no release tags yet (only nightly builds from `v5-develop`) and its
frontend is a different codebase (react-query and zustand instead of redux,
TSX everywhere). The backend half of this patch applies as-is. The frontend
half maps to `useQualityProfile` / `useEpisodeFile` hooks in
`frontend/src/Series/Details/EpisodeRow.tsx` and the TSX versions of the
profile editor components. The V5 API resource would also need the field.
