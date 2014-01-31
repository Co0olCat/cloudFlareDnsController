#!/bin/bash

# Step 1: Fill in EMAIL, TOKEN, DOMAIN and SUBDOMAIN
# Step 2: Create an A record on Cloudflare with the subdomain you chose
# Step 3: Run "./ddns.sh -l" to get the rec_id of the record you created. 
#         Fill in REC_ID below
# Step 4: Run "./ddns.sh". It should tell you that record was updated or that it didn't need updating.
#         Use "./ddns.sh -s to silence normal output (e.g. to run as a cron script)"

IP=`curl -s http://ipv4.icanhazip.com`
IP_FILE='/tmp/ddns_last_ip'
[[ -r "$IP_FILE" ]] && LAST_IP=`cat $IP_FILE` || LAST_IP=''

EMAIL=''
TOKEN=''
DOMAIN=''
SUBDOMAIN=''
REC_ID=''

CURL="curl -s https://www.cloudflare.com/api_json.html -d email=$EMAIL -d tkn=$TOKEN -d z=$DOMAIN "

if [ "$IP" == "$LAST_IP" ]; then
  [ "$1" != "-s" ] && echo "IP Unchanged"
  exit
fi

if [ "$1" == "-l" ]; then
  $CURL -d 'a=rec_load_all' | sed -e 's/[{}]/\n/g' | grep '"name":"'"$SUBDOMAIN"'.'"$DOMAIN"'"' | grep '"type":"A"' | sed -e 's/,/\n/g'
  exit
fi

[ "$1" != "-s" ] && echo "Setting IP to $IP"

$CURL \
  -d 'a=rec_edit' \
  -d "id=$REC_ID" \
  -d 'type=A' \
  -d "name=$SUBDOMAIN" \
  -d 'ttl=1' \
  -d 'service_mode=0' \
  -d "content=$IP" \
  1>/dev/null

echo $IP > $IP_FILE