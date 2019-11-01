#!/bin/bash

# shellcheck source=src/qln-lib.sh
type qln_msg >/dev/null 2>&1 || source /lib/qln-lib.sh

# shellcheck disable=SC1091
type getarg >/dev/null 2>&1 || source /lib/dracut-lib.sh

qln_read_auth_secret() {
    local keyname="$1"
    local method="$2"
    local waiting="Waiting for YubiKey..."
    local delay
    local slot

    delay="$(getoptcomma "$method" "delay")"
    slot="$(getoptcomma "$method" "slot")"

    while true; do
        qln_msg "$waiting"
        if ykinfo -a >/dev/null 2>&1; then
            break
        fi
        sleep "${delay:-2}"
    done
    qln_hide "$waiting"

    systemd-ask-password --timeout=0 "QLN Ykchalresp:" \
        | tr -d '\n' \
        | ykchalresp -"${slot:-2}" -i - \
        | tr -d '\n' \
        | qln_concat_key "$keyname"
}
