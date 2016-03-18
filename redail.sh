#!/bin/bash

iface=ppp0
#profile=viplc101
profile=jhjsq35

echo 'close connection.....'
poff  $profile >/dev/null 2>&1
ifconfig $iface down
sleep 1

echo 'clean unused routing.....'
oldip=$(route -n|grep -v grep|grep UGH|awk '{print $1}')
route del -net 0.0.0.0 dev $iface  >/dev/null 2>&1
for ip in $oldip;do 
    route del -net $ip  netmask 255.255.255.255 dev eth0
done

sleep 1

echo 'try to redial .....'
pon $profile >/dev/null 2>&1
for i in `seq 1 20`;do
    echo "waiting for gateway .... $i"
    ifconfig |grep "P-t-P" >/dev/null 2>&1
    if [ $? -eq 0 ];then
     route add -net 0.0.0.0 dev $iface 
     curl http://ip.cn
     echo "OK"
     exit 0
   fi
   sleep 1
done

echo "FAIL"
exit 1

