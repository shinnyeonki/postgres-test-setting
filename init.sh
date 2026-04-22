#!/bin/bash

# 1. 변수 설정 (관리 포인트)
DB_ROOT_USER="postgres"
DB_ROOT_PW="postgrespassword"
DB_NAME="sampledb"
DB_USER="sampleuser"
DB_PW="samplepassword"

PGADMIN_EMAIL="admin@admin.com"
PGADMIN_PW="admin"
PGADMIN_PORT="8005"

DB_CONTAINER_NAME="sql_tutorial_db"
PGADMIN_CONTAINER_NAME="sql_tutorial_admin"


# 2. docker-compose.yml 파일 생성
if [ ! -f "docker-compose.yml" ]; then
    echo "📄 docker-compose.yml 파일이 없어 새로 생성합니다..."
    cat <<EOF > docker-compose.yml
services:
  db:
    image: postgres:15
    container_name: ${DB_CONTAINER_NAME}
    environment:
      POSTGRES_USER: ${DB_ROOT_USER}
      POSTGRES_PASSWORD: ${DB_ROOT_PW}
    ports:
      - "5432:5432"
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    restart: always

  pgadmin:
    image: dpage/pgadmin4
    container_name: ${PGADMIN_CONTAINER_NAME}
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PW}
    ports:
      - "${PGADMIN_PORT}:80"
    volumes:
      - ./servers.json:/pgadmin4/servers.json
    depends_on:
      - db
    restart: always

volumes:
  postgres_data:
EOF
else
    echo "✅ 이미 docker-compose.yml 파일이 존재합니다."
fi

# 3. pgAdmin 서버 등록 정보 파일 생성
if [ ! -f "servers.json" ]; then
    echo "📄 servers.json 파일을 생성합니다..."
    cat <<EOF > servers.json
{
  "Servers": {
    "1": {
      "Name": "${DB_NAME}",
      "Group": "Servers",
      "Host": "db",
      "Port": 5432,
      "MaintenanceDB": "${DB_NAME}",
      "Username": "${DB_USER}",
      "Password": "${DB_PW}",
      "SSLMode": "prefer",
      "PassFile": "/tmp/pgpassfile"
    }
  }
}
EOF
else
    echo "✅ 이미 servers.json 파일이 존재합니다."
fi

# 4. 컨테이너 실행
echo "🐳 Docker 컨테이너 실행 중..."
docker compose up -d

# 5. DB 엔진 준비 대기 (상태 체크 루프)
echo "⌛ PostgreSQL 시작 대기 중..."
until docker exec ${DB_CONTAINER_NAME} pg_isready -U ${DB_ROOT_USER} > /dev/null 2>&1; do
  echo "접속 대기 중... (1초)"
  sleep 1
done

# 6. 유저 및 데이터베이스 생성
echo "🛠️ 작업 유저(${DB_USER}) 및 데이터베이스(${DB_NAME}) 생성 중..."

# 유저 생성
docker exec -i ${DB_CONTAINER_NAME} psql -U ${DB_ROOT_USER} -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PW}';" 2>/dev/null || echo "이미 존재하는 유저입니다."
# 데이터베이스 생성
docker exec -i ${DB_CONTAINER_NAME} psql -U ${DB_ROOT_USER} -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || echo "이미 존재하는 데이터베이스입니다."
# 권한 부여
docker exec -i ${DB_CONTAINER_NAME} psql -U ${DB_ROOT_USER} -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

echo "========================================="
echo "🎉 설정 완료!"
echo "-----------------------------------------"
echo "▶ 1. DB 접속 정보"
echo "  - User: ${DB_USER}"
echo "  - Password: ${DB_PW}"
echo "  - Database: ${DB_NAME}"
echo ""
echo "▶ 2. pgAdmin 접속 및 서버 등록"
echo "  - URL: http://localhost:${PGADMIN_PORT}"
echo "  - ID: ${PGADMIN_EMAIL} / PW: ${PGADMIN_PW}"
echo "========================================="
