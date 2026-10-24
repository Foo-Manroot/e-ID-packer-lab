#!/bin/sh
#
# Starts the VM built with the qemu builder.
#
# The VM's SSH and HTTPS ports are forwarded to 127.0.0.1:2222 and 127.0.0.1:8443. All DIDs reference
# https://viscon.swiyu (port 443), so for Burp's DNS override to 127.0.0.1 to work, also run a redirector
# from 127.0.0.1:443 to 127.0.0.1:8443 (see README):
#	sudo socat TCP-LISTEN:443,bind=127.0.0.1,reuseaddr,fork TCP:127.0.0.1:8443
#
# Runs on a copy-on-write overlay so the built image stays pristine. Delete the overlay to reset.

set -e

BASE=output-eID/eID_testlab.qcow2
OVERLAY=output-eID/eID_testlab-run.qcow2

if [ ! -f "$BASE" ]
then
	printf "%s not found. Run ./run.sh first (with hypervisor = \"qemu\")\n" "$BASE"
	exit 1
fi

if [ ! -f "$OVERLAY" ]
then
	qemu-img create -f qcow2 -b "$(basename "$BASE")" -F qcow2 "$OVERLAY"
fi

exec qemu-system-x86_64 \
	-enable-kvm -cpu host -smp 2 -m 8192 \
	-device virtio-scsi-pci -drive file="$OVERLAY",if=none,id=hd0,format=qcow2 -device scsi-hd,drive=hd0 \
	-netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:8443-:443 -device virtio-net,netdev=net0 \
	-device virtio-vga,xres=1920,yres=1080 -display gtk
