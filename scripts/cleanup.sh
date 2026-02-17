#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 清理脚本
# =============================================================================
# 警告：此脚本会删除所有生成的证书、密钥、配置和数据！
# 仅在需要完全重置环境时使用。
# =============================================================================

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

# 初始化
init_script

# 获取项目路径
PROJECT_ROOT=$(get_project_root)

# 显示横幅
print_banner "$AGENTICGRC_NAME 环境清理"

print_error "警告：此操作将删除所有生成的文件和数据！"
echo ""
echo "将被删除的内容："
print_list_item ".env 文件"
print_list_item ".secrets 文件"
print_list_item "SSL 证书"
print_list_item "证书安装包"
print_list_item "生成的辅助脚本"
print_list_item "备份文件"
print_list_item "Docker 卷（数据库数据）"
echo ""

print_warning "此操作无法撤销！"
echo ""

# 确认删除
if ! confirm_destructive "确认删除所有数据?" "DELETE"; then
    exit 0
fi

cd "$PROJECT_ROOT"

# 停止服务
echo ""
print_info "停止 Docker 服务..."
docker compose down -v 2>/dev/null || true

# 删除生成的文件
print_info "删除生成的文件..."

# 环境和密钥文件
rm -f .env .secrets .env.backup *.env.backup 2>/dev/null || true

# 证书文件
rm -rf certs/* 2>/dev/null || true

# 证书安装包
rm -rf cert-installers/linux-debian cert-installers/linux-redhat cert-installers/macos cert-installers/windows 2>/dev/null || true
rm -f cert-installers/*.tar.gz cert-installers/*.zip 2>/dev/null || true
rm -f cert-installers/README.md cert-installers/create-archives.sh 2>/dev/null || true

# 根目录符号链接
rm -f start.sh stop.sh logs.sh backup.sh 2>/dev/null || true

# 生成的脚本
rm -rf scripts/generated/* 2>/dev/null || true

# 部署文档
rm -f DEPLOYMENT_GUIDE.md 2>/dev/null || true

# 备份和数据
rm -rf backups/ 2>/dev/null || true
rm -rf media/* custom-templates/* geoip/* 2>/dev/null || true

echo ""
print_success "清理完成！"
echo ""
echo "现在可以重新初始化："
echo -e "  ${COLOR_YELLOW}./scripts/quick-init.sh${COLOR_NC}"
echo ""
