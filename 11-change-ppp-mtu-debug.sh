#!/bin/sh
# Which PPP interfaces to monitor?
# You can list multiple interfaces like this
# MINTERFACES="(ppp0|ppp1|ppp10)"
MINTERFACES="(ppp0)"
# Desired MTU of PPP interfaces
PTARGET=1500
SET_MSS=FALSE

runningmtu=0
restartpppd=0
emtucorrect=0
pmtucorrect=0

function check_mtu {
    ip link list | grep -E $MINTERFACES | grep 'mtu '$PTARGET > /dev/null
}

while true; do
    if check_mtu; then
      echo "PPP MTU is configured at "$PTARGET
    else
      # An interface has the wrong MTU, or doesnt exist/isnt up! To the batcave...
      echo "Checking interfaces as no correctly configured PPP interface exists"
      # Start by getting all ppp interfaces configured in the system
      pinterfaces=$(ls /etc/ppp/peers/)
      for pinterface in $pinterfaces
      do
        # Check to see if this is an interface we should be monitoring for MTU
        if [[ $pinterface =~ $MINTERFACES ]]; then
          echo $pinterface is one we should be checking
          # Check to see if we need to update the config file
          echo Checking MTU for $pinterface
          pmtu=$(grep $(($PTARGET-8)) /etc/ppp/peers/$pinterface)
          if [[ $pmtu ]]; then
            echo Current config file MTU for $pinterface is $pmtu
            echo Updating config file for $pinterface
            echo Making changes to /etc/ppp/peers/$pinterface
            # Update MTU in ppp interface config file
            sed -i 's/ '$(($PTARGET-8))'/ '$PTARGET'/g' /etc/ppp/peers/$pinterface
            killall -SIGHUP pppd
          else
            echo MTU already correct in /etc/ppp/peers/$pinterface
            pmtucorrect=1
          fi
          # Determine eth interface associated with ppp interface
          einterface=$(sed -n 's/plugin rp-pppoe.so \(.*\)/\1/p' /etc/ppp/peers/$pinterface)
          echo Got $einterface from /etc/ppp/peers/$pinterface
          # Check if we need to change the ethernet MTU instead of just blindly taking interfaces up and down
          emtu=$(ip link show $einterface | head -n1 |sed 's/.*mtu \([0-9]\{4\}\).*/\1/')
          echo Got $emtu for $einterface
          # Current ethernet MTU is incorrect so needs changing
          echo Checking $einterface
          if [[ $emtu -lt $(($PTARGET+8)) ]] ; then
            echo $einterface has wrong MTU
            # Use +12 in above command if PPPoE over VLAN
            echo Reconfiguring ethernet MTU to $(($PTARGET+8)) for $einterface
            # Set eth interface MTU to ppp interface MTU + 8
            # This works for straight PPPoE as used in UK broadband
            echo Running ip link set dev $einterface mtu $(($PTARGET+8))
            ip link set dev $einterface mtu $(($PTARGET+8))
            # Maybe your PPPoE is over a VLAN and you need this instead, like in Norway
            # ip link set dev $einterface mtu $(($PTARGET+12)) && ip link set dev $einterface.6 mtu $(($PTARGET+8))
            # Bring interface down and up to apply changes
            echo Running ip link set $einterface down \&\& ip link set $einterface up
            ip link set $einterface down && ip link set $einterface up
          else
            echo $einterface has right MTU
            emtucorrect=1
          fi
          # A situation can occur where all the configuration files are correct
          # but the ppp interface is still not right
          # In this instance pppd must be restarted
          # Maybe we can get away with a SIGHUP
          if [ $pmtucorrect -eq 1 ] && [ $emtucorrect -eq 1 ]; then
            # Config files are all correct
            echo Config files are now all set correctly
            runningmtu=$(ip link list | grep $pinterface | grep $(($PTARGET-8)))
            if [ ! -z $runningmtu ]; then
              echo $pinterface still has wrong MTU
              restartpppd=1
            fi
          fi
        fi
      done
      
      if [[ $SET_MSS ]]; then
        echo "Checking if iptables MSS Value needs to be updated"
        currentMSS=$(iptables -L -t mangle --line-numbers | grep -m 1 'SYN,RST/SYN TCPMSS' | sed 's/.*set \([0-9]\{4\}\).*/\1/')
        targetMSS=$(($PTARGET-40))
        if [[ $currentMSS -ne $targetMSS ]]; then
            echo "Updating MSS from $currentMSS to $targetMSS"
            while [[ $(iptables -L -t mangle --line-numbers | grep 'SYN,RST/SYN TCPMSS') ]]; do
                iptables -t mangle -D UBIOS_FORWARD_TCPMSS 1
            done
            iptables -t mangle -A UBIOS_FORWARD_TCPMSS -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $targetMSS
        else
            echo "iptables already has correct MSS Value"
        fi
      fi
      
      if [[ $restartpppd == 1 ]]; then
        echo Killing pppd
        killall -SIGHUP pppd
      fi
    fi
    runningmtu=0
    restartpppd=0
    emtucorrect=0
    pmtucorrect=0
    sleep 60
done
