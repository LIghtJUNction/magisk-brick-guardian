#!/system/bin/sh
# Copyright (C) 2024 Kirk Lin
# 
# Magisk Brick Guardian 卸载脚本
# Version: 250117

# 清理模块文件
cleanup_module() {
    local module_path="/data/adb/modules/magisk-brick-guardian"
    
    # 删除模块目录
    if [ -d "$module_path" ]; then
        rm -rf "$module_path"
    fi
}

# 执行清理
cleanup_module


