#!/usr/bin/env sh
curl -fsL "https://raw.githubusercontent.com/unifi-utilities/unifios-utilities/HEAD/on-boot-script/remote_install.sh" | /bin/sh
cp 10-monitor-ppp-mtu.sh /data/on_boot.d/
chmod +x /data/on_boot.d/10-monitor-ppp-mtu.sh
mkdir -p /data/change-ppp-mtu
cp 11-change-ppp-mtu.sh /data/change-ppp-mtu/
chmod +x /data/change-ppp-mtu/11-change-ppp-mtu.sh
