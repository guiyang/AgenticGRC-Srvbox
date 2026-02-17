#!/bin/bash
# 快速启动 Authentik 服务

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

echo "启动 Authentik 服务..."
echo "工作目录: $(pwd)"
echo ""

docker compose pull
docker compose up -d

echo ""
echo "等待服务启动..."
sleep 5

docker compose ps

echo ""
echo "✓ Authentik 服务已启动"
echo ""
echo "访问地址:"
echo "  HTTP:  http://localhost:9000/if/flow/initial-setup/"
echo "  HTTPS: https://localhost:9443/if/flow/initial-setup/"
