#!/usr/bin/env bash

# Step 1: Fill in EMAIL, TOKEN, DOMAIN and SUBDOMAIN. Your API token is here: https://www.cloudflare.com/a/account/my-account
#         Make sure the token is the Global token, or has these permissions: #zone:read, #dns_record:read, #dns_records:edit
# Step 2: Create an A record on Cloudflare with the subdomain you chose
# Step 3: Run "./ddns.sh -l" to get the zone_id and rec_id of the record you created.
#         Fill in ZONE_ID and REC_ID below
#         This step is optional, but will save you 2 requests every time you this script
# Step 4: Run "./ddns.sh". It should tell you that record was updated or that it didn't need updating.
# Step 5: Run it every hour with cron. Use the '-s' flag to silence normal output
#         0 * * * * /path/to/ddns.sh -s


EMAIL=''
TOKEN=''
DOMAIN=''
SUBDOMAIN=''
ZONE_ID=''
REC_ID=''



set -euo pipefail
#set -x # enable for debugging

VERBOSE="[ '${1:-}' != '-s' ]"
LOOKUP="[ '${1:-}' == '-l' ]"

API_URL="https://api.cloudflare.com/client/v4"
CURL="curl -s \
  -H Content-Type:application/json \
  -H X-Auth-Key:$TOKEN \
  -H X-Auth-Email:$EMAIL "


if [ -z "$ZONE_ID" ] || $LOOKUP; then
  ZONE_ID="$($CURL "$API_URL/zones?name=$DOMAIN" | sed -e 's/[{}]/\n/g' | grep '"name":"'"$DOMAIN"'"' | sed -e 's/,/\n/g' | grep '"id":"' | cut -d'"' -f4)"
  $VERBOSE && echo "ZONE_ID='$ZONE_ID'"
fi

if [ -z "$REC_ID" ] || $LOOKUP; then
  REC_ID="$($CURL "$API_URL/zones/$ZONE_ID/dns_records" | sed -e 's/[{}]/\n/g' | grep '"name":"'"$SUBDOMAIN"'.'"$DOMAIN"'"' | sed -e 's/,/\n/g' | grep '"id":"' | cut -d'"' -f4)"
  $VERBOSE && echo "REC_ID='$REC_ID'"
fi

$LOOKUP && exit 0

IP="$(curl -s http://ipv4.icanhazip.com)"
RECORD_IP="$($CURL "$API_URL/zones/$ZONE_ID/dns_records/$REC_ID" | sed -e 's/[{}]/\n/g' | sed -e 's/,/\n/g' | grep '"content":"' | cut -d'"' -f4)"

if [ "$IP" == "$RECORD_IP" ]; then
  $VERBOSE && echo "IP Unchanged"
  exit 0
fi

$VERBOSE && echo "Setting IP to $IP"

$CURL -X PUT "$API_URL/zones/$ZONE_ID/dns_records/$REC_ID" --data '{"type":"A","name":"'"$SUBDOMAIN"'","content":"'"$IP"'","proxied":false}' 1>/dev/null

exit 0
