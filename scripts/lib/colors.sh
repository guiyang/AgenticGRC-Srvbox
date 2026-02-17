#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 共享库 - 颜色定义
# =============================================================================
# 文件: scripts/lib/colors.sh
# 用途: 统一管理所有脚本的颜色输出
# =============================================================================

# 防止重复加载
[[ -n "${_AGENTICGRC_COLORS_LOADED:-}" ]] && return 0
_AGENTICGRC_COLORS_LOADED=1

# =============================================================================
# 颜色定义
# =============================================================================

# 基础颜色
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_WHITE='\033[1;37m'
export COLOR_GRAY='\033[0;90m'
export COLOR_NC='\033[0m'  # No Color / Reset

# 别名（兼容旧代码）
export RED="$COLOR_RED"
export GREEN="$COLOR_GREEN"
export YELLOW="$COLOR_YELLOW"
export BLUE="$COLOR_BLUE"
export CYAN="$COLOR_CYAN"
export MAGENTA="$COLOR_MAGENTA"
export NC="$COLOR_NC"

# =============================================================================
# 颜色检测
# =============================================================================

# 检测是否支持颜色输出
supports_color() {
    # 如果不是终端，不支持颜色
    [[ ! -t 1 ]] && return 1
    
    # 如果设置了 NO_COLOR 环境变量，不使用颜色
    [[ -n "${NO_COLOR:-}" ]] && return 1
    
    # 检查 TERM
    case "${TERM:-}" in
        xterm*|rxvt*|vt100*|screen*|tmux*|linux*|cygwin*|ansi*)
            return 0
            ;;
        *)
            # 检查是否有 tput
            if command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
                return 0
            fi
            return 1
            ;;
    esac
}

# 禁用颜色
disable_colors() {
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_CYAN=''
    COLOR_MAGENTA=''
    COLOR_WHITE=''
    COLOR_GRAY=''
    COLOR_NC=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    NC=''
}

# 如果不支持颜色，禁用所有颜色
if ! supports_color; then
    disable_colors
fi
