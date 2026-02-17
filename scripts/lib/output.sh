#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 共享库 - 输出函数
# =============================================================================
# 文件: scripts/lib/output.sh
# 用途: 统一管理所有脚本的输出格式
# =============================================================================

# 防止重复加载
[[ -n "${_AGENTICGRC_OUTPUT_LOADED:-}" ]] && return 0
_AGENTICGRC_OUTPUT_LOADED=1

# 确保颜色已加载
if [[ -z "${_AGENTICGRC_COLORS_LOADED:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# =============================================================================
# 横幅和标题
# =============================================================================

# 打印主横幅
print_banner() {
    local title="${1:-AgenticGRC-Srvbox}"
    echo ""
    echo -e "${COLOR_CYAN}╔════════════════════════════════════════════════════════════════════════╗${COLOR_NC}"
    echo -e "${COLOR_CYAN}║                                                                        ║${COLOR_NC}"
    printf "${COLOR_CYAN}║%*s%s%*s║${COLOR_NC}\n" $(( (72 - ${#title}) / 2 )) "" "$title" $(( (73 - ${#title}) / 2 )) ""
    echo -e "${COLOR_CYAN}║                                                                        ║${COLOR_NC}"
    echo -e "${COLOR_CYAN}╚════════════════════════════════════════════════════════════════════════╝${COLOR_NC}"
    echo ""
}

# 打印节标题
print_header() {
    echo ""
    echo -e "${COLOR_CYAN}============================================================================${COLOR_NC}"
    echo -e "${COLOR_CYAN} $1${COLOR_NC}"
    echo -e "${COLOR_CYAN}============================================================================${COLOR_NC}"
    echo ""
}

# 打印子标题
print_subheader() {
    echo ""
    echo -e "${COLOR_BLUE}--- $1 ---${COLOR_NC}"
    echo ""
}

# =============================================================================
# 状态消息
# =============================================================================

# 打印步骤信息
print_step() {
    local step="$1"
    local message="$2"
    echo -e "${COLOR_GREEN}[步骤 $step]${COLOR_NC} $message"
}

# 打印信息
print_info() {
    echo -e "${COLOR_BLUE}[信息]${COLOR_NC} $1"
}

# 打印成功消息
print_success() {
    echo -e "${COLOR_GREEN}[成功]${COLOR_NC} $1"
}

# 打印警告消息
print_warning() {
    echo -e "${COLOR_YELLOW}[警告]${COLOR_NC} $1"
}

# 打印错误消息
print_error() {
    echo -e "${COLOR_RED}[错误]${COLOR_NC} $1" >&2
}

# 打印调试信息（仅在 DEBUG 模式下）
print_debug() {
    if [[ "${DEBUG:-}" == "1" || "${DEBUG:-}" == "true" ]]; then
        echo -e "${COLOR_GRAY}[调试]${COLOR_NC} $1" >&2
    fi
}

# =============================================================================
# 状态指示器
# =============================================================================

# 打印带状态的检查项
print_check() {
    local status="$1"  # ok, warn, fail, skip
    local message="$2"
    
    case "$status" in
        ok|pass|success)
            echo -e "${COLOR_GREEN}✓${COLOR_NC} $message"
            ;;
        warn|warning)
            echo -e "${COLOR_YELLOW}⚠${COLOR_NC} $message"
            ;;
        fail|error)
            echo -e "${COLOR_RED}✗${COLOR_NC} $message"
            ;;
        skip|skipped)
            echo -e "${COLOR_GRAY}○${COLOR_NC} $message ${COLOR_GRAY}(跳过)${COLOR_NC}"
            ;;
        *)
            echo -e "  $message"
            ;;
    esac
}

# =============================================================================
# 进度显示
# =============================================================================

# 开始一个操作（显示进行中）
print_action_start() {
    local message="$1"
    echo -ne "${COLOR_BLUE}[...]${COLOR_NC} $message..."
}

# 完成一个操作
print_action_done() {
    local status="${1:-ok}"  # ok, warn, fail
    
    # 回到行首
    echo -ne "\r"
    
    case "$status" in
        ok|success)
            echo -e "${COLOR_GREEN}[成功]${COLOR_NC}"
            ;;
        warn|warning)
            echo -e "${COLOR_YELLOW}[警告]${COLOR_NC}"
            ;;
        fail|error)
            echo -e "${COLOR_RED}[失败]${COLOR_NC}"
            ;;
    esac
}

# =============================================================================
# 列表和缩进
# =============================================================================

# 打印列表项
print_list_item() {
    local indent="${2:-2}"
    printf "%${indent}s• %s\n" "" "$1"
}

# 打印编号列表项
print_numbered_item() {
    local number="$1"
    local message="$2"
    local indent="${3:-2}"
    printf "%${indent}s%d) %s\n" "" "$number" "$message"
}

# =============================================================================
# 用户交互
# =============================================================================

# 确认提示
confirm() {
    local prompt="${1:-确认继续?}"
    local default="${2:-n}"  # y 或 n
    
    local yn_prompt
    if [[ "$default" == "y" ]]; then
        yn_prompt="[Y/n]"
    else
        yn_prompt="[y/N]"
    fi
    
    read -p "$prompt $yn_prompt " response
    response=${response:-$default}
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 强确认（需要输入特定文字）
confirm_destructive() {
    local prompt="${1:-此操作不可撤销}"
    local confirm_text="${2:-DELETE}"
    
    print_warning "$prompt"
    echo ""
    read -p "请输入 '$confirm_text' 确认: " response
    
    if [[ "$response" == "$confirm_text" ]]; then
        return 0
    else
        print_info "已取消"
        return 1
    fi
}

# 暂停等待用户按键
pause() {
    local message="${1:-按 Enter 继续...}"
    read -p "$message"
}

# =============================================================================
# 分隔线
# =============================================================================

# 打印分隔线
print_separator() {
    local char="${1:--}"
    local width="${2:-76}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# 打印空行
print_newline() {
    local count="${1:-1}"
    for ((i=0; i<count; i++)); do
        echo ""
    done
}
