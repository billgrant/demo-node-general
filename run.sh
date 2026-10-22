#!/bin/bash
# Usage: ./run.sh demo-node:public   (or demo-node:cg, demo-node:cg-libs)
IMAGE="${1:-demo-node:cg}"
set -x
docker run --rm -d --name demo-node-general -p 3000:3000 "$IMAGE"
sleep 2
curl -s localhost:3000/quotes
docker stop demo-node-general
