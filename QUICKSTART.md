# 🚀 AgenticGRC-Srvbox 快速使用指南

## ⚡ 超级简单：一个命令搞定所有

```bash
cd /Users/oliver/workspaces/AgenticGRC-Srvbox
./agenticgrc.sh
```

这个统一控制台可以完成所有操作：
- ✅ 初始化和配置
- ✅ 证书安装
- ✅ 服务管理
- ✅ 数据备份
- ✅ 查看文档

**菜单式操作，简单直观！**

---

## 📋 或者按步骤操作

### 第 1 步：运行初始化脚本

```bash
cd /Users/oliver/workspaces/AgenticGRC-Srvbox
./scripts/quick-init.sh
```

您会看到三个选项：
- **选项 1: 快速初始化** - 使用默认域名 `authentik.local`（推荐测试环境）
- **选项 2: 自定义初始化** - 可以输入您自己的域名（如 `auth.example.com`）
- **选项 3: 仅生成密钥** - 跳过证书生成

**推荐选择**：选项 1（直接按回车）

**如果需要自定义域名**，选择选项 2，然后输入您的域名。

**或者直接命令行指定域名**：
```bash
./scripts/init-all.sh --domain 你的域名.com --non-interactive
```

脚本会自动完成：
- ✅ 生成数据库密码和 Authentik 密钥
- ✅ 创建 SSL 证书（10年有效期）
- ✅ 配置 .env 文件
- ✅ 生成各操作系统的证书安装包
- ✅ 创建辅助脚本

### 第 2 步：安装 SSL 证书到系统

**macOS 用户：**
```bash
cd cert-installers/macos
./install.sh
```

**Linux (Ubuntu/Debian) 用户：**
```bash
cd cert-installers/linux-debian
./install.sh
```

**Linux (RedHat/CentOS) 用户：**
```bash
cd cert-installers/linux-redhat
./install.sh
```

**Windows 用户：**
以管理员身份运行 PowerShell：
```powershell
cd cert-installers\windows
.\install.ps1
```

### 第 3 步：启动服务

```bash
cd /Users/oliver/workspaces/AgenticGRC-Srvbox
./start.sh
```

### 第 4 步：访问 Authentik

在浏览器中打开：
```
https://localhost:9443/if/flow/initial-setup/
```

为默认管理员 `akadmin` 设置密码。

---

## 日常使用

### 启动服务
```bash
./start.sh
```

### 停止服务
```bash
./stop.sh
```

### 查看日志
```bash
./logs.sh              # 查看所有服务日志
./logs.sh server       # 查看 server 日志
./logs.sh worker       # 查看 worker 日志
./logs.sh postgresql   # 查看数据库日志
```

### 备份数据
```bash
./backup.sh
```
备份文件会保存在 `backups/` 目录。

### 查看服务状态
```bash
docker compose ps
```

---

## 重要文件位置

| 文件/目录 | 说明 | 重要性 |
|-----------|------|--------|
| `.env` | 环境配置（含密钥） | ⚠️ 不要提交到 git |
| `.secrets` | 密钥备份文件 | ⚠️ 请妥善保管 |
| `certs/` | SSL 证书目录 | 🔒 私钥不要分享 |
| `cert-installers/` | 证书安装包 | ✅ 可分发给团队 |
| `backups/` | 数据备份目录 | 💾 定期备份 |
| `DEPLOYMENT_GUIDE.md` | 完整部署文档 | 📖 自动生成 |

---

## 故障排除

### 问题 1：端口被占用

```bash
# 检查端口占用
sudo lsof -i :9000
sudo lsof -i :9443

# 停止占用端口的服务，然后重启
./stop.sh
./start.sh
```

### 问题 2：证书不被信任

```bash
# 重新安装证书
cd cert-installers/<your-os>
./install.sh
```

### 问题 3：服务启动失败

```bash
# 查看详细日志
./logs.sh

# 重新初始化
./scripts/quick-init.sh

# 重启服务
./stop.sh
./start.sh
```

### 问题 4：忘记管理员密码

```bash
# 重置 akadmin 密码
docker compose exec server ak change_password akadmin
```

### 问题 5：数据库连接失败

```bash
# 检查数据库状态
docker compose ps postgresql

# 重启数据库
docker compose restart postgresql

# 查看数据库日志
./logs.sh postgresql
```

---

## 高级用法

### 自定义域名

```bash
# 使用自定义域名重新初始化
./scripts/init-all.sh --domain auth.yourdomain.com
```

### 仅生成密钥（跳过证书）

```bash
./scripts/init-all.sh --skip-certs
```

### 使用 Let's Encrypt（生产环境推荐）

```bash
./ssl-setup.sh
# 选择选项 2: Setup Let's Encrypt certificate
```

### 配置邮件服务

编辑 `.env` 文件：
```bash
nano .env
```

添加邮件配置：
```
AUTHENTIK_EMAIL__HOST=smtp.gmail.com
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@yourdomain.com
AUTHENTIK_EMAIL__USERNAME=your-email@gmail.com
AUTHENTIK_EMAIL__PASSWORD=your-app-password
```

重启服务：
```bash
docker compose restart
```

### 定期自动备份

添加到 crontab：
```bash
crontab -e
```

添加：
```
# 每天凌晨 2 点备份
0 2 * * * cd /Users/oliver/workspaces/AgenticGRC-Srvbox && ./backup.sh
```

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目总览 |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | 完整部署指南（自动生成） |
| [scripts/README.md](scripts/README.md) | 脚本详细说明 |
| [cert-installers/README.md](cert-installers/README.md) | 证书安装指南 |
| [SSL-SETUP.md](SSL-SETUP.md) | SSL 高级配置 |

---

## 安全提示

1. ✅ **不要提交敏感文件到 Git**
   - `.env` 和 `.secrets` 已在 `.gitignore` 中

2. ✅ **定期备份**
   - 使用 `./backup.sh` 或设置自动备份

3. ✅ **生产环境使用真实证书**
   - 自签名证书仅用于开发/测试
   - 生产环境请使用 Let's Encrypt

4. ✅ **定期更新**
   - 更新 Docker 镜像
   - 关注 Authentik 安全公告

5. ✅ **限制网络访问**
   - 使用防火墙规则
   - 不要暴露数据库端口到公网

---

## 获取帮助

### 查看完整文档
```bash
cat DEPLOYMENT_GUIDE.md
```

### 查看脚本帮助
```bash
./scripts/init-all.sh --help
```

### 官方资源
- [Authentik 官方文档](https://docs.goauthentik.io/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [社区论坛](https://goauthentik.io/discord)

---

**祝使用愉快！** 🎉
