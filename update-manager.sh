#!/bin/bash
#
# update-manager.sh - 主更新管理器脚本
# 功能：监控U盘更新触发，协调更新流程
# 作者：AutoGen
# 版本：1.0.0
#

# 设置脚本在遇到错误时退出
set -e

# 定义脚本目录和相关路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config/update.conf"
LOG_DIR="$SCRIPT_DIR/logs"
TEMP_DIR="$SCRIPT_DIR/temp"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# 日志文件和状态文件路径
LOG_FILE="$LOG_DIR/update-manager.log"
STATUS_FILE="$SCRIPT_DIR/update-status.txt"

# 加载配置文件
source "$CONFIG_FILE"

# 日志记录函数
# 参数1: 日志级别 (INFO, ERROR, WARNING)
# 参数2: 日志消息
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    # 将日志级别转换为中文
    case $level in
        INFO) level="信息" ;;
        ERROR) level="错误" ;;
        WARNING) level="警告" ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] $message"
}

# 更新状态文件函数
# 参数1: 状态 (READY, UPDATING, COMPLETED, FAILED, SKIPPED, ERROR)
# 参数2: 状态消息
update_status() {
    local status="$1"
    local message="$2"
    # 将状态转换为中文
    case $status in
        READY) status_cn="就绪" ;;
        UPDATING) status_cn="更新中" ;;
        COMPLETED) status_cn="完成" ;;
        FAILED) status_cn="失败" ;;
        SKIPPED) status_cn="跳过" ;;
        ERROR) status_cn="错误" ;;
        *) status_cn="未知" ;;
    esac
    echo "STATUS:$status" > "$STATUS_FILE"
    echo "MESSAGE:$message" >> "$STATUS_FILE"
    log_message "INFO" "状态更新: $status_cn - $message"
}

# 检查U盘更新函数
check_usb_update() {
    log_message "INFO" "正在检查U盘更新..."
    
    # 遍历配置的挂载点
    for base_mount in $USB_MOUNT_POINTS; do
        for mount_point in $base_mount/*; do
            if [ -d "$mount_point" ]; then
                log_message "INFO" "检测到U盘挂载: $mount_point"
                # 检查是否存在update.json配置文件
                if [ -f "$mount_point/update.json" ]; then
                    log_message "INFO" "在 $mount_point 中找到 update.json"
                    
                    # 解析update.json文件
                    local update_config=$(cat "$mount_point/update.json")
                    local package_name=$(echo "$update_config" | grep -o '"package": "[^"]*"' | cut -d '"' -f 4)
                    local version=$(echo "$update_config" | grep -o '"version": "[^"]*"' | cut -d '"' -f 4)
                    
                    # 检查更新包是否存在
                    if [ -f "$mount_point/$package_name" ]; then
                        log_message "INFO" "找到更新包: $package_name (版本: $version)"
                        
                        # 获取当前版本
                        local current_version=$(cat "$APP_DIR/version.txt" 2>/dev/null || echo "0.0.0.0")
                        log_message "INFO" "当前版本: $current_version, 更新版本: $version"
                        
                        # 检查版本是否需要更新
                        if "$SCRIPTS_DIR/version-check.sh" "$current_version" "$version"; then
                            log_message "INFO" "版本检查通过，开始更新"
                            
                            # 更新状态为正在更新
                            update_status "UPDATING" "开始从U盘更新"
                            
                            # 复制更新包和配置文件到临时目录
                            cp "$mount_point/$package_name" "$TEMP_DIR/"
                            cp "$mount_point/update.json" "$TEMP_DIR/"
                            
                            # 调用部署代理执行更新
                            "$SCRIPT_DIR/deploy-agent.sh" "$TEMP_DIR/$package_name" "$TEMP_DIR/update.json"
                            
                            # 更新状态为完成
                            update_status "COMPLETED" "更新成功完成"
                            log_message "INFO" "更新成功完成"
                        else
                            log_message "INFO" "版本检查失败，跳过更新"
                            update_status "SKIPPED" "版本检查失败"
                        fi
                    else
                        log_message "ERROR" "未找到更新包 $package_name"
                        update_status "ERROR" "未找到更新包"
                    fi
                fi
            fi
        done
    done
}

# 主函数
main() {
    log_message "INFO" "更新管理器已启动"
    update_status "READY" "等待更新触发"
    
    # 无限循环检查更新
    while true; do
        check_usb_update
        sleep 10  # 每10秒检查一次
    done
}

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    log_message "ERROR" "脚本必须以root权限运行"
    exit 1
fi

# 创建必要的目录
mkdir -p "$LOG_DIR" "$TEMP_DIR"

# 启动主函数
main