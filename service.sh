#!/system/bin/sh
MODDIR=${0%/*}

(
until [ $(getprop sys.boot_completed) -eq 1 ] ; do
  sleep 5
done
export PATH="/system/bin:/system/xbin:/vendor/bin:$(magisk --path)/.magisk/busybox:$PATH"
crond -c $MODDIR/cron

#777权限
chmod 777 /data/adb/modules/WeChat-Lite-LING/Whitelist520/*
rm -rf /data/adb/modules/WeChat-Lite-LING/update
)