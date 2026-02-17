#!/bin/bash
# 备份 Authentik 数据

# 获取脚本所在目录（处理符号链接）
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(get_script_dir)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT" || { echo "错误: 无法切换到 $PROJECT_ROOT"; exit 1; }

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/authentik-backup-$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

echo "创建备份: $BACKUP_FILE"

# 备份数据库
echo "备份数据库..."
docker compose exec -T postgresql pg_dump -U authentik authentik > "${BACKUP_FILE}.sql"

# 备份媒体文件
echo "备份媒体文件..."
tar -czf "${BACKUP_FILE}-media.tar.gz" media/

# 备份配置
echo "备份配置文件..."
cp .env "${BACKUP_FILE}.env"

echo ""
echo "✓ 备份完成:"
echo "  数据库: ${BACKUP_FILE}.sql"
echo "  媒体:   ${BACKUP_FILE}-media.tar.gz"
echo "  配置:   ${BACKUP_FILE}.env"
