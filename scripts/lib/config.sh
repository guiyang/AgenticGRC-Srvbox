#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 共享库 - 配置管理
# =============================================================================
# 文件: scripts/lib/config.sh
# 用途: 配置文件管理和环境变量处理
# =============================================================================

# 防止重复加载
[[ -n "${_AGENTICGRC_CONFIG_LOADED:-}" ]] && return 0
_AGENTICGRC_CONFIG_LOADED=1

# =============================================================================
# 版本信息
# =============================================================================

readonly AGENTICGRC_VERSION="1.0.0"
readonly AGENTICGRC_NAME="AgenticGRC-Srvbox"

# =============================================================================
# 默认配置
# =============================================================================

# 证书配置
: "${CERT_VALIDITY_DAYS:=3650}"      # 10年
: "${DEFAULT_DOMAIN:=authentik.local}"
: "${CERT_COUNTRY:=CN}"
: "${CERT_STATE:=Beijing}"
: "${CERT_CITY:=Beijing}"
: "${CERT_ORG:=AgenticGRC}"
: "${CERT_ORG_UNIT:=IT}"

# 端口配置
: "${COMPOSE_PORT_HTTP:=9000}"
: "${COMPOSE_PORT_HTTPS:=9443}"

# =============================================================================
# 路径管理
# =============================================================================

# 初始化项目路径
init_paths() {
    # 如果 PROJECT_ROOT 已设置，使用它
    if [[ -n "${PROJECT_ROOT:-}" ]]; then
        return 0
    fi
    
    # 尝试从调用脚本推断
    local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    local script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    
    # 如果在 scripts/lib 目录中
    if [[ "$script_dir" == */scripts/lib ]]; then
        PROJECT_ROOT="$(dirname "$(dirname "$script_dir")")"
    # 如果在 scripts 目录中
    elif [[ "$script_dir" == */scripts ]]; then
        PROJECT_ROOT="$(dirname "$script_dir")"
    # 否则假设在项目根目录
    else
        PROJECT_ROOT="$script_dir"
    fi
    
    export PROJECT_ROOT
}

# 获取项目路径
get_project_root() {
    init_paths
    echo "$PROJECT_ROOT"
}

# 获取脚本目录路径
get_scripts_dir() {
    echo "$(get_project_root)/scripts"
}

# 获取库目录路径
get_lib_dir() {
    echo "$(get_scripts_dir)/lib"
}

# 获取证书目录路径
get_cert_dir() {
    echo "$(get_project_root)/certs"
}

# 获取证书安装包目录路径
get_cert_dist_dir() {
    echo "$(get_project_root)/cert-installers"
}

# 获取环境文件路径
get_env_file() {
    echo "$(get_project_root)/.env"
}

# 获取示例环境文件路径
get_env_example() {
    echo "$(get_project_root)/.env.example"
}

# 获取密钥备份文件路径
get_secrets_file() {
    echo "$(get_project_root)/.secrets"
}

# =============================================================================
# 环境变量管理
# =============================================================================

# 从 .env 文件加载环境变量
load_env() {
    local env_file="${1:-$(get_env_file)}"
    
    if [[ ! -f "$env_file" ]]; then
        print_debug ".env 文件不存在: $env_file"
        return 1
    fi
    
    # 逐行读取，忽略注释和空行
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过空行和注释
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # 提取变量名和值
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # 去除值两端的引号
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            
            # 只设置未定义的变量
            if [[ -z "${!name:-}" ]]; then
                export "$name=$value"
            fi
        fi
    done < "$env_file"
    
    return 0
}

# 读取单个环境变量
get_env_var() {
    local name="$1"
    local default="${2:-}"
    local env_file="${3:-$(get_env_file)}"
    
    # 首先检查环境变量
    if [[ -n "${!name:-}" ]]; then
        echo "${!name}"
        return 0
    fi
    
    # 然后从文件读取
    if [[ -f "$env_file" ]]; then
        local value=$(grep "^${name}=" "$env_file" 2>/dev/null | head -1 | cut -d= -f2-)
        if [[ -n "$value" ]]; then
            # 去除引号
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            echo "$value"
            return 0
        fi
    fi
    
    # 返回默认值
    echo "$default"
}

# 设置环境变量到文件
set_env_var() {
    local name="$1"
    local value="$2"
    local env_file="${3:-$(get_env_file)}"
    
    if [[ ! -f "$env_file" ]]; then
        print_error "环境文件不存在: $env_file"
        return 1
    fi
    
    # 使用 | 作为 sed 分隔符以避免值中的 / 冲突
    if grep -q "^${name}=" "$env_file"; then
        # 更新现有变量
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${name}=.*|${name}=${value}|" "$env_file"
        else
            sed -i "s|^${name}=.*|${name}=${value}|" "$env_file"
        fi
    else
        # 添加新变量
        echo "${name}=${value}" >> "$env_file"
    fi
}

# =============================================================================
# 配置验证
# =============================================================================

# 验证必需的环境变量
validate_required_vars() {
    local vars=("$@")
    local missing=()
    
    for var in "${vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "缺少必需的环境变量: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# 验证端口号
validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        return 1
    fi
    
    return 0
}

# 验证域名格式
validate_domain() {
    local domain="$1"
    
    # 简单的域名验证
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    
    # IP 地址
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    
    return 1
}

# =============================================================================
# 配置摘要
# =============================================================================

# 显示当前配置
show_config() {
    print_header "当前配置"
    
    echo "项目路径:     $(get_project_root)"
    echo "版本:         $AGENTICGRC_VERSION"
    echo ""
    echo "证书配置:"
    echo "  域名:       ${AUTHENTIK_DOMAIN:-$DEFAULT_DOMAIN}"
    echo "  有效期:     $CERT_VALIDITY_DAYS 天"
    echo "  组织:       $CERT_ORG"
    echo ""
    echo "端口配置:"
    echo "  HTTP:       $COMPOSE_PORT_HTTP"
    echo "  HTTPS:      $COMPOSE_PORT_HTTPS"
    echo ""
}
