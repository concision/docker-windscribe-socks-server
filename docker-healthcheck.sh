#!/bin/bash
if windscribe status | grep -q "DISCONNECTED"; then
   exit 1
else
   exit 0
fi