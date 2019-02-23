#!/usr/bin/env bash
# lastRootLogin.sh

sudo cat /var/log/secure |grep "session opened for user root by" | tail -1

if [[ "$?" -ne "0" ]]; then
  return "$?"
fi


