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

# 日志配置
# 日期文件夹：YYYY-MM-DD
LOG_DATE_DIR="$LOG_DIR/$(date +"%Y-%m-%d")"
# 服务启动时间：HHMMSS
START_TIME=$(date +"%H%M%S")
# 日志文件路径：日期文件夹/服务_启动时间.log
DEPLOY_LOG="$LOG_DATE_DIR/deploy-agent_$START_TIME.log"

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
    echo "[$timestamp] [$level] $message" >> "$DEPLOY_LOG"
    echo "[$timestamp] [$level] $message"
}

# 备份当前文件函数
# 参数1: 目标版本号
# 返回值: 备份目录路径
backup_current_files() {
    local target_version="$1"
    # 使用版本号命名备份目录：back_版本_before
    local backup_dir="$TEMP_DIR/back_${target_version}_before"
    
    # 检查备份目录是否已存在
    if [ -d "$backup_dir" ]; then
        log_message "INFO" "版本 $target_version 的备份已存在: $backup_dir，跳过备份"
        echo "$backup_dir"
        return 0
    fi
    
    # 备份目录不存在，创建备份
    log_message "INFO" "正在 $backup_dir 创建备份"
    
    mkdir -p "$backup_dir"
    
    # 如果指定了可执行文件名，仅备份该文件
    if [ -n "$EXECUTABLE_NAME" ] && [ -f "$APP_DIR/$EXECUTABLE_NAME" ]; then
        log_message "INFO" "仅备份可执行文件: $EXECUTABLE_NAME"
        cp "$APP_DIR/$EXECUTABLE_NAME" "$backup_dir/" 2>/dev/null || true
        # 同时备份版本文件
        if [ -f "$APP_DIR/$VERSION_FILE" ]; then
            cp "$APP_DIR/$VERSION_FILE" "$backup_dir/" 2>/dev/null || true
        fi
    else
        # 否则备份整个目录
        log_message "INFO" "备份整个应用目录"
        cp -r "$APP_DIR"/* "$backup_dir/" 2>/dev/null || true
    fi
    
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
        # 如果指定了可执行文件名，仅回滚该文件
        if [ -n "$EXECUTABLE_NAME" ] && [ -f "$backup_dir/$EXECUTABLE_NAME" ]; then
            log_message "INFO" "仅回滚可执行文件: $EXECUTABLE_NAME"
            cp "$backup_dir/$EXECUTABLE_NAME" "$APP_DIR/" 2>/dev/null || true
            # 同时回滚版本文件
            if [ -f "$backup_dir/$VERSION_FILE" ]; then
                cp "$backup_dir/$VERSION_FILE" "$APP_DIR/" 2>/dev/null || true
            fi
        else
            # 否则回滚整个目录
            log_message "INFO" "回滚整个应用目录"
            rm -rf "$APP_DIR"/* 2>/dev/null || true
            cp -r "$backup_dir"/* "$APP_DIR/" 2>/dev/null || true
        fi
        
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
    
    # 从配置文件中获取目标版本
    local target_version=$(grep -o '"version": "[^"]*"' "$config_path" | cut -d '"' -f 4)
    if [ -z "$target_version" ]; then
        # 如果未获取到版本，使用时间戳作为临时版本
        target_version="temp_$(date +"%Y%m%d_%H%M%S")"
        log_message "WARNING" "未从配置文件获取到版本，使用临时版本: $target_version"
    fi
    
    # 创建备份（仅更新前备份一次，使用版本号命名）
    local backup_dir=$(backup_current_files "$target_version")
    
    # 停止服务
    stop_service
    
    # 检查是否为单个可执行文件更新
    if [[ "$package_path" != *.tar.gz ]] && [ "$SUPPORT_SINGLE_EXECUTABLE" = "true" ]; then
        log_message "INFO" "使用单个可执行文件更新模式"
        
        # 获取可执行文件名
        local executable_name="$EXECUTABLE_NAME"
        if [ -z "$executable_name" ]; then
            # 如果配置文件中未指定，使用包名作为可执行文件名
            executable_name=$(basename "$package_path")
            log_message "INFO" "未配置可执行文件名，使用包名: $executable_name"
        fi
        
        # 复制可执行文件到应用目录
        log_message "INFO" "正在复制可执行文件到 $APP_DIR/$executable_name"
        cp "$package_path" "$APP_DIR/$executable_name"
        
        # 设置执行权限
        log_message "INFO" "正在设置可执行权限"
        chmod +x "$APP_DIR/$executable_name"
        
        # 更新version.txt
        log_message "INFO" "正在更新版本文件，版本: $target_version"
        echo "$target_version" > "$APP_DIR/$VERSION_FILE"
    else
        # 原有tar.gz包更新流程
        log_message "INFO" "使用tar.gz包更新模式"
        
        # 创建部署目录
        local deploy_dir="$TEMP_DIR/deploy_${target_version}"
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
        
        # 如果version.txt不存在或内容不同，更新它
        if [ ! -f "$APP_DIR/$VERSION_FILE" ] || [ "$(cat "$APP_DIR/$VERSION_FILE")" != "$target_version" ]; then
            log_message "INFO" "正在更新版本文件，版本: $target_version"
            echo "$target_version" > "$APP_DIR/$VERSION_FILE"
        fi
    fi
    
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
    
    # 检查是否为tar.gz文件
    if [[ "$package_path" == *.tar.gz ]]; then
        # 验证tar.gz格式
        if ! tar -tzf "$package_path" >/dev/null 2>&1; then
            log_message "ERROR" "无效的tar.gz包格式"
            return 1
        fi
    elif [ "$SUPPORT_SINGLE_EXECUTABLE" = "true" ]; then
        # 单个可执行文件，无需解压验证，只需检查是否为文件
        log_message "INFO" "单个可执行文件验证通过"
        return 0
    else
        log_message "ERROR" "不支持的包格式"
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