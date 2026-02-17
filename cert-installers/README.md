# AgenticGRC SSL 证书安装包

此目录包含用于在不同操作系统上安装 AgenticGRC Root CA 证书的安装包。

## 为什么需要安装证书?

- Electron 桌面应用需要 HTTPS 连接
- 开发环境中使用自签名证书
- 避免浏览器安全警告

## 安装说明

### macOS

```bash
cd macos && ./install.sh
```

### Linux (Debian/Ubuntu)

```bash
cd linux-debian && ./install.sh
```

### Linux (RedHat/CentOS)

```bash
cd linux-redhat && ./install.sh
```

### Windows

以管理员身份运行 `windows/install.ps1` 或 `windows/install.bat`

## 验证安装

```bash
curl https://192.169.31.62:9443
```

## 证书信息

- **组织**: AgenticGRC
- **域名**: 192.169.31.62
- **有效期**: 3650 天
- **生成时间**: Mon Feb 16 07:42:51 CST 2026

## 安全说明

⚠️ 这是自签名的根证书，仅用于开发/测试环境。
生产环境请使用 Let's Encrypt 或商业 CA 颁发的证书。
