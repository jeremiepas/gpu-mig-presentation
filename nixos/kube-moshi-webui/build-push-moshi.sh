#!/bin/bash

# Build and push Moshi Docker image
# Usage: ./build-push-moshi.sh [REGISTRY_URL] [TAG]

set -e

# Default values
REGISTRY_URL="ghcr.io"
TAG="latest"
IMAGE_NAME="moshi"

# Parse arguments
if [ $# -ge 1 ]; then
  REGISTRY_URL="$1"
fi

if [ $# -ge 2 ]; then
  TAG="$2"
fi

# Build Docker image
 echo "Building Moshi Docker image with tag: $TAG"
 docker build -t "$IMAGE_NAME:$TAG" .

# Tag for registry
echo "Tagging image for registry: $REGISTRY_URL"
 docker tag "$IMAGE_NAME:$TAG" "$REGISTRY_URL/kyutai-labs/$IMAGE_NAME:$TAG"

# Login to registry (GitHub Container Registry in this case)
echo "Logging in to $REGISTRY_URL"
 echo "Please enter your GitHub username:"
 read -r GITHUB_USERNAME
 echo "Please enter your GitHub Personal Access Token (with packages:write scope):"
 read -r -s GITHUB_TOKEN
 echo "$GITHUB_TOKEN" | docker login "$REGISTRY_URL" -u "$GITHUB_USERNAME" --password-stdin

# Push to registry
echo "Pushing image to $REGISTRY_URL"
 docker push "$REGISTRY_URL/kyutai-labs/$IMAGE_NAME:$TAG"

echo "Successfully built and pushed $REGISTRY_URL/kyutai-labs/$IMAGE_NAME:$TAG"