#!/bin/bash
# 整理脚本文件 - 将根目录的脚本移到 scripts 目录

set -e

echo "正在整理脚本文件..."

# 移动自动生成的脚本到 scripts/generated/
mkdir -p scripts/generated

# 如果存在这些文件，移动它们
[ -f start.sh ] && mv start.sh scripts/generated/ && echo "✓ 移动 start.sh"
[ -f stop.sh ] && mv stop.sh scripts/generated/ && echo "✓ 移动 stop.sh"
[ -f logs.sh ] && mv logs.sh scripts/generated/ && echo "✓ 移动 logs.sh"
[ -f backup.sh ] && mv backup.sh scripts/generated/ && echo "✓ 移动 backup.sh"

# 移动原有脚本到 scripts/legacy/
mkdir -p scripts/legacy

[ -f ssl-setup.sh ] && mv ssl-setup.sh scripts/legacy/ && echo "✓ 移动 ssl-setup.sh"
[ -f init-db.sh ] && mv init-db.sh scripts/legacy/ && echo "✓ 移动 init-db.sh"

echo ""
echo "脚本整理完成！"
echo ""
echo "新的脚本组织结构："
echo "  scripts/               - 核心脚本"
echo "  scripts/generated/     - 自动生成的管理脚本"
echo "  scripts/legacy/        - 原有兼容脚本"
echo "  cert-installers/       - 证书安装脚本"

