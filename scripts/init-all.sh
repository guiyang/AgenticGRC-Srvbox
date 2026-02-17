#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 一键初始化脚本
# =============================================================================
# 此脚本将自动执行以下操作:
# 1. 生成所有必需的密钥和密码
# 2. 创建 SSL 证书
# 3. 配置 .env 文件
# 4. 为不同操作系统打包证书安装文件
# 5. 初始化所需目录结构
#
# 用法:
#   ./scripts/init-all.sh [选项]
#
# 选项:
#   --domain DOMAIN      设置证书域名 (默认: authentik.local)
#   --non-interactive    非交互模式,使用所有默认值
#   --skip-certs         跳过证书生成
#   --help               显示帮助信息
# =============================================================================

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

# 加载证书模块
load_certs_module

# =============================================================================
# 配置
# =============================================================================

# 默认配置
DOMAIN="${AUTHENTIK_DOMAIN:-$DEFAULT_DOMAIN}"
NON_INTERACTIVE=false
SKIP_CERTS=false

# =============================================================================
# 帮助信息
# =============================================================================

show_help() {
    cat << EOF
$AGENTICGRC_NAME 一键初始化脚本 v$AGENTICGRC_VERSION

用法: $0 [选项]

选项:
  --domain DOMAIN       设置证书域名 (默认: $DEFAULT_DOMAIN)
  --non-interactive     非交互模式,使用所有默认值
  --skip-certs          跳过证书生成
  --help                显示此帮助信息

示例:
  # 交互模式
  $0

  # 非交互模式,使用默认域名
  $0 --non-interactive

  # 指定域名
  $0 --domain auth.example.com

  # 跳过证书生成(仅生成密钥)
  $0 --skip-certs

EOF
    exit 0
}

# =============================================================================
# 解析命令行参数
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --skip-certs)
                SKIP_CERTS=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                print_error "未知选项: $1"
                echo "使用 --help 查看帮助"
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# 初始化步骤
# =============================================================================

# 步骤 1: 创建目录结构
setup_directories() {
    print_step "1/8" "创建必要的目录结构..."
    
    local project_root=$(get_project_root)
    
    ensure_dir "$(get_cert_dir)"
    ensure_dir "$(get_cert_dist_dir)"
    ensure_dir "$project_root/media"
    ensure_dir "$project_root/custom-templates"
    ensure_dir "$project_root/geoip"
    ensure_dir "$project_root/scripts/generated"
    
    print_success "目录结构创建完成"
}

# 步骤 2: 生成环境变量文件
generate_env_file() {
    print_step "2/8" "生成环境配置文件..."
    
    local env_file=$(get_env_file)
    local env_example=$(get_env_example)
    local secrets_file=$(get_secrets_file)
    local project_root=$(get_project_root)
    
    # 检查是否已存在 .env 文件
    if [[ -f "$env_file" ]]; then
        if [[ "$NON_INTERACTIVE" == "false" ]]; then
            print_warning ".env 文件已存在"
            if ! confirm "是否覆盖现有配置?" "n"; then
                print_info "跳过 .env 文件生成"
                return 0
            fi
        else
            print_warning ".env 文件已存在,将备份为 .env.backup"
            backup_file "$env_file"
        fi
    fi
    
    # 生成密钥
    print_info "生成数据库密码..."
    local pg_pass=$(generate_secret 36)
    
    print_info "生成 Authentik 密钥..."
    local authentik_secret=$(generate_secret 60)
    
    # 从示例文件复制
    if [[ ! -f "$env_example" ]]; then
        print_error ".env.example 文件不存在"
        exit 1
    fi
    
    cp "$env_example" "$env_file"
    
    # 更新密钥值
    set_env_var "PG_PASS" "$pg_pass" "$env_file"
    set_env_var "AUTHENTIK_SECRET_KEY" "$authentik_secret" "$env_file"
    
    # 保存密钥到安全文件
    cat > "$secrets_file" << EOF
# =============================================================================
# 生成的密钥 - 请妥善保管此文件
# 生成时间: $(date)
# =============================================================================

数据库密码 (PG_PASS):
${pg_pass}

Authentik 密钥 (AUTHENTIK_SECRET_KEY):
${authentik_secret}

# =============================================================================
# 重要提示:
# - 请勿将此文件提交到版本控制系统
# - 请定期备份此文件到安全位置
# - 如果丢失这些密钥,需要重新初始化数据库
# =============================================================================
EOF
    
    chmod 600 "$secrets_file"
    
    print_success "环境配置文件生成完成"
    print_info "密钥已保存到 .secrets 文件(请妥善保管)"
}

# 步骤 3: 生成 SSL 证书
generate_ssl_certificates() {
    if [[ "$SKIP_CERTS" == "true" ]]; then
        print_step "3/8" "跳过证书生成 (--skip-certs)"
        return 0
    fi
    
    print_step "3/8" "生成 SSL 证书..."
    
    local cert_dir=$(get_cert_dir)
    
    # 检查是否已存在证书
    if cert_exists "$cert_dir"; then
        if [[ "$NON_INTERACTIVE" == "false" ]]; then
            print_warning "证书文件已存在"
            if ! confirm "是否重新生成证书?" "n"; then
                print_info "跳过证书生成"
                return 0
            fi
        else
            print_info "非交互模式: 备份现有证书"
            backup_certs "$cert_dir"
        fi
    fi
    
    # 在非交互模式下询问域名
    if [[ "$NON_INTERACTIVE" == "false" ]]; then
        echo ""
        echo "证书配置 (按 Enter 使用默认值):"
        read -p "域名或 IP [$DOMAIN]: " input_domain
        DOMAIN=${input_domain:-$DOMAIN}
    fi
    
    # 生成证书
    generate_root_ca_certs "$DOMAIN" "$cert_dir" "$CERT_VALIDITY_DAYS" || {
        print_error "证书生成失败"
        return 1
    }
    
    # 生成 DH 参数
    generate_dhparam "$cert_dir" 2048 || true
    
    # 显示证书信息
    echo ""
    print_info "证书信息:"
    openssl x509 -in "$cert_dir/fullchain.pem" -noout -text 2>/dev/null | \
        grep -E "(Subject:|Issuer:|DNS:|Not Before|Not After)" || true
}

# 步骤 4: 创建证书安装包
create_cert_installer_packages() {
    if [[ "$SKIP_CERTS" == "true" ]]; then
        print_step "4/8" "跳过证书安装包创建 (--skip-certs)"
        return 0
    fi
    
    print_step "4/8" "为不同操作系统创建证书安装包..."
    
    create_cert_installers "$(get_cert_dir)" "$(get_cert_dist_dir)" "$DOMAIN"
}

# 步骤 5: 创建辅助脚本
create_helper_scripts() {
    print_step "5/8" "创建辅助脚本..."
    
    local project_root=$(get_project_root)
    local generated_dir="$project_root/scripts/generated"
    
    ensure_dir "$generated_dir"
    
    # 创建启动脚本
    cat > "$generated_dir/start.sh" << 'EOF'
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
EOF
    chmod +x "$generated_dir/start.sh"
    
    # 创建停止脚本
    cat > "$generated_dir/stop.sh" << 'EOF'
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
EOF
    chmod +x "$generated_dir/stop.sh"
    
    # 创建日志查看脚本
    cat > "$generated_dir/logs.sh" << 'EOF'
#!/bin/bash
# 查看 Authentik 日志

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

SERVICE=${1:-}

if [ -z "$SERVICE" ]; then
    echo "查看所有服务日志..."
    docker compose logs -f
else
    echo "查看 $SERVICE 服务日志..."
    docker compose logs -f "$SERVICE"
fi
EOF
    chmod +x "$generated_dir/logs.sh"
    
    # 创建备份脚本
    cat > "$generated_dir/backup.sh" << 'EOF'
#!/bin/bash
# 备份 Authentik 数据

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

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/authentik-backup-$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

echo "创建备份: $BACKUP_FILE"

# 备份数据库
echo "备份数据库..."
docker compose exec -T postgresql pg_dump -U authentik authentik > "${BACKUP_FILE}.sql"

# 备份媒体文件
echo "备份媒体文件..."
tar -czf "${BACKUP_FILE}-media.tar.gz" media/

# 备份配置
echo "备份配置文件..."
cp .env "${BACKUP_FILE}.env"

echo ""
echo "✓ 备份完成:"
echo "  数据库: ${BACKUP_FILE}.sql"
echo "  媒体:   ${BACKUP_FILE}-media.tar.gz"
echo "  配置:   ${BACKUP_FILE}.env"
EOF
    chmod +x "$generated_dir/backup.sh"
    
    # 在根目录创建符号链接
    ln -sf "scripts/generated/start.sh" "$project_root/start.sh" 2>/dev/null || true
    ln -sf "scripts/generated/stop.sh" "$project_root/stop.sh" 2>/dev/null || true
    ln -sf "scripts/generated/logs.sh" "$project_root/logs.sh" 2>/dev/null || true
    ln -sf "scripts/generated/backup.sh" "$project_root/backup.sh" 2>/dev/null || true
    
    print_success "辅助脚本创建完成"
    print_info "脚本位置: scripts/generated/"
}

# 步骤 6: 生成部署文档
generate_deployment_guide() {
    print_step "6/8" "生成部署指南..."
    
    local project_root=$(get_project_root)
    
    cat > "$project_root/DEPLOYMENT_GUIDE.md" << EOF
# AgenticGRC-Srvbox 部署指南

**生成时间**: $(date)
**版本**: $AGENTICGRC_VERSION

## 快速开始

### 1. 启动服务

\`\`\`bash
./start.sh
\`\`\`

### 2. 访问 Authentik

- HTTP: http://localhost:9000/if/flow/initial-setup/
- HTTPS: https://localhost:9443/if/flow/initial-setup/

### 3. 创建管理员账户

首次访问时,系统会提示创建管理员密码。默认管理员用户名为 \`akadmin\`。

## 生成的密钥

所有密钥已自动生成并保存在 \`.env\` 和 \`.secrets\` 文件中:

- **数据库密码**: 已自动配置
- **Authentik 密钥**: 已自动配置
- **SSL 证书**: 已生成并位于 \`certs/\` 目录

⚠️ **重要**: 请妥善保管 \`.secrets\` 文件,不要提交到版本控制系统。

## SSL 证书安装

根据您的操作系统,进入相应目录并运行安装脚本:

\`\`\`bash
# macOS
cd cert-installers/macos && ./install.sh

# Linux (Debian/Ubuntu)
cd cert-installers/linux-debian && ./install.sh

# Linux (RedHat/CentOS)
cd cert-installers/linux-redhat && ./install.sh

# Windows (以管理员身份运行 PowerShell)
cd cert-installers/windows && ./install.ps1
\`\`\`

## 常用命令

\`\`\`bash
# 启动服务
./start.sh

# 停止服务
./stop.sh

# 查看日志
./logs.sh

# 查看特定服务日志
./logs.sh server

# 备份数据
./backup.sh

# 查看服务状态
docker compose ps
\`\`\`

## 目录结构

\`\`\`
AgenticGRC-Srvbox/
├── certs/                    # SSL 证书
├── cert-installers/          # 证书安装包
├── media/                    # 用户上传的媒体文件
├── custom-templates/         # 自定义 UI 模板
├── geoip/                    # GeoIP 数据库
├── scripts/                  # 管理脚本
│   ├── lib/                  # 共享库
│   ├── generated/            # 生成的辅助脚本
│   └── legacy/               # 遗留脚本
├── .env                      # 环境配置 (已生成)
├── .secrets                  # 密钥备份 (请妥善保管)
└── docker-compose.yml        # Docker Compose 配置
\`\`\`

## 安全注意事项

1. ✅ 密钥已自动生成,无需手动设置
2. ⚠️ 请勿将 \`.env\` 和 \`.secrets\` 文件提交到版本控制
3. ⚠️ 定期更新 Docker 镜像
4. ⚠️ 生产环境使用 Let's Encrypt 证书
5. ⚠️ 定期备份数据库和配置文件

## 更多资源

- [Authentik 官方文档](https://docs.goauthentik.io/)
- [证书安装包说明](cert-installers/README.md)
- [脚本说明](scripts/README.md)

---

**祝您使用愉快!** 🚀
EOF
    
    print_success "部署指南生成完成"
}

# 步骤 7: 验证配置
verify_setup() {
    print_step "7/8" "验证配置..."
    
    local errors=0
    local project_root=$(get_project_root)
    local env_file=$(get_env_file)
    local secrets_file=$(get_secrets_file)
    local cert_dir=$(get_cert_dir)
    local cert_dist_dir=$(get_cert_dist_dir)
    
    # 检查 .env 文件
    if [[ ! -f "$env_file" ]]; then
        print_check "fail" ".env 文件不存在"
        errors=$((errors + 1))
    else
        print_check "ok" ".env 文件已创建"
    fi
    
    # 检查密钥文件
    if [[ ! -f "$secrets_file" ]]; then
        print_check "warn" ".secrets 文件不存在"
    else
        print_check "ok" ".secrets 文件已创建"
    fi
    
    # 检查证书文件
    if [[ "$SKIP_CERTS" == "false" ]]; then
        if cert_exists "$cert_dir"; then
            print_check "ok" "SSL 证书已生成"
        else
            print_check "fail" "SSL 证书文件缺失"
            errors=$((errors + 1))
        fi
        
        # 检查证书安装包
        if [[ -d "$cert_dist_dir/linux-debian" && -d "$cert_dist_dir/macos" && -d "$cert_dist_dir/windows" ]]; then
            print_check "ok" "证书安装包已创建"
        else
            print_check "warn" "部分证书安装包可能缺失"
        fi
    fi
    
    # 检查辅助脚本
    if [[ -f "$project_root/start.sh" && -f "$project_root/stop.sh" ]]; then
        print_check "ok" "辅助脚本已创建"
    else
        print_check "warn" "部分辅助脚本可能缺失"
    fi
    
    if [[ $errors -gt 0 ]]; then
        print_error "验证发现 $errors 个错误"
        return 1
    else
        print_success "所有配置验证通过"
        return 0
    fi
}

# 步骤 8: 显示完成摘要
show_summary() {
    print_step "8/8" "初始化完成"
    
    print_header "初始化摘要"
    
    echo -e "${COLOR_GREEN}✓ 环境配置${COLOR_NC}"
    echo "  - .env 文件已生成"
    echo "  - .secrets 文件已生成 (请妥善保管)"
    echo ""
    
    if [[ "$SKIP_CERTS" == "false" ]]; then
        echo -e "${COLOR_GREEN}✓ SSL 证书${COLOR_NC}"
        echo "  - 证书已生成: $(get_cert_dir)"
        echo "  - 域名: $DOMAIN"
        echo "  - 有效期: $CERT_VALIDITY_DAYS 天 (约 $((CERT_VALIDITY_DAYS / 365)) 年)"
        echo ""
        
        echo -e "${COLOR_GREEN}✓ 证书安装包${COLOR_NC}"
        echo "  - Linux (Debian/Ubuntu): cert-installers/linux-debian/"
        echo "  - Linux (RedHat/CentOS):  cert-installers/linux-redhat/"
        echo "  - macOS:                  cert-installers/macos/"
        echo "  - Windows:                cert-installers/windows/"
        echo ""
    fi
    
    echo -e "${COLOR_GREEN}✓ 辅助脚本${COLOR_NC}"
    echo "  - ./start.sh   - 启动服务"
    echo "  - ./stop.sh    - 停止服务"
    echo "  - ./logs.sh    - 查看日志"
    echo "  - ./backup.sh  - 备份数据"
    echo ""
    
    print_header "下一步操作"
    
    echo -e "${COLOR_CYAN}1. 安装 SSL 证书到系统 (可选,推荐)${COLOR_NC}"
    echo ""
    
    local os=$(detect_os)
    case "$os" in
        macos)
            echo -e "   ${COLOR_YELLOW}cd cert-installers/macos && ./install.sh${COLOR_NC}"
            ;;
        debian)
            echo -e "   ${COLOR_YELLOW}cd cert-installers/linux-debian && ./install.sh${COLOR_NC}"
            ;;
        redhat)
            echo -e "   ${COLOR_YELLOW}cd cert-installers/linux-redhat && ./install.sh${COLOR_NC}"
            ;;
        *)
            echo "   根据您的操作系统选择相应的安装包"
            ;;
    esac
    echo ""
    
    echo -e "${COLOR_CYAN}2. 启动 Authentik 服务${COLOR_NC}"
    echo ""
    echo -e "   ${COLOR_YELLOW}./start.sh${COLOR_NC}"
    echo ""
    
    echo -e "${COLOR_CYAN}3. 访问 Authentik${COLOR_NC}"
    echo ""
    echo "   HTTP:  http://localhost:9000/if/flow/initial-setup/"
    echo "   HTTPS: https://localhost:9443/if/flow/initial-setup/"
    echo ""
    
    print_header "重要提示"
    
    print_warning "安全注意事项:"
    echo "  1. .env 和 .secrets 文件包含敏感信息,请勿提交到版本控制"
    echo "  2. 定期备份数据库和配置文件 (使用 ./backup.sh)"
    echo "  3. 生产环境建议使用 Let's Encrypt 证书替代自签名证书"
    echo ""
    
    print_success "$AGENTICGRC_NAME 初始化完成! 🎉"
    echo ""
}

# =============================================================================
# 主程序
# =============================================================================

main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 初始化脚本环境
    init_script
    
    # 显示欢迎信息
    clear
    print_banner "$AGENTICGRC_NAME 一键初始化"
    
    print_info "此脚本将自动完成以下任务:"
    echo "  1. 创建必要的目录结构"
    echo "  2. 生成安全的密钥和密码"
    echo "  3. 配置环境变量文件"
    if [[ "$SKIP_CERTS" == "false" ]]; then
        echo "  4. 生成 SSL 证书"
        echo "  5. 创建多平台证书安装包"
    else
        echo "  4. 跳过 SSL 证书生成"
    fi
    echo "  6. 创建辅助脚本"
    echo "  7. 生成部署文档"
    echo ""
    
    if [[ "$NON_INTERACTIVE" == "false" ]]; then
        pause "按 Enter 键继续,或 Ctrl+C 取消..."
        echo ""
    fi
    
    # 检查依赖
    require_dependencies openssl || exit $?
    
    if command_exists docker; then
        print_check "ok" "docker 已安装"
    else
        print_check "warn" "docker 未安装 (运行服务时需要)"
    fi
    
    # 执行初始化步骤
    setup_directories
    generate_env_file
    generate_ssl_certificates
    create_cert_installer_packages
    create_helper_scripts
    generate_deployment_guide
    verify_setup
    show_summary
}

# 运行主程序
main "$@"
