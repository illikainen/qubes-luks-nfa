#!/bin/bash

check() {
    return 0
}

install() {
    if ! dracut_module_included "systemd"; then
        echo "ERROR: qubes-luks-nfa requires systemd"
        exit 1
    fi

    # Local dependencies.
    local qln
    # shellcheck disable=SC2154
    for qln in "${moddir}"/qln-*.sh; do
        inst "$qln" "/lib/$(basename "$qln")"
    done
    inst "${moddir}/qln.conf" /etc/qln.conf
    inst "${moddir}/qln-cryptsetup.conf" \
         "/etc/systemd/system/systemd-cryptsetup@.service.d/qln-cryptsetup.conf"

    # System dependencies.
    inst_multiple \
        /usr/bin/keyctl \
        /usr/bin/lsusb \
        /usr/bin/systemd-ask-password \
        /usr/bin/tr \
        /usr/bin/wc \
        /usr/sbin/halt

    if [[ -e "/usr/bin/ykchalresp" ]]; then
        inst /usr/bin/ykchalresp
        inst /usr/bin/ykinfo
    else
        echo "WARN: ykpers not installed" >&2
    fi

    # Postpone the pciback hook.
    # shellcheck source=etc/qln.conf
    source "${moddir}/qln.conf"
    if [[ "${delay_usb_pciback:-0}" -eq 1 ]]; then
        # shellcheck disable=2154
        sed -i 's/\brd\.qubes\.hide_all_usb\b/rd.qln.hide_all_usb/' \
            "${initdir}/usr/lib/dracut/hooks/cmdline/02-qubes-pciback.sh"
    fi
}
