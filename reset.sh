#!/bin/bash
# Reset between runs: remove the demo's built images so every run starts clean.
# Base images are kept, because re-pulling them is slow on a poor network.
# Pass --full to also clear Docker's build cache.
set -e
docker rm -f demo-node-general 2>/dev/null || true
docker rmi -f demo-node:public demo-node:cg demo-node:cg-libs demo-node:cg-libs-blocked 2>/dev/null || true
if [ "$1" = "--full" ]; then
  docker builder prune -af
fi
echo "Reset done."
