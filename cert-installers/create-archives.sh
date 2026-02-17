#!/bin/bash
# 创建各平台的压缩包

cd "$(dirname "$0")"

echo "创建压缩包..."

[[ -d linux-debian ]] && tar -czf agenticgrc-ca-linux-debian.tar.gz linux-debian/ README.md && echo "✓ linux-debian"
[[ -d linux-redhat ]] && tar -czf agenticgrc-ca-linux-redhat.tar.gz linux-redhat/ README.md && echo "✓ linux-redhat"
[[ -d macos ]] && tar -czf agenticgrc-ca-macos.tar.gz macos/ README.md && echo "✓ macos"

if command -v zip &>/dev/null && [[ -d windows ]]; then
    zip -rq agenticgrc-ca-windows.zip windows/ README.md && echo "✓ windows"
fi

echo "完成"
