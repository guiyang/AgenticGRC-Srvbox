#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 快速初始化脚本
# =============================================================================
# 此脚本提供一个简单的入口，用于快速初始化整个环境
# 它会调用完整的 init-all.sh 脚本并使用合理的默认值
#
# 用法:
#   ./scripts/quick-init.sh
# =============================================================================

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

# 初始化
init_script

# 显示横幅
print_banner "$AGENTICGRC_NAME 快速初始化向导"

print_success "欢迎使用 $AGENTICGRC_NAME 快速初始化工具！"
echo ""
echo "此工具将帮助您:"
print_list_item "生成所有必需的密钥和密码"
print_list_item "创建 SSL 证书"
print_list_item "配置环境变量"
print_list_item "创建多平台证书安装包"
print_list_item "设置辅助脚本"
echo ""

# 询问初始化模式
print_subheader "请选择初始化模式"

print_numbered_item 1 "快速初始化 (推荐) - 使用默认配置,适合开发和测试"
print_numbered_item 2 "自定义初始化 - 可以自定义域名等配置"
print_numbered_item 3 "仅生成密钥 - 跳过证书生成,仅创建密钥和配置"
echo ""

read -p "请输入选项 [1-3] (默认: 1): " mode_choice
mode_choice=${mode_choice:-1}

case $mode_choice in
    1)
        echo ""
        print_info "开始快速初始化..."
        echo ""
        "$SCRIPT_DIR/init-all.sh" --non-interactive
        ;;
    2)
        echo ""
        read -p "请输入证书域名 (默认: $DEFAULT_DOMAIN): " domain
        domain=${domain:-$DEFAULT_DOMAIN}
        
        echo ""
        print_info "开始自定义初始化 (域名: $domain)..."
        echo ""
        "$SCRIPT_DIR/init-all.sh" --domain "$domain"
        ;;
    3)
        echo ""
        print_info "开始仅密钥生成模式..."
        echo ""
        "$SCRIPT_DIR/init-all.sh" --non-interactive --skip-certs
        ;;
    *)
        echo ""
        print_warning "无效选项,使用默认快速初始化模式"
        echo ""
        "$SCRIPT_DIR/init-all.sh" --non-interactive
        ;;
esac

exit 0
