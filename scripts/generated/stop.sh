#!/bin/bash
# 停止 Authentik 服务

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

echo "停止 Authentik 服务..."
docker compose down

echo "✓ 服务已停止"
