#!/bin/sh
# Run our monitoring script on startup
# /bin/sh is different on the UDM-Pro and the UDM-SE
# On the UDM-Pro it is the busybox shell interpreter
# On the UDM-SE it is dash BUT full bash is also available
# We want to run in busybox shell on a UDM-Pro and bash on a UDM-SE

if [ -f /bin/bash ]; then
  /bin/bash /mnt/data/change-ppp-mtu/11-change-ppp-mtu.sh &
else
  /bin/sh /mnt/data/change-ppp-mtu/11-change-ppp-mtu.sh &
fi
