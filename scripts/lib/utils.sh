#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 共享库 - 工具函数
# =============================================================================
# 文件: scripts/lib/utils.sh
# 用途: 通用工具函数
# =============================================================================

# 防止重复加载
[[ -n "${_AGENTICGRC_UTILS_LOADED:-}" ]] && return 0
_AGENTICGRC_UTILS_LOADED=1

# =============================================================================
# 错误码定义
# =============================================================================

readonly E_SUCCESS=0
readonly E_GENERAL=1
readonly E_MISSING_DEP=2
readonly E_CONFIG_ERROR=3
readonly E_CERT_ERROR=4
readonly E_DOCKER_ERROR=5
readonly E_FILE_ERROR=6
readonly E_PERMISSION_ERROR=7
readonly E_USER_CANCEL=130

# =============================================================================
# 系统检测
# =============================================================================

# 检测操作系统
detect_os() {
    case "$OSTYPE" in
        darwin*)
            echo "macos"
            ;;
        linux*)
            if [[ -f /etc/debian_version ]]; then
                echo "debian"
            elif [[ -f /etc/redhat-release ]]; then
                echo "redhat"
            elif [[ -f /etc/arch-release ]]; then
                echo "arch"
            else
                echo "linux"
            fi
            ;;
        msys*|cygwin*|win*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 检测是否为 root 用户
is_root() {
    [[ $EUID -eq 0 ]]
}

# 检测命令是否存在
command_exists() {
    command -v "$1" &>/dev/null
}

# =============================================================================
# 依赖检查
# =============================================================================

# 检查必需的依赖
check_dependencies() {
    local missing=0
    local deps=("$@")
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            print_check "fail" "$dep 未安装"
            missing=$((missing + 1))
        else
            print_check "ok" "$dep 已安装"
        fi
    done
    
    return $missing
}

# 检查必需依赖（带错误退出）
require_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "缺少必需的依赖: ${missing[*]}"
        echo ""
        print_info "安装说明:"
        
        local os=$(detect_os)
        for dep in "${missing[@]}"; do
            case "$os" in
                macos)
                    echo "  brew install $dep"
                    ;;
                debian)
                    echo "  sudo apt-get install $dep"
                    ;;
                redhat)
                    echo "  sudo yum install $dep"
                    ;;
                *)
                    echo "  请安装 $dep"
                    ;;
            esac
        done
        
        return $E_MISSING_DEP
    fi
    
    return 0
}

# =============================================================================
# 文件操作
# =============================================================================

# 安全创建目录
ensure_dir() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" && chmod "$mode" "$dir"
    fi
}

# 安全备份文件
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.backup.$(date +%Y%m%d_%H%M%S)}"
    
    if [[ -f "$file" ]]; then
        cp "$file" "${file}${backup_suffix}"
        print_info "已备份: ${file}${backup_suffix}"
        return 0
    fi
    return 1
}

# 检查文件是否存在且可读
file_readable() {
    [[ -f "$1" && -r "$1" ]]
}

# 检查文件是否存在且可写
file_writable() {
    if [[ -f "$1" ]]; then
        [[ -w "$1" ]]
    else
        # 文件不存在，检查父目录是否可写
        local dir=$(dirname "$1")
        [[ -d "$dir" && -w "$dir" ]]
    fi
}

# 检查目录是否存在且可写
dir_writable() {
    [[ -d "$1" && -w "$1" ]]
}

# =============================================================================
# 字符串处理
# =============================================================================

# 去除字符串首尾空白
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# 字符串是否为空
is_empty() {
    [[ -z "${1:-}" ]]
}

# 字符串是否非空
is_not_empty() {
    [[ -n "${1:-}" ]]
}

# =============================================================================
# 随机生成
# =============================================================================

# 生成随机密钥
generate_secret() {
    local length=${1:-60}
    openssl rand -base64 "$length" | tr -d '\n'
}

# 生成随机密码（更易读的格式）
generate_password() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# 生成 UUID
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        openssl rand -hex 16 | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-/'
    fi
}

# =============================================================================
# 执行命令
# =============================================================================

# 运行命令并捕获输出
run_cmd() {
    local description="$1"
    shift
    
    print_debug "执行: $*"
    
    if "$@" 2>&1; then
        print_debug "$description 成功"
        return 0
    else
        local exit_code=$?
        print_debug "$description 失败 (退出码: $exit_code)"
        return $exit_code
    fi
}

# 运行命令（带进度显示）
run_with_status() {
    local description="$1"
    shift
    
    print_info "$description..."
    
    if "$@" 2>&1; then
        print_success "$description 完成"
        return 0
    else
        local exit_code=$?
        print_error "$description 失败"
        return $exit_code
    fi
}

# 静默运行命令
run_silent() {
    "$@" >/dev/null 2>&1
}

# =============================================================================
# 版本比较
# =============================================================================

# 比较版本号 (返回: 0=相等, 1=v1>v2, 2=v1<v2)
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    if [[ "$v1" == "$v2" ]]; then
        return 0
    fi
    
    local IFS=.
    local i ver1=($v1) ver2=($v2)
    
    # 补齐版本号长度
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    
    return 0
}

# =============================================================================
# 网络工具
# =============================================================================

# 检查端口是否被占用
port_in_use() {
    local port="$1"
    
    if command_exists lsof; then
        lsof -i ":$port" >/dev/null 2>&1
    elif command_exists netstat; then
        netstat -tuln | grep -q ":$port "
    elif command_exists ss; then
        ss -tuln | grep -q ":$port "
    else
        return 1
    fi
}

# 等待端口可用
wait_for_port() {
    local port="$1"
    local timeout="${2:-30}"
    local elapsed=0
    
    while port_in_use "$port"; do
        if [[ $elapsed -ge $timeout ]]; then
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    return 0
}

# =============================================================================
# 日期时间
# =============================================================================

# 获取时间戳
timestamp() {
    date +%Y%m%d_%H%M%S
}

# 获取 ISO 格式时间
iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}
