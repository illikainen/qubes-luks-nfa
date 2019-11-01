#!/bin/bash

qln_read_auth_secret() {
    local keyname="$1"

    systemd-ask-password \
        --keyname="$keyname" \
        --no-output \
        --timeout=0 \
        "QLN Password:"
}
