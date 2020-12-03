#!/bin/bash
# check windscribe status
if windscribe status | grep -q "DISCONNECTED"; then
    exit 1
fi
