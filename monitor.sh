#!/bin/bash

PUSHOVER_USER="REDACTED"
PUSHOVER_TOKEN="REDACTED"
THRESHOLD=80
zpool_status=$(zpool status -x)
DISKS=$(lsblk | awk '/disk/ {print "/dev/"$1}')
UPDATE_AVAILABLE=$(cli -m table -c 'system update check_available' | awk '/status/ {print $4}')

if [[ "$UPDATE_AVAILABLE" == "AVAILABLE" ]]; then
    VERSION=$(cli -m table -c 'system update check_available' | awk '/version/ {print $4}')
    curl -s \
    --form-string "token=$PUSHOVER_TOKEN" \
    --form-string "user=$PUSHOVER_USER" \
    --form-string "message=Warning: TrueNAS update available version: $VERSION" \
    https://api.pushover.net/1/messages.json
fi

for disk in $DISKS; do
    if [[ "$disk" == "/dev/sdd" ]]; then
        part="${disk}3"
    else
        part="${disk}2"
    fi
    SMARTCTL=$(smartctl -H $part | awk -F ": " '/SMART overall-health self-assessment test result|SMART Health Status/{print $2}')
    if ! [[ $SMARTCTL == "OK" || $SMARTCTL == "PASSED" ]]; then
        curl -s \
        --form-string "token=$PUSHOVER_TOKEN" \
        --form-string "user=$PUSHOVER_USER" \
        --form-string "message=Warning: Smartctl on $disk: $SMARTCTL" \
        https://api.pushover.net/1/messages.json
    fi
done

if [[ "$zpool_status" != "all pools are healthy" ]]; then
        curl -s \
        --form-string "token=$PUSHOVER_TOKEN" \
        --form-string "user=$PUSHOVER_USER" \
        --form-string "message=Warning: ZFS pool unhealthy $zpool_status" \
        https://api.pushover.net/1/messages.json
fi

while IFS= read -r line; do
    pool=$(echo "$line" | awk '{print $1}')
    usage=$(echo "$line" | awk '{print $2}' | tr -d '%')

    if (( usage >= THRESHOLD )); then
        curl -s \
            --form-string "token=$PUSHOVER_TOKEN" \
            --form-string "user=$PUSHOVER_USER" \
            --form-string "message=Warning: ZFS pool $pool is $usage% full!" \
            https://api.pushover.net/1/messages.json
    fi
done < <(zpool list -Ho name,capacity)
exit 0