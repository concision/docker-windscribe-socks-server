#!/bin/bash
# check windscribe status
if windscribe status | tee "$(tty)" | grep -q "DISCONNECTED"; then
    exit 1
fi
