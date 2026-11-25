#!/bin/bash
# Collect charge-limit diagnostics without changing the charge limit.
set -u

section() { printf '\n========== %s ==========\n' "$1"; }
run() {
    printf '\n$'; printf ' %q' "$@"; printf '\n'
    "$@" 2>&1 || printf '[命令失败，退出码: %s]\n' "$?"
}

section '基本信息'
run date '+%F %T %Z'
run uname -r
run gnome-shell --version

section '电池与电源状态'
for device in /sys/class/power_supply/*; do
    [ -d "$device" ] || continue
    [ "$(cat "$device/type" 2>/dev/null)" = Battery ] || [ "$(cat "$device/type" 2>/dev/null)" = Mains ] || continue
    printf '\n%s\n' "$device"
    for field in type online capacity status; do
        [ -r "$device/$field" ] && printf '  %s: %s\n' "$field" "$(cat "$device/$field")"
    done
done

section '充电限制固件状态（需要 sudo）'
if [ -x /usr/local/bin/set_charge_limit.sh ]; then
    if [ "$(id -u)" -eq 0 ]; then
        run /usr/local/bin/set_charge_limit.sh status
    elif [ -t 0 ]; then
        run sudo /usr/local/bin/set_charge_limit.sh status
    else
        run sudo -n /usr/local/bin/set_charge_limit.sh status
    fi
else
    printf '未找到已安装的充电限制脚本。\n'
fi

section 'GNOME 扩展（请以桌面用户运行本脚本）'
run gnome-extensions info charge-limit@t0shka.github.io

section 'systemd 服务'
run systemctl is-enabled charge-limit.service
run systemctl is-active charge-limit.service
run systemctl status charge-limit.service --no-pager --full

section '本次启动的服务日志（最多 80 行）'
run journalctl -b -u charge-limit.service -n 80 --no-pager -o short-iso

section '本次启动的插电重新应用日志（最多 80 行）'
run journalctl -b -t charge-limit -n 80 --no-pager -o short-iso

section 'udev 规则与电源设备属性'
if [ -r /etc/udev/rules.d/99-charge-limit.rules ]; then
    run cat /etc/udev/rules.d/99-charge-limit.rules
else
    printf '未找到或无法读取已安装的 udev 规则。\n'
fi
for device in /sys/class/power_supply/*; do
    [ -r "$device/type" ] || continue
    [ "$(cat "$device/type")" = Mains ] || continue
    run udevadm info --query=property --path="$device"
done

section '本次启动的 udev 相关日志（最多 80 行）'
run journalctl -b -u systemd-udevd.service -n 80 --no-pager -o short-iso

section '诊断完成'
printf '请提供完整输出；插电前后分别运行可用于比较。\n'
