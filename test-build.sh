#!/usr/bin/env bash
set -euo pipefail

# Read defaults from configuration files if not set via environment
DEFAULT_GO_VERSION=$(jq -r '.release[0]' .github/go-versions.json)
DEFAULT_BOULDER_VERSION=$(cat .github/boulder-version.txt | tr -d '\n')

# Build configuration - override with environment variables
BOULDER_VERSION="${BOULDER_VERSION:-${DEFAULT_BOULDER_VERSION}}"
GO_VERSION="${GO_VERSION:-${DEFAULT_GO_VERSION}}"

echo "Building with:"
echo "  BOULDER_VERSION=${BOULDER_VERSION}"
echo "  GO_VERSION=${GO_VERSION}"
echo ""

IMAGE_TAG="boulder:test-${BOULDER_VERSION}-go${GO_VERSION}"

docker buildx build \
  --build-arg BOULDER_VERSION="${BOULDER_VERSION}" \
  --build-arg GO_VERSION="${GO_VERSION}" \
  --platform linux/amd64,linux/arm64 \
  --load \
  --tag "${IMAGE_TAG}" \
  .

echo ""
echo "Testing amd64 build..."
docker run --rm --platform linux/amd64 "${IMAGE_TAG}" --version

echo ""
echo "Testing arm64 build..."
docker run --rm --platform linux/arm64 "${IMAGE_TAG}" --version

echo ""
echo "Cleaning up..."
docker rmi "${IMAGE_TAG}"
