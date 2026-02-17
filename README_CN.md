# AgenticGRC-Srvbox

基于 Authentik 的生产级 Docker Compose 部署配置，提供完整的身份认证和访问管理解决方案。

## ⚡ 快速开始（一键部署）

### 5 分钟完成部署

```bash
# 1. 运行快速初始化（自动生成所有密钥、证书和配置）
./scripts/quick-init.sh

# 2. 安装 SSL 证书到系统（根据您的操作系统）
cd cert-installers/macos && ./install.sh          # macOS
cd cert-installers/linux-debian && ./install.sh   # Ubuntu/Debian
cd cert-installers/linux-redhat && ./install.sh   # CentOS/RHEL

# 3. 启动服务
./start.sh

# 4. 访问 Authentik
# 浏览器打开: https://localhost:9443/if/flow/initial-setup/
```

就这么简单！🎉

## 📋 功能特性

### 自动化初始化系统
- ✅ 一键生成所有密钥和密码（密码学安全）
- ✅ 自动创建 SSL 证书（4096位 RSA）
- ✅ 自动配置环境变量
- ✅ 为所有主流操作系统生成证书安装包
- ✅ 自动创建管理和备份脚本
- ✅ 生成完整的部署文档

### 跨平台支持
- 🍎 macOS
- 🐧 Linux (Debian/Ubuntu/CentOS/RHEL)
- 🪟 Windows

### 安全特性
- 🔒 使用 `openssl rand` 生成高强度密钥
- 🔒 4096 位 RSA 加密
- 🔒 自动设置正确的文件权限
- 🔒 包含 DH 参数增强安全性
- 🔒 密钥自动备份

### 易用性
- 🎨 彩色输出和进度提示
- 📖 完整的中文文档
- 🔧 交互式和非交互式模式
- ✅ 自动验证和错误检查

## 📚 文档

- **[QUICKSTART.md](QUICKSTART.md)** - 5分钟快速开始指南
- **[scripts/README.md](scripts/README.md)** - 所有脚本的详细使用说明
- **[USAGE_GUIDE.txt](USAGE_GUIDE.txt)** - 可视化使用流程和命令速查表
- **[OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md)** - 系统优化详细总结
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - 完整部署指南（运行初始化后生成）

## 🔧 脚本说明

### 快速初始化脚本
```bash
./scripts/quick-init.sh          # 交互式向导（推荐）
./scripts/init-all.sh            # 完整初始化脚本
./scripts/verify.sh              # 验证安装完整性
```

### 管理脚本（自动生成）
```bash
./start.sh                       # 启动所有服务
./stop.sh                        # 停止所有服务
./logs.sh [service]              # 查看日志
./backup.sh                      # 备份数据库和文件
```

### 维护脚本
```bash
./scripts/cleanup.sh             # 清理所有生成的文件
./scripts/test-init.sh           # 测试初始化脚本
./ssl-setup.sh                   # SSL 证书管理工具（高级）
```

## 🌟 命令示例

### 基本使用
```bash
# 快速初始化（使用默认配置）
./scripts/quick-init.sh

# 自定义域名
./scripts/init-all.sh --domain auth.example.com

# 非交互模式（适合 CI/CD）
./scripts/init-all.sh --non-interactive

# 仅生成密钥（跳过证书）
./scripts/init-all.sh --skip-certs
```

### 日常管理
```bash
# 启动服务
./start.sh

# 查看所有服务日志
./logs.sh

# 查看特定服务日志
./logs.sh server
./logs.sh worker
./logs.sh postgresql

# 创建备份
./backup.sh

# 重启服务
docker compose restart

# 查看服务状态
docker compose ps
```

## 📦 生成的文件结构

```
AgenticGRC-Srvbox/
├── .env                         # 环境配置（已生成密钥）
├── .secrets                     # 密钥备份文件
├── certs/                       # SSL 证书目录
│   ├── privkey.pem             # 私钥
│   ├── fullchain.pem           # 完整证书链
│   └── ca.pem                  # 根 CA 证书
├── cert-installers/            # 证书安装包
│   ├── macos/                  # macOS 安装包
│   ├── linux-debian/           # Ubuntu/Debian 安装包
│   ├── linux-redhat/           # CentOS/RHEL 安装包
│   └── windows/                # Windows 安装包
├── scripts/                    # 初始化和管理脚本
├── start.sh                    # 启动脚本（自动生成）
├── stop.sh                     # 停止脚本（自动生成）
├── logs.sh                     # 日志脚本（自动生成）
└── backup.sh                   # 备份脚本（自动生成）
```

## 🔐 证书安装

初始化完成后，根据您的操作系统安装证书：

### macOS
```bash
cd cert-installers/macos
./install.sh
```

### Linux (Ubuntu/Debian)
```bash
cd cert-installers/linux-debian
./install.sh
```

### Linux (CentOS/RHEL)
```bash
cd cert-installers/linux-redhat
./install.sh
```

### Windows
以管理员身份运行 PowerShell：
```powershell
cd cert-installers\windows
.\install.ps1
```

详细说明请查看 `cert-installers/README.md`。

## 🛠️ 故障排除

### 端口被占用
```bash
# 检查端口占用
sudo lsof -i :9000
sudo lsof -i :9443

# 停止服务并重启
./stop.sh
./start.sh
```

### 证书不被信任
```bash
# 重新安装证书
cd cert-installers/<your-os>
./install.sh
```

### 服务启动失败
```bash
# 查看详细日志
./logs.sh

# 验证配置
./scripts/verify.sh

# 重新初始化
./scripts/cleanup.sh
./scripts/quick-init.sh
```

### 忘记管理员密码
```bash
# 重置 akadmin 密码
docker compose exec server ak change_password akadmin
```

更多故障排除信息请查看 [QUICKSTART.md](QUICKSTART.md)。

## 🚀 生产环境部署

### 使用 Let's Encrypt（推荐）
```bash
# 使用 SSL 管理工具配置 Let's Encrypt
./ssl-setup.sh
# 选择选项 2: Setup Let's Encrypt certificate
```

### 配置邮件服务
编辑 `.env` 文件：
```bash
nano .env
```

添加邮件配置：
```env
AUTHENTIK_EMAIL__HOST=smtp.gmail.com
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@example.com
AUTHENTIK_EMAIL__USERNAME=your-email@gmail.com
AUTHENTIK_EMAIL__PASSWORD=your-app-password
```

重启服务：
```bash
docker compose restart
```

### 设置定期备份
```bash
# 编辑 crontab
crontab -e

# 添加每天凌晨 2 点备份
0 2 * * * cd /path/to/AgenticGRC-Srvbox && ./backup.sh
```

## 💡 高级用法

### CI/CD 集成
```bash
# 非交互模式，适合自动化部署
./scripts/init-all.sh --non-interactive --domain ${DOMAIN}
```

### 自定义配置
```bash
# 编辑环境变量
nano .env

# 重启服务应用更改
docker compose restart
```

### 更新 Authentik
```bash
# 1. 编辑 .env 文件，更新版本号
AUTHENTIK_TAG=2025.10.4

# 2. 拉取新镜像
docker compose pull

# 3. 重启服务
docker compose up -d
```

## 📊 系统要求

- **Docker** Engine 20.10+
- **Docker Compose** v2+
- **操作系统**: Linux / macOS / Windows
- **内存**: 最低 2GB，推荐 4GB+
- **磁盘**: 10GB+ 可用空间

## 🔒 安全建议

1. ✅ **不要提交敏感文件** - `.env` 和 `.secrets` 已在 `.gitignore` 中
2. ✅ **定期备份** - 使用 `./backup.sh` 或设置自动备份
3. ✅ **生产环境使用真实证书** - 使用 Let's Encrypt 替代自签名证书
4. ✅ **定期更新** - 关注 Authentik 安全公告并及时更新
5. ✅ **限制网络访问** - 使用防火墙规则，不要暴露数据库端口

## 📞 获取帮助

### 查看文档
```bash
cat QUICKSTART.md           # 快速开始
cat USAGE_GUIDE.txt         # 使用指南
cat DEPLOYMENT_GUIDE.md     # 部署指南（生成后）
```

### 查看帮助
```bash
./scripts/init-all.sh --help
./scripts/verify.sh
```

### 官方资源
- [Authentik 官方文档](https://docs.goauthentik.io/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [社区论坛](https://goauthentik.io/discord)

## 🎯 特性对比

| 功能 | 手动配置 | 使用本脚本 |
|------|---------|-----------|
| 生成密钥 | ❌ 需要手动运行多个命令 | ✅ 自动生成 |
| 配置环境 | ❌ 手动编辑多个文件 | ✅ 一键配置 |
| SSL 证书 | ❌ 需要交互式配置 | ✅ 自动生成 |
| 证书安装包 | ❌ 需要手动创建 | ✅ 多平台自动生成 |
| 管理脚本 | ❌ 需要自己编写 | ✅ 自动创建 |
| 文档 | ❌ 需要手动编写 | ✅ 自动生成 |
| 完成时间 | ⏱️ 30+ 分钟 | ⏱️ 5 分钟 |

## 📝 版本信息

- **版本**: 1.0.0
- **更新时间**: 2026-02-16
- **Authentik 版本**: 2025.10.3
- **Docker Compose**: v2+

## 📜 许可证

本 Docker Compose 配置按原样提供，用于部署 Authentik，Authentik 采用 [MIT 许可证](https://github.com/goauthentik/authentik/blob/main/LICENSE)。

---

**祝您使用愉快！** 🚀

如有问题，请查阅文档或运行 `./scripts/verify.sh` 进行诊断。
