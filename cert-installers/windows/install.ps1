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
