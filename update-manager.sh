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

# 加载配置文件
source "$CONFIG_FILE"

# 日志配置
# 日期文件夹：YYYY-MM-DD
LOG_DATE_DIR="$LOG_DIR/$(date +"%Y-%m-%d")"
# 服务启动时间：HHMMSS
START_TIME=$(date +"%H%M%S")
# 日志文件路径：日期文件夹/服务_启动时间.log
LOG_FILE="$LOG_DATE_DIR/update-manager_$START_TIME.log"
STATUS_FILE="$SCRIPT_DIR/update-status.txt"

# 日志记录函数
# 参数1: 日志级别 (INFO, ERROR, WARNING)
# 参数2: 日志消息
log_message() {
    # 确保日期文件夹存在
    mkdir -p "$LOG_DATE_DIR"
    
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
    
    # 定义支持的更新配置文件名
    local update_config_files=('update.json' 'update')
    
    # 遍历配置的挂载点
    for base_mount in $USB_MOUNT_POINTS; do
        log_message "INFO" "检查挂载点基础目录: $base_mount"
        
        # 递归遍历所有子目录，查找U盘挂载点
        # 使用find命令查找所有深度的目录，排除系统隐藏目录
        find "$base_mount" -type d -not -path "*/\.*" -not -name "System Volume Information" | while read -r mount_point; do
            # 跳过基础目录本身
            if [ "$mount_point" == "$base_mount" ]; then
                continue
            fi
            
            log_message "INFO" "检测到挂载点目录: $mount_point"
            
            # 检查是否存在更新配置文件
            local found_config=""
            for config_file in "${update_config_files[@]}"; do
                if [ -f "$mount_point/$config_file" ]; then
                    found_config="$config_file"
                    log_message "INFO" "在 $mount_point 中找到更新配置文件: $config_file"
                    break
                fi
            done
            
            if [ -n "$found_config" ]; then
                # 解析更新配置文件
                local update_config=$(cat "$mount_point/$found_config")
                local package_name=$(echo "$update_config" | grep -o '"package": "[^"]*"' | cut -d '"' -f 4)
                local version=$(echo "$update_config" | grep -o '"version": "[^"]*"' | cut -d '"' -f 4)
                
                if [ -z "$package_name" ]; then
                    log_message "ERROR" "在 $found_config 中未找到 package 字段"
                    continue
                fi
                
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
                        cp "$mount_point/$found_config" "$TEMP_DIR/update.json"  # 统一命名为update.json供后续使用
                        
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
                    log_message "ERROR" "在 $mount_point 中未找到更新包 $package_name"
                    update_status "ERROR" "未找到更新包"
                fi
            else
                log_message "INFO" "在 $mount_point 中未找到更新配置文件 (尝试了: ${update_config_files[*]})"
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