#!/system/bin/sh
# Copyright (C) 2024 Kirk Lin
# 
# This module is part of Magisk Brick Guardian
# Version: 250117

# 设置完整的PATH
export PATH="/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/system_ext/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin:/data/user/0/com.gjzs.chongzhi.online/files/usr/busybox:/dev/P5TeaG/.magisk/busybox"

# 模块基础配置
MODDIR=${0%/*}
MODID=${MODDIR##*/}
MODULE_INFO=$MODDIR/module.prop
START_LOG=$MODDIR/startup_count.log
RESCUE_LOG=$MODDIR/rescue_count.log
VERSION_FILE=$MODDIR/now_version
WHITELIST_FILE=$MODDIR/白名单.conf
DEBUG_LOG=$MODDIR/brick_guardian_early_debug.log

# 确保日志目录存在
ensure_log_dir() {
    local log_dir=$(dirname $DEBUG_LOG)
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        chmod 755 "$log_dir"
    fi
}

# 日志函数
log_debug() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $1" >> $DEBUG_LOG
}

log_info() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> $DEBUG_LOG
}

log_warning() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> $DEBUG_LOG
}

log_error() {
    ensure_log_dir
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> $DEBUG_LOG
}

# 安全的文件写入函数
safe_write() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp"
    
    # 确保目标目录存在
    mkdir -p "$(dirname "$file")" 2>/dev/null
    
    # 写入临时文件
    echo "$content" > "$temp_file"
    if [ $? -ne 0 ]; then
        log_error "写入临时文件失败: $temp_file"
        rm -f "$temp_file"
        return 1
    fi
    
    # 设置正确的权限
    chmod 644 "$temp_file"
    sync "$temp_file"
    
    # 移动到目标位置
    if ! mv -f "$temp_file" "$file"; then
        log_error "移动文件失败: $temp_file -> $file"
        rm -f "$temp_file"
        return 1
    fi
    
    sync "$file"
    return 0
}

# 安全的文件读取函数
safe_read() {
    local file="$1"
    local default="$2"
    local content
    
    # 检查文件是否存在且可读
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        echo "$default"
        return 0
    fi
    
    # 读取文件内容
    content=$(cat "$file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "读取文件失败: $file"
        echo "$default"
        return 1
    fi
    
    # 验证内容是否为数字
    if ! echo "$content" | grep -q '^[0-9][0-9]*$'; then
        log_error "文件内容无效: $file (content: $content)"
        echo "$default"
        return 1
    fi
    
    echo "$content"
    return 0
}

# 禁用所有模块（除白名单外）
disable_all_modules() {
    log_info "开始禁用模块操作..."
    local module
    local disabled_count=0
    local success=true
    
    # 检查modules目录是否存在
    if [ ! -d "/data/adb/modules" ]; then
        log_error "modules目录不存在"
        ls -l /data/adb >> $DEBUG_LOG 2>&1
        return 1
    fi
    
    ls "/data/adb/modules" | while read module; do
        # 跳过当前模块
        if [ "$module" = "$MODID" ]; then
            log_debug "跳过当前模块: $module"
            continue
        fi
        
        # 禁用模块
        if touch "/data/adb/modules/$module/disable" 2>/dev/null; then
            log_info "已禁用模块: $module"
            disabled_count=$((disabled_count + 1))
        else
            log_error "无法禁用模块: $module"
            ls -l "/data/adb/modules/$module" >> $DEBUG_LOG 2>&1
            success=false
        fi
    done
    
    log_info "模块禁用操作完成，共禁用 $disabled_count 个模块"
    
    # 处理白名单
    if ! handle_whitelist; then
        success=false
    fi
    
    sync
    if [ "$success" = true ]; then
        log_info "准备重启系统..."
        reboot
    else
        log_error "模块禁用过程中出现错误，尝试强制重启..."
        reboot -f
    fi
}

# 更新救砖统计
update_rescue_stats() {
    log_info "更新救砖统计..."
    local count=1
    
    # 安全读取当前计数
    if [ -f "$RESCUE_LOG" ]; then
        count=$(safe_read "$RESCUE_LOG" "0")
        count=$((count + 1))
    fi
    
    # 安全写入新计数
    if ! safe_write "$RESCUE_LOG" "$count"; then
        log_error "更新救砖统计失败"
        return 1
    fi
    
    log_info "当前救砖次数: $count"
    return 0
}

# 处理白名单
handle_whitelist() {
    log_info "开始处理白名单..."
    if [ ! -f "$WHITELIST_FILE" ]; then
        log_warning "白名单文件不存在"
        ls -l $MODDIR >> $DEBUG_LOG 2>&1
        return 0
    fi
    
    # 读取并处理白名单
    local enabled_count=0
    local success=true
    local module
    
    # 使用临时文件存储处理后的白名单
    local temp_whitelist="${WHITELIST_FILE}.tmp"
    if ! sed '/^[[:space:]]*$/d;/^#/d' "$WHITELIST_FILE" > "$temp_whitelist"; then
        log_error "处理白名单文件失败"
        rm -f "$temp_whitelist"
        return 1
    fi
    
    while read module; do
        if [ -d "/data/adb/modules/$module" ]; then
            if rm -f "/data/adb/modules/$module/disable" 2>/dev/null; then
                log_info "已启用白名单模块: $module"
                enabled_count=$((enabled_count + 1))
            else
                log_error "无法启用白名单模块: $module"
                ls -l "/data/adb/modules/$module" >> $DEBUG_LOG 2>&1
                success=false
            fi
        else
            log_warning "白名单模块不存在: $module"
        fi
    done < "$temp_whitelist"
    
    rm -f "$temp_whitelist"
    log_info "白名单处理完成，共启用 $enabled_count 个模块"
    return $success
}

# 解冻应用
unfreeze_apps() {
    log_info "开始解冻应用..."
    
    # 检测是否在Android环境
    if ps | grep zygote | grep -qv grep || ps -A 2>/dev/null | grep zygote | grep -qv grep; then
        BOOTMODE=true
        log_info "检测到Android环境"
    else
        BOOTMODE=false
        log_warning "未检测到Android环境"
    fi
    
    # 检查文件是否存在
    if [ ! -f "/data/system/users/0/package-restrictions.xml" ]; then
        log_info "应用限制文件不存在，无需解冻"
        return 0
    fi
    
    # 删除应用限制文件
    if rm -f /data/system/users/0/package-restrictions.xml; then
        log_info "成功删除应用限制文件"
        sync
    else
        log_error "删除应用限制文件失败"
        ls -l /data/system/users/0 >> $DEBUG_LOG 2>&1
        return 1
    fi
    
    log_info "应用解冻完成"
    return 0
}

# 主函数
main() {
    # 创建日志文件
    ensure_log_dir
    log_info "=== Brick Guardian Early Script Started ==="
    log_info "当前目录: $MODDIR"
    ls -l $MODDIR >> $DEBUG_LOG 2>&1
    
    # 检查启动次数
    local BOOT_COUNT=1
    
    # 安全读取启动次数
    if [ -f "$START_LOG" ]; then
        BOOT_COUNT=$(safe_read "$START_LOG" "0")
        BOOT_COUNT=$((BOOT_COUNT + 1))
    fi
    
    # 安全写入新的启动次数
    if ! safe_write "$START_LOG" "$BOOT_COUNT"; then
        log_error "更新启动次数失败"
        BOOT_COUNT=1
    fi
    
    log_info "当前启动次数: $BOOT_COUNT"
    
    # 根据启动次数执行不同操作
    case $BOOT_COUNT in
        2)
            log_warning "第二次启动：准备禁用所有模块"
            chmod 000 /data/adb/service.d/* /data/adb/post-fs-data.d/* 2>/dev/null
            update_rescue_stats
            disable_all_modules
            ;;
        4)
            log_warning "第四次启动：准备解冻所有应用"
            rm -f "$START_LOG"
            sync
            update_rescue_stats
            if unfreeze_apps; then
                log_info "准备重启系统..."
                reboot
            else
                log_error "解冻失败，尝试强制重启..."
                reboot -f
            fi
            ;;
        *)
            log_info "正常启动，无需特殊处理"
            ;;
    esac
    
    log_info "=== Early Script execution completed ==="
}

# 执行主函数
main
