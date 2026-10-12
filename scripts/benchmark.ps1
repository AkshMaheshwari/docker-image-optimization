# Compares the baseline and optimized Docker images on:
#   - build time
#   - final image size
#   - number of layers
# Run from the project root: .\scripts\benchmark.ps1

Write-Output "=== Building baseline image (no cache) ==="
$start = Get-Date
docker build --no-cache -f Dockerfile.baseline -t docker-image-optimization:baseline .
$baselineTime = (Get-Date) - $start

Write-Output ""
Write-Output "=== Building optimized image (no cache) ==="
$start = Get-Date
docker build --no-cache -f Dockerfile.optimized -t docker-image-optimization:optimized .
$optimizedTime = (Get-Date) - $start

Write-Output ""
Write-Output "=== Image sizes ==="
docker images docker-image-optimization --format "table {{.Tag}}\t{{.Size}}"

$baselineLayers = (docker history -q docker-image-optimization:baseline | Measure-Object -Line).Lines
$optimizedLayers = (docker history -q docker-image-optimization:optimized | Measure-Object -Line).Lines

Write-Output ""
Write-Output "=== Summary ==="
Write-Output ("Baseline  build time: {0:N1}s | layers: {1}" -f $baselineTime.TotalSeconds, $baselineLayers)
Write-Output ("Optimized build time: {0:N1}s | layers: {1}" -f $optimizedTime.TotalSeconds, $optimizedLayers)
