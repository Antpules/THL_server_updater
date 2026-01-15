#!/bin/bash
#
# usb-monitor.sh - U盘监控脚本
# 功能：监控U盘挂载事件，触发更新流程
# 作者：AutoGen
# 版本：1.0.0
#

# 定义脚本目录和相关路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config/update.conf"
LOG_DIR="$SCRIPT_DIR/logs"

# 加载配置文件
source "$CONFIG_FILE"

# 日志文件路径
LOG_FILE="$LOG_DIR/usb-monitor.log"

# 日志记录函数
# 参数1: 日志级别 (INFO, ERROR, DEBUG)
# 参数2: 日志消息
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] $message"
}

# 监控U盘函数
monitor_usb() {
    log_message "INFO" "Starting USB monitor"
    
    # 创建临时文件用于存储inotify事件
    local event_file=$(mktemp)
    
    # 持续监控挂载点变化
    while true; do
        # 使用inotifywait监控目录变化
        inotifywait -e create -e modify -e move -r $USB_MOUNT_POINTS > "$event_file" 2>&1
        
        if [ $? -eq 0 ]; then
            local events=$(cat "$event_file")
            log_message "DEBUG" "Received inotify events: $events"
            
            # 检查每个挂载点
            for mount_point in $USB_MOUNT_POINTS; do
                if [ -d "$mount_point" ]; then
                    for device_dir in "$mount_point"/*; do
                        if [ -d "$device_dir" ]; then
                            # 检查是否存在update.json文件
                            if [ -f "$device_dir/update.json" ]; then
                                log_message "INFO" "Detected update.json in $device_dir"
                                
                                # 触发更新流程
                                "$SCRIPT_DIR/update-manager.sh" --usb "$device_dir"
                                
                                # 睡眠以避免重复触发
                                sleep 5
                            fi
                        fi
                    done
                fi
            done
        else
            log_message "ERROR" "inotifywait failed, restarting monitor"
            sleep 5
        fi
    done
    
    # 清理临时文件
    rm -f "$event_file"
}

# 检查inotifywait是否安装
if ! command -v inotifywait &> /dev/null; then
    log_message "ERROR" "inotifywait is not installed. Please install inotify-tools."
    exit 1
fi

# 创建日志目录
mkdir -p "$LOG_DIR"

# 开始监控
monitor_usb