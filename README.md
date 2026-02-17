# Authentik Docker Compose Deployment

Production-ready Docker Compose configuration for [Authentik](https://goauthentik.io/), an open-source Identity Provider focused on flexibility and versatility.

## About Authentik

Authentik is a modern authentication and authorization solution that provides:
- **Single Sign-On (SSO)** across multiple applications
- **Multi-Factor Authentication (MFA)** with TOTP, WebAuthn, and more
- **Protocol Support**: OAuth2, OpenID Connect (OIDC), SAML, LDAP
- **User Federation** with external identity providers
- **Access Control** with fine-grained policies
- **Web-based Administration** interface

## Architecture

This deployment consists of four services:

| Service | Description |
|---------|-------------|
| **PostgreSQL** | Primary database for all configuration and user data |
| **Redis** | Cache layer for improved performance |
| **Server** | Main Authentik server handling HTTP(S), API, SSO requests |
| **Worker** | Background task processor (emails, notifications, etc.) |

## Requirements

- **Docker** Engine 20.10 or later
- **Docker Compose** v2 (see [upgrade instructions](https://docs.docker.com/compose/install/))
- **Hardware**: Minimum 2 CPU cores, 2GB RAM (4GB+ recommended for production)
- **Disk**: 10GB+ free space for database and media files

## Quick Start

### 🚀 一键初始化（推荐）

使用自动化脚本快速完成所有配置：

```bash
# 运行快速初始化向导
./scripts/quick-init.sh
```

脚本会自动：
- ✅ 生成所有密钥和密码
- ✅ 创建 SSL 证书
- ✅ 配置环境变量
- ✅ 创建多平台证书安装包
- ✅ 生成辅助脚本和文档

### 📦 安装 SSL 证书（推荐）

根据您的操作系统，运行相应的安装脚本：

```bash
# macOS
cd cert-installers/macos && ./install.sh

# Linux (Debian/Ubuntu)
cd cert-installers/linux-debian && ./install.sh

# Linux (RedHat/CentOS)
cd cert-installers/linux-redhat && ./install.sh

# Windows (以管理员身份运行 PowerShell)
cd cert-installers\windows
.\install.ps1
```

### 🎯 启动服务

```bash
./start.sh
```

### 🌐 访问 Authentik

浏览器访问初始设置页面：
- **HTTPS** (推荐): https://localhost:9443/if/flow/initial-setup/
- **HTTP**: http://localhost:9000/if/flow/initial-setup/

**注意**: URL 末尾的 `/` 是必需的。

您将被提示为默认管理员账户 `akadmin` 设置密码。

---

## 传统手动安装方式

<details>
<summary>点击展开手动安装步骤</summary>

### 1. 生成密钥

```bash
# 生成 PostgreSQL 密码
echo "PG_PASS=$(openssl rand -base64 36 | tr -d '\n')" >> .env

# 生成 Authentik 密钥
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')" >> .env
```

### 2. 配置环境

```bash
cp .env.example .env
# 编辑 .env 文件
nano .env
```

**必需配置：**
- `PG_PASS`: 数据库密码
- `AUTHENTIK_SECRET_KEY`: 密钥

### 3. 创建目录

```bash
mkdir -p media custom-templates geoip certs
```

### 4. 生成 SSL 证书

```bash
./ssl-setup.sh
# 选择选项 1: 生成自签名证书
```

### 5. 启动服务

```bash
docker compose pull
docker compose up -d
```

### 6. 查看日志

```bash
docker compose logs -f worker
```

首次启动可能需要 3-4 分钟来初始化数据库。

</details>

## SSL/TLS 配置

**重要**: Electron 桌面应用和生产环境必须配置 SSL/TLS 证书。

### 自动 SSL 设置（推荐）

如果您使用了快速初始化脚本，证书已自动生成：

```bash
# 证书位置
ls -lh certs/

# 安装证书到系统（根据您的操作系统）
cd cert-installers/macos && ./install.sh       # macOS
cd cert-installers/linux-debian && ./install.sh  # Ubuntu
cd cert-installers/windows && ./install.ps1     # Windows
```

### 手动 SSL 设置

使用交互式配置脚本：

```bash
./ssl-setup.sh
```

支持以下方式：
- 自签名证书（用于测试）
- Let's Encrypt 证书（用于生产）
- 自定义证书（您自己的 CA/商业证书）

### 详细 SSL 配置

包括反向代理配置（Nginx/Traefik），请查看 [SSL-SETUP.md](SSL-SETUP.md)。

### Basic Direct SSL (Authentik on port 9443)

1. Place certificates in the `certs/` directory:
   - `certs/privkey.pem` - Private key
   - `certs/fullchain.pem` - Certificate chain

2. Uncomment SSL environment variables in [docker-compose.yml](docker-compose.yml):

```yaml
server:
  environment:
    AUTHENTIK_SSL_CERTIFICATE: /certs/fullchain.pem
    AUTHENTIK_SSL_KEY: /certs/privkey.pem
```

3. Restart and access via HTTPS:
   ```bash
   docker compose restart server
   # Access: https://your-server:9443/if/flow/initial-setup/
   ```

### Electron Desktop App Compatibility

Electron applications require HTTPS for secure OAuth/OIDC flows. Configure SSL using one of these methods:

1. **Let's Encrypt with Reverse Proxy** (Recommended)
   - See [SSL-SETUP.md](SSL-SETUP.md) for Nginx/Traefik setup
   - Provides trusted certificates automatically renewed

2. **Direct SSL on Authentik**
   - Use Let's Encrypt or commercial certificate
   - Self-signed certs require trust store configuration

3. **Development Only** - Self-signed certificate:
   ```bash
   ./ssl-setup.sh  # Choose option 1
   ```
   Then add the certificate to your system trust store (see [SSL-SETUP.md](SSL-SETUP.md)).

## Production Considerations

### Security Best Practices

1. **Use strong, unique secrets** - Generate with `openssl rand -base64 60`
2. **Enable HTTPS** - Use a reverse proxy (Traefik, Nginx) with SSL/TLS
3. **Restrict network access** - Use firewall rules to limit access
4. **Regular backups** - Backup the PostgreSQL volume regularly
5. **Keep updated** - Subscribe to Authentik release announcements

### Reverse Proxy Configuration

For production deployments, place Authentik behind a reverse proxy:

**Traefik Example:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.authentik.rule=Host(`authentik.example.com`)"
  - "traefik.http.routers.authentik.entrypoints=websecure"
  - "traefik.http.routers.authentik.tls.certresolver=letsencrypt"
  - "traefik.http.services.authentik.loadbalancer.server.port=9000"
```

**Nginx Example:**
```nginx
location / {
    proxy_pass http://localhost:9000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Backup Strategy

Backup the PostgreSQL volume:

```bash
# Create backup
docker compose exec postgresql pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql

# Backup media files
tar -czf media-backup-$(date +%Y%m%d).tar.gz media/
```

### Resource Limits

Default resource limits are configured in `docker-compose.yml`:

- **PostgreSQL**: 512MB memory, 1 CPU
- **Redis**: 256MB memory, 0.5 CPU
- **Server/Worker**: 1GB memory, 2 CPUs each

Adjust based on your load and available resources.

### Docker Socket Security

By default, the Docker socket is mounted to the worker for automatic outpost management. For enhanced security:

1. **Remove the socket mount** if not using outposts
2. **Use a Docker Socket Proxy** (see `docker-compose.socket-proxy.yml`)

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PG_DB` | `authentik` | PostgreSQL database name |
| `PG_USER` | `authentik` | PostgreSQL user |
| `PG_PASS` | *required* | PostgreSQL password |
| `AUTHENTIK_SECRET_KEY` | *required* | Cryptographic signing key |
| `COMPOSE_PORT_HTTP` | `9000` | HTTP port |
| `COMPOSE_PORT_HTTPS` | `9443` | HTTPS port |
| `AUTHENTIK_LOG_LEVEL` | `info` | Logging verbosity |
| `AUTHENTIK_EMAIL__*` | - | Email configuration |

### Volumes

| Volume | Purpose |
|--------|---------|
| `pg_data` | PostgreSQL database persistence |
| `./media` | User-uploaded media files |
| `./custom-templates` | Custom UI templates |
| `./geoip` | MaxMind GeoIP databases |
| `./certs` | Custom SSL certificates |

## 日常维护

### 常用命令

使用自动生成的辅助脚本：

```bash
# 启动服务
./start.sh

# 停止服务
./stop.sh

# 查看日志（所有服务）
./logs.sh

# 查看特定服务日志
./logs.sh server
./logs.sh worker

# 创建备份
./backup.sh
```

### 升级 Authentik

1. **查看发布说明**了解破坏性变更
2. **更新版本标签**在 `.env` 中：
   ```
   AUTHENTIK_TAG=2025.10.4
   ```
3. **拉取新镜像**：
   ```bash
   docker compose pull
   ```
4. **重启服务**：
   ```bash
   docker compose up -d
   ```

### 查看日志

```bash
# 所有服务
docker compose logs -f

# 特定服务
docker compose logs -f server
docker compose logs -f worker
```

### 数据库管理

```bash
# 访问 PostgreSQL shell
docker compose exec postgresql psql -U authentik -d authentik

# 创建数据库备份
docker compose exec postgresql pg_dump -U authentik authentik > backup.sql

# 恢复数据库
docker compose exec -T postgresql psql -U authentik authentik < backup.sql
```

## Troubleshooting

### Common Issues

**Service won't start:**
- Check logs: `docker compose logs worker`
- Verify database password in `.env` matches generated secret
- Ensure ports are not already in use

**Initial setup page not accessible:**
- Verify trailing slash in URL: `.../initial-setup/`
- Check firewall allows port 9000
- Review server logs for errors

**Email not working:**
- Verify SMTP settings in `.env`
- Check email provider allows relays from your IP
- Test with `AUTHENTIK_LOG_LEVEL=debug`

### Health Checks

All services include health checks. View status:

```bash
docker compose ps
```

## 项目文档

- [完整部署指南](DEPLOYMENT_GUIDE.md) - 自动生成的完整部署文档
- [脚本使用说明](scripts/README.md) - 所有脚本的详细说明
- [证书安装指南](cert-installers/README.md) - 多平台证书安装说明
- [SSL/TLS 配置指南](SSL-SETUP.md) - 高级 SSL 证书配置

## 其他资源

- [Authentik 官方文档](https://docs.goauthentik.io/)
- [Docker Compose 安装指南](https://docs.goauthentik.io/install-config/install/docker-compose/)
- [Authentik GitHub](https://github.com/goauthentik/authentik)
- [社区论坛](https://goauthentik.io/discord)

## License

This Docker Compose configuration is provided as-is for deployment of Authentik, which is licensed under the [MIT License](https://github.com/goauthentik/authentik/blob/main/LICENSE).
