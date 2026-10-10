#!/bin/sh
#
# Starts the VM built with the qemu builder.
#
# The VM's SSH and HTTPS ports are forwarded to 127.0.0.1:2222 and 127.0.0.1:443, so Burp can reach
# viscon.swiyu via a DNS override to 127.0.0.1. Forwarding port 443 as a normal user needs:
#	sudo sysctl net.ipv4.ip_unprivileged_port_start=443
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
	qemu-img create -f qcow2 -b eID_testlab.qcow2 -F qcow2 "$OVERLAY"
fi

exec qemu-system-x86_64 \
	-enable-kvm -cpu host -smp 2 -m 8192 \
	-device virtio-scsi-pci -drive file="$OVERLAY",if=none,id=hd0,format=qcow2 -device scsi-hd,drive=hd0 \
	-netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:443-:443 -device virtio-net,netdev=net0 \
	-device virtio-vga,xres=1920,yres=1080 -display gtk
