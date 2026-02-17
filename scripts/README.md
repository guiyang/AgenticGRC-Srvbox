# AgenticGRC-Srvbox 脚本说明

本目录包含用于 AgenticGRC-Srvbox 项目的各种初始化和管理脚本。

## 目录结构

```
scripts/
├── README.md              # 本文档
├── init-all.sh            # 核心初始化脚本
├── quick-init.sh          # 快速初始化向导
├── verify.sh              # 验证脚本
├── cleanup.sh             # 清理脚本
├── lib/                   # 共享库
│   ├── core.sh            # 核心加载器
│   ├── colors.sh          # 颜色定义
│   ├── output.sh          # 输出函数
│   ├── utils.sh           # 工具函数
│   ├── config.sh          # 配置管理
│   └── certs.sh           # 证书管理
├── generated/             # 初始化生成的脚本
│   ├── start.sh           # 启动服务
│   ├── stop.sh            # 停止服务
│   ├── logs.sh            # 查看日志
│   └── backup.sh          # 备份数据
└── legacy/                # 遗留脚本（保持兼容）
    ├── ssl-setup.sh       # SSL 高级配置
    └── init-db.sh         # 数据库初始化
```

## 快速开始

### 推荐方式

```bash
# 运行快速初始化向导
./scripts/quick-init.sh
```

### 命令行方式

```bash
# 非交互模式，使用默认配置
./scripts/init-all.sh --non-interactive

# 指定自定义域名
./scripts/init-all.sh --domain auth.example.com

# 仅生成密钥，跳过证书
./scripts/init-all.sh --skip-certs
```

## 脚本说明

### 主要脚本

| 脚本 | 用途 | 推荐度 |
|------|------|--------|
| `quick-init.sh` | 快速初始化向导，交互式操作 | ⭐⭐⭐ |
| `init-all.sh` | 完整初始化，支持命令行参数 | ⭐⭐⭐ |
| `verify.sh` | 验证安装完整性 | ⭐⭐ |
| `cleanup.sh` | 清理所有生成的文件 | ⭐ |

### 共享库 (lib/)

| 文件 | 用途 |
|------|------|
| `core.sh` | 核心加载器，加载所有其他库 |
| `colors.sh` | 终端颜色定义 |
| `output.sh` | 统一的输出格式函数 |
| `utils.sh` | 通用工具函数（依赖检查、文件操作等） |
| `config.sh` | 配置管理和环境变量处理 |
| `certs.sh` | SSL 证书生成和管理 |

### 使用共享库

在自定义脚本中使用共享库：

```bash
#!/bin/bash
# 加载共享库
source "$(dirname "$0")/lib/core.sh"

# 初始化脚本环境
init_script

# 现在可以使用所有库函数
print_banner "我的脚本"
print_info "开始执行..."

# 检查依赖
require_dependencies openssl docker

# 使用配置
local project_root=$(get_project_root)
local cert_dir=$(get_cert_dir)

# 生成证书
load_certs_module
generate_root_ca_certs "mydomain.local"
```

## 命令行参数

### init-all.sh

| 参数 | 说明 | 示例 |
|------|------|------|
| `--domain DOMAIN` | 设置证书域名 | `--domain auth.example.com` |
| `--non-interactive` | 非交互模式 | `--non-interactive` |
| `--skip-certs` | 跳过证书生成 | `--skip-certs` |
| `--help` | 显示帮助 | `--help` |

## 功能特性

### 自动化
- ✅ 一键初始化所有配置
- ✅ 自动生成安全密钥
- ✅ 自动创建 SSL 证书
- ✅ 自动创建多平台证书安装包

### 安全性
- ✅ 使用 `openssl rand` 生成密码学安全的密钥
- ✅ 4096 位 RSA 密钥
- ✅ 自动设置文件权限
- ✅ 密钥备份到 `.secrets` 文件

### 跨平台支持
- ✅ macOS
- ✅ Linux (Debian/Ubuntu)
- ✅ Linux (RedHat/CentOS)
- ✅ Windows (PowerShell/批处理)

### 模块化设计
- ✅ 共享库消除代码重复
- ✅ 统一的输出格式
- ✅ 可扩展的架构

## 常见问题

### Q: 如何查看所有可用选项？

```bash
./scripts/init-all.sh --help
```

### Q: 如何重新生成证书？

```bash
./scripts/init-all.sh --non-interactive
# 或使用清理后重新初始化
./scripts/cleanup.sh
./scripts/quick-init.sh
```

### Q: 脚本执行权限错误怎么办？

```bash
chmod +x scripts/*.sh
chmod +x scripts/lib/*.sh
```

### Q: 如何只更新密钥不更新证书？

```bash
./scripts/init-all.sh --skip-certs
```

## 开发指南

### 添加新脚本

1. 在脚本开头加载共享库：
   ```bash
   source "$(dirname "$0")/lib/core.sh"
   init_script
   ```

2. 使用统一的输出函数：
   - `print_banner` - 显示横幅
   - `print_header` - 显示标题
   - `print_info/success/warning/error` - 状态消息
   - `print_check` - 验证结果

3. 使用配置函数：
   - `get_project_root` - 获取项目根目录
   - `get_env_file` - 获取 .env 文件路径
   - `load_env` - 加载环境变量

### 添加新的库模块

1. 在 `lib/` 目录创建新文件
2. 添加防重复加载检查
3. 在 `core.sh` 中注册加载

## 更多资源

- [部署指南](../DEPLOYMENT_GUIDE.md)
- [证书安装说明](../cert-installers/README.md)
- [Authentik 官方文档](https://docs.goauthentik.io/)
