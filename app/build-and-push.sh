#!/usr/bin/env bash
# Builds the private target image and pushes it to the project ECR repository.
# Pass the repository URL in ECR_REPOSITORY_URL.
set -euo pipefail
cd "$(dirname "$0")"

: "${AWS_PROFILE:=crosscloud-admin}"
: "${AWS_REGION:=eu-north-1}"
export AWS_PROFILE AWS_REGION

: "${ECR_REPOSITORY_URL:?Set ECR_REPOSITORY_URL to an existing project ECR repository}"

# The Docker config here still names Docker Desktop's Windows credential helper
# while the engine is the native one on the unix socket, so a normal login fails
# in the helper. A throwaway config avoids it, and takes the short-lived ECR
# token out of the filesystem when the script exits.
DOCKER_CONFIG=$(mktemp -d)
export DOCKER_CONFIG
trap 'rm -rf "$DOCKER_CONFIG"' EXIT

repo="$ECR_REPOSITORY_URL"
tag=${1:-latest}

aws ecr get-login-password | docker login --username AWS --password-stdin "${repo%%/*}"

# Native build: ARM64 workstation, ARM Fargate task.
docker build --platform linux/arm64 -t "$repo:$tag" .
docker push "$repo:$tag"
