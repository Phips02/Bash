#!bin/bash

source /home/pi/telegram/telegram.credentials.sh

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

}
