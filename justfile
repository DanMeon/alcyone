# Alcyone — Apache Atlas 2.5.0 Fork
# Usage: just <recipe>

export JAVA_HOME := "/opt/homebrew/Cellar/openjdk@11/11.0.30/libexec/openjdk.jdk/Contents/Home"
export MAVEN_OPTS := "-Xms1g -Xmx4g -XX:+UseG1GC -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"

skip_opts := "-DskipTests -Drat.skip=true -Dcheckstyle.skip=true -DskipDocs -Dmaven.javadoc.skip=true -Dmaven.source.skip=true"
profile := "-Pdist,external-hbase-solr"
docker_dir := "dev-support/atlas-docker"
atlas_version := "2.5.0"

# * 전체 빌드 (clean, 첫 빌드용)
build:
    mvn clean verify -T 1C {{profile}} {{skip_opts}}

# * 증분 빌드 (변경분만, 빠름)
rebuild:
    mvn verify -T 1C {{profile}} {{skip_opts}}

# * 증분 빌드 + 오프라인 (의존성 캐시된 후, 가장 빠름)
rebuild-fast:
    mvn verify -T 1C {{profile}} {{skip_opts}} -o

# * 특정 모듈만 빌드 (예: just module graphdb/janusgraph-rdbms)
module path:
    mvn verify -T 1C {{skip_opts}} -pl {{path}} -am

# * UI만 빌드
ui:
    mvn verify {{skip_opts}} -pl dashboardv2,webapp,distro -am

# * 빌드 결과물을 Docker dist로 복사
dist:
    cp distro/target/apache-atlas-{{atlas_version}}-server.tar.gz {{docker_dir}}/dist/
    cp distro/target/apache-atlas-{{atlas_version}}-hive-hook.tar.gz {{docker_dir}}/dist/
    cp distro/target/apache-atlas-{{atlas_version}}-kafka-hook.tar.gz {{docker_dir}}/dist/
    cp distro/target/apache-atlas-{{atlas_version}}-hbase-hook.tar.gz {{docker_dir}}/dist/

# * Docker: Atlas 서버 이미지 빌드
docker: dist
    cd {{docker_dir}} && \
    docker build \
        --build-arg ATLAS_BACKEND=postgres \
        --build-arg ATLAS_SERVER_JAVA_VERSION=11 \
        --build-arg ATLAS_VERSION={{atlas_version}} \
        -f Dockerfile.atlas \
        -t atlas:latest .

# * 컨테이너 실행 (기존 컨테이너 재생성)
up:
    docker compose up -d --force-recreate atlas

# * 컨테이너 중지
down:
    docker compose down

# * 서버 상태 확인
status:
    @curl -s -u admin:datahub http://localhost:21000/api/atlas/admin/status | python3 -m json.tool

# * 로그 확인
logs:
    docker exec atlas tail -f /opt/atlas/logs/application.log

# * 전체 파이프라인 (빌드 → Docker 이미지 → 실행)
deploy: build docker up status

# * 빠른 재배포 (증분 빌드 → Docker 이미지 → 실행)
redeploy: rebuild docker up status
