#!/bin/bash
# check windscribe status
if windscribe status | tee "$(tty)" | grep -q "DISCONNECTED"; then
    exit 1
else
   # check IP resolution is successful
    curl -s "https://api.ipify.org/" || exit 1
fi
