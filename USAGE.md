# Linux下位机服务端程序自动更新系统使用教程

## 一、系统概述

本自动更新系统专为Linux下位机服务端程序设计，支持通过U盘和网络两种方式触发更新，具有自动版本检测、文件备份、服务管理、错误处理和回滚机制等功能。

### 主要特性

- ✅ U盘自动检测与更新触发
- ✅ 版本号智能比较
- ✅ 自动备份与回滚机制
- ✅ 详细的日志记录
- ✅ 系统服务集成
- ✅ 多级别错误处理

## 二、目录结构

```
/usr/local/update/
├── update-manager.sh       # 主更新管理器
├── deploy-agent.sh         # 部署代理
├── config/
│   └── update.conf         # 配置文件
├── logs/                   # 日志目录
├── temp/                   # 临时文件目录
└── scripts/                # 辅助脚本
    ├── version-check.sh    # 版本校验
    └── usb-monitor.sh      # U盘监控
```

## 三、安装与配置

### 1. 安装步骤

1. **复制文件**
   ```bash
   sudo cp -r update /usr/local/
   sudo chmod +x /usr/local/update/*.sh
   sudo chmod +x /usr/local/update/scripts/*.sh
   ```

2. **配置系统服务**
   ```bash
   sudo cp /usr/local/update/update-manager.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable update-manager
   sudo systemctl start update-manager
   ```

3. **安装依赖**
   ```bash
   # 安装inotify-tools（用于U盘监控）
   sudo apt-get install inotify-tools   # Debian/Ubuntu
   sudo yum install inotify-tools       # CentOS/RHEL
   ```

### 2. 配置文件设置

编辑 `/usr/local/update/config/update.conf` 文件：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| APP_DIR | 应用程序安装目录 | `/usr/local/app` |
| SERVICE_NAME | 系统服务名称 | `server-app` |
| LOG_LEVEL | 日志级别 | `INFO` |
| CHECK_INTERVAL | 更新检查间隔(秒) | `10` |
| USB_MOUNT_POINTS | U盘挂载点 | `/media /mnt` |
| UPDATE_PACKAGE_EXTENSION | 更新包扩展名 | `tar.gz` |
| VERSION_FILE | 版本文件名 | `version.txt` |

## 四、使用方法

### 1. U盘更新方式

#### 准备更新包

1. **创建版本文件**：在应用程序目录中创建 `version.txt` 文件，格式为 `major.minor.patch.build`，例如 `1.0.0.0`

2. **打包应用程序**：
   ```bash
   # 进入应用程序目录
   cd /path/to/your/app
   
   # 创建版本文件（如果不存在）
   echo "1.0.1.0" > version.txt
   
   # 打包
   tar -czf server-app-v1.0.1.0.tar.gz ./*
   ```

3. **创建配置文件**：在U盘根目录创建 `update.json` 文件
   ```json
   {
     "package": "server-app-v1.0.1.0.tar.gz",
     "version": "1.0.1.0",
     "description": "更新说明",
     "timestamp": "2024-01-15T10:00:00Z"
   }
   ```

4. **复制文件**：将 `update.json` 和 `server-app-v1.0.1.0.tar.gz` 复制到U盘根目录

#### 执行更新

1. **插入U盘**：将准备好的U盘插入到Linux设备
2. **自动检测**：更新系统会自动检测到U盘并开始更新流程
3. **查看状态**：可以通过以下命令查看更新状态
   ```bash
   cat /usr/local/update/update-status.txt
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

```bash
# 主更新管理器日志
tail -f /usr/local/update/logs/update-manager.log

# 部署代理日志
tail -f /usr/local/update/logs/deploy-agent.log

# U盘监控日志
tail -f /usr/local/update/logs/usb-monitor.log
```

### 2. 检查服务状态

```bash
# 查看更新管理器服务状态
sudo systemctl status update-manager

# 查看应用服务状态
sudo systemctl status server-app
```

### 3. 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| U盘未被检测到 | 挂载点不在监控列表 | 检查 USB_MOUNT_POINTS 配置 |
| 更新包验证失败 | 包损坏或格式错误 | 重新打包并验证文件完整性 |
| 服务启动失败 | 应用程序错误 | 查看应用服务日志，使用备份回滚 |
| 权限错误 | 脚本权限不足 | 确保所有脚本有执行权限 |

## 六、更新包格式规范

### 1. 版本号格式

- **格式**：`major.minor.patch.build`
- **示例**：`1.0.0.0`, `2.1.3.45`
- **规则**：数字递增，不能使用字母或特殊字符

### 2. 包结构

更新包应包含应用程序的所有必要文件，包括：
- 可执行文件
- 配置文件
- 依赖库
- `version.txt` 版本文件

### 3. 配置文件规范

`update.json` 文件必须包含以下字段：
- `package`：更新包文件名
- `version`：版本号
- `description`：更新说明（可选）
- `timestamp`：时间戳（可选）

## 七、安全注意事项

1. **权限控制**：确保更新脚本以适当权限运行，避免使用root权限执行不必要的操作
2. **文件校验**：始终验证更新包的完整性，避免使用未经验证的包
3. **备份策略**：定期检查备份目录，确保有足够的空间存储备份
4. **网络安全**：如果启用网络更新，确保使用安全的传输协议和认证机制
5. **日志审计**：定期检查更新日志，及时发现异常情况

## 八、高级用法

### 1. 自定义更新策略

可以通过修改配置文件调整更新行为：
- 调整检查间隔以平衡实时性和系统资源
- 修改超时设置以适应不同大小的应用程序
- 配置备份保留数量以控制磁盘使用

### 2. 集成到CI/CD流程

可以将更新系统集成到持续集成/持续部署流程中：
1. 自动构建生成更新包
2. 通过网络方式推送更新
3. 监控更新状态并发送通知

### 3. 远程管理

可以通过以下方式远程管理更新系统：
- 查看远程日志文件
- 触发远程更新
- 监控更新状态

## 九、故障恢复

### 1. 回滚操作

如果更新失败，系统会自动尝试回滚到上一版本。也可以手动执行回滚：

```bash
# 找到备份目录
ls -la /usr/local/update/temp/backup_*

# 手动复制备份文件
sudo cp -r /usr/local/update/temp/backup_20240115_120000/* /usr/local/app/
sudo systemctl restart server-app
```

### 2. 紧急停止

```bash
# 停止更新管理器
sudo systemctl stop update-manager

# 停止应用服务（如果必要）
sudo systemctl stop server-app
```

## 十、版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2024-01-15 | 初始版本，支持U盘更新和基本功能 |

## 十一、联系与支持

如果您在使用过程中遇到任何问题，请参考以下资源：

- **日志文件**：详细记录了所有操作和错误信息
- **配置文档**：本教程提供了完整的配置和使用说明
- **系统服务**：通过systemctl命令管理服务状态

---

**注意**：在生产环境中使用前，请务必在测试环境中验证更新流程的完整性和可靠性。