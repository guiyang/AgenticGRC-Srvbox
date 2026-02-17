#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 验证脚本
# =============================================================================
# 此脚本用于验证所有初始化脚本的完整性和功能
# =============================================================================

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

# 初始化
init_script

# 错误计数
ERRORS=0
WARNINGS=0

# 显示横幅
print_banner "$AGENTICGRC_NAME 脚本验证工具"

# =============================================================================
# 验证函数
# =============================================================================

check_file() {
    local file="$1"
    local desc="$2"
    
    if [[ -f "$file" ]]; then
        print_check "ok" "$desc: $file"
        return 0
    else
        print_check "fail" "$desc: $file (缺失)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_executable() {
    local file="$1"
    local desc="$2"
    
    if [[ -f "$file" && -x "$file" ]]; then
        print_check "ok" "$desc: $file (可执行)"
        return 0
    elif [[ -f "$file" ]]; then
        print_check "warn" "$desc: $file (不可执行)"
        chmod +x "$file"
        print_info "  → 已添加执行权限"
        WARNINGS=$((WARNINGS + 1))
        return 0
    else
        print_check "fail" "$desc: $file (缺失)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_directory() {
    local dir="$1"
    local desc="$2"
    
    if [[ -d "$dir" ]]; then
        print_check "ok" "$desc: $dir"
        return 0
    else
        print_check "warn" "$desc: $dir (缺失)"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

check_syntax() {
    local script="$1"
    
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            print_check "ok" "$script 语法正确"
            return 0
        else
            print_check "fail" "$script 语法错误"
            ERRORS=$((ERRORS + 1))
            return 1
        fi
    fi
    return 0
}

# =============================================================================
# 开始验证
# =============================================================================

PROJECT_ROOT=$(get_project_root)
cd "$PROJECT_ROOT"

# 验证核心配置文件
print_subheader "验证核心文件"

check_file ".env.example" "环境配置示例"
check_file ".gitignore" "Git 忽略配置"
check_file "docker-compose.yml" "Docker Compose 配置"

# 验证脚本
print_subheader "验证脚本文件"

check_executable "scripts/init-all.sh" "完整初始化脚本"
check_executable "scripts/quick-init.sh" "快速初始化脚本"
check_executable "scripts/cleanup.sh" "清理脚本"
check_executable "scripts/verify.sh" "验证脚本"

# 验证共享库
print_subheader "验证共享库"

check_file "scripts/lib/core.sh" "核心库"
check_file "scripts/lib/colors.sh" "颜色库"
check_file "scripts/lib/output.sh" "输出库"
check_file "scripts/lib/utils.sh" "工具库"
check_file "scripts/lib/config.sh" "配置库"
check_file "scripts/lib/certs.sh" "证书库"

# 验证遗留脚本
print_subheader "验证遗留脚本"

check_executable "scripts/legacy/ssl-setup.sh" "SSL 设置脚本"
check_executable "scripts/legacy/init-db.sh" "数据库初始化脚本"

# 验证文档
print_subheader "验证文档文件"

check_file "README.md" "项目说明"
check_file "scripts/README.md" "脚本说明文档"

# 验证目录结构
print_subheader "验证目录结构"

check_directory "scripts" "脚本目录"
check_directory "scripts/lib" "共享库目录"
check_directory "scripts/legacy" "遗留脚本目录"
check_directory "scripts/generated" "生成脚本目录"
check_directory "certs" "证书目录"
check_directory "cert-installers" "证书安装包目录"

# 验证依赖工具
print_subheader "验证依赖工具"

if command_exists openssl; then
    print_check "ok" "openssl 已安装"
else
    print_check "fail" "openssl 未安装"
    ERRORS=$((ERRORS + 1))
fi

if command_exists docker; then
    print_check "ok" "docker 已安装"
else
    print_check "warn" "docker 未安装 (运行服务时需要)"
    WARNINGS=$((WARNINGS + 1))
fi

if command_exists docker && docker compose version &>/dev/null; then
    print_check "ok" "docker compose 已安装"
else
    print_check "warn" "docker compose 未安装 (运行服务时需要)"
    WARNINGS=$((WARNINGS + 1))
fi

# 验证脚本语法
print_subheader "验证脚本语法"

for script in scripts/init-all.sh scripts/quick-init.sh scripts/cleanup.sh scripts/verify.sh; do
    check_syntax "$script"
done

for script in scripts/lib/*.sh; do
    check_syntax "$script"
done

# =============================================================================
# 显示结果
# =============================================================================

print_separator "="
echo ""

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    print_success "验证通过！所有脚本和文件完整。"
    echo ""
    echo "下一步："
    print_list_item "运行快速初始化: ./scripts/quick-init.sh"
    print_list_item "安装 SSL 证书: cd cert-installers/<your-os> && ./install.sh"
    print_list_item "启动服务: ./start.sh"
    print_list_item "访问: https://localhost:9443/if/flow/initial-setup/"
elif [[ $ERRORS -eq 0 ]]; then
    print_warning "验证完成，有 $WARNINGS 个警告。"
    echo ""
    echo "建议检查上述警告并修复。"
else
    print_error "验证失败！发现 $ERRORS 个错误，$WARNINGS 个警告。"
    echo ""
    echo "请检查上述错误并修复。"
fi

echo ""
exit $ERRORS
