About
=====

`qubes-luks-nfa` is a `dracut` module for [Qubes OS][1] that adds
support for multifactor unlocking of cryptsetup devices.

There are currently two supported methods:

- challenge-response authentication with YubiKey
- password-based authentication

These can be combined in order to have a part of the final secret be
derived from a YubiKey, and a part from a traditional password.


Usage
=====

1. Edit `etc/qln.conf`.
2. `sudo make initramfs`
3. Reboot.

Example `qln.conf`:

```sh
# This setting must contain one or more methods.  They are executed in the
# order specified, and each method must be specified with a `name=`.  Optional
# settings can be provided as a comma-separated list of `key=val` after the
# name.
#
# The output from all methods are concatenated for the final passphrase.
methods="name=password name=ykchalresp,slot=2`

# This option is used to delay USB controller detaching in the Qubes pciback
# module.  Required if `rd.qubes.hide_all_usb` is enabled and `ykchalresp` is
# used as an authentication method.
delay_usb_pciback=1
```

In the example above, a combination of a normal password and
challenge-response with a YubiKey is used to derive the final
passphrase.  This can be setup as follows (assuming slot 2 on the
YubiKey has been setup for challenge-response authentication):

```sh
$ read -s chal
$ pw1="$(echo -n "$chal" | ykchalresp -2 -i -)"
$ read -s pw2
$ sudo cryptsetup luksAddKey /dev/XXX
Enter any existing passphrase: <old>
Enter new passphrase for key slot: <concatenate $pw1 and $pw2>
Verify passphrase: <concatinate $pw1 and $pw2>
```

Note that the configuration file is `source`d by the module, so it must
be written with valid shell syntax.

Also note that the `ykpers` package is required for `ykchalresp`:

```sh
sudo qubes-dom0-update ykpers
```


Design
======

The kernel keyring is used internally by systemd to store one or more
passwords for cryptsetup (see [ask-password-api.c][2]).  They are stored
in the users keyring with a description of `cryptsetup`.  The content is
a string that may contain NUL-bytes.

NUL-bytes are treated as separators internally by systemd.  This is used
to allow more than one password to be kept in the keyring.

On the first attempt to decrypt a device with `systemd-cryptsetup` (see
[cryptsetup.c][3]), the systemd password API is instructed to accept
cached password from the keyring.  Each password is tried in succession
until one succeeds or everyone fail.  If every cached password fail,
systemd will prompt the user for the device password and cached replies
will not be accepted.

This approach allows systemd to open multiple devices that shares
passwords without prompting the user multiple times.

The functionality described above is used by this module to implement
N-factor authentication.  Unlike many other non-standard cryptsetup
modules, this means that `qubes-luks-nfa` does not forgo systemd and its
use of `/etc/crypttab` (so optional settings to enable e.g. `discard`
will continue working.)

This module installs an override for `systemd-cryptsetup@.service.d`
that adds an `ExecStartPre`.  The final passphrase is derived in that
executable and it's stored in the keyring that systemd uses internally
to unluck devices.

There is one important consideration to have in mind: in order to use
USB-based authenticators (currently only `ykchalresp`), the USB
controllers have to be available when [systemd-cryptsetup@.service.d][4]
executes.  This means that the USB controllers can't be detached until
this module has finished executing.

The way that this is implemented is by replacing `rd.qubes.hide_all_usb`
with `rd.qln.hide_all_usb` in the `pciback` hook when the initramfs is
built.  The `qln` version is **not** meant to be enabled in the kernel
command line.  Instead it is set dynamically (with a value corresponding
to the original `qubes` variable) when `qubes-luks-nfa` has finished
executing.

That is, do **not** make any modifications to your kernel command-line.
Keep `rd.qubes.hide_all_usb` enabled if you want your USB controllers
attached to a VM.

The implementation details for the delayed unbinding is found in
`src/module-setup.sh:install()` and
`src/qln-cryptsetup.sh:qln_pciback()`.

The `pciback` hook is executed before [systemd-cryptsetup@.service.d][4]
continues; that is, the USB controllers are detached before the device
is opened with cryptsetup (if `rd.qubes.hide_all_usb` is enabled).  This
means that there is one shot to open a device with this hook.  If it
fails, systemd will use normal password-based authentication.

[1]: https://qubes-os.org
[2]: https://github.com/systemd/systemd/blob/v231/src/shared/ask-password-api.c
[3]: https://github.com/systemd/systemd/blob/v231/src/cryptsetup/cryptsetup.c
[4]: https://github.com/systemd/systemd/blob/v231/src/cryptsetup/cryptsetup-generator.c