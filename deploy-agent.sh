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
    echo "[$timestamp] [$level] $message" >> "$DEPLOY_LOG"
    echo "[$timestamp] [$level] $message"
}

# 备份当前文件函数
# 返回值: 备份目录路径
backup_current_files() {
    local backup_dir="$TEMP_DIR/backup_$(date +"%Y%m%d_%H%M%S")"
    log_message "INFO" "Creating backup in $backup_dir"
    
    mkdir -p "$backup_dir"
    cp -r "$APP_DIR"/* "$backup_dir/" 2>/dev/null || true
    
    echo "$backup_dir"
}

# 停止服务函数
stop_service() {
    log_message "INFO" "Stopping service: $SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        log_message "INFO" "Service stopped successfully"
    else
        log_message "INFO" "Service is not running"
    fi
}

# 启动服务函数
# 返回值: 0表示成功，1表示失败
start_service() {
    log_message "INFO" "Starting service: $SERVICE_NAME"
    
    systemctl start "$SERVICE_NAME"
    
    sleep 5  # 等待服务启动
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_message "INFO" "Service started successfully"
        return 0
    else
        log_message "ERROR" "Failed to start service"
        return 1
    fi
}

# 回滚函数
# 参数1: 备份目录路径
rollback() {
    local backup_dir="$1"
    log_message "ERROR" "Rolling back to backup: $backup_dir"
    
    if [ -d "$backup_dir" ]; then
        rm -rf "$APP_DIR"/* 2>/dev/null || true
        cp -r "$backup_dir"/* "$APP_DIR/" 2>/dev/null || true
        
        start_service
        log_message "INFO" "Rollback completed"
    else
        log_message "ERROR" "Backup directory not found, cannot rollback"
    fi
}

# 部署更新函数
# 参数1: 更新包路径
# 参数2: 配置文件路径
# 返回值: 0表示成功，1表示失败
deploy_update() {
    local package_path="$1"
    local config_path="$2"
    
    log_message "INFO" "Starting deployment of $package_path"
    
    # 创建备份
    local backup_dir=$(backup_current_files)
    
    # 停止服务
    stop_service
    
    # 创建部署目录
    local deploy_dir="$TEMP_DIR/deploy_$(date +"%Y%m%d_%H%M%S")"
    mkdir -p "$deploy_dir"
    
    # 解压更新包
    log_message "INFO" "Extracting update package"
    tar -xzf "$package_path" -C "$deploy_dir"
    
    # 部署文件
    log_message "INFO" "Deploying files to $APP_DIR"
    rm -rf "$APP_DIR"/* 2>/dev/null || true
    cp -r "$deploy_dir"/* "$APP_DIR/"
    
    # 设置权限
    log_message "INFO" "Setting permissions"
    chmod +x "$APP_DIR"/*.sh 2>/dev/null || true
    chmod +x "$APP_DIR"/*.bin 2>/dev/null || true
    
    # 启动服务并验证
    if start_service; then
        log_message "INFO" "Deployment completed successfully"
        rm -rf "$backup_dir" 2>/dev/null || true  # 清理备份
        return 0
    else
        log_message "ERROR" "Deployment failed, initiating rollback"
        rollback "$backup_dir"
        return 1
    fi
}

# 验证更新包函数
# 参数1: 更新包路径
# 返回值: 0表示成功，1表示失败
verify_package() {
    local package_path="$1"
    log_message "INFO" "Verifying update package"
    
    if [ ! -f "$package_path" ]; then
        log_message "ERROR" "Package file not found"
        return 1
    fi
    
    if ! tar -tzf "$package_path" >/dev/null 2>&1; then
        log_message "ERROR" "Invalid package format"
        return 1
    fi
    
    log_message "INFO" "Package verification passed"
    return 0
}

# 主函数
# 参数1: 更新包路径
# 参数2: 配置文件路径
main() {
    local package_path="$1"
    local config_path="$2"
    
    if [ -z "$package_path" ] || [ -z "$config_path" ]; then
        log_message "ERROR" "Missing required arguments"
        exit 1
    fi
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    log_message "INFO" "Deploy agent started"
    
    # 验证更新包
    if verify_package "$package_path"; then
        # 部署更新
        if deploy_update "$package_path" "$config_path"; then
            log_message "INFO" "Update deployment successful"
            exit 0
        else
            log_message "ERROR" "Update deployment failed"
            exit 1
        fi
    else
        log_message "ERROR" "Package verification failed"
        exit 1
    fi
}

# 调用主函数
main "$@"