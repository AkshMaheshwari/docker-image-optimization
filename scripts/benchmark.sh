#!/bin/bash
# Compares the baseline and optimized Docker images on:
#   - build time
#   - final image size
#   - number of layers
# Run from the project root: bash scripts/benchmark.sh
set -e

echo "=== Building baseline image (no cache) ==="
START=$(date +%s)
docker build --no-cache -f Dockerfile.baseline -t docker-image-optimization:baseline .
END=$(date +%s)
BASELINE_TIME=$((END - START))

echo ""
echo "=== Building optimized image (no cache) ==="
START=$(date +%s)
docker build --no-cache -f Dockerfile.optimized -t docker-image-optimization:optimized .
END=$(date +%s)
OPTIMIZED_TIME=$((END - START))

echo ""
echo "=== Image sizes ==="
docker images docker-image-optimization --format "table {{.Tag}}\t{{.Size}}"

BASELINE_LAYERS=$(docker history -q docker-image-optimization:baseline | wc -l)
OPTIMIZED_LAYERS=$(docker history -q docker-image-optimization:optimized | wc -l)

echo ""
echo "=== Summary ==="
echo "Baseline  build time: ${BASELINE_TIME}s | layers: ${BASELINE_LAYERS}"
echo "Optimized build time: ${OPTIMIZED_TIME}s | layers: ${OPTIMIZED_LAYERS}"
