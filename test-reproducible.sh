#!/usr/bin/env bash
# Test bit-for-bit reproducibility of Boulder binary builds
set -euo pipefail

# Hard-coded test configuration for reproducibility verification
BOULDER_VERSION="v0.20251007.0"
GO_VERSION="1.25.2"
RUNTIME_BASE_IMAGE="gcr.io/distroless/base-nossl-debian12:nonroot@sha256:a1922debbf4ff2cc245d7c0d1e2021cfcee35fe24afae7505aeec59f7e7802f6"

# Expected binary digests by architecture - update when configuration changes
EXPECTED_AMD64_SHA256="0a75fc71064c42064521ae13f1b52457ccb1e184f958cff1c8c55fdc36aebdfa"
EXPECTED_ARM64_SHA256="e7060c12ec7d44286c58964e5b1f2123a1486ad175b6d3622a5f1ad75296a137"

echo "Testing Boulder binary reproducibility:"
echo "  BOULDER_VERSION=${BOULDER_VERSION}"
echo "  GO_VERSION=${GO_VERSION}"
echo "  RUNTIME_BASE_IMAGE=${RUNTIME_BASE_IMAGE}"
echo ""
echo "Expected binary SHA256:"
echo "  amd64: ${EXPECTED_AMD64_SHA256}"
echo "  arm64: ${EXPECTED_ARM64_SHA256}"
echo ""

# Image tag for test
IMAGE_TAG="boulder:repro-test-${BOULDER_VERSION}-go${GO_VERSION}"

# Cleanup function
cleanup() {
  docker rm -f repro-test-amd64 repro-test-arm64 2>/dev/null || true
  rm -f boulder-amd64 boulder-arm64
  docker rmi -f "${IMAGE_TAG}" 2>/dev/null || true
}
trap cleanup EXIT

# Build multi-arch image without layer cache
echo "Building multi-arch image (amd64, arm64) without layer cache..."
docker buildx build \
  --build-arg BOULDER_VERSION="${BOULDER_VERSION}" \
  --build-arg GO_VERSION="${GO_VERSION}" \
  --build-arg RUNTIME_BASE_IMAGE="${RUNTIME_BASE_IMAGE}" \
  --platform linux/amd64,linux/arm64 \
  --no-cache \
  --load \
  --tag "${IMAGE_TAG}" \
  .

# Extract amd64 binary
echo ""
echo "Extracting amd64 binary..."
docker create --name repro-test-amd64 --platform linux/amd64 "${IMAGE_TAG}"
docker cp repro-test-amd64:/usr/local/bin/boulder boulder-amd64

# Extract arm64 binary
echo ""
echo "Extracting arm64 binary..."
docker create --name repro-test-arm64 --platform linux/arm64 "${IMAGE_TAG}"
docker cp repro-test-arm64:/usr/local/bin/boulder boulder-arm64

# Verify binaries
echo ""
echo "Verifying binaries:"
ACTUAL_AMD64_SHA256=$(sha256sum boulder-amd64 | awk '{print $1}')
ACTUAL_ARM64_SHA256=$(sha256sum boulder-arm64 | awk '{print $1}')

echo ""
echo "amd64:"
echo "  Actual:   ${ACTUAL_AMD64_SHA256}"
echo "  Expected: ${EXPECTED_AMD64_SHA256}"

echo ""
echo "arm64:"
echo "  Actual:   ${ACTUAL_ARM64_SHA256}"
echo "  Expected: ${EXPECTED_ARM64_SHA256}"

# Results
echo ""
AMD64_MATCH=false
ARM64_MATCH=false

if [ "$ACTUAL_AMD64_SHA256" = "$EXPECTED_AMD64_SHA256" ]; then
  echo "✓ amd64 binary matches expected: PASS"
  AMD64_MATCH=true
else
  echo "✗ amd64 binary matches expected: FAIL"
fi

if [ "$ACTUAL_ARM64_SHA256" = "$EXPECTED_ARM64_SHA256" ]; then
  echo "✓ arm64 binary matches expected: PASS"
  ARM64_MATCH=true
else
  echo "✗ arm64 binary matches expected: FAIL"
fi

echo ""
if [ "$AMD64_MATCH" = true ] && [ "$ARM64_MATCH" = true ]; then
  echo "SUCCESS: Boulder binaries are reproducible on all architectures"
  exit 0
else
  echo "FAILURE: Reproducibility verification failed"
  echo ""
  echo "To update expected values in the script:"
  echo "  EXPECTED_AMD64_SHA256=\"${ACTUAL_AMD64_SHA256}\""
  echo "  EXPECTED_ARM64_SHA256=\"${ACTUAL_ARM64_SHA256}\""
  exit 1
fi
