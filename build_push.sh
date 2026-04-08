#!/usr/bin/env bash
set -euo pipefail

# Atlas Docker images: cross-build for amd64 and push to NCR registry
#
# Usage:
#   ./build_push.sh                  # Build all images (amd64, no push)
#   ./build_push.sh --push           # Build all and push to registry
#   ./build_push.sh --push atlas     # Build & push atlas only
#   ./build_push.sh arm              # Build for arm64 (local dev)
#   ./build_push.sh prod --push      # Push to prod registry

ARCH="amd"
ENV="dev"
PUSH=false
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    amd|arm)   ARCH="$arg" ;;
    dev|prod)  ENV="$arg" ;;
    --push)    PUSH=true ;;
    *)         TARGETS+=("$arg") ;;
  esac
done

# Registry
if [[ "$ENV" == "prod" ]]; then
  REGISTRY="jadx-si-registry.ncr.gov-ntruss.com"
else
  REGISTRY="jadx-registry.ncr.gov-ntruss.com"
fi

# Platform & tag
if [[ "$ARCH" == "arm" ]]; then
  PLATFORM="linux/arm64"
  TAG="arm-latest"
else
  PLATFORM="linux/amd64"
  TAG="latest"
fi

# Build args from .env
DOCKER_DIR="dev-support/atlas-docker"
UBUNTU_VERSION="22.04"
ATLAS_BASE_JAVA_VERSION="11"
ATLAS_SERVER_JAVA_VERSION="11"
ATLAS_VERSION="2.5.0"
KAFKA_VERSION="2.8.2"

# Load overrides from .env if exists
if [[ -f "${DOCKER_DIR}/.env" ]]; then
  source "${DOCKER_DIR}/.env"
fi

# Copy dist tarballs
DIST_SRC="distro/target"
DIST_DST="${DOCKER_DIR}/dist"
REQUIRED_TARBALLS=(
  "apache-atlas-${ATLAS_VERSION}-server.tar.gz"
)

if [[ ! -d "$DIST_SRC" ]]; then
  echo "Error: ${DIST_SRC} not found. Run 'just build' first." >&2
  exit 1
fi

mkdir -p "$DIST_DST"
MISSING=()
for tarball in "${REQUIRED_TARBALLS[@]}"; do
  if [[ -f "${DIST_SRC}/${tarball}" ]]; then
    cp -f "${DIST_SRC}/${tarball}" "$DIST_DST/"
  elif [[ ! -f "${DIST_DST}/${tarball}" ]]; then
    MISSING+=("$tarball")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: missing dist tarballs:" >&2
  for m in "${MISSING[@]}"; do echo "  - $m" >&2; done
  echo "Run 'just build' first." >&2
  exit 1
fi
echo "Dist tarballs ready in ${DIST_DST}"

# Copy tools
TOOLS_DST="${DIST_DST}/tools"
mkdir -p "$TOOLS_DST"

declare -A TOOLS=(
  ["atlas-index-repair"]="atlas-index-repair-tool-${ATLAS_VERSION}.jar repair_index.py atlas-logback.xml"
  ["notification-analyzer"]="atlas-notification-analyzer-${ATLAS_VERSION}.jar atlas-logback.xml atlas-application.properties"
)

for tool in "${!TOOLS[@]}"; do
  TOOL_SRC="tools/${tool}"
  TOOL_DST="${TOOLS_DST}/${tool}"
  mkdir -p "$TOOL_DST"

  for file in ${TOOLS[$tool]}; do
    if [[ -f "${TOOL_SRC}/target/${file}" ]]; then
      cp -f "${TOOL_SRC}/target/${file}" "$TOOL_DST/"
    elif [[ -f "${TOOL_SRC}/src/main/resources/${file}" ]]; then
      cp -f "${TOOL_SRC}/src/main/resources/${file}" "$TOOL_DST/"
    else
      echo "Warning: ${file} not found for ${tool}" >&2
    fi
  done
  echo "Tool copied: ${tool}"
done

OUTPUT_FLAGS="--load"
if [[ "$PUSH" == true ]]; then
  OUTPUT_FLAGS="--push"
fi

echo "Registry: $REGISTRY"
echo "Platform: $PLATFORM (tag: $TAG)"
echo "Output:   ${PUSH:+push}${PUSH:+}${PUSH:-load}"
echo ""

# Default: build all
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("base" "zk" "solr" "kafka" "atlas")
fi

for target in "${TARGETS[@]}"; do
  case "$target" in
    base)
      echo "==> Building atlas-base..."
      docker buildx build \
        --platform "$PLATFORM" \
        --build-arg UBUNTU_VERSION="$UBUNTU_VERSION" \
        --build-arg ATLAS_BASE_JAVA_VERSION="$ATLAS_BASE_JAVA_VERSION" \
        -f "${DOCKER_DIR}/Dockerfile.atlas-base" \
        -t "atlas-base:${TAG}" \
        --load \
        "$DOCKER_DIR"
      ;;

    zk)
      echo "==> Building atlas-zk..."
      docker buildx build \
        --platform "$PLATFORM" \
        -f "${DOCKER_DIR}/Dockerfile.atlas-zk" \
        -t "${REGISTRY}/atlas-zk:${TAG}" \
        $OUTPUT_FLAGS \
        "$DOCKER_DIR"
      ;;

    solr)
      echo "==> Building atlas-solr..."
      docker buildx build \
        --platform "$PLATFORM" \
        -f "${DOCKER_DIR}/Dockerfile.atlas-solr" \
        -t "${REGISTRY}/atlas-solr:${TAG}" \
        $OUTPUT_FLAGS \
        "$DOCKER_DIR"
      ;;

    kafka)
      echo "==> Building atlas-kafka..."
      docker buildx build \
        --platform "$PLATFORM" \
        --build-arg ATLAS_VERSION="$ATLAS_VERSION" \
        --build-arg KAFKA_VERSION="$KAFKA_VERSION" \
        -f "${DOCKER_DIR}/Dockerfile.atlas-kafka" \
        -t "${REGISTRY}/atlas-kafka:${TAG}" \
        $OUTPUT_FLAGS \
        "$DOCKER_DIR"
      ;;

    atlas)
      echo "==> Building atlas..."
      docker buildx build \
        --platform "$PLATFORM" \
        --build-arg ATLAS_BACKEND=postgres \
        --build-arg ATLAS_SERVER_JAVA_VERSION="$ATLAS_SERVER_JAVA_VERSION" \
        --build-arg ATLAS_VERSION="$ATLAS_VERSION" \
        -f "${DOCKER_DIR}/Dockerfile.atlas" \
        -t "${REGISTRY}/atlas:${TAG}" \
        $OUTPUT_FLAGS \
        "$DOCKER_DIR"
      ;;

    *)
      echo "Unknown target: $target (available: base, zk, solr, kafka, atlas)" >&2
      exit 1
      ;;
  esac
  echo ""
done

echo "Done."
