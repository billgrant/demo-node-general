#!/bin/bash
set -e
set -x

docker pull node:24

docker build --no-cache --progress=plain \
  -t demo-node:public . -f Dockerfile

{ set +x; } 2>/dev/null
echo "Paused — press Enter to scan with grype"
read -r
set -x

grype --by-cve demo-node:public
