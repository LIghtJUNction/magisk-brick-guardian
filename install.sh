##########################################################################################
#
# Magisk 模块安装脚本
# Copyright (C) 2024 Kirk Lin
#
##########################################################################################

# 基础配置
SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true

# 系统文件替换列表
REPLACE="
"

##########################################################################################
# 打印模块信息
print_modname() {
  ui_print "*******************************"
  ui_print "   Magisk Brick Guardian"
  ui_print "   自动防砖 v250117"
  ui_print "   作者：Kirk Lin"
  ui_print "*******************************"
  ui_print " "
  ui_print "当前系统版本：$(getprop ro.system.build.version.incremental)"
  ui_print " "
  ui_print "模块功能："
  ui_print "1. 自动检测并防止模块导致的系统无法启动"
  ui_print "2. 支持智能白名单机制"
  ui_print "3. OTA升级保护"
  ui_print " "
  ui_print "工作机制："
  ui_print "- 连续重启3次或开机界面等待90秒后仍无法启动"
  ui_print "- 系统升级后等待时间延长至15分钟"
  ui_print "- 自动禁用可能导致问题的模块"
  ui_print "- 支持通过白名单保护特定模块"
  ui_print " "
  ui_print "*******************************"
  
  # 记录初始系统版本
  echo $(getprop ro.system.build.version.incremental) > $MODPATH/now_version
}

# 安装文件
on_install() {
  ui_print "- 安装模块文件"
  
  # 解压所有必要文件到根目录
  ui_print "- 解压模块文件..."
  unzip -o "$ZIPFILE" 'brick_guardian_early.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'brick_guardian_late.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'post-fs-data.sh' -d $MODPATH >&2   
  unzip -o "$ZIPFILE" 'service.sh' -d $MODPATH >&2   
  unzip -o "$ZIPFILE" 'action.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'module.prop' -d $MODPATH >&2
  unzip -o "$ZIPFILE" 'uninstall.sh' -d $MODPATH >&2
  unzip -o "$ZIPFILE" '白名单.conf' -d $MODPATH >&2
  
  # 创建module.prop备份
  if [ -f "$MODPATH/module.prop" ]; then
    cp -f "$MODPATH/module.prop" "$MODPATH/module.prop.bak"
  fi
  
  # 验证关键文件是否存在
  ui_print "- 验证文件完整性..."
  local missing_files=0
  for script in brick_guardian_early.sh brick_guardian_late.sh post-fs-data.sh service.sh action.sh module.prop 白名单.conf; do
    if [ ! -f "$MODPATH/$script" ]; then
      ui_print "! 错误：$script 未能成功安装"
      missing_files=1
    else
      ui_print "  √ $script 已安装"
    fi
  done
  
  if [ $missing_files -eq 1 ]; then
    abort "! 安装失败：关键文件缺失"
  fi
  
  ui_print "- 设置文件权限"
}

# 设置权限
set_permissions() {
  ui_print "- 设置基本权限..."
  # 设置基本权限
  set_perm_recursive $MODPATH 0 0 0755 0644
  
  ui_print "- 设置脚本执行权限..."
  # 设置脚本执行权限
  for script in brick_guardian_early.sh brick_guardian_late.sh post-fs-data.sh service.sh action.sh; do
    if [ -f "$MODPATH/$script" ]; then
      set_perm $MODPATH/$script 0 0 0755
      ui_print "  √ $script 权限设置完成"
    else
      ui_print "! 警告：$script 不存在，跳过权限设置"
    fi
  done
  
  ui_print "- 权限设置完成"
}
