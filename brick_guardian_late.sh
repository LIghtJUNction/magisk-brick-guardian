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
DEBUG_LOG=$MODDIR/brick_guardian_early_late.log

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
    log_info "开始禁用模块操作（后期阶段）..."
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
    return "$count"
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

# 更新模块描述
update_module_description() {
    local rescue_count=$1
    log_info "更新模块描述，当前救砖次数: $rescue_count"
    
    local description="自动救砖条件：系统连续重启到3次或卡在开机界面${BOOT_WAIT_TIME}分钟(每次OTA升级系统时将自动延长时间至15分钟)，将禁用所有模块。若再不开机会执行APP解冻救砖模式再开机。模块目录/白名单.conf里可以添加救砖跳过的白名单。GitHub: https://github.com/kirklin/magisk-brick-guardian 已为您自动救砖：${rescue_count}次。"
    
    # 使用临时文件进行原子写入
    local temp_file="${MODULE_INFO}.tmp"
    if ! sed "/^description=/c description=$description" "$MODULE_INFO" > "$temp_file"; then
        log_error "生成新的模块描述失败"
        rm -f "$temp_file"
        return 1
    fi
    
    if ! mv -f "$temp_file" "$MODULE_INFO"; then
        log_error "更新模块描述失败"
        ls -l "$MODULE_INFO" >> $DEBUG_LOG 2>&1
        rm -f "$temp_file"
        return 1
    fi
    
    sync "$MODULE_INFO"
    log_info "模块描述更新成功"
    return 0
}

# 主函数
main() {
    # 创建日志文件
    ensure_log_dir
    log_info "=== Brick Guardian Late Script Started ==="
    log_info "当前目录: $MODDIR"
    ls -l $MODDIR >> $DEBUG_LOG 2>&1
    
    # 恢复模块信息备份
    if [ -f "${MODULE_INFO}.bak" ]; then
        log_info "正在恢复模块信息备份..."
        if mv -f "${MODULE_INFO}.bak" "$MODULE_INFO"; then
            log_info "模块信息备份恢复成功"
            sync "$MODULE_INFO"
        else
            log_error "模块信息备份恢复失败"
            ls -l "${MODULE_INFO}.bak" >> $DEBUG_LOG 2>&1
        fi
    fi
    
    # 等待系统启动
    local BOOT_WAIT_TIME=1.5
    log_info "等待系统启动 ${BOOT_WAIT_TIME} 分钟..."
    sleep "${BOOT_WAIT_TIME}m"
    
    # 检查系统是否成功启动
    local boot_status=$(getprop init.svc.bootanim)
    log_info "系统启动状态: $boot_status"
    
    if [ "$boot_status" = "stopped" ]; then
        # 系统已正常启动
        log_info "系统已正常启动"
        
        if rm -f "$START_LOG"; then
            log_info "已清除启动计数"
            sync
        else
            log_warning "清除启动计数失败"
            ls -l "$START_LOG" >> $DEBUG_LOG 2>&1
        fi
        
        # 更新救砖统计和描述
        if [ -f "$RESCUE_LOG" ]; then
            local rescue_count
            rescue_count=$(safe_read "$RESCUE_LOG" "0")
            if [ $? -eq 0 ]; then
                log_info "读取到救砖统计: $rescue_count"
                update_module_description "$rescue_count"
            else
                log_error "读取救砖统计失败"
            fi
        else
            log_info "未找到救砖统计文件"
            ls -l $MODDIR >> $DEBUG_LOG 2>&1
        fi
        
        # 更新系统版本记录
        local current_version=$(getprop ro.system.build.version.incremental)
        if ! safe_write "$VERSION_FILE" "$current_version"; then
            log_error "更新系统版本记录失败"
        else
            log_info "系统版本记录已更新: $current_version"
        fi
    else
        # 系统未能正常启动
        log_warning "系统未能正常启动，准备执行救砖操作"
        update_rescue_stats
        disable_all_modules
    fi
    
    log_info "=== Late Script execution completed ==="
}

# 执行主函数
main

