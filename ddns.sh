#!/bin/bash

IP=`curl -s http://icanhazip.com`
IP_FILE='/tmp/ddns_last_ip'
LAST_IP=`cat $IP_FILE`

EMAIL=''
TOKEN=''
DOMAIN=''
SUBDOMAIN=''

if [ "$IP" == "$LAST_IP" ]; then
  echo "IP Unchanged"
else
  curl https://www.cloudflare.com/api_json.html \
    -d 'a=rec_edit' \
    -d "email=$EMAIL" \
    -d "tkn=$TOKEN" \
    -d "z=$DOMAIN" \
    -d 'id=9001' \
    -d 'type=A' \
    -d "name=$SUBDOMAIN" \
    -d 'ttl=1' \
    -d "content=$IP"
  echo $IP > $IP_FILE
fi