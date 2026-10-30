#!/bin/bash
# vbcase.sh CASE BUILD   run one floppy-swap case on the VirtualBox host
#
# Real media changes, which DOSBox-X cannot make: the guest asks for a swap
# with COMWAIT (see vbrun.sh) and the host puts another image in drive A:.
# The run is staged here (DOSBox-X's own DOS, not booted), copied to the host,
# booted there by vbrun.sh, then copied back and checked here. One run at a
# time; the host's VM is used by nothing else.
#
# BUILD: orig, fix, none (no MICACHE: the control) or a work/exe name.
# Cases:
#   SWAP-RAW  cache a floppy track with raw INT 13h reads, swap, read it
#             twice more: the reads that succeed must give the new disk
#   SWAP-DOS  copy floppy 1 through DOS (FAT and root now cached), swap,
#             list A: and copy a file onto floppy 2, swap back and copy
#             floppy 1 again: both disks must end up exactly right
#   SWAP-DIAG copy floppy 1 twice, swap, list A:, with the cache's counters
#             (MC /M) in SCREEN.TXT after each step: no pass/fail
#   SWAP-CHG  CHG13 probes of the change line (CHG.TXT) before and after a
#             swap: no pass/fail
# Result line appended to work/VBOX.TXT; files in work/vbres/CASE-BUILD.
source "$(dirname "$0")/../lib.sh"
cd "$T"
HOST=user@vboxhost
SSH=(ssh -i "$HOME/.ssh/id_rsa" -o BatchMode=yes $HOST)
SCP=(scp -q -i "$HOME/.ssh/id_rsa" -o BatchMode=yes)
c=$1 b=$2
case $c in SWAP-RAW|SWAP-DOS|SWAP-DIAG|SWAP-CHG) ;; *) echo "unknown case: $c" >&2; exit 1 ;; esac
case $b in
orig) exe=$T/../MICACHE.EXE ;; fix) exe=$T/../out/MICACHE.EXE ;; none) exe= ;;
*[!A-Za-z0-9_-]*) echo "bad build: $b" >&2; exit 1 ;;
*) exe=$T/work/exe/$b.EXE ;;
esac
[ -z "$exe" ] || [ -f "$exe" ] || { echo "no $exe" >&2; exit 1; }
[ -f work/base/FLOP2.IMG ] || { echo "no work/base/FLOP2.IMG" >&2; exit 1; }

id=$c-$b d=$T/work/vbres/$id
r=$T/work/vb/RUN rw="$TW\\work\\vb\\RUN" ry="y:\\work\\vb\\RUN"   # 8.3 names for DOSBox-X
rm -rf "$r" "$d"; mkdir -p "$r" "$d"
mc() { [ -n "$exe" ] && echo "MC $*"; }
sec() { echo "SEC13 $* >> C:\\SEC.LOG"; }
stats() { [ -n "$exe" ] && printf 'CLS\nMC /M\nSCRDUMP\n'; }   # counters since the last flush
{
	case $c in
	SWAP-RAW)
		mc A: 64 -C
		sec R 0 0 0 1 1 'C:\JUNK.BIN'
		sec R 0 1 0 1 18 'C:\JUNK.BIN'
		sec R 0 1 0 1 18 'C:\JUNK.BIN'
		echo 'COMWAIT SWAP 2'
		sec R 0 1 0 1 18 'C:\T.BIN'
		sec R 0 1 0 1 18 'C:\T.BIN' ;;
	SWAP-DOS)
		mc A: 128 -C
		echo 'MKDIR C:\FD1'
		echo 'XCOPY A:\*.* C:\FD1 > NUL'
		echo 'COMWAIT SWAP 2'
		echo 'DIR A:\ > C:\D2.TXT'
		echo 'COPY C:\SRC\F00.DAT A:\ > NUL'
		echo 'COMWAIT SWAP 1'
		echo 'MKDIR C:\FD1B'
		echo 'XCOPY A:\*.* C:\FD1B > NUL' ;;
	SWAP-DIAG)
		mc A: 128 -C
		echo 'MKDIR C:\FD1'
		echo 'XCOPY A:\*.* C:\FD1 > NUL'
		stats
		echo 'MKDIR C:\FD1C'
		echo 'XCOPY A:\*.* C:\FD1C > NUL'
		stats
		echo 'COMWAIT SWAP 2'
		echo 'DIR A:\ > C:\D2.TXT'
		stats ;;
	SWAP-CHG)
		mc A: 128 -C
		echo 'CHG13 >> C:\CHG.TXT'
		echo 'DIR A:\ > NUL'
		echo 'CHG13 >> C:\CHG.TXT'
		echo 'COMWAIT SWAP 2'
		echo 'CHG13 >> C:\CHG.TXT'
		echo 'CHG13 >> C:\CHG.TXT' ;;
	esac
	echo 'SCRDUMP'
	echo 'CLS'
	mc /M
	echo 'SCRDUMP'
	echo 'ECHO DONE > C:\DONE.LOG'
} | crlf > "$r/TEST.BAT"
crlf > "$r/AUTOEXEC.BAT" <<'EOF'
@ECHO OFF
PATH C:\DOS;C:\
CALL C:\TEST.BAT
POWEROFF
EOF
printf 'FILES=30\nBUFFERS=10\n' | crlf > "$r/CONFIG.SYS"
cp work/base/HD17.IMG "$r/RUN.IMG"
cp work/base/FLOP.IMG "$r/FD1.IMG"
cp work/base/FLOP2.IMG "$r/FD2.IMG"
[ -n "$exe" ] && cp "$exe" "$r/MC.EXE"
lines=("imgmount c \"$rw\\RUN.IMG\" -t hdd > nul"
	"copy $ry\\CONFIG.SYS c:\\ > nul" "copy $ry\\AUTOEXEC.BAT c:\\ > nul"
	"copy $ry\\TEST.BAT c:\\ > nul" "copy y:\\tools\\*.COM c:\\dos > nul"
	"mkdir c:\\src" "copy y:\\data\\SRC\\*.* c:\\src > nul")
[ -n "$exe" ] && lines+=("copy $ry\\MC.EXE c:\\ > nul")
run_dbx 60 "${lines[@]}" "exit" || { echo "staging failed" >&2; exit 1; }

# run on the host
rdir=micache-vbox/runs/$id
"${SSH[@]}" "rm -rf ~/$rdir && mkdir -p ~/$rdir" || exit 1
"${SCP[@]}" "$r/RUN.IMG" "$r/FD1.IMG" "$r/FD2.IMG" $HOST:$rdir/ || exit 1
out=$("${SSH[@]}" "cd ~/$rdir && ~/micache-vbox/vbrun.sh RUN.IMG 306 4 17 FD1.IMG ${VBTO:-120}")
rc=$?
rm -f "$r"/*.IMG
for f in RUN.IMG FD1.IMG FD2.IMG; do
	"${SCP[@]}" $HOST:"$rdir/$f" "$r/" || { echo "could not fetch $f" >&2; exit 1; }
done
"${SCP[@]}" $HOST:"$rdir/COM.LOG" "$d/" 2>/dev/null
"${SCP[@]}" $HOST:"$rdir/HANG.png" "$d/" 2>/dev/null
"$SEVENZ" x -y -o"$d/c" "$r/RUN.IMG" > /dev/null 2>&1
"$SEVENZ" x -y -o"$d/a1" "$r/FD1.IMG" > /dev/null 2>&1
"$SEVENZ" x -y -o"$d/a2" "$r/FD2.IMG" > /dev/null 2>&1

# ---- check -----------------------------------------------------------------
same() { # DIR1 DIR2: same files, same contents
	diff -r -q "$1" "$2" > /dev/null 2>&1 || { echo "$(basename "$2") differs from $(basename "$1")"; return 1; }
}
fdtrack() { # IMG CYL HEAD -> that track's 18 sectors
	dd if="$1" bs=512 skip=$(( ($2 * 2 + $3) * 18 )) count=18 status=none
}
check() {
	[ -f "$d/c/DONE.LOG" ] || { echo "test did not finish"; return 1; }
	case $c in
	SWAP-RAW)
		local n=$(grep -c " OK" "$d/c/SEC.LOG") sz=$(stat -c %s "$d/c/T.BIN" 2>/dev/null || echo 0)
		[ $sz -gt 0 ] || { echo "no read after the swap succeeded"; return 1; }
		local k ok=1
		for ((k = 0; k < sz / 9216; k++)); do
			cmp -s <(dd if="$d/c/T.BIN" bs=9216 skip=$k count=1 status=none) <(fdtrack "$r/FD2.IMG" 1 0) || ok=0
		done
		echo "after swap: $(tail -2 "$d/c/SEC.LOG" | tr -d '\r' | sed 's/.*\(OK\|ERR ..\)$/\1/' | tr '\n' ' ')"
		[ $ok = 1 ] || { echo "read after the swap returned the old disk's track"; return 1; } ;;
	SWAP-DOS)
		local bad=0
		same data/FLOP "$d/c/FD1" || bad=1
		grep -q "SECOND" "$d/c/D2.TXT" || { echo "DIR after the swap did not show floppy 2"; bad=1; }
		[ -f "$d/a2/SECOND.TXT" ] && cmp -s "$d/a2/F00.DAT" data/SRC/F00.DAT ||
			{ echo "floppy 2 wrong: $(ls "$d/a2" | tr '\n' ' ')"; bad=1; }
		[ $(ls "$d/a2" | wc -l) = 2 ] || { echo "floppy 2 has $(ls "$d/a2" | wc -l) files"; bad=1; }
		same data/FLOP "$d/a1" || bad=1
		same data/FLOP "$d/c/FD1B" || bad=1
		return $bad ;;
	esac
}
if res=$(check 2>&1); then v=PASS; else v=FAIL; fi
[ $rc = 124 ] && res="timed out; $res"
printf '%-9s %-5s %-4s %s  %s\n' "$c" "$b" "$v" "$(echo "$out" | grep -o '[0-9]*s$')" \
	"$(echo "$res" | grep -v '^$' | head -3 | tr '\n' ';' | cut -c1-110)" | tee -a work/VBOX.TXT
