#!/bin/bash
# explicitly define variables here or source them from an .env file with --env-file flag
#export WINDSCRIBE_DNS="1.1.1.1"
#export WINDSCRIBE_USERNAME="username"
#export WINDSCRIBE_PASSWORD="password"
#export WINDSCRIBE_LOCATION=""

docker run \
	--detach \
	--restart=always \
	--cap-add=NET_ADMIN \
	--publish 1080:1080 \
	--tmpfs /etc/windscribe:exec \
	--env WINDSCRIBE_DNS \
	--env WINDSCRIBE_USERNAME \
	--env WINDSCRIBE_PASSWORD \
	--env WINDSCRIBE_LOCATION \
	--env-file .env \
	--name windscribe \
	"concisions/windscribe-socks-server:latest"
