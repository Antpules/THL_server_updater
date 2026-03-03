#!/bin/bash
#
# install.sh - 安装脚本
# 功能：安装启动脚本并配置服务
# 作者：RUAN
# 版本：1.0.0
#

# 设置脚本在遇到错误时退出
set -e

# 定义常量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/update"
SERVICE_FILE="${SCRIPT_DIR}/update-manager.service"
TARGET_SERVICE_FILE="/etc/systemd/system/update-manager.service"

# 日志颜色
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "脚本必须以root权限运行"
        exit 1
    fi
}

# 创建安装目录
create_install_dir() {
    if [ ! -d "${INSTALL_DIR}" ]; then
        log_info "创建安装目录: ${INSTALL_DIR}"
        mkdir -p "${INSTALL_DIR}"
    else
        log_info "安装目录已存在: ${INSTALL_DIR}"
    fi
}

# 复制文件
copy_files() {
    log_info "复制文件到安装目录"
    
    # 复制主要脚本
    cp -f "${SCRIPT_DIR}/update-manager.sh" "${INSTALL_DIR}/"
    cp -f "${SCRIPT_DIR}/deploy-agent.sh" "${INSTALL_DIR}/"
    
    # 复制服务文件
    cp -f "${SCRIPT_DIR}/update-manager.service" "${INSTALL_DIR}/"
    
    # 复制websocket_server.service（如果存在）
    if [ -f "${SCRIPT_DIR}/websocket_server.service" ]; then
        cp -f "${SCRIPT_DIR}/websocket_server.service" "${INSTALL_DIR}/"
    fi
    
    # 复制配置文件
    if [ -d "${SCRIPT_DIR}/config" ]; then
        mkdir -p "${INSTALL_DIR}/config"
        cp -rf "${SCRIPT_DIR}/config/"* "${INSTALL_DIR}/config/"
    fi
    
    # 复制脚本目录
    if [ -d "${SCRIPT_DIR}/scripts" ]; then
        mkdir -p "${INSTALL_DIR}/scripts"
        cp -rf "${SCRIPT_DIR}/scripts/"* "${INSTALL_DIR}/scripts/"
    fi
    
    # 复制文档
    if [ -f "${SCRIPT_DIR}/README.md" ]; then
        cp -f "${SCRIPT_DIR}/README.md" "${INSTALL_DIR}/"
    fi
    
    if [ -f "${SCRIPT_DIR}/USAGE.md" ]; then
        cp -f "${SCRIPT_DIR}/USAGE.md" "${INSTALL_DIR}/"
    fi
    
    # 创建必要的目录
    mkdir -p "${INSTALL_DIR}/logs"
    mkdir -p "${INSTALL_DIR}/temp"
    
    log_info "文件复制完成"
}

# 设置权限
set_permissions() {
    log_info "设置执行权限"
    chmod -R 777 "${INSTALL_DIR}"
    log_info "权限设置完成"
}

# 配置服务
configure_service() {
    log_info "配置系统服务"
    
    # 复制服务文件到systemd目录
    cp -f "${SERVICE_FILE}" "${TARGET_SERVICE_FILE}"
    
    # 复制websocket_server.service到systemd目录（如果存在）
    if [ -f "${SCRIPT_DIR}/websocket_server.service" ]; then
        log_info "复制websocket_server.service到systemd目录"
        cp -f "${SCRIPT_DIR}/websocket_server.service" "/etc/systemd/system/"
        
        # 给予可执行权限
        chmod +x "/etc/systemd/system/websocket_server.service"
    fi
    
    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable update-manager
    
    log_info "服务配置完成"
}

# 安装依赖
install_dependencies() {
    log_info "安装必要的依赖"
    
    # 检查inotify-tools是否已安装
    if ! command -v inotifywait &> /dev/null; then
        log_info "安装inotify-tools..."
        
        # 检测系统类型并使用相应的包管理器
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            apt-get update && apt-get install -y inotify-tools
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL
            yum install -y inotify-tools
        elif command -v dnf &> /dev/null; then
            # Fedora
            dnf install -y inotify-tools
        elif command -v zypper &> /dev/null; then
            # SUSE
            zypper install -y inotify-tools
        else
            log_warning "无法自动安装inotify-tools，请手动安装"
            log_warning "安装命令示例:"
            log_warning "  Debian/Ubuntu: apt-get install inotify-tools"
            log_warning "  CentOS/RHEL: yum install inotify-tools"
        fi
    else
        log_info "inotify-tools已安装"
    fi
}

# 启动服务
start_service() {
    log_info "启动update-manager服务"
    
    # 检查服务是否正在运行
    if systemctl is-active --quiet update-manager; then
        log_info "服务已在运行，重启服务..."
        systemctl restart update-manager
    else
        log_info "启动服务..."
        systemctl start update-manager
    fi
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet update-manager; then
        log_info "服务启动成功"
    else
        log_error "服务启动失败，请检查日志"
        log_info "查看服务日志: journalctl -u update-manager"
    fi
}

# 验证安装
verify_installation() {
    log_info "验证安装结果"
    
    # 检查关键文件是否存在
    local missing_files=()
    
    if [ ! -f "${INSTALL_DIR}/update-manager.sh" ]; then
        missing_files+=("${INSTALL_DIR}/update-manager.sh")
    fi
    
    if [ ! -f "${INSTALL_DIR}/deploy-agent.sh" ]; then
        missing_files+=("${INSTALL_DIR}/deploy-agent.sh")
    fi
    
    if [ ! -f "${TARGET_SERVICE_FILE}" ]; then
        missing_files+=("${TARGET_SERVICE_FILE}")
    fi
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_info "安装验证通过，所有关键文件都已存在"
        return 0
    else
        log_error "安装验证失败，缺少以下文件:"
        for file in "${missing_files[@]}"; do
            log_error "  - $file"
        done
        return 1
    fi
}

# 显示安装完成信息
show_completion_info() {
    log_info ""
    log_info "================================"
    log_info "安装完成！"
    log_info "================================"
    log_info ""
    log_info "安装目录: ${INSTALL_DIR}"
    log_info "配置文件: ${INSTALL_DIR}/config/update.conf"
    log_info "日志目录: ${INSTALL_DIR}/logs/"
    log_info ""
    log_info "服务状态:"
    systemctl status update-manager --no-pager
    log_info ""
    log_info "使用说明:"
    log_info "1. 编辑配置文件: vim ${INSTALL_DIR}/config/update.conf"
    log_info "2. 查看日志: tail -f ${INSTALL_DIR}/logs/$(date +"%Y-%m-%d")/update-manager_*.log"
    log_info "3. 手动触发更新: ${INSTALL_DIR}/update-manager.sh"
    log_info ""
    log_info "详细使用说明请查看: ${INSTALL_DIR}/USAGE.md"
    log_info ""
}

# 主函数
main() {
    log_info "开始安装Linux下位机服务端程序自动更新系统"
    
    # 检查权限
    check_root
    
    # 创建安装目录
    create_install_dir
    
    # 复制文件
    copy_files
    
    # 设置权限
    set_permissions
    
    # 配置服务
    configure_service
    
    # 安装依赖
    install_dependencies
    
    # 启动服务
    start_service
    
    # 验证安装
    verify_installation
    
    # 显示完成信息
    show_completion_info
    
    log_info "安装过程已完成"
}

# 执行主函数
main