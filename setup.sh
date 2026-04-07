#!/usr/bin/env bash
set -euo pipefail

# Alcyone — Apache Atlas 2.5.0 Fork Docker Setup
# 포크 저장소 루트에서 Docker 이미지를 빌드합니다.
#
# 사용법:
#   ./setup.sh           # 전체 빌드 (다운로드 + 빌드)
#   ./setup.sh download  # 아카이브 다운로드만
#   ./setup.sh build     # Docker 이미지 빌드만
#
# 요구사항:
#   - Docker Desktop (메모리 6GB 이상 할당 권장)
#   - 디스크 공간 약 10GB (소스 + Maven 캐시 + 이미지)
#   - 첫 빌드 시 30분~1시간 소요 (Maven 의존성 다운로드)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ^ .env 로드
if [ -f .env ]; then
    source .env
else
    echo "[ERROR] .env 파일이 없습니다. 먼저 복사하세요:"
    echo "  cp .env.example .env"
    exit 1
fi

DOCKER_DIR="$SCRIPT_DIR/dev-support/atlas-docker"

# * 의존성 아카이브 다운로드
download_archives() {
    echo "[INFO] 의존성 아카이브 다운로드 중..."
    cd "$DOCKER_DIR"
    bash download-archives.sh
    echo "[OK] 다운로드 완료."
    cd "$SCRIPT_DIR"
}

# * Docker 이미지 빌드
build_images() {
    if [ ! -d "$DOCKER_DIR" ]; then
        echo "[ERROR] dev-support/atlas-docker 디렉토리를 찾을 수 없습니다."
        exit 1
    fi

    cd "$DOCKER_DIR"

    # ^ .env를 빌드 디렉토리에 복사 (공식 빌드 스크립트가 참조)
    cp "$SCRIPT_DIR/.env" "$DOCKER_DIR/.env"

    echo ""
    echo "============================================"
    echo " Step 1/4: Base 이미지 빌드"
    echo "============================================"
    docker build \
        --build-arg UBUNTU_VERSION="${UBUNTU_VERSION}" \
        --build-arg ATLAS_BASE_JAVA_VERSION="${ATLAS_BASE_JAVA_VERSION}" \
        -f Dockerfile.atlas-base \
        -t atlas-base:latest .

    echo ""
    echo "============================================"
    echo " Step 2/4: Atlas 소스 빌드 (Maven, 시간 소요)"
    echo "============================================"
    docker compose -f docker-compose.atlas-build.yml build atlas-build
    docker compose -f docker-compose.atlas-build.yml run --rm atlas-build

    echo ""
    echo "============================================"
    echo " Step 3/4: 인프라 이미지 빌드"
    echo "============================================"

    # ^ ZooKeeper
    docker build -f Dockerfile.atlas-zk -t atlas-zk:latest .

    # ^ Solr
    docker build -f Dockerfile.atlas-solr -t atlas-solr:latest .

    # ^ Kafka
    docker build \
        --build-arg KAFKA_VERSION="${KAFKA_VERSION}" \
        --build-arg ATLAS_VERSION="${ATLAS_VERSION}" \
        -f Dockerfile.atlas-kafka -t atlas-kafka:latest .

    # ^ PostgreSQL
    docker build -f Dockerfile.atlas-db -t atlas-db:latest .

    echo ""
    echo "============================================"
    echo " Step 4/4: Atlas Server 이미지 빌드"
    echo "============================================"
    docker build \
        --build-arg ATLAS_BACKEND=postgres \
        --build-arg ATLAS_SERVER_JAVA_VERSION="${ATLAS_SERVER_JAVA_VERSION}" \
        --build-arg ATLAS_VERSION="${ATLAS_VERSION}" \
        -f Dockerfile.atlas \
        -t atlas:latest .

    cd "$SCRIPT_DIR"

    echo ""
    echo "============================================"
    echo " 빌드 완료!"
    echo "============================================"
    echo ""
    echo "실행:"
    echo "  docker compose up -d"
    echo ""
    echo "Atlas Web UI:"
    echo "  http://localhost:21000"
    echo "  ID: admin / PW: datahub"
    echo ""
}

# * 메인 실행
COMMAND="${1:-all}"

case "$COMMAND" in
    download)
        download_archives
        ;;
    build)
        build_images
        ;;
    all)
        download_archives
        build_images
        ;;
    *)
        echo "Usage: ./setup.sh [download|build|all]"
        exit 1
        ;;
esac
