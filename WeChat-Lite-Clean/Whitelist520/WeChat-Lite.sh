#!/system/bin/sh
# 独立执行版本：息屏时清理微信多余后台进程
# 用法：sh Whitelist520/WeChat-Lite.sh
#
# 策略（批量处理）：
#   1) 一次性对所有目标进程发送 SIGTERM(-15)
#   2) 统一等待 2 秒
#   3) 检查哪些还活着，统一补 SIGKILL(-9)

##########################################################################
# 1. 检查屏幕状态
##########################################################################
status="$(dumpsys window policy | grep mInputRestricted | cut -d= -f2)"
if [ "$status" != "true" ]; then
  echo "亮屏，不操作"
  exit 0
fi

##########################################################################
# 2. 检查微信是否在前台
#    用 case 替代 [[ ]] 兼容 BusyBox sh
##########################################################################
focused="$(dumpsys activity | grep mFocusedApp)"
case "$focused" in
  *com.tencent.mm*)
    echo "微信在前台，不操作"
    exit 0
    ;;
esac

echo "息屏且微信不在前台，开始清理后台进程……"

##########################################################################
# 3. 找出微信子进程（排除 push 服务）
##########################################################################
pids="$(ps -ef | grep -E 'com\.tencent\.mm$|com\.tencent\.mm:' | \
  grep -v push | grep -v grep | awk '{print $2}')"

if [ -z "$pids" ]; then
  echo "没有需要清理的微信后台进程"
  exit 0
fi

echo "  发现 $pids 个进程"

##########################################################################
# 4. 批量处理：全部 -15 → 等 2 秒 → 查存活 → 补 -9
##########################################################################

# 第一步：全发 SIGTERM
for pid in $pids; do
  echo -n "  SIGTERM(-15): $pid … "
  kill -15 "$pid" 2>/dev/null
  echo "已发送"
done

# 第二步：统一等待
echo "  等待 2 秒让进程自行退出……"
sleep 2

# 第三步：检查存活，补 SIGKILL
survivors=""
for pid in $pids; do
  if kill -0 "$pid" 2>/dev/null; then
    echo "  $pid 还活着，补 SIGKILL(-9)！"
    kill -9 "$pid" 2>/dev/null
    survivors="$survivors $pid"
  else
    echo "  $pid 已退出 ✓"
  fi
done

echo "清理完成"
[ -n "$survivors" ] && echo "  (有 $survivors 个进程是被强制终止的)"