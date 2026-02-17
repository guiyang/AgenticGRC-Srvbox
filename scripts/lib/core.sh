#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 共享库 - 核心加载器
# =============================================================================
# 文件: scripts/lib/core.sh
# 用途: 加载所有共享库模块，提供统一入口
# 
# 用法:
#   source "$(dirname "$0")/lib/core.sh"
#   或
#   source "/path/to/scripts/lib/core.sh"
# =============================================================================

# 防止重复加载
[[ -n "${_AGENTICGRC_CORE_LOADED:-}" ]] && return 0
_AGENTICGRC_CORE_LOADED=1

# =============================================================================
# 库目录定位
# =============================================================================

# 获取库目录的绝对路径
_AGENTICGRC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# 加载核心模块
# =============================================================================

# 加载顺序很重要：colors -> output -> utils -> config
source "$_AGENTICGRC_LIB_DIR/colors.sh"
source "$_AGENTICGRC_LIB_DIR/output.sh"
source "$_AGENTICGRC_LIB_DIR/utils.sh"
source "$_AGENTICGRC_LIB_DIR/config.sh"

# =============================================================================
# 全局初始化
# =============================================================================

# 脚本初始化函数
init_script() {
    # 设置严格模式
    set -e
    set -o pipefail
    
    # 初始化路径
    init_paths
    
    # 设置信号处理
    trap '_cleanup_on_exit $?' EXIT
    trap '_handle_interrupt' INT TERM
    
    # 打印调试信息
    print_debug "脚本初始化完成"
    print_debug "PROJECT_ROOT: $PROJECT_ROOT"
    print_debug "LIB_DIR: $_AGENTICGRC_LIB_DIR"
}

# 退出清理
_cleanup_on_exit() {
    local exit_code=$1
    
    # 清理临时文件
    if [[ -n "${_TEMP_FILES:-}" ]]; then
        for f in "${_TEMP_FILES[@]}"; do
            rm -f "$f" 2>/dev/null || true
        done
    fi
    
    # 清理临时目录
    if [[ -n "${_TEMP_DIRS:-}" ]]; then
        for d in "${_TEMP_DIRS[@]}"; do
            rm -rf "$d" 2>/dev/null || true
        done
    fi
    
    print_debug "清理完成，退出码: $exit_code"
}

# 中断处理
_handle_interrupt() {
    echo ""
    print_warning "操作被中断"
    exit $E_USER_CANCEL
}

# =============================================================================
# 临时文件管理
# =============================================================================

# 创建临时文件（会在退出时自动清理）
create_temp_file() {
    local prefix="${1:-agenticgrc}"
    local temp_file=$(mktemp -t "${prefix}.XXXXXX")
    
    _TEMP_FILES+=("$temp_file")
    echo "$temp_file"
}

# 创建临时目录（会在退出时自动清理）
create_temp_dir() {
    local prefix="${1:-agenticgrc}"
    local temp_dir=$(mktemp -d -t "${prefix}.XXXXXX")
    
    _TEMP_DIRS+=("$temp_dir")
    echo "$temp_dir"
}

# =============================================================================
# 帮助信息
# =============================================================================

# 显示版本信息
show_version() {
    echo "$AGENTICGRC_NAME v$AGENTICGRC_VERSION"
}

# 显示库信息
show_lib_info() {
    print_header "AgenticGRC-Srvbox 共享库信息"
    
    echo "版本:         $AGENTICGRC_VERSION"
    echo "库目录:       $_AGENTICGRC_LIB_DIR"
    echo ""
    echo "已加载模块:"
    [[ -n "${_AGENTICGRC_COLORS_LOADED:-}" ]] && echo "  ✓ colors.sh"
    [[ -n "${_AGENTICGRC_OUTPUT_LOADED:-}" ]] && echo "  ✓ output.sh"
    [[ -n "${_AGENTICGRC_UTILS_LOADED:-}" ]] && echo "  ✓ utils.sh"
    [[ -n "${_AGENTICGRC_CONFIG_LOADED:-}" ]] && echo "  ✓ config.sh"
    [[ -n "${_AGENTICGRC_CERTS_LOADED:-}" ]] && echo "  ✓ certs.sh"
    echo ""
}

# =============================================================================
# 可选模块加载
# =============================================================================

# 加载证书模块（可选）
load_certs_module() {
    if [[ -z "${_AGENTICGRC_CERTS_LOADED:-}" ]]; then
        if [[ -f "$_AGENTICGRC_LIB_DIR/certs.sh" ]]; then
            source "$_AGENTICGRC_LIB_DIR/certs.sh"
            return 0
        else
            print_warning "证书模块不存在: $_AGENTICGRC_LIB_DIR/certs.sh"
            return 1
        fi
    fi
    return 0
}

# =============================================================================
# 初始化临时文件数组
# =============================================================================

declare -a _TEMP_FILES=()
declare -a _TEMP_DIRS=()

# =============================================================================
# 完成加载
# =============================================================================

print_debug "AgenticGRC-Srvbox 核心库加载完成 (v$AGENTICGRC_VERSION)"
