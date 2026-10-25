#!/usr/bin/env bash
# End-to-end smoke test for the fork image: starts a throwaway container and
# drives the API to prove the Always Show flag survives every path, on both API
# versions (the v5 UI talks to /api/v5, tools like Recyclarr still use /api/v3).
#
#   fork/smoke-test.sh sonarr-fork:5.0.0.2785
#
# Needs docker, curl and node (for JSON handling). On Windows Git Bash set
# MSYS_NO_PATHCONV=1 and SMOKE_TMP to a Windows-style directory
# (curl.exe cannot open /tmp paths), e.g.
#   MSYS_NO_PATHCONV=1 SMOKE_TMP=C:/Temp fork/smoke-test.sh sonarr-fork:5.0.0.2785
set -euo pipefail
IMAGE="${1:?image}"
NAME=sonarr-fork-smoke
PORT=18989
BASE="http://localhost:${PORT}"
TMPD="${SMOKE_TMP:-/tmp}"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$NAME" -p ${PORT}:8989 -e PUID=1000 -e PGID=1000 -e TZ=UTC "$IMAGE" >/dev/null
echo "container started, waiting for /ping"
for i in $(seq 1 60); do
  if curl -fs "${BASE}/ping" >/dev/null 2>&1; then break; fi
  sleep 2
  if [ "$i" = 60 ]; then echo "timed out waiting for Sonarr"; docker logs "$NAME" | tail -30; exit 1; fi
done

APIKEY=$(docker exec "$NAME" sh -c 'sed -n "s:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p" /config/config.xml')
[ -n "$APIKEY" ] || { echo "no api key"; exit 1; }
H=(-H "X-Api-Key: ${APIKEY}" -H "Content-Type: application/json")

api() { curl -fsS "${H[@]}" "$@"; }
json() { node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const o=JSON.parse(s);console.log(eval(process.argv[1]))})" "$1"; }

# expect <api version> <true|false>: reads the stored flag back through that API version.
expect() {
  local got
  got=$(api "${BASE}/api/$1/qualityprofile/${PID}" | json "o.formatItems.find(i=>i.format==${CF_ID}).alwaysShow")
  echo "   [$1] stored alwaysShow: ${got} (expected $2)"
  [ "${got}" = "$2" ] || { echo "FAIL"; exit 1; }
}

echo "== system status =="
api "${BASE}/api/v3/system/status" | json "o.version + ' | ' + o.packageVersion + ' | ' + o.packageAuthor + ' | ' + o.packageUpdateMechanism"

echo "== translations served =="
api "${BASE}/api/v3/localization" | json "JSON.stringify({a:o.strings.CustomFormatAlwaysShow, b:o.strings.CustomFormatAlwaysShowHelpText})"

echo "== create custom format =="
CF_ID=$(api -X POST "${BASE}/api/v3/customformat" -d '{"name":"Smoke Dual Audio","includeCustomFormatWhenRenaming":false,"specifications":[{"name":"dual","implementation":"ReleaseTitleSpecification","negate":false,"required":false,"fields":[{"name":"value","value":"dual"}]}]}' | json "o.id")
echo "   custom format id: $CF_ID"

echo "== profile after custom format added, expect alwaysShow=false on both APIs =="
PID=$(api "${BASE}/api/v3/qualityprofile" | json "o[0].id")
expect v3 false
expect v5 false

echo "== v5 PUT alwaysShow=true (what the UI sends), expect true on both APIs =="
api "${BASE}/api/v5/qualityprofile/${PID}" | json "(o.formatItems.find(i=>i.format==${CF_ID}).alwaysShow=true, JSON.stringify(o))" > ${TMPD}/profile-v5-true.json
api -X PUT "${BASE}/api/v5/qualityprofile/${PID}" -d @${TMPD}/profile-v5-true.json >/dev/null
expect v5 true
expect v3 true

echo "== v3 PUT with alwaysShow omitted on every item (Recyclarr style), expect true preserved =="
api "${BASE}/api/v3/qualityprofile/${PID}" | json "(o.formatItems.forEach(i=>delete i.alwaysShow), JSON.stringify(o))" > ${TMPD}/profile-v3-omitted.json
echo "   alwaysShow occurrences in payload: $(grep -c alwaysShow ${TMPD}/profile-v3-omitted.json || true)"
api -X PUT "${BASE}/api/v3/qualityprofile/${PID}" -d @${TMPD}/profile-v3-omitted.json >/dev/null
expect v3 true

echo "== v5 PUT with alwaysShow omitted on every item, expect true preserved =="
api "${BASE}/api/v5/qualityprofile/${PID}" | json "(o.formatItems.forEach(i=>delete i.alwaysShow), JSON.stringify(o))" > ${TMPD}/profile-v5-omitted.json
api -X PUT "${BASE}/api/v5/qualityprofile/${PID}" -d @${TMPD}/profile-v5-omitted.json >/dev/null
expect v5 true

echo "== v3 PUT alwaysShow=false explicitly, expect false on both APIs =="
api "${BASE}/api/v3/qualityprofile/${PID}" | json "(o.formatItems.find(i=>i.format==${CF_ID}).alwaysShow=false, JSON.stringify(o))" > ${TMPD}/profile-v3-false.json
api -X PUT "${BASE}/api/v3/qualityprofile/${PID}" -d @${TMPD}/profile-v3-false.json >/dev/null
expect v3 false
expect v5 false

echo "smoke test finished OK"
