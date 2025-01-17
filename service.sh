#!/system/bin/sh
# Copyright (C) 2024 Kirk Lin
# 
# This module is part of Magisk Brick Guardian
# Version: 250117

# 模块基础配置
MODDIR=${0%/*}

# 设置完整的PATH
export PATH="/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/system_ext/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin:/data/user/0/com.gjzs.chongzhi.online/files/usr/busybox:/dev/P5TeaG/.magisk/busybox"

# 配置文件路径
VERSION_FILE=$MODDIR/now_version
RESCUE_SCRIPT=$MODDIR/brick_guardian_late.sh
LOG_FILE=$MODDIR/brick_guardian.log

# OTA升级后等待时间（分钟）
OTA_WAIT_TIME=15

# 确保日志目录存在
ensure_log_dir() {
    local log_dir=$(dirname $LOG_FILE)
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        chmod 755 "$log_dir"
    fi
}

# 日志函数
log_info() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> $LOG_FILE
}

log_warning() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> $LOG_FILE
}

log_error() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> $LOG_FILE
}

# 检查文件权限和存在性
check_script() {
    local script=$1
    log_info "检查脚本: $script"
    
    if [ ! -f "$script" ]; then
        log_error "脚本文件不存在: $script"
        ls -l $(dirname "$script") >> $LOG_FILE 2>&1
        return 1
    fi
    
    if [ ! -x "$script" ]; then
        log_warning "脚本没有执行权限，尝试添加权限: $script"
        chmod 755 "$script"
        if [ ! -x "$script" ]; then
            log_error "无法设置脚本执行权限: $script"
            ls -l "$script" >> $LOG_FILE 2>&1
            return 1
        fi
        log_info "成功添加脚本执行权限: $script"
    fi
    
    # 检查文件内容
    if [ ! -s "$script" ]; then
        log_error "脚本文件为空: $script"
        return 1
    fi
    
    log_info "脚本检查通过: $script"
    ls -l "$script" >> $LOG_FILE 2>&1
    return 0
}

# 检查系统版本变化
check_system_version() {
    local prev_version
    local curr_version
    
    if [ ! -f "$VERSION_FILE" ]; then
        log_warning "版本文件不存在，可能是首次运行"
        return 1
    fi
    
    prev_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    curr_version=$(getprop ro.system.build.version.incremental)
    
    log_info "Previous system version: $prev_version"
    log_info "Current system version: $curr_version"
    
    # 如果版本不同，说明进行了OTA升级
    if [ "$prev_version" != "$curr_version" ]; then
        log_warning "检测到系统升级，等待 $OTA_WAIT_TIME 分钟..."
        sleep "${OTA_WAIT_TIME}m"
        log_info "OTA等待期结束"
        return 0
    fi
    return 1
}

# 记录系统信息
log_system_info() {
    log_info "=== System Information ==="
    log_info "Android version: $(getprop ro.build.version.release)"
    log_info "SDK version: $(getprop ro.build.version.sdk)"
    log_info "Device: $(getprop ro.product.model)"
    log_info "Magisk version: $(magisk -v 2>/dev/null || echo 'unknown')"
    log_info "Module path: $MODDIR"
    log_info "Rescue script path: $RESCUE_SCRIPT"
    ls -l $MODDIR >> $LOG_FILE 2>&1
    log_info "========================="
}

# 主函数
main() {
    # 创建日志文件
    ensure_log_dir
    log_info "=== Brick Guardian Service Started ==="
    log_info "当前目录: $MODDIR"
    ls -l $MODDIR >> $LOG_FILE 2>&1
    log_system_info
    
    # 检查救砖脚本
    if ! check_script "$RESCUE_SCRIPT"; then
        log_error "救砖脚本检查失败，尝试重新安装模块"
        exit 1
    fi
    
    log_info "检查系统版本..."
    if check_system_version; then
        log_info "系统版本检查完成，继续执行..."
    fi
    
    log_info "执行救砖脚本..."
    if /system/bin/sh "$RESCUE_SCRIPT" 2>> $LOG_FILE; then
        log_info "救砖脚本执行成功"
    else
        log_error "救砖脚本执行失败，错误代码: $?"
        # 记录更多调试信息
        log_error "当前目录: $(pwd)"
        log_error "脚本内容:"
        cat "$RESCUE_SCRIPT" >> $LOG_FILE 2>&1
        exit 1
    fi
    
    log_info "=== Service execution completed ==="
}

# 执行主函数
main

