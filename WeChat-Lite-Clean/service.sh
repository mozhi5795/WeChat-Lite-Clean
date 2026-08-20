#!/system/bin/sh
MODDIR=${0%/*}

##########################################################################
# Logger —— 所有输出同时写入模块目录下的日志文件，方便排错
##########################################################################
LOGFILE="$MODDIR/clean.log"
logger() {
  local msg="$(date '+%Y-%m-%d %H:%M:%S')  $*"
  echo "$msg"
  echo "$msg" >> "$LOGFILE"
}

# 日志轮转：超过 500 KB 就清空重来
[ -f "$LOGFILE" ] && [ "$(stat -c%s "$LOGFILE" 2>/dev/null || echo 0)" -gt 512000 ] && \
  : > "$LOGFILE"

##########################################################################
# 开机等待
##########################################################################
until [ "$(getprop sys.boot_completed)" -eq 1 ]; do
  sleep 5
done

logger "模块启动，开始监控微信后台……"

##########################################################################
# 后台循环：息屏时清理微信多余后台进程
#
# 策略（批量处理）：
#   1) 一次性对所有目标进程发送 SIGTERM(-15)
#   2) 统一等待 2 秒
#   3) 检查哪些还活着，统一补 SIGKILL(-9)
#
# 说明：
#   - 用 case 替代 [[ ]] 以兼容 BusyBox sh
#   - 只匹配带冒号后缀的子进程，主进程 com.tencent.mm 天然不匹配；
#     再排除 push 服务。保留：主进程 + push | 清理：其他所有子进程
#   - PID 回收重用概率极低（sleep 2 窗口期极短），不额外处理
#   - 如需排查运行情况，查看 $MODDIR/clean.log
##########################################################################
(
while true; do
  sleep 120

  # 检查是否息屏
  status="$(dumpsys window policy | grep mInputRestricted | cut -d= -f2)"
  [ "$status" != "true" ] && continue

  # 检查微信是否在前台
  focused="$(dumpsys activity | grep mFocusedApp)"
  case "$focused" in
    *com.tencent.mm*) continue ;;
  esac

  # 找出微信子进程（只匹配带冒号后缀的，主进程天然不匹配；再排除 push）
  # 保留：主进程 + push | 清理：其他所有子进程
  pids="$(ps -ef | grep -E 'com\.tencent\.mm:' | \
    grep -v push | grep -v grep | awk '{print $2}')"
  [ -z "$pids" ] && continue

  logger "息屏，发现子进程：$(echo $pids | tr '\n' ' ')"

  # 第一步：全部 SIGTERM
  for pid in $pids; do
    kill -15 "$pid" 2>/dev/null
  done
  logger "  SIGTERM 已发送，等待 2 秒……"

  # 第二步：统一等待
  sleep 2

  # 第三步：检查存活，补 SIGKILL
  survivors=""
  for pid in $pids; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null
      survivors="$survivors $pid"
    fi
  done

  if [ -n "$survivors" ]; then
    logger "  存活进程已补 SIGKILL：$survivors"
  else
    logger "  所有进程已正常退出 ✓"
  fi
done
) &