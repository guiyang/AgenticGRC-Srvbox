#!/bin/bash
# 测试初始化脚本
# 此脚本用于验证 init-all.sh 的功能

echo "开始测试初始化脚本..."
echo ""

# 创建临时测试目录
TEST_DIR="/tmp/agenticgrc-srvbox-test-$$"
mkdir -p "$TEST_DIR"

echo "测试目录: $TEST_DIR"
echo ""

# 复制必要文件到测试目录
cp .env.example "$TEST_DIR/"
cp scripts/init-all.sh "$TEST_DIR/"
cp docker-compose.yml "$TEST_DIR/"

cd "$TEST_DIR"

# 运行初始化脚本（仅生成密钥，跳过证书）
echo "运行初始化脚本（测试模式）..."
./init-all.sh --non-interactive --skip-certs

echo ""
echo "测试完成！"
echo ""
echo "检查生成的文件:"
ls -lh .env .secrets 2>/dev/null || echo "文件生成失败"

echo ""
echo "清理测试目录..."
rm -rf "$TEST_DIR"

echo "测试完成！"
