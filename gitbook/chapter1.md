# 在 CentOS下部署

### 安装VPN相关程序
``` bash
#安装相关程序
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y pptp.x86_64 pptp-setup.x86_64

#通过pptpsetup生成配置文件
pptpsetup --create $VPN_NAME --server $VPN_Server_IP --username $User_Name --password $Password  --encrypt --start

#拷贝拨号快捷方式
cp /usr/share/doc/ppp-*/scripts/poff /usr/sbin/
cp /usr/share/doc/ppp-*/scripts/pon /usr/sbin/
chmod +x /usr/sbin/poff
chmod +x /usr/sbin/pon

#配置安全路由,其中 172.30.204.1 为你的默认网关，可通过 route -n|grep UG 找到
export gw=172.30.204.1
route add -net 172.16.0.0/12 gateway $gw
route add -net 10.0.0.0/8 gateway $gw

#加入开机自启动
echo 'route add -net 172.16.0.0/12 gateway 172.30.204.1' >> /etc/rc.local
echo 'route add -net 10.0.0.0/8 gateway 172.30.204.1' >> /etc/rc.local
```

### VPN 相关文件

`vi /etc/ppp/chap-secrets` 观察一下即可无需理会：
```bash
# added by pptpsetup for <VPN名称>
<用户名> <VPN名称> "<密码>" *
```


### 调试运行

``` bash
#直接运行
pon $VPN_NAME

tail -f /var/log/messages
Mar 29 11:15:34 11F-zhangmh-205238 pppd[19674]: CHAP authentication succeeded
Mar 29 11:15:34 11F-zhangmh-205238 pppd[19674]: CCP terminated by peer (No compression negotiated)
Mar 29 11:15:34 11F-zhangmh-205238 pppd[19674]: Compression disabled by peer.
Mar 29 11:15:34 11F-zhangmh-205238 pppd[19674]: local  IP address 10.10.5.2
Mar 29 11:15:34 11F-zhangmh-205238 pppd[19674]: remote IP address 10.10.5.254

#表示拨号成功
```
> 另外通过 `ifconfig` 观察是否有 `ppp0` 接口，如果有一般都表示连接成功.

此时，vpn虽然已经链接，但是系统默认路由没有更改，需要配置

``` bash
route add -net 0.0.0.0 dev $iface 
```

> 请务必确认**安全路由** 已经添加，否则会导致 ssh 瞬间断线！

最后可以用`curl http://ip.cn`观察一下 IP 是否有变化.

### redial.sh <源代码>

``` bash
#!/bin/bash

source /etc/profile

iface=ppp0 #iface接口名称一般为ppp0,不需要修改
profile=60 #修改这里为你的VPN链接名

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

```
用任意编辑器保存为`redial.sh`,并执行`chmod 755 redial.sh && cp redial.sh /usr/sbin` 尝试运行即可.

> 源代码和说明文件在 https://github.com/onion83/redail.git 随时更新.