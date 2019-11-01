#!/bin/bash

# Return 0 if key exist.
#
# $1: key description to check
qln_has_key() {
    local desc="$1"

    keyctl describe "%user:${desc}" >/dev/null 2>&1
}

# Print the contents of a key.
#
# The key is printed with NUL-bytes stripped.  Systemd uses NUL-bytes
# internally to store a list of passwords.  QLN uses systemd-ask-password to
# compute multiple passwords from different sources; and the secret is used in
# its entirety to decrypt a device.  Thus NUL-bytes must be removed to prevent
# systemd from interpreting a password as a list of multiple passwords.
#
# $1: key description to print
qln_cat_key() {
    local desc="$1"

    if qln_has_key "$desc"; then
        keyctl pipe "%user:${desc}" 2>/dev/null | tr -d '\0'
    fi
}

# Remove a key.
#
# $1: key description to remove.
qln_rm_key() {
    local desc="$1"

    keyctl unlink "%user:${desc}" >/dev/null 2>&1
}

# Add the content of stdin to a key.
#
# This function is meant to be used when systemd-ask-password with --keyname
# can't be used (e.g. because the secret has to be transformed before storing
# it in the keyring).  The timeout is set to 2.5 minutes (which is what
# systemd-ask-password uses).
#
# $1: key description to add.
qln_add_key() {
    local desc="$1"
    local tmout="160"

    keyctl padd user "$desc" @u >/dev/null 2>&1
    keyctl timeout "%user:${desc}" "$tmout" >/dev/null 2>&1
}

# Concatenate the content of stdin to a key.
#
# $1: key description for the destination.
qln_concat_key() {
    local desc="$1"
    local tmp_desc="qln:tmp-desc"

    qln_add_key "$tmp_desc"

    {
        qln_cat_key "$desc"
        qln_cat_key "$tmp_desc"
    } | qln_add_key "$desc"

    qln_rm_key "$tmp_desc"
}

qln_fatal() {
    echo "fatal: $*" >&2
    plymouth display-message --text="fatal: $*"
    sleep 10
    halt --poweroff
}

qln_warn() {
    echo "warn: $*" >&2
    plymouth display-message --text="warn: $*"
}

qln_msg() {
    echo "$*"
    plymouth display-message --text="$*"
}

qln_hide() {
    plymouth hide-message --text="$*"
}

qln_info() {
    echo "$*"
}
