#!/bin/bash
set -e
: "${CHAINGUARD_ORG:?Set CHAINGUARD_ORG to your Chainguard org name (see README)}"
set -x

docker pull cgr.dev/$CHAINGUARD_ORG/node:24-dev

docker build --no-cache --progress=plain \
  --build-arg CHAINGUARD_ORG="$CHAINGUARD_ORG" \
  -t demo-node:cg . -f cg.Dockerfile

{ set +x; } 2>/dev/null
echo "Paused — press Enter to scan with grype"
read -r
set -x

grype --by-cve demo-node:cg
