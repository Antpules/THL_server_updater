# Linux下位机服务端程序自动更新系统使用教程

## 一、系统概述

本自动更新系统专为Linux下位机服务端程序设计，支持通过U盘触发更新，具有自动版本检测、文件备份、服务管理、错误处理和回滚机制等功能。

### 主要特性

- ✅ U盘自动检测与更新触发
- ✅ 支持单个可执行文件更新（简化版更新流程）
- ✅ 递归查找U盘挂载点，支持复杂目录结构（如 `/media/lj/TSU10`）
- ✅ 版本号智能比较与管理
- ✅ 自动备份与回滚机制（相同版本不重复备份）
- ✅ 按日期分类的详细日志记录
- ✅ 系统服务集成
- ✅ 多级别错误处理

## 二、目录结构

```
/usr/local/update/
├── update-manager.sh       # 主更新管理器
├── deploy-agent.sh         # 部署代理
├── update-manager.service  # 系统服务配置
├── config/
│   └── update.conf         # 配置文件
├── logs/                   # 日志目录
│   ├── 2026-01-19/         # 按日期分类的日志
│   │   ├── update-manager_094218.log  # 主更新管理器日志
│   │   ├── deploy-agent_094218.log    # 部署代理日志
│   │   └── usb-monitor_094218.log     # U盘监控日志
│   └── ...
├── temp/                   # 临时文件目录
│   ├── back_1.0.1.0_before/  # 版本号命名的备份目录
│   └── ...
└── scripts/                # 辅助脚本
    ├── version-check.sh    # 版本校验
    └── usb-monitor.sh      # U盘监控
```

## 三、安装与配置

### 1. 一键安装（推荐）

```bash
# 设置脚本可执行权限
chmod +x install.sh

# 以root权限执行安装脚本
sudo ./install.sh
```

一键安装脚本会自动完成以下操作：
- 检查权限并创建安装目录
- 复制所有必要的文件到安装目录
- 设置脚本文件的执行权限
- 配置系统服务（包括update-manager.service和websocket_server.service）
- 安装必要的依赖（inotify-tools）
- 启动并验证update-manager服务
- 显示安装完成信息

### 2. 手动安装（可选）

#### 2.1 复制文件
```bash
sudo cp -r update /usr/local/
sudo chmod +x /usr/local/update/*.sh
sudo chmod +x /usr/local/update/scripts/*.sh
```

#### 2.2 配置系统服务
```bash
# 配置update-manager服务
sudo cp /usr/local/update/update-manager.service /etc/systemd/system/

# 配置websocket_server服务（如果存在）
if [ -f "/usr/local/update/websocket_server.service" ]; then
    sudo cp /usr/local/update/websocket_server.service /etc/systemd/system/
    sudo chmod +x /etc/systemd/system/websocket_server.service
fi

sudo systemctl daemon-reload
sudo systemctl enable update-manager
sudo systemctl start update-manager
```

#### 2.3 安装依赖
```bash
# 安装inotify-tools（用于U盘监控）
sudo apt-get install inotify-tools   # Debian/Ubuntu
sudo yum install inotify-tools       # CentOS/RHEL
```

### 3. 配置文件设置

编辑 `/usr/local/update/config/update.conf` 文件，完整配置项说明：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| APP_DIR | 应用程序安装目录 | `/usr/local/app` |
| SERVICE_NAME | 系统服务名称 | `server-app` |
| LOG_LEVEL | 日志级别 | `INFO` |
| CHECK_INTERVAL | 更新检查间隔(秒) | `10` |
| USB_MOUNT_POINTS | U盘挂载点（空格分隔） | `/media /mnt /run/media` |
| UPDATE_PACKAGE_EXTENSION | 更新包扩展名 | `tar.gz` |
| VERSION_FILE | 版本文件名 | `version.txt` |
| EXECUTABLE_NAME | 要更新的可执行文件名（单个可执行文件更新时生效，可选） | `` |
| SUPPORT_SINGLE_EXECUTABLE | 是否支持单个可执行文件更新 | `true` |
| BACKUP_RETENTION | 备份保留数量 | `5` |
| ENABLE_VERIFICATION | 启用包完整性验证 | `true` |
| VERIFICATION_METHOD | 验证方法 | `SHA256` |
| STOP_TIMEOUT | 服务停止超时（秒） | `30` |
| START_TIMEOUT | 服务启动超时（秒） | `60` |
| DEPLOY_TIMEOUT | 部署超时（秒） | `120` |

## 四、使用方法

### 1. U盘更新方式

#### 准备更新包

##### 方式一：传统tar.gz包更新（适用于多个文件更新）

1. **创建版本文件**：在应用程序目录中创建 `version.txt` 文件，格式为 `major.minor.patch.build`，例如 `1.0.0.0`

2. **打包应用程序**：
   ```bash
   # 进入应用程序目录
   cd /path/to/your/app
   
   # 创建版本文件（如果不存在）
   echo "1.0.1.0" > version.txt
   
   # 打包所有文件
   tar -czf server-app-v1.0.1.0.tar.gz ./*
   ```

3. **创建配置文件**：在U盘根目录创建 `update.json` 文件
   ```json
   {
     "package": "server-app-v1.0.1.0.tar.gz",
     "version": "1.0.1.0",
     "description": "更新说明",
     "timestamp": "2026-01-19T10:00:00Z"
   }
   ```

4. **复制文件**：将 `update.json` 和 `server-app-v1.0.1.0.tar.gz` 复制到U盘根目录

##### 方式二：单个可执行文件更新（简化版，适用于只有一个可执行文件需要更新）

1. **准备可执行文件**：确保您的可执行文件已编译完成，例如 `websocket_server`

2. **创建配置文件**：在U盘根目录创建 `update.json` 文件
   ```json
   {
     "package": "websocket_server",
     "version": "1.0.1.0",
     "description": "更新说明",
     "timestamp": "2026-01-19T10:00:00Z"
   }
   ```
   注意：`package` 字段直接填写可执行文件名，无需 `.tar.gz` 扩展名

3. **复制文件**：将 `update.json` 和 `websocket_server` 可执行文件复制到U盘根目录

##### 配置说明

如果您使用单个可执行文件更新，可以在 `config/update.conf` 中配置：

```bash
# 要更新的可执行文件名（可选，默认使用package字段指定的文件名）
EXECUTABLE_NAME="websocket_server"

# 是否支持单个可执行文件更新
SUPPORT_SINGLE_EXECUTABLE="true"
```

#### 执行更新

1. **插入U盘**：将准备好的U盘插入到Linux设备
2. **自动检测**：更新系统会自动递归查找所有挂载点，包括深层目录（如 `/media/lj/TSU10`）
3. **查看状态**：可以通过以下命令查看更新状态
   ```bash
   cat /usr/local/update/update-status.txt
   ```
4. **查看日志**：可以通过以下命令查看详细日志
   ```bash
   # 查看今日日志目录
   ls -la /usr/local/update/logs/$(date +"%Y-%m-%d")/
   
   # 查看主更新管理器日志
   tail -f /usr/local/update/logs/$(date +"%Y-%m-%d")/update-manager_*.log
   ```

### 2. 手动触发更新

```bash
# 使用指定的更新包和配置文件
sudo /usr/local/update/update-manager.sh --package /path/to/package.tar.gz --config /path/to/update.json

# 从指定目录触发更新
sudo /usr/local/update/update-manager.sh --usb /media/usb-drive
```

## 五、监控与调试

### 1. 查看日志

日志按日期分类存储在 `/usr/local/update/logs/YYYY-MM-DD/` 目录下，每个服务启动生成一个新的日志文件：

```bash
# 查看所有日志目录
ls -la /usr/local/update/logs/

# 查看今日日志文件
ls -la /usr/local/update/logs/$(date +"%Y-%m-%d")/

# 查看主更新管理器日志
tail -f /usr/local/update/logs/$(date +"%Y-%m-%d")/update-manager_*.log

# 查看部署代理日志
tail -f /usr/local/update/logs/$(date +"%Y-%m-%d")/deploy-agent_*.log

# 查看U盘监控日志
tail -f /usr/local/update/logs/$(date +"%Y-%m-%d")/usb-monitor_*.log
```

### 2. 检查服务状态

```bash
# 查看更新管理器服务状态
sudo systemctl status update-manager

# 查看应用服务状态
sudo systemctl status server-app

# 查看更新管理器服务日志
sudo journalctl -u update-manager -f
```

### 3. 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| U盘未被检测到 | 挂载点不在监控列表 | 检查 `USB_MOUNT_POINTS` 配置，确保包含 `/run/media` 等动态挂载点 |
| 更新包验证失败 | 包损坏或格式错误 | 重新打包并验证文件完整性，单个可执行文件无需打包 |
| 服务启动失败 | 应用程序错误 | 查看应用服务日志，使用备份回滚 |
| 权限错误 | 脚本权限不足 | 确保所有脚本有执行权限：`sudo chmod +x /usr/local/update/*.sh /usr/local/update/scripts/*.sh` |
| 相同版本重复备份 | 备份逻辑问题 | 系统已优化，相同版本号不会重复备份 |
| 日志文件过大 | 日志管理问题 | 日志按日期分类存储，可定期清理旧日志 |

## 六、更新包格式规范

### 1. 版本号格式

- **格式**：`major.minor.patch.build`
- **示例**：`1.0.0.0`, `2.1.3.45`
- **规则**：数字递增，不能使用字母或特殊字符

### 2. 包结构

#### 方式一：tar.gz包结构

更新包应包含应用程序的所有必要文件，包括：
- 可执行文件
- 配置文件
- 依赖库
- `version.txt` 版本文件

#### 方式二：单个可执行文件

直接使用编译好的可执行文件，无需打包。系统会自动：
- 替换目标可执行文件
- 根据 `update.json` 中的版本信息更新 `version.txt`
- 设置正确的执行权限

### 3. 配置文件规范

`update.json` 文件必须包含以下字段：
- `package`：更新包文件名（tar.gz包或单个可执行文件名）
- `version`：版本号
- `description`：更新说明（可选）
- `timestamp`：时间戳（可选）

## 七、备份与回滚机制

### 1. 备份机制

- **自动备份**：每次更新前自动创建备份
- **版本号命名**：备份目录格式为 `back_${version}_before`
- **相同版本不备份**：如果目标版本的备份已存在，跳过备份操作
- **智能备份**：仅备份必要文件，单个可执行文件更新时仅备份该文件

### 2. 回滚操作

如果更新失败，系统会自动尝试回滚到上一版本。也可以手动执行回滚：

```bash
# 找到备份目录
ls -la /usr/local/update/temp/back_*

# 手动复制备份文件（根据实际情况选择）

# 方式一：单个可执行文件回滚
sudo cp /usr/local/update/temp/back_1.0.1.0_before/websocket_server /usr/local/app/
sudo cp /usr/local/update/temp/back_1.0.1.0_before/version.txt /usr/local/app/

# 方式二：完整目录回滚
sudo cp -r /usr/local/update/temp/back_1.0.1.0_before/* /usr/local/app/

# 重启服务
sudo systemctl restart server-app
```

## 八、安全注意事项

1. **权限控制**：确保更新脚本以适当权限运行，避免使用root权限执行不必要的操作
2. **文件校验**：始终验证更新包的完整性，避免使用未经验证的包
3. **备份策略**：定期检查备份目录，确保有足够的空间存储备份
4. **日志审计**：定期检查更新日志，及时发现异常情况
5. **U盘安全**：确保使用可靠的U盘进行更新，避免使用来历不明的U盘

## 九、高级用法

### 1. 自定义更新策略

可以通过修改配置文件调整更新行为：
- 调整检查间隔以平衡实时性和系统资源
- 修改超时设置以适应不同大小的应用程序
- 配置备份保留数量以控制磁盘使用

### 2. 集成到CI/CD流程

可以将更新系统集成到持续集成/持续部署流程中：
1. 自动构建生成更新包
2. 通过U盘方式分发更新
3. 监控更新状态并发送通知

### 3. 远程管理

可以通过以下方式远程管理更新系统：
- 查看远程日志文件
- 触发远程更新
- 监控更新状态

## 十、故障恢复

### 1. 回滚操作

参考第七节 "备份与回滚机制"。

### 2. 紧急停止

```bash
# 停止更新管理器
sudo systemctl stop update-manager

# 停止应用服务（如果必要）
sudo systemctl stop server-app
```

### 3. 恢复服务

```bash
# 重启更新管理器
sudo systemctl start update-manager

# 重启应用服务
sudo systemctl start server-app
```

## 十一、版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2024-01-15 | 初始版本，支持U盘更新和基本功能 |
| 1.1.0 | 2026-01-19 | 支持单个可执行文件更新，优化日志管理和备份机制 |
| 1.1.1 | 2026-01-19 | 支持递归查找U盘挂载点，修复深层目录检测问题 |
| 1.1.2 | 2026-01-19 | 优化备份逻辑，相同版本不重复备份 |
| 1.2.0 | 2026-01-27 | 添加一键安装脚本，支持自动安装和配置 |

## 十二、联系与支持

如果您在使用过程中遇到任何问题，请参考以下资源：

- **日志文件**：详细记录了所有操作和错误信息，按日期分类存储
- **配置文档**：本教程提供了完整的配置和使用说明
- **系统服务**：通过systemctl命令管理服务状态

---

**注意**：在生产环境中使用前，请务必在测试环境中验证更新流程的完整性和可靠性。