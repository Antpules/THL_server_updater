#!/bin/bash
#
# deploy-agent.sh - 部署代理脚本
# 功能：处理具体的文件替换和服务重启
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

# 加载配置文件
source "$CONFIG_FILE"

# 部署日志文件路径
DEPLOY_LOG="$LOG_DIR/deploy-agent.log"

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
    echo "[$timestamp] [$level] $message" >> "$DEPLOY_LOG"
    echo "[$timestamp] [$level] $message"
}

# 备份当前文件函数
# 返回值: 备份目录路径
backup_current_files() {
    local backup_dir="$TEMP_DIR/backup_$(date +"%Y%m%d_%H%M%S")"
    log_message "INFO" "正在 $backup_dir 创建备份"
    
    mkdir -p "$backup_dir"
    cp -r "$APP_DIR"/* "$backup_dir/" 2>/dev/null || true
    
    echo "$backup_dir"
}

# 停止服务函数
stop_service() {
    log_message "INFO" "正在停止服务: $SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        log_message "INFO" "服务已成功停止"
    else
        log_message "INFO" "服务未运行"
    fi
}

# 启动服务函数
# 返回值: 0表示成功，1表示失败
start_service() {
    log_message "INFO" "正在启动服务: $SERVICE_NAME"
    
    systemctl start "$SERVICE_NAME"
    
    sleep 5  # 等待服务启动
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_message "INFO" "服务已成功启动"
        return 0
    else
        log_message "ERROR" "服务启动失败"
        return 1
    fi
}

# 回滚函数
# 参数1: 备份目录路径
rollback() {
    local backup_dir="$1"
    log_message "ERROR" "正在回滚到备份: $backup_dir"
    
    if [ -d "$backup_dir" ]; then
        rm -rf "$APP_DIR"/* 2>/dev/null || true
        cp -r "$backup_dir"/* "$APP_DIR/" 2>/dev/null || true
        
        start_service
        log_message "INFO" "回滚完成"
    else
        log_message "ERROR" "未找到备份目录，无法回滚"
    fi
}

# 部署更新函数
# 参数1: 更新包路径
# 参数2: 配置文件路径
# 返回值: 0表示成功，1表示失败
deploy_update() {
    local package_path="$1"
    local config_path="$2"
    
    log_message "INFO" "正在开始部署 $package_path"
    
    # 创建备份
    local backup_dir=$(backup_current_files)
    
    # 停止服务
    stop_service
    
    # 创建部署目录
    local deploy_dir="$TEMP_DIR/deploy_$(date +"%Y%m%d_%H%M%S")"
    mkdir -p "$deploy_dir"
    
    # 解压更新包
    log_message "INFO" "正在解压更新包"
    tar -xzf "$package_path" -C "$deploy_dir"
    
    # 部署文件
    log_message "INFO" "正在部署文件到 $APP_DIR"
    rm -rf "$APP_DIR"/* 2>/dev/null || true
    cp -r "$deploy_dir"/* "$APP_DIR/"
    
    # 设置权限
    log_message "INFO" "正在设置权限"
    chmod +x "$APP_DIR"/*.sh 2>/dev/null || true
    chmod +x "$APP_DIR"/*.bin 2>/dev/null || true
    
    # 启动服务并验证
    if start_service; then
        log_message "INFO" "部署成功完成"
        rm -rf "$backup_dir" 2>/dev/null || true  # 清理备份
        return 0
    else
        log_message "ERROR" "部署失败，正在启动回滚"
        rollback "$backup_dir"
        return 1
    fi
}

# 验证更新包函数
# 参数1: 更新包路径
# 返回值: 0表示成功，1表示失败
verify_package() {
    local package_path="$1"
    log_message "INFO" "正在验证更新包"
    
    if [ ! -f "$package_path" ]; then
        log_message "ERROR" "未找到包文件"
        return 1
    fi
    
    if ! tar -tzf "$package_path" >/dev/null 2>&1; then
        log_message "ERROR" "无效的包格式"
        return 1
    fi
    
    log_message "INFO" "包验证通过"
    return 0
}

# 主函数
# 参数1: 更新包路径
# 参数2: 配置文件路径
main() {
    local package_path="$1"
    local config_path="$2"
    
    if [ -z "$package_path" ] || [ -z "$config_path" ]; then
        log_message "ERROR" "缺少必要参数"
        exit 1
    fi
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    log_message "INFO" "部署代理已启动"
    
    # 验证更新包
    if verify_package "$package_path"; then
        # 部署更新
        if deploy_update "$package_path" "$config_path"; then
            log_message "INFO" "更新部署成功"
            exit 0
        else
            log_message "ERROR" "更新部署失败"
            exit 1
        fi
    else
        log_message "ERROR" "包验证失败"
        exit 1
    fi
}

# 调用主函数
main "$@"