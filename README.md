# Linux下位机服务端程序自动更新系统

## 一、项目概述

本自动更新系统专为Linux下位机服务端程序设计，支持通过U盘触发更新，具有自动版本检测、文件备份、服务管理、错误处理和回滚机制等功能。

## 二、主要特性

- ✅ U盘自动检测与更新触发
- ✅ 支持单个可执行文件更新（简化版更新流程）
- ✅ 递归查找U盘挂载点，支持复杂目录结构
- ✅ 版本号智能比较与管理
- ✅ 自动备份与回滚机制（相同版本不重复备份）
- ✅ 按日期分类的详细日志记录
- ✅ 系统服务集成
- ✅ 多级别错误处理

## 三、快速安装

### 1. 复制文件
```bash
sudo cp -r update /usr/local/
sudo chmod +x /usr/local/update/*.sh
sudo chmod +x /usr/local/update/scripts/*.sh
```

### 2. 配置系统服务
```bash
sudo cp /usr/local/update/update-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable update-manager
sudo systemctl start update-manager
```

### 3. 安装依赖
```bash
# 安装inotify-tools（用于U盘监控）
sudo apt-get install inotify-tools   # Debian/Ubuntu
sudo yum install inotify-tools       # CentOS/RHEL
```

## 四、基本配置

编辑 `/usr/local/update/config/update.conf` 文件，主要配置项：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| APP_DIR | 应用程序安装目录 | `/usr/local/app` |
| SERVICE_NAME | 系统服务名称 | `server-app` |
| USB_MOUNT_POINTS | U盘挂载点 | `/media /mnt /run/media` |
| EXECUTABLE_NAME | 要更新的可执行文件名（单个可执行文件更新时生效） | `` |
| SUPPORT_SINGLE_EXECUTABLE | 是否支持单个可执行文件更新 | `true` |

## 五、基本使用

### 1. U盘更新方式

#### 准备更新包（选择其中一种）

##### 方式一：传统tar.gz包更新（适用于多个文件更新）
1. 打包应用程序：`tar -czf server-app-v1.0.1.0.tar.gz ./*`
2. 创建配置文件 `update.json`：
   ```json
   {
     "package": "server-app-v1.0.1.0.tar.gz",
     "version": "1.0.1.0",
     "description": "更新说明"
   }
   ```
3. 将 `update.json` 和 `server-app-v1.0.1.0.tar.gz` 复制到U盘根目录

##### 方式二：单个可执行文件更新（简化版）
1. 准备可执行文件，例如 `server-app`
2. 创建配置文件 `update.json`：
   ```json
   {
     "package": "server-app",
     "version": "1.0.1.0",
     "description": "更新说明"
   }
   ```
3. 将 `update.json` 和 `server-app` 复制到U盘根目录

#### 执行更新
1. 将准备好的U盘插入到Linux设备
2. 系统会自动检测到U盘并开始更新流程
3. 查看更新状态：`cat /usr/local/update/update-status.txt`

### 2. 查看日志

日志按日期分类存储在 `/usr/local/update/logs/YYYY-MM-DD/` 目录下：
```bash
# 查看今日日志目录
ls -la /usr/local/update/logs/$(date +"%Y-%m-%d")/

# 查看主更新管理器日志
tail -f /usr/local/update/logs/$(date +"%Y-%m-%d")/update-manager_*.log
```

## 六、详细使用说明

请参考完整的使用手册：[USAGE.md](USAGE.md)

## 七、故障排除

- **U盘未被检测到**：检查 `USB_MOUNT_POINTS` 配置，确保包含U盘实际挂载点
- **更新包验证失败**：检查更新包格式是否正确，单个可执行文件无需打包
- **服务启动失败**：查看应用服务日志，使用备份回滚
- **权限错误**：确保所有脚本有执行权限

## 八、版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2024-01-15 | 初始版本，支持U盘更新和基本功能 |
| 1.1.0 | 2026-01-19 | 支持单个可执行文件更新，优化日志管理和备份机制 |

## 九、注意事项

- 在生产环境中使用前，请务必在测试环境中验证更新流程
- 定期检查备份目录和日志文件，确保系统正常运行
- 确保U盘格式兼容Linux系统

---

**详细文档**：请查看 [USAGE.md](USAGE.md) 获取完整的使用说明、高级配置和故障排除指南。