#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 主控制脚本
# =============================================================================
# 统一入口，管理所有初始化、部署和维护操作
# =============================================================================

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/core.sh"

# 初始化
init_script

# =============================================================================
# 菜单显示
# =============================================================================

show_menu() {
    print_subheader "请选择操作"
    
    echo -e "  ${COLOR_CYAN}初始化${COLOR_NC}"
    print_numbered_item 1 "快速初始化 - 一键完成所有配置（推荐）" 4
    print_numbered_item 2 "自定义初始化 - 可设置域名等参数" 4
    print_numbered_item 3 "验证安装 - 检查配置是否完整" 4
    echo ""
    
    echo -e "  ${COLOR_CYAN}证书管理${COLOR_NC}"
    print_numbered_item 4 "安装证书到系统 - macOS" 4
    print_numbered_item 5 "安装证书到系统 - Linux (Debian/Ubuntu)" 4
    print_numbered_item 6 "安装证书到系统 - Linux (RedHat/CentOS)" 4
    print_numbered_item 7 "SSL 高级配置（Let's Encrypt等）" 4
    echo ""
    
    echo -e "  ${COLOR_CYAN}服务管理${COLOR_NC}"
    print_numbered_item 8 "启动服务" 4
    print_numbered_item 9 "停止服务" 4
    print_numbered_item 10 "查看日志" 4
    print_numbered_item 11 "重启服务" 4
    print_numbered_item 12 "查看服务状态" 4
    echo ""
    
    echo -e "  ${COLOR_CYAN}数据管理${COLOR_NC}"
    print_numbered_item 13 "备份数据" 4
    print_numbered_item 14 "查看备份列表" 4
    echo ""
    
    echo -e "  ${COLOR_CYAN}维护工具${COLOR_NC}"
    print_numbered_item 15 "清理环境（重置所有配置）" 4
    print_numbered_item 16 "查看文档" 4
    echo ""
    
    print_numbered_item 0 "退出" 4
    echo ""
}

# =============================================================================
# 命令执行
# =============================================================================

run_command() {
    local cmd="$1"
    local description="$2"
    
    echo ""
    print_info ">>> $description"
    echo ""
    
    if eval "$cmd"; then
        echo ""
        print_success "完成"
        return 0
    else
        echo ""
        print_error "出错了"
        return 1
    fi
}

# =============================================================================
# 主循环
# =============================================================================

main() {
    while true; do
        clear
        print_banner "$AGENTICGRC_NAME 管理控制台"
        show_menu
        
        read -p "请输入选项 [0-16]: " choice
        
        case $choice in
            1)
                run_command "$SCRIPT_DIR/scripts/quick-init.sh" "运行快速初始化"
                pause
                ;;
            2)
                echo ""
                read -p "请输入证书域名 (默认: $DEFAULT_DOMAIN): " domain
                domain=${domain:-$DEFAULT_DOMAIN}
                run_command "$SCRIPT_DIR/scripts/init-all.sh --domain $domain" "运行自定义初始化"
                pause
                ;;
            3)
                run_command "$SCRIPT_DIR/scripts/verify.sh" "验证安装"
                pause
                ;;
            4)
                run_command "cd $SCRIPT_DIR/cert-installers/macos && ./install.sh" "安装证书到 macOS"
                pause
                ;;
            5)
                run_command "cd $SCRIPT_DIR/cert-installers/linux-debian && ./install.sh" "安装证书到 Debian/Ubuntu"
                pause
                ;;
            6)
                run_command "cd $SCRIPT_DIR/cert-installers/linux-redhat && ./install.sh" "安装证书到 RedHat/CentOS"
                pause
                ;;
            7)
                run_command "$SCRIPT_DIR/scripts/legacy/ssl-setup.sh" "SSL 高级配置"
                pause
                ;;
            8)
                if [[ -f "$SCRIPT_DIR/scripts/generated/start.sh" ]]; then
                    run_command "$SCRIPT_DIR/scripts/generated/start.sh" "启动服务"
                else
                    run_command "cd $SCRIPT_DIR && docker compose up -d" "启动服务"
                fi
                pause
                ;;
            9)
                if [[ -f "$SCRIPT_DIR/scripts/generated/stop.sh" ]]; then
                    run_command "$SCRIPT_DIR/scripts/generated/stop.sh" "停止服务"
                else
                    run_command "cd $SCRIPT_DIR && docker compose down" "停止服务"
                fi
                pause
                ;;
            10)
                echo ""
                print_info ">>> 查看日志 (Ctrl+C 退出)"
                echo ""
                if [[ -f "$SCRIPT_DIR/scripts/generated/logs.sh" ]]; then
                    "$SCRIPT_DIR/scripts/generated/logs.sh"
                else
                    cd "$SCRIPT_DIR" && docker compose logs -f
                fi
                pause
                ;;
            11)
                run_command "cd $SCRIPT_DIR && docker compose restart" "重启服务"
                pause
                ;;
            12)
                run_command "cd $SCRIPT_DIR && docker compose ps" "查看服务状态"
                pause
                ;;
            13)
                if [[ -f "$SCRIPT_DIR/scripts/generated/backup.sh" ]]; then
                    run_command "$SCRIPT_DIR/scripts/generated/backup.sh" "备份数据"
                else
                    echo ""
                    print_error "备份脚本未生成，请先运行初始化"
                fi
                pause
                ;;
            14)
                echo ""
                print_info ">>> 备份列表"
                echo ""
                if [[ -d "$SCRIPT_DIR/backups" ]]; then
                    ls -lh "$SCRIPT_DIR/backups/"
                else
                    echo "暂无备份文件"
                fi
                pause
                ;;
            15)
                run_command "$SCRIPT_DIR/scripts/cleanup.sh" "清理环境"
                pause
                ;;
            16)
                clear
                print_header "文档列表"
                echo ""
                echo "快速开始:        cat QUICKSTART.md"
                echo "完整说明:        cat README.md"
                echo "脚本说明:        cat scripts/README.md"
                echo "部署指南:        cat DEPLOYMENT_GUIDE.md"
                echo ""
                read -p "输入要查看的文档名 (或按 Enter 返回): " doc_name
                if [[ -n "$doc_name" ]]; then
                    if [[ -f "$SCRIPT_DIR/$doc_name" ]]; then
                        less "$SCRIPT_DIR/$doc_name"
                    else
                        echo ""
                        print_error "文件不存在: $doc_name"
                        pause
                    fi
                fi
                ;;
            0)
                echo ""
                print_success "再见！"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                print_error "无效选项，请重试"
                sleep 2
                ;;
        esac
    done
}

# 运行主程序
main
