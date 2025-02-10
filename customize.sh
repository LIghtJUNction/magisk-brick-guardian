##########################################################################################
#
# Magisk 模块安装脚本
# Copyright (C) 2024 Kirk Lin
#
##########################################################################################
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

# 设置权限
set_permissions() {
  ui_print "- 设置基本权限..."
  # 设置基本权限
  set_perm_recursive $MODPATH 0 0 0755 0755
  ui_print "- 设置脚本执行权限..."
  ui_print "- 权限设置完成"
}
print_modname
set_permissions
