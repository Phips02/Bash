#!/bin/bash

#Step 1
# sudo apt-get update
# sudo apt-get install dnsutils

source /home/pi/OVH/dynhost.credentials.sh

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
else
	LOG "The file OLD_IP.txt does not exist"
	LOG "file creation..."
	echo "$MY_IP" > OLD_IP.txt
fi


LOG "Current external IP address: $MY_IP"


if [ "$MY_IP" = "$OLD_IP" ]; then
        LOG "IP haven't change."
else
        LOG "IP have change."

        # Updating dynHost IP
        url="https://www.ovh.com/nic/update?system=dyndns&hostname=$OVH_HOSTNAME&myip=$IP"
	curl -s $url --user "$OVH_USERNAME:$OVH_PASSWD"

fi

# Log separator
LOG "-------------------------------------------------------"

#mise à jour adresse dans le script
echo "$MY_IP" > OLD_IP.txt
