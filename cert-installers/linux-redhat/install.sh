#!/bin/bash
# AgenticGRC Root CA 证书安装脚本 - RedHat/CentOS
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "正在安装 AgenticGRC Root CA 证书到系统信任存储..."

# 复制证书
sudo cp *.crt /etc/pki/ca-trust/source/anchors/

# 更新证书存储
sudo update-ca-trust

echo "✓ 证书安装完成"
echo ""
echo "验证: curl https://authentik.local:9443 应该不再显示证书错误"
