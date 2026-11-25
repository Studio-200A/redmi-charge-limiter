# 充电限制部署说明

本方案通过 `acpi_call` 调用固件，将充电限制设为 80%。以下命令在仓库目录执行，适用于已安装并加载 `acpi_call` 的系统。

```bash
cd /home/shawnzhang/Projects/redmi-charge-limiter
lsmod | grep '^acpi_call'
ls -l /proc/acpi/call
```

## 组件与部署

### 1. 充电限制脚本

`set_charge_limit.sh` 负责启用、关闭和读取固件中的限制状态。

```bash
sudo install -m 755 set_charge_limit.sh /usr/local/bin/set_charge_limit.sh
```

### 2. systemd 服务

`charge-limit.service` 在开机时启用限制；停止服务时关闭限制。服务为 `oneshot`，运行完成后显示 `active (exited)` 是正常现象。

```bash
sudo install -m 644 charge-limit.service /etc/systemd/system/charge-limit.service
sudo systemctl daemon-reload
sudo systemctl enable --now charge-limit.service
```

### 3. udev 规则

`charge-limit-ac.rules` 在检测到交流电源在线事件且服务处于 active 状态时，重新执行关闭、开启限制的操作。

```bash
sudo install -m 644 charge-limit-ac.rules /etc/udev/rules.d/99-charge-limit.rules
sudo udevadm control --reload
```

### 4. GNOME 扩展和 polkit 规则

扩展在快速设置中提供开关，通过 systemd 服务控制限制。安装脚本同时安装 polkit 规则并重新部署服务文件；当前规则允许本地活跃会话中的 `wheel` 或 `sudo` 组用户免密码操作该服务。

```bash
./gnome-extension/install.sh
```

注销并重新登录 GNOME 后启用扩展：

```bash
gnome-extensions enable charge-limit@t0shka.github.io
```

## 状态检查

```bash
sudo /usr/local/bin/set_charge_limit.sh status
systemctl status charge-limit.service --no-pager
journalctl -b -t charge-limit --no-pager
./check-charge-limit.sh
```

`status` 输出中的 `null 字节`警告来自 `acpi_call` 返回的数据格式。`charge-limit` 日志用于查看插电后重新应用的记录；扩展开关显示的是服务状态，不直接读取固件。

本机已验证基本开关、开机服务和 GNOME 51 扩展加载。长时间离电后插电的行为仍需实际测试。
