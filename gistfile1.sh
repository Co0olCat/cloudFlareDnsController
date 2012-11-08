#!/bin/sh
WAN_IP=`wget -O - -q http://ifconfig.me/ip`
OLD_WAN_IP=`cat /var/CURRENT_WAN_IP.txt`
if [ "$WAN_IP" = "$OLD_WAN_IP" ]
then
        echo "IP Unchanged"
else
        curl https://www.cloudflare.com/api_json.html \
          -d 'a=rec_edit' \
          -d 'tkn=8afbe6dea02407989af4dd4c97bb6e25' \
          -d 'email=sample@example.com' \
          -d 'z=example.com' \
          -d 'id=9001' \
          -d 'type=A' \
          -d 'name=sub' \
          -d 'ttl=1' \
          -d "content=$WAN_IP"
        echo $WAN_IP > /var/CURRENT_WAN_IP.txt
fi