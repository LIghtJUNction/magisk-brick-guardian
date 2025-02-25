#!/system/bin/sh
# Copyright (C) 2024 Kirk Lin
# 
# This module is part of Magisk Brick Guardian
# Version: 250117

# 设置完整的PATH
export PATH="/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/system_ext/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin:/data/user/0/com.gjzs.chongzhi.online/files/usr/busybox:/dev/P5TeaG/.magisk/busybox"

# 模块基础配置
MODDIR=${0%/*}
START_LOG=$MODDIR/startup_count.log
RESCUE_SCRIPT=$MODDIR/brick_guardian_early.sh
DEBUG_LOG=$MODDIR/post_fs_data.log

# 确保日志目录存在
ensure_log_dir() {
    local log_dir=$(dirname $DEBUG_LOG)
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        chmod 755 "$log_dir"
    fi
}

# 日志函数
log_info() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> $DEBUG_LOG
}

log_error() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> $DEBUG_LOG
}

# 检查文件权限和存在性
check_script() {
    local script=$1
    log_info "检查脚本: $script"
    
    if [ ! -f "$script" ]; then
        log_error "脚本文件不存在: $script"
        ls -l $(dirname "$script") >> $DEBUG_LOG 2>&1
        return 1
    fi
    
    if [ ! -x "$script" ]; then
        log_info "尝试设置脚本执行权限: $script"
        chmod 755 "$script"
        if [ ! -x "$script" ]; then
            log_error "无法设置脚本执行权限: $script"
            ls -l "$script" >> $DEBUG_LOG 2>&1
            return 1
        fi
    fi
    
    # 检查文件内容
    if [ ! -s "$script" ]; then
        log_error "脚本文件为空: $script"
        return 1
    fi
    
    log_info "脚本权限和内容检查通过: $script"
    ls -l "$script" >> $DEBUG_LOG 2>&1
    return 0
}

# 处理modules_update目录
handle_modules_update() {
    if [ -d "/data/adb/modules_update" ]; then
        log_info "检测到modules_update目录，准备备份..."
        if mv -f /data/adb/modules_update /data/adb/modules_update.bak; then
            log_info "modules_update目录备份成功"
            sync
            return 0
        else
            log_error "modules_update目录备份失败"
            ls -l /data/adb >> $DEBUG_LOG 2>&1
            return 1
        fi
    fi
    return 0
}

# 处理modules_update.bak目录
handle_modules_update_bak() {
    if [ -d "/data/adb/modules_update.bak" ]; then
        log_info "检测到modules_update.bak目录，准备处理..."
        
        # 检查modules目录是否存在
        if [ ! -d "/data/adb/modules" ]; then
            log_info "创建modules目录..."
            mkdir -p /data/adb/modules
            chmod 755 /data/adb/modules
        fi
        
        # 处理备份目录中的模块
        for module_dir in /data/adb/modules_update.bak/*; do
            if [ -d "$module_dir" ]; then
                module_name=$(basename "$module_dir")
                log_info "处理模块: $module_name"
                
                # 如果模块已存在，先删除旧版本
                if [ -d "/data/adb/modules/$module_name" ]; then
                    log_info "删除旧版本模块: $module_name"
                    rm -rf "/data/adb/modules/$module_name"
                fi
                
                # 移动新版本模块
                if mv -f "$module_dir" "/data/adb/modules/"; then
                    log_info "模块 $module_name 更新成功"
                else
                    log_error "模块 $module_name 更新失败"
                fi
            fi
        done
        
        # 删除备份目录
        log_info "删除modules_update.bak目录..."
        rm -rf /data/adb/modules_update.bak
        sync
        
        # 返回1表示需要重启
        return 1
    fi
    
    # 返回0表示不需要重启
    return 0
}

# 确保modules目录存在
ensure_modules_dir() {
    if [ ! -d "/data/adb/modules" ]; then
        log_info "创建modules目录..."
        if mkdir -p /data/adb/modules && chmod 755 /data/adb/modules; then
            log_info "modules目录创建成功"
            return 0
        else
            log_error "modules目录创建失败"
            ls -l /data/adb >> $DEBUG_LOG 2>&1
            return 1
        fi
    fi
    return 0
}

# 主函数
main() {
    # 创建日志文件
    ensure_log_dir
    log_info "=== Brick Guardian Post-fs-data Started ==="
    log_info "当前目录: $MODDIR"
    ls -l $MODDIR >> $DEBUG_LOG 2>&1
    
    # 处理modules_update目录
    if handle_modules_update; then
        log_info "modules_update处理完成"
    else
        log_error "modules_update处理失败"
    fi
    
    # 处理modules_update.bak目录
    if handle_modules_update_bak; then
        log_info "modules_update.bak处理完成，无需重启"
    else
        log_info "modules_update.bak处理完成，准备重启..."
        sync
        reboot
        exit 0
    fi

    # 确保modules目录存在
    if ! ensure_modules_dir; then
        log_error "无法确保modules目录存在，退出"
        exit 1
    fi

    # 检查并执行救砖脚本
    if check_script "$RESCUE_SCRIPT"; then
        log_info "执行早期救砖脚本..."
        if ! /system/bin/sh "$RESCUE_SCRIPT" 2>> $DEBUG_LOG; then
            log_error "救砖脚本执行失败"
            log_error "脚本内容:"
            cat "$RESCUE_SCRIPT" >> $DEBUG_LOG 2>&1
            exit 1
        fi
    else
        log_error "救砖脚本检查失败"
        exit 1
    fi
    
    log_info "=== Post-fs-data execution completed ==="
}

# 执行主函数
main

