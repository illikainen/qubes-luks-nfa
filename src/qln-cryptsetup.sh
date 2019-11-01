#!/bin/bash

# shellcheck source=etc/qln.conf
source /etc/qln.conf

# shellcheck source=src/qln-lib.sh
type qln_info >/dev/null 2>&1 || source /lib/qln-lib.sh

# shellcheck disable=SC1091
type getarg >/dev/null 2>&1 || source /lib/dracut-lib.sh

# Read the authentication secrets into the kernel keyring.
qln_read_auth_secrets() {
    local methods="$1"
    local keyname="qln:keyname"
    local systemd_keyname="cryptsetup"
    local method

    for method in $methods; do
        local src
        src="/lib/qln-auth-$(getoptcomma "$method" "name").sh"
        if [ ! -r "$src" ]; then
            qln_warn "invalid method: $src"
            return
        fi

        qln_info "Authenticating with '$src'"
        source "$src"
        qln_read_auth_secret "$keyname" "$method"

        # Fall back to standard passphrase-based authentication if the keyring
        # doesn't exist (meaning that the user entered a blank password).
        if ! keyctl describe "%user:${keyname}" >/dev/null 2>&1; then
            return
        fi
    done

    qln_cat_key "$keyname" | qln_add_key "$systemd_keyname"
    qln_rm_key "$keyname"
}

# Run Qubes pciback hook.
#
# Dracut accepts arguments through the kernel command-line as well as through
# /etc/cmdline and /etc/cmdline.d/*.conf.  The file-based argument parsing is
# used to set rd.qln.hide_all_usb based on rd.qubes.hide_all_usb (the qubes
# variant is replaced with qln on initramfs creation in module-setup.sh if
# delay_usb_pciback is 1).
#
# See:
# - getcmdline() in dracut-lib.sh
# - install() in module-setup.sh
qln_pciback() {
    if [[ "${delay_usb_pciback:-0}" -eq 1 ]]; then
        if getargbool 0 rd.qubes.hide_all_usb; then
            qln_info "Detaching USB controllers"
            echo "rd.qln.hide_all_usb" >/etc/cmdline.d/qubes-hide-all-usb.conf

            if ! /usr/lib/dracut/hooks/cmdline/02-qubes-pciback.sh; then
                qln_fatal "qubes-pciback failed"
            fi

            if [[ "$(lsusb |wc -l)" -ne 0 ]]; then
                qln_fatal "USB controller(s) still attached"
            fi
        fi
    fi
}

main() {
    qln_read_auth_secrets "${methods:-password}"
    qln_pciback
}

main "$@"
