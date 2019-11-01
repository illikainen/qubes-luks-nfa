DESTDIR ?=
MODULE_DIR ?= $(DESTDIR)/usr/lib/dracut/modules.d/99qubes-luks-nfa
CONFIG_DIR ?= $(DESTDIR)/etc

KERNEL ?= $(shell uname -r)
TIMESTAMP ?= $(shell date "+%s")
INITRAMFS ?= /boot/initramfs-$(KERNEL).img
INITRAMFS_BACKUP ?= $(INITRAMFS).backup

all:

install:
	install -d "$(MODULE_DIR)"
	install src/*.sh "$(MODULE_DIR)"
	install -m u=rw,g=r,o=r etc/*.conf "$(MODULE_DIR)"

initramfs: install
	@test ! -e "$(INITRAMFS_BACKUP)" && \
		cp -av "$(INITRAMFS)" "$(INITRAMFS_BACKUP)" || \
		cp -av "$(INITRAMFS)" "$(INITRAMFS_BACKUP)-$(TIMESTAMP)"
	dracut --kver "$(KERNEL)" --force

uninstall:
	rm -rf "$(MODULE_DIR)"

test:
	shellcheck -x src/*.sh

.PHONY: all install initramfs uninstall test
