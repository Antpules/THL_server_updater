#!/bin/bash
#
# version-check.sh - 版本检查脚本
# 功能：比较两个版本字符串，判断目标版本是否更新
# 作者：AutoGen
# 版本：1.0.0
#
# 版本号格式：major.minor.patch.build
# 例如：1.0.0.0, 2.1.3.45
#
# 使用方法：
#   ./version-check.sh <当前版本> <目标版本>
#
# 返回值：
#   0 - 目标版本更新
#   1 - 目标版本不更新或版本相同

# 比较版本函数
# 参数1: 当前版本字符串
# 参数2: 目标版本字符串
# 返回值: 0表示目标版本更新，1表示目标版本不更新或版本相同
compare_versions() {
    local current="$1"
    local target="$2"
    
    # 将版本字符串转换为数组
    IFS='.' read -r -a current_parts <<< "$current"
    IFS='.' read -r -a target_parts <<< "$target"
    
    # 确保两个数组都有4个部分（major.minor.patch.build）
    while [ "${#current_parts[@]}" -lt 4 ]; do
        current_parts+=("0")
    done
    
    while [ "${#target_parts[@]}" -lt 4 ]; do
        target_parts+=("0")
    done
    
    # 逐部分比较版本号
    for i in 0 1 2 3; do
        local current_val="${current_parts[$i]}"
        local target_val="${target_parts[$i]}"
        
        if [ "$target_val" -gt "$current_val" ]; then
            return 0  # 目标版本更新
        elif [ "$target_val" -lt "$current_val" ]; then
            return 1  # 目标版本更旧
        fi
    done
    
    return 1  # 版本相同
}

# 主函数
if [ $# -ne 2 ]; then
    echo "Usage: $0 <current_version> <target_version>"
    exit 1
fi

current_version="$1"
target_version="$2"

# 调用比较函数并返回结果
compare_versions "$current_version" "$target_version"
exit $?