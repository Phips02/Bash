#!/bin/bash

#Step 1
# sudo apt-get update
# sudo apt-get install dnsutils

#Step 2
# Add on crontab
# Crontab -l
# 00 00 * * * /huser/pi/OVH/synhost.sh

source /home/pi/OVH/dynhost.credentials.sh


#----------------------------------------------------Telegram----------------------------------------------------
DATE=$(date "+%F %H:%M:%S")
IP_PUBLIC=$(curl -s ipinfo.io/ip)
API="https://api.telegram.org/bot${KEY}"

function telegram_text_send()
{
	API="$1"
	CHATID="$2"
	KEY="$3"
	PARSE_MODE="$4"
	TEXT="$5"
	ENDPOINT="sendMessage"

	curl -s -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=${PARSE_MODE}" ${API}/${ENDPOINT} >/dev/null
#	curl -s -d "chat_id=${CHATID}&text=${TEXT}&parse_mode=${PARSE_MODE}" ${API}/${ENDPOINT}
}
#----------------------------------------------------------------------------------------------------------------


MY_IP=$(curl -s https://ifconfig.me)


# Setting log file
log="."

if [ ! -z "$LOG" ]; then
    log="$LOG"
fi

echo "$log"


# Log function
function LOG() {
  # Log date
  fmt_date=$(date +"%D %T")
  # Log msg
  msg="$fmt_date - $1"

  # Print & Log
  echo $msg
  echo $msg >> "$log/dynhost.log"
}


###
# Script body
###



if [ -e OLD_IP.txt ]; then
	LOG "File OLD_IP.txt existing, ok"
	OLD_IP=$(cat OLD_IP.txt)
	LOG "Stored external IP address: $OLD_IP"
        LOG "Current external IP address: $MY_IP"
else
	LOG "The file OLD_IP.txt does not exist"
	LOG "file creation..."
        LOG "Current external IP address: $MY_IP"
        echo "$MY_IP" > OLD_IP.txt
fi


#--------------Telegram--------------
TEXT="$DATE %0A\
Update public IP address on OVH DynHost %0A\
OLD IP : $OLD_IP %0A\
NEW IP : $IP_PUBLIC"
#------------------------------------

if [ "$MY_IP" = "$OLD_IP" ]; then
        LOG "IP haven't change."
else
        LOG "IP have change."

        # Updating dynHost IP
        url="https://www.ovh.com/nic/update?system=dyndns&hostname=$OVH_HOSTNAME&myip=$IP"
	curl -s $url --user "$OVH_USERNAME:$OVH_PASSWD"
        telegram_text_send "$API" "$CHATID" "$KEY" "markdown" "$TEXT"

fi

# Log separator
LOG "-------------------------------------------------------"

#mise à jour adresse dans le script
echo "$MY_IP" > OLD_IP.txt

