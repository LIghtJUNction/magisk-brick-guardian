#!/system/bin/sh
# 这是一个测试用的危险模块，用于测试Magisk Brick Guardian的防护功能
# 警告：请勿在生产环境中使用！

MODDIR=${0%/*}

# 记录模块启动
if [ ! -f "$MODDIR/test.log" ]; then
    echo "Test Brick Module started at $(date)" > "$MODDIR/test.log"
else
    echo "Test Brick Module restarted at $(date)" >> "$MODDIR/test.log"
fi

# 这里不执行任何实际的系统修改操作
# 仅用于测试防砖功能

exit 0 
