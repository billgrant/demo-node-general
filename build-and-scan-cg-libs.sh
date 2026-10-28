#!/bin/bash
set -e
: "${CHAINGUARD_ORG:?Set CHAINGUARD_ORG to your Chainguard org name (see README)}"
[ -f cg-libs/.npmrc ] || { echo "Missing cg-libs/.npmrc (see README)"; exit 1; }

set -x
docker pull cgr.dev/$CHAINGUARD_ORG/node:24-dev

# ── Beat 1: a developer adds a package flagged as malware ──
# Expected to FAIL at the Chainguard endpoint. Separate tag, so a failure
# here can never overwrite or produce the real demo image.
if docker build --progress=plain \
     --build-arg CHAINGUARD_ORG="$CHAINGUARD_ORG" \
     --build-arg ADD_BLOCKED_PKG=true \
     --secret id=npmrc,src=cg-libs/.npmrc \
     -t demo-node:cg-libs-blocked . -f cg-libs.Dockerfile; then
  { set +x; } 2>/dev/null
  echo "!!! UNEXPECTED: tensorlake installed. Removing image. Do NOT run it. Report this to Chainguard."
  docker rmi demo-node:cg-libs-blocked
  exit 1
fi
{ set +x; } 2>/dev/null
echo -e "\033[0;31m>>> Blocked by Chainguard Libraries: tensorlake never downloaded, nothing executed.\033[0m"
echo "Paused — press Enter for the clean build"
read -r
set -x

# ── Beat 2: the clean build, with remediated express + axios ──
docker build --no-cache --progress=plain \
  --build-arg CHAINGUARD_ORG="$CHAINGUARD_ORG" \
  --secret id=npmrc,src=cg-libs/.npmrc \
  -t demo-node:cg-libs . -f cg-libs.Dockerfile

{ set +x; } 2>/dev/null
echo "Paused — press Enter to scan with grype"
read -r
set -x

CLICOLOR_FORCE=1 grype --by-cve demo-node:cg-libs | head -30
