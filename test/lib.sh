#!/bin/bash
# Test harness for MICACHE: real MS-DOS 6.22 booted inside DOSBox-X from disk
# image files. Nothing here touches a host disk: the guest only ever sees the
# .img files under test/work.
#
#   source lib.sh
#   make_hd NAME CYLS HEADS SPT     - blank HD image with DOS 6.22 installed
#   boot_hd IMG [FLOPPY] [TIMEOUT]  - boot DOS from IMG (A: = FLOPPY image)
#   get FILE IMG DEST               - copy a file out of an image (7-Zip)

T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$T/../.." && pwd)"
DBX=/c/DOSBox-X/dosbox-x.exe
SEVENZ="/c/Program Files/7-Zip/7z.exe"
TW="$(cygpath -w "$T")"
mkdir -p "$T/work"

crlf() { sed 's/$/\r/'; }

# conf for booting a guest DOS: fast CPU, 16M RAM, APM so POWEROFF works
dbx_conf() {
	cat > "$T/work/boot.conf" <<-EOF
	[dosbox]
	memsize=${MEMSIZE:-16}
	[cpu]
	core=normal
	cycles=max
	[dos]
	xms=true
	ems=true
	umb=true
	[speaker]
	pcspeaker=false
	EOF
}

# run_dbx TIMEOUT BAT-LINES... : run DOSBox-X with Y: = test dir, then the lines
run_dbx() {
	local to=$1; shift
	printf '%s\r\n' "$@" > "$T/work/RUN.BAT"
	dbx_conf
	(cd "$T" && timeout -k 10 "$to" nice -n 15 "$DBX" -silent -nogui -nomenu -conf "$T/work/boot.conf" \
		-c "mount y \"$TW\"" -c "y:" -c "work\\RUN.BAT" >/dev/null 2>&1)
	local rc=$?
	[ $rc = 124 ] && echo "run_dbx: TIMEOUT after ${to}s" >&2
	return $rc
}

# make_hd NAME C H S
make_hd() {
	local name=$1 c=$2 h=$3 s=$4
	local img="$TW\\work\\$name.IMG"
	cp "$T/iso/BOOT622.IMG" "$T/work/SYS.IMG"
	printf 'FILES=30\r\nBUFFERS=20\r\n' > "$T/work/SYSCONF.SYS"
	printf '@echo off\r\nSYS A:\\ C: > A:\\SYS.LOG\r\nDIR C:\\ /A > A:\\DIR.LOG\r\nPOWEROFF > A:\\PO.LOG\r\n' > "$T/work/SYSAUTO.BAT"
	# SYS needs an empty root, so make the disk bootable first ...
	run_dbx 120 \
		"imgmake \"$img\" -t hd -chs $c,$h,$s -force > work\\MAKEHD.LOG" \
		"imgmount c \"$img\" -t hdd >> work\\MAKEHD.LOG" \
		"imgmount a \"$TW\\work\\SYS.IMG\" -t floppy >> work\\MAKEHD.LOG" \
		"copy y:\\work\\SYSCONF.SYS a:\\CONFIG.SYS > nul" \
		"copy y:\\work\\SYSAUTO.BAT a:\\AUTOEXEC.BAT > nul" \
		"copy y:\\tools\\POWEROFF.COM a:\\POWEROFF.COM > nul" \
		"boot a: -noconvertfat"
	# ... then add DOS and our tools
	run_dbx 60 \
		"imgmount c \"$img\" -t hdd > nul" \
		"mkdir c:\\dos" \
		"copy y:\\dist\\*.* c:\\dos > nul" \
		"copy y:\\tools\\*.* c:\\dos > nul" \
		"exit"
}

# put IMG HOSTFILE DOSPATH...: copy host files into an HD image (no boot)
put() {
	local img=$1; shift
	local lines=("imgmount c \"$TW\\work\\$img\" -t hdd > nul")
	while [ $# -gt 1 ]; do
		lines+=("copy \"$1\" \"$2\" > nul"); shift 2
	done
	run_dbx 60 "${lines[@]}" "exit"
}

# boot_hd IMG [FLOPPYIMG] [TIMEOUT]
boot_hd() {
	local img=$1 fl=$2 to=${3:-300}
	local lines=()
	[ -n "$fl" ] && lines+=("imgmount 0 \"$TW\\work\\$fl\" -t floppy -fs none > nul")
	lines+=("imgmount 2 \"$TW\\work\\$img\" -t hdd -fs none > nul" "boot c: -noconvertfat")
	run_dbx "$to" "${lines[@]}"
}

# get IMG PATH-IN-IMAGE DESTDIR : extract with 7-Zip
get() {
	"$SEVENZ" e -y -o"$3" "$T/work/$1" "$2" > /dev/null
}
