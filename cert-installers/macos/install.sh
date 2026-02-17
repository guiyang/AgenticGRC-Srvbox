#!/bin/bash
# AgenticGRC Root CA 证书安装脚本 - macOS
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CERT_FILE="$(ls *.crt 2>/dev/null | head -n 1)"

if [[ -z "$CERT_FILE" ]]; then
    echo "错误: 未找到证书文件"
    exit 1
fi

echo "正在安装 AgenticGRC Root CA 证书到系统钥匙串..."

# 添加到系统钥匙串并设置为信任
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_FILE"

echo "✓ 证书安装完成"
echo ""
echo "验证: curl https://authentik.local:9443 应该不再显示证书错误"
echo ""
echo "如需卸载:"
echo "  sudo security delete-certificate -c 'AgenticGRC Root CA' /Library/Keychains/System.keychain"
