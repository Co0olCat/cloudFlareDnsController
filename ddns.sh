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
# Thank you. Use it at your own risk.


EMAIL='' # Registration email for CloudFlare
TOKEN='' # Global API Key
DOMAIN='' # Root domain, e.g. example.com
SUBDOMAIN='' # Full doamin name, e.g. www.example.com or example.com when you are not using www prefix

MAIN_IP='' # If accessible and backup is used -> will be switched to main, e.g. 1.2.3.4
BACKUP_IP='' # If main IP is not accessible -> will be switched to backup, e.g. 9.8.7.6

ZONE_ID='' # For DOMAIN -> Run "./ddns.sh -l" to get value
REC_ID='' # For SUBDOMAIN -> Run "./ddns.sh -l" to get value

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
  REC_ID="$($CURL "$API_URL/zones/$ZONE_ID/dns_records" | sed -e 's/[{}]/\n/g' | grep '"name":"'"$SUBDOMAIN"'"' | sed -e 's/,/\n/g' | grep '"id":"' | cut -d'"' -f4)"
  $VERBOSE && echo "REC_ID='$REC_ID'"
fi

$LOOKUP && exit 0

# Get Cloudflare current IP for SUBDOMAIN
RECORD_IP="$($CURL "$API_URL/zones/$ZONE_ID/dns_records/$REC_ID" | sed -e 's/[{}]/\n/g' | sed -e 's/,/\n/g' | grep '"content":"' | cut -d'"' -f4)"	
$VERBOSE && echo "CloudFlare IP for '$SUBDOMAIN' is $RECORD_IP"

$VERBOSE && echo "Checking whether it is accessible..."

# Check whether server is accessible
if ping -c1 -W1 $RECORD_IP &> /dev/null 
then 
	# Domain is accessible -> no change is required
	$VERBOSE && echo "$DOMAIN is UP"
    
    #Check whether it is main address
    if [ "$RECORD_IP" == "$MAIN_IP" ]; then
    	$VERBOSE && echo "This is MAIN IP"
    else 
    	$VERBOSE && echo "This is BACKUP IP"
        
        # Check whether MAIN IP is accessible
        if ping -c1 -W1 $MAIN_IP &> /dev/null 
		then 
        	$VERBOSE && echo "MAIN IP is accessible -> Switching..."	
			$VERBOSE && echo "Setting IP to $MAIN_IP"

			$CURL -X PUT "$API_URL/zones/$ZONE_ID/dns_records/$REC_ID" --data '{"type":"A","name":"'"$DOMAIN"'","content":"'"$MAIN_IP"'","proxied":true}' 1>/dev/null
        else 
        	$VERBOSE && echo "MAIN IP is NOT accessible -> Keeping existing settings"
        fi
    fi
else 
    # Domain is not accessible -> 
    $VERBOSE && echo "$DOMAIN is down -> switching IP"   
    
    # Check whether it is main address
    if [ "$RECORD_IP" == "$MAIN_IP" ]; then
    	$VERBOSE && echo "This is MAIN IP"
    else 
    	$VERBOSE && echo "This is BACKUP IP"
        BACKUP_IP = $MAIN_IP
    fi
        
    # Check whether BACKUP IP is accessible
    if ping -c1 -W1 $BACKUP_IP &> /dev/null 
    then 
        $VERBOSE && echo "BACKUP IP is accessible -> Switching..."	
        $VERBOSE && echo "Setting IP to $BACKUP_IP"

        $CURL -X PUT "$API_URL/zones/$ZONE_ID/dns_records/$REC_ID" --data '{"type":"A","name":"'"$SUBDOMAIN"'","content":"'"$BACKUP_IP"'","proxied":true}' 1>/dev/null
    else 
        $VERBOSE && echo "BACKUP IP is NOT accessible -> Keeping existing settings"
    fi    
fi

exit 0