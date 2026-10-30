#!/bin/bash
# vbrun.sh HDIMG C H S [FLOPIMG] [TIMEOUT]  (runs on the VirtualBox host)
#
# Boot the micache-test VM from the raw disk image HDIMG (geometry C/H/S),
# with FLOPIMG in drive A: if given, and wait until the guest powers itself
# off (POWEROFF.COM, through APM). After TIMEOUT seconds (default 240) the VM
# is switched off hard and we exit 124. The images are used in place, so the
# caller reads the results straight out of them afterwards.
#
# COM1 is a TCP server on 127.0.0.1:$VBPORT (default 5701) while the VM runs,
# which we serve, so a test can ask (COMWAIT.COM) for the floppy to be
# changed: a real media change, which DOSBox-X cannot do.
#
# Setup, once: put this script in ~/micache-vbox/ and create the VM:
#   VBoxManage createvm --name micache-test --ostype DOS --register \
#     --basefolder ~/micache-vbox/vm
#   VBoxManage modifyvm micache-test --memory 16 --vram 9 --cpus 1 --ioapic off \
#     --acpi off --boot1 disk --boot2 floppy --boot3 none --boot4 none \
#     --audio-enabled off --usb-ohci off --nic1 none --graphicscontroller vboxvga \
#     --uart1 0x3F8 4 --uart-mode1 disconnected
#   VBoxManage storagectl micache-test --name IDE --add ide --controller PIIX4
#   VBoxManage storagectl micache-test --name Floppy --add floppy --controller I82078
set -u
VM=micache-test
img=$(readlink -f "$1") c=$2 h=$3 s=$4 fl=${5:-} to=${6:-240}
[ -n "$fl" ] && fl=$(readlink -f "$fl")
dir=$(dirname "$img")
vmdk="$dir/$(basename "$img" .IMG).vmdk"

# a flat VMDK descriptor over the raw image, with its CHS geometry
cat > "$vmdk" <<EOF
# Disk DescriptorFile
version=1
CID=fffffffe
parentCID=ffffffff
createType="monolithicFlat"

RW $(( $(stat -c %s "$img") / 512 )) FLAT "$(basename "$img")" 0

ddb.virtualHWVersion = "4"
ddb.adapterType="ide"
ddb.geometry.cylinders="$c"
ddb.geometry.heads="$h"
ddb.geometry.sectors="$s"
ddb.geometry.biosCylinders="$c"
ddb.geometry.biosHeads="$h"
ddb.geometry.biosSectors="$s"
EOF

# Every VBoxManage call is serialised (one at a time, even the COM server's)
# and given a time limit: unserialised calls, including a showvminfo poll
# during the VM's teardown, once wedged VBoxSVC for good.
# (-o: VBoxManage may start VBoxSVC, which must not inherit the lock)
vbm() { flock -o -w 60 "$HOME/micache-vbox/.vbm.lock" timeout 30 VBoxManage "$@" 9>&-; }

detach() {
	vbm storageattach $VM --storagectl IDE --port 0 --device 0 --medium none 2>/dev/null
	vbm storageattach $VM --storagectl Floppy --port 0 --device 0 --medium none 2>/dev/null
	vbm closemedium disk "$vmdk" 2>/dev/null
	local f
	for f in ${fl:+"$fl"} "$dir"/FD*.IMG; do
		[ -f "$f" ] && vbm closemedium floppy "$f" 2>/dev/null
	done
	rm -f "$vmdk"
}
# the VM runs as our own child (VBoxHeadless), which exits when the guest
# powers off: no polling of the VM's state
stopvm() {
	[ -n "${HPID:-}" ] && kill -0 $HPID 2>/dev/null || return 0
	vbm controlvm $VM poweroff >/dev/null 2>&1
	local i
	for i in $(seq 15); do kill -0 $HPID 2>/dev/null || return 0; sleep 1; done
	echo "vbrun: VM would not power off, killing it" >&2
	kill -9 $HPID 2>/dev/null; sleep 2
}

# COM1 server: the guest's COMWAIT sends a line, we act on it and answer
# with one byte. "SWAP n" puts $dir/FDn.IMG in drive A: (logged in COM.LOG).
serve() {
	local i
	# (a failed exec redirection would end this shell, so the connection is
	# made on the loop, and retried until the VM is listening)
	for i in $(seq 30); do
		serve1 3<>/dev/tcp/127.0.0.1/${VBPORT:-5701} 2>/dev/null && return
		sleep 1
	done
}
serve1() {
	local line n
	while IFS= read -r line <&3; do
		line=${line%$'\r'}
		echo "$((SECONDS - t0))s $line" >> "$dir/COM.LOG"
		case $line in
		"SWAP "*)
			n=${line#SWAP }
			case $n in
			''|*[!0-9]*) echo "  bad swap" >> "$dir/COM.LOG" ;;
			*) vbm storageattach $VM --storagectl Floppy --port 0 --device 0 \
				--type fdd --medium "$dir/FD$n.IMG" >> "$dir/COM.LOG" 2>&1 ;;
			esac ;;
		esac
		printf K >&3
	done
	return 0
}

# one run at a time on this host
exec 9> "$HOME/micache-vbox/.run.lock"
flock -n 9 || { echo "vbrun: another run is in progress" >&2; exit 1; }
vbm showvminfo $VM --machinereadable | grep -q '^VMState="poweroff"' ||
	{ echo "vbrun: $VM is not powered off" >&2; exit 1; }
HPID= SPID=
trap 'kill $SPID 2>/dev/null; stopvm; detach' EXIT INT TERM
vbm storageattach $VM --storagectl IDE --port 0 --device 0 --type hdd --medium "$vmdk" || exit 1
vbm storageattach $VM --storagectl Floppy --port 0 --device 0 --type fdd --medium "${fl:-emptydrive}" || exit 1
vbm modifyvm $VM --uart-mode1 tcpserver ${VBPORT:-5701} || exit 1
rm -f "$dir/COM.LOG" "$dir/HANG.png"
t0=$SECONDS
VBoxHeadless --startvm $VM --vrde off > "$dir/HEADLESS.LOG" 2>&1 9>&- & HPID=$!
serve & SPID=$!
while [ $((SECONDS - t0)) -lt $to ]; do
	sleep 1
	kill -0 $HPID 2>/dev/null || { wait $HPID; echo "vbrun: powered off after $((SECONDS - t0))s"; exit 0; }
done
vbm controlvm $VM screenshotpng "$dir/HANG.png" 2>/dev/null
echo "vbrun: TIMEOUT after ${to}s"
exit 124
