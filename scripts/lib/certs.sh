#!/bin/bash
# =============================================================================
# AgenticGRC-Srvbox 共享库 - 证书管理
# =============================================================================
# 文件: scripts/lib/certs.sh
# 用途: SSL 证书生成、管理和安装
# =============================================================================

# 防止重复加载
[[ -n "${_AGENTICGRC_CERTS_LOADED:-}" ]] && return 0
_AGENTICGRC_CERTS_LOADED=1

# 确保依赖库已加载
if [[ -z "${_AGENTICGRC_UTILS_LOADED:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
fi

# =============================================================================
# 证书配置
# =============================================================================

# 默认证书配置
: "${CERT_KEY_SIZE:=4096}"
: "${CERT_VALIDITY_DAYS:=3650}"
: "${DEFAULT_DOMAIN:=authentik.local}"
: "${CERT_COUNTRY:=CN}"
: "${CERT_STATE:=Beijing}"
: "${CERT_CITY:=Beijing}"
: "${CERT_ORG:=AgenticGRC}"
: "${CERT_ORG_UNIT:=IT}"

# =============================================================================
# 证书检查
# =============================================================================

# 检查 openssl 是否可用
check_openssl() {
    if ! command_exists openssl; then
        print_error "openssl 未安装"
        print_info "安装说明:"
        case "$(detect_os)" in
            macos)  echo "  brew install openssl" ;;
            debian) echo "  sudo apt-get install openssl" ;;
            redhat) echo "  sudo yum install openssl" ;;
        esac
        return $E_MISSING_DEP
    fi
    return 0
}

# 检查证书是否存在
cert_exists() {
    local cert_dir="${1:-$(get_cert_dir)}"
    [[ -f "$cert_dir/privkey.pem" && -f "$cert_dir/fullchain.pem" ]]
}

# 检查证书是否即将过期（默认30天内）
cert_expiring_soon() {
    local cert_file="${1:-$(get_cert_dir)/fullchain.pem}"
    local days="${2:-30}"
    
    if [[ ! -f "$cert_file" ]]; then
        return 0  # 不存在视为需要更新
    fi
    
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    [[ $days_until_expiry -le $days ]]
}

# =============================================================================
# 证书生成 - Root CA 模式
# =============================================================================

# 检测是否为 IP 地址
is_ip_address() {
    local input="$1"
    # IPv4 正则匹配
    if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    # IPv6 简单检测
    if [[ "$input" =~ ^[0-9a-fA-F:]+$ && "$input" == *:* ]]; then
        return 0
    fi
    return 1
}

# 生成 Root CA 和服务器证书（推荐方式）
generate_root_ca_certs() {
    local domain="${1:-$DEFAULT_DOMAIN}"
    local cert_dir="${2:-$(get_cert_dir)}"
    local validity_days="${3:-$CERT_VALIDITY_DAYS}"
    
    check_openssl || return $?
    
    # 检测是否为 IP 地址
    local is_ip=false
    if is_ip_address "$domain"; then
        is_ip=true
        print_info "检测到 IP 地址: $domain"
    else
        print_info "检测到域名: $domain"
    fi
    
    print_info "使用 Root CA 模式生成证书..."
    print_info "  目标: $domain"
    print_info "  目录: $cert_dir"
    print_info "  有效期: $validity_days 天"
    
    # 创建证书目录
    ensure_dir "$cert_dir"
    
    # 1. 生成私钥
    print_info "[1/6] 生成 ${CERT_KEY_SIZE} 位 RSA 私钥..."
    openssl genrsa -out "$cert_dir/privkey.pem" "$CERT_KEY_SIZE" 2>/dev/null || {
        print_error "私钥生成失败"
        return $E_CERT_ERROR
    }
    
    # 2. 生成 Root CA 证书
    print_info "[2/6] 生成根证书颁发机构 (Root CA)..."
    openssl req -new -x509 -key "$cert_dir/privkey.pem" \
        -out "$cert_dir/ca.pem" \
        -days "$validity_days" \
        -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_ORG_UNIT/CN=$CERT_ORG Root CA" \
        2>/dev/null || {
        print_error "Root CA 证书生成失败"
        return $E_CERT_ERROR
    }
    
    # 3. 生成服务器证书签名请求 (CSR)
    print_info "[3/6] 生成证书签名请求 (CSR)..."
    openssl req -new -key "$cert_dir/privkey.pem" \
        -out "$cert_dir/server.csr" \
        -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_ORG_UNIT/CN=$domain" \
        2>/dev/null || {
        print_error "CSR 生成失败"
        return $E_CERT_ERROR
    }
    
    # 4. 创建扩展配置文件
    print_info "[4/6] 配置证书扩展..."
    
    if [[ "$is_ip" == "true" ]]; then
        # IP 地址模式：主要使用 IP SAN
        cat > "$cert_dir/v3.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = $domain
IP.2 = 127.0.0.1
EOF
    else
        # 域名模式：主要使用 DNS SAN
        cat > "$cert_dir/v3.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = localhost
DNS.3 = *.$domain
IP.1 = 127.0.0.1
EOF
    fi
    
    # 5. 使用 Root CA 签名服务器证书
    print_info "[5/6] 使用 Root CA 签名服务器证书..."
    openssl x509 -req -in "$cert_dir/server.csr" \
        -CA "$cert_dir/ca.pem" \
        -CAkey "$cert_dir/privkey.pem" \
        -CAcreateserial \
        -out "$cert_dir/cert.pem" \
        -days "$validity_days" \
        -extfile "$cert_dir/v3.ext" \
        2>/dev/null || {
        print_error "证书签名失败"
        return $E_CERT_ERROR
    }
    
    # 6. 创建证书链
    print_info "[6/6] 创建证书链文件..."
    cat "$cert_dir/cert.pem" "$cert_dir/ca.pem" > "$cert_dir/fullchain.pem"
    cp "$cert_dir/ca.pem" "$cert_dir/chain.pem"
    
    # 设置权限
    chmod 600 "$cert_dir/privkey.pem"
    chmod 644 "$cert_dir/ca.pem" "$cert_dir/cert.pem" "$cert_dir/fullchain.pem" "$cert_dir/chain.pem"
    
    # 清理临时文件
    rm -f "$cert_dir/server.csr" "$cert_dir/v3.ext" "$cert_dir/ca.srl"
    
    print_success "SSL 证书生成完成"
    return 0
}

# =============================================================================
# 证书生成 - 简单自签名模式
# =============================================================================

# 生成简单的自签名证书
generate_simple_certs() {
    local domain="${1:-$DEFAULT_DOMAIN}"
    local cert_dir="${2:-$(get_cert_dir)}"
    local validity_days="${3:-$CERT_VALIDITY_DAYS}"
    
    check_openssl || return $?
    
    # 检测是否为 IP 地址
    local san_ext
    if is_ip_address "$domain"; then
        print_info "检测到 IP 地址: $domain"
        san_ext="subjectAltName=DNS:localhost,IP:$domain,IP:127.0.0.1"
    else
        print_info "检测到域名: $domain"
        san_ext="subjectAltName=DNS:$domain,DNS:localhost,DNS:*.$domain,IP:127.0.0.1"
    fi
    
    print_info "使用简单自签名模式生成证书..."
    
    ensure_dir "$cert_dir"
    
    # 生成私钥
    print_info "[1/2] 生成私钥..."
    openssl genrsa -out "$cert_dir/privkey.pem" "$CERT_KEY_SIZE" 2>/dev/null || {
        print_error "私钥生成失败"
        return $E_CERT_ERROR
    }
    
    # 生成自签名证书
    print_info "[2/2] 生成自签名证书..."
    openssl req -new -x509 -key "$cert_dir/privkey.pem" \
        -out "$cert_dir/fullchain.pem" \
        -days "$validity_days" \
        -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_ORG_UNIT/CN=$domain" \
        -addext "$san_ext" \
        2>/dev/null || {
        print_error "证书生成失败"
        return $E_CERT_ERROR
    }
    
    # 复制为 chain.pem
    cp "$cert_dir/fullchain.pem" "$cert_dir/chain.pem"
    
    # 设置权限
    chmod 600 "$cert_dir/privkey.pem"
    chmod 644 "$cert_dir/fullchain.pem" "$cert_dir/chain.pem"
    
    print_success "自签名证书生成完成"
    return 0
}

# =============================================================================
# DH 参数
# =============================================================================

# 生成 DH 参数
generate_dhparam() {
    local cert_dir="${1:-$(get_cert_dir)}"
    local bits="${2:-2048}"
    
    print_info "生成 DH 参数 (${bits} 位)，这可能需要一分钟..."
    
    if openssl dhparam -out "$cert_dir/dhparam.pem" "$bits" 2>/dev/null; then
        chmod 644 "$cert_dir/dhparam.pem"
        print_success "DH 参数生成完成"
        return 0
    else
        print_warning "DH 参数生成失败，继续..."
        return 1
    fi
}

# =============================================================================
# 证书安装包
# =============================================================================

# 创建证书安装包
create_cert_installers() {
    local cert_dir="${1:-$(get_cert_dir)}"
    local dist_dir="${2:-$(get_cert_dist_dir)}"
    local domain="${3:-$DEFAULT_DOMAIN}"
    
    if [[ ! -f "$cert_dir/ca.pem" ]]; then
        print_error "Root CA 证书不存在: $cert_dir/ca.pem"
        return $E_FILE_ERROR
    fi
    
    print_info "创建证书安装包..."
    
    # 清理旧的安装包
    rm -rf "$dist_dir/linux-debian" "$dist_dir/linux-redhat" "$dist_dir/macos" "$dist_dir/windows"
    
    # 1. Linux (Debian/Ubuntu)
    print_info "  创建 Linux (Debian/Ubuntu) 安装包..."
    ensure_dir "$dist_dir/linux-debian"
    cp "$cert_dir/ca.pem" "$dist_dir/linux-debian/${CERT_ORG}-root-ca.crt"
    _create_debian_installer "$dist_dir/linux-debian"
    
    # 2. Linux (RedHat/CentOS)
    print_info "  创建 Linux (RedHat/CentOS) 安装包..."
    ensure_dir "$dist_dir/linux-redhat"
    cp "$cert_dir/ca.pem" "$dist_dir/linux-redhat/${CERT_ORG}-root-ca.crt"
    _create_redhat_installer "$dist_dir/linux-redhat"
    
    # 3. macOS
    print_info "  创建 macOS 安装包..."
    ensure_dir "$dist_dir/macos"
    cp "$cert_dir/ca.pem" "$dist_dir/macos/${CERT_ORG}-root-ca.crt"
    _create_macos_installer "$dist_dir/macos"
    
    # 4. Windows
    print_info "  创建 Windows 安装包..."
    ensure_dir "$dist_dir/windows"
    cp "$cert_dir/ca.pem" "$dist_dir/windows/${CERT_ORG}-root-ca.crt"
    _create_windows_installer "$dist_dir/windows"
    
    # 5. 创建 README
    _create_cert_readme "$dist_dir" "$domain"
    
    # 6. 创建打包脚本
    _create_archive_script "$dist_dir"
    
    print_success "证书安装包创建完成"
    print_info "位置: $dist_dir"
    return 0
}

# 创建 Debian 安装脚本
_create_debian_installer() {
    local dir="$1"
    cat > "$dir/install.sh" << 'EOF'
#!/bin/bash
# AgenticGRC Root CA 证书安装脚本 - Debian/Ubuntu
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "正在安装 AgenticGRC Root CA 证书到系统信任存储..."

# 复制证书
sudo cp *.crt /usr/local/share/ca-certificates/

# 更新证书存储
sudo update-ca-certificates

echo "✓ 证书安装完成"
echo ""
echo "验证: curl https://authentik.local:9443 应该不再显示证书错误"
EOF
    chmod +x "$dir/install.sh"
}

# 创建 RedHat 安装脚本
_create_redhat_installer() {
    local dir="$1"
    cat > "$dir/install.sh" << 'EOF'
#!/bin/bash
# AgenticGRC Root CA 证书安装脚本 - RedHat/CentOS
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "正在安装 AgenticGRC Root CA 证书到系统信任存储..."

# 复制证书
sudo cp *.crt /etc/pki/ca-trust/source/anchors/

# 更新证书存储
sudo update-ca-trust

echo "✓ 证书安装完成"
echo ""
echo "验证: curl https://authentik.local:9443 应该不再显示证书错误"
EOF
    chmod +x "$dir/install.sh"
}

# 创建 macOS 安装脚本
_create_macos_installer() {
    local dir="$1"
    cat > "$dir/install.sh" << 'EOF'
#!/bin/bash
# AgenticGRC Root CA 证书安装脚本 - macOS
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CERT_FILE="$(ls *.crt 2>/dev/null | head -n 1)"

if [[ -z "$CERT_FILE" ]]; then
    echo "错误: 未找到证书文件"
    exit 1
fi

echo "正在安装 AgenticGRC Root CA 证书到系统钥匙串..."

# 添加到系统钥匙串并设置为信任
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_FILE"

echo "✓ 证书安装完成"
echo ""
echo "验证: curl https://authentik.local:9443 应该不再显示证书错误"
echo ""
echo "如需卸载:"
echo "  sudo security delete-certificate -c 'AgenticGRC Root CA' /Library/Keychains/System.keychain"
EOF
    chmod +x "$dir/install.sh"
}

# 创建 Windows 安装脚本
_create_windows_installer() {
    local dir="$1"
    
    # PowerShell 脚本
    cat > "$dir/install.ps1" << 'EOF'
# AgenticGRC Root CA 证书安装脚本 - Windows
# 需要管理员权限运行

$ErrorActionPreference = "Stop"

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "此脚本需要管理员权限运行"
    Write-Host "请右键点击此脚本,选择 '以管理员身份运行'" -ForegroundColor Yellow
    Read-Host "按任意键退出"
    exit 1
}

Write-Host "正在安装 AgenticGRC Root CA 证书到受信任的根证书颁发机构..." -ForegroundColor Cyan

# 获取证书文件
$certFile = Get-ChildItem -Filter "*.crt" | Select-Object -First 1

if (-not $certFile) {
    Write-Error "未找到证书文件 (.crt)"
    exit 1
}

# 导入证书
Import-Certificate -FilePath $certFile.FullName -CertStoreLocation Cert:\LocalMachine\Root

Write-Host "✓ 证书安装完成" -ForegroundColor Green
Write-Host ""
Write-Host "验证: 在浏览器中访问 https://authentik.local:9443 应该不再显示证书错误"

Read-Host "按任意键退出"
EOF
    
    # 批处理脚本
    cat > "$dir/install.bat" << 'EOF'
@echo off
REM AgenticGRC Root CA 证书安装脚本 - Windows
REM 需要管理员权限运行

echo 正在安装 AgenticGRC Root CA 证书...
echo.

for %%f in (*.crt) do (
    certutil -addstore -f "ROOT" "%%f"
    if errorlevel 1 (
        echo 错误: 证书安装失败
        echo 请确保以管理员身份运行此脚本
        pause
        exit /b 1
    )
)

echo.
echo 证书安装完成
echo.
pause
EOF
}

# 创建 README
_create_cert_readme() {
    local dir="$1"
    local domain="$2"
    
    cat > "$dir/README.md" << EOF
# AgenticGRC SSL 证书安装包

此目录包含用于在不同操作系统上安装 AgenticGRC Root CA 证书的安装包。

## 为什么需要安装证书?

- Electron 桌面应用需要 HTTPS 连接
- 开发环境中使用自签名证书
- 避免浏览器安全警告

## 安装说明

### macOS

\`\`\`bash
cd macos && ./install.sh
\`\`\`

### Linux (Debian/Ubuntu)

\`\`\`bash
cd linux-debian && ./install.sh
\`\`\`

### Linux (RedHat/CentOS)

\`\`\`bash
cd linux-redhat && ./install.sh
\`\`\`

### Windows

以管理员身份运行 \`windows/install.ps1\` 或 \`windows/install.bat\`

## 验证安装

\`\`\`bash
curl https://${domain}:9443
\`\`\`

## 证书信息

- **组织**: ${CERT_ORG}
- **域名**: ${domain}
- **有效期**: ${CERT_VALIDITY_DAYS} 天
- **生成时间**: $(date)

## 安全说明

⚠️ 这是自签名的根证书，仅用于开发/测试环境。
生产环境请使用 Let's Encrypt 或商业 CA 颁发的证书。
EOF
}

# 创建打包脚本
_create_archive_script() {
    local dir="$1"
    cat > "$dir/create-archives.sh" << 'EOF'
#!/bin/bash
# 创建各平台的压缩包

cd "$(dirname "$0")"

echo "创建压缩包..."

[[ -d linux-debian ]] && tar -czf agenticgrc-ca-linux-debian.tar.gz linux-debian/ README.md && echo "✓ linux-debian"
[[ -d linux-redhat ]] && tar -czf agenticgrc-ca-linux-redhat.tar.gz linux-redhat/ README.md && echo "✓ linux-redhat"
[[ -d macos ]] && tar -czf agenticgrc-ca-macos.tar.gz macos/ README.md && echo "✓ macos"

if command -v zip &>/dev/null && [[ -d windows ]]; then
    zip -rq agenticgrc-ca-windows.zip windows/ README.md && echo "✓ windows"
fi

echo "完成"
EOF
    chmod +x "$dir/create-archives.sh"
}

# =============================================================================
# 证书信息
# =============================================================================

# 显示证书信息
show_cert_info() {
    local cert_file="${1:-$(get_cert_dir)/fullchain.pem}"
    
    if [[ ! -f "$cert_file" ]]; then
        print_error "证书文件不存在: $cert_file"
        return $E_FILE_ERROR
    fi
    
    print_header "证书信息"
    
    echo "文件: $cert_file"
    echo ""
    
    openssl x509 -in "$cert_file" -noout -text 2>/dev/null | \
        grep -E "(Subject:|Issuer:|DNS:|Not Before|Not After)" || true
    
    echo ""
    return 0
}

# =============================================================================
# 证书清理
# =============================================================================

# 清理所有证书文件
clean_certs() {
    local cert_dir="${1:-$(get_cert_dir)}"
    
    print_warning "将删除 $cert_dir 中的所有证书文件"
    
    rm -f "$cert_dir"/*.pem "$cert_dir"/*.crt "$cert_dir"/*.csr "$cert_dir"/*.srl "$cert_dir"/*.ext 2>/dev/null || true
    
    print_success "证书文件已清理"
    return 0
}

# 备份证书
backup_certs() {
    local cert_dir="${1:-$(get_cert_dir)}"
    local backup_dir="${cert_dir}/backup_$(timestamp)"
    
    if ! cert_exists "$cert_dir"; then
        print_warning "没有证书需要备份"
        return 0
    fi
    
    ensure_dir "$backup_dir"
    
    cp "$cert_dir"/*.pem "$backup_dir/" 2>/dev/null || true
    cp "$cert_dir"/*.crt "$backup_dir/" 2>/dev/null || true
    
    print_success "证书已备份到: $backup_dir"
    return 0
}
