#!/bin/bash
# suite.sh [-j N] [CASE...]   run MICACHE test cases, original vs fixed build
#
# Each case boots real MS-DOS 6.22 in DOSBox-X from throwaway copies of the
# base images, runs a scenario under MICACHE (with the FAULT13 fault
# injector loaded below it, and the probe tools), powers off, and is then
# checked on the host from the disk images. Runs are isolated in
# work/r/Rnnn, so several run at once (-j, default 4).
#
# Every case runs with both builds. A case that targets a bug expects the
# original to FAIL (showing the bug is real) and the fix to PASS; the others
# expect both to pass. Summary: work/SUITE.TXT. List cases: suite.sh -l
source "$(dirname "$0")/lib.sh"
cd "$T"
ORIG="$T/../MICACHE.EXE"
FIX="$T/../out/MICACHE.EXE"

# ---- base images and data ----------------------------------------------
# geometry of each base: cyls heads spt
declare -A GEOM=([HD17]="306 4 17" [HD26]="300 4 26" [HD35]="300 8 35" [HD63]="200 16 63" [FLOP]="80 2 18")

setup() {
	[ -d data/SRC ] || perl mkdata.pl data/SRC 30 1
	[ -d data/FLOP ] || perl mkdata.pl data/FLOP 40 2
	mkdir -p work/base
	local b
	for b in HD17 HD26 HD35 HD63; do
		[ -f work/base/$b.IMG ] && continue
		make_hd $b ${GEOM[$b]} && mv work/$b.IMG work/base/
	done
	if [ ! -f work/base/FLOP.IMG ]; then
		run_dbx 60 \
			"imgmake \"$TW\\work\\base\\FLOP.IMG\" -t fd_1440 -force > nul" \
			"imgmount a \"$TW\\work\\base\\FLOP.IMG\" -t floppy > nul" \
			"copy y:\\data\\FLOP\\*.* a:\\ > nul" "exit"
	fi
}

# ---- case definitions ----------------------------------------------------
# A case sets: BASE (HD image), FLOP (1 = floppy in A:), MODE (C|X|E),
# MEM (MB), EXPECT (fail|pass: what the ORIGINAL should do), WLSEED, and
# prints the scenario (TEST.BAT lines) on stdout; check_<kind> judges it.
CASES_ALL="COPY-HD17-C COPY-HD17-X COPY-HD17-E COPY-HD26-C COPY-HD35-X
 COPY-HD63-C COPY-HD63-X COPY-HD63-E FLOPPY-GEOM FORMAT BIGXMS DF A20
 ERR-READ ERR-READ-X ERR-EXTEND CHANGE DMA-C DMA-X LOCKED
 WL-HD17-C-1 WL-HD17-X-2 WL-HD17-E-3 WL-HD26-C-4 WL-HD35-X-5 WL-HD63-C-6
 WL-HD63-E-7 WL-HD17-C-8 WL-HD35-C-9 WL-HD63-X-10"

sec() { echo "SEC13 $* >> C:\\SEC.LOG"; }   # raw sector op, logged

define() { # CASE -> sets vars, prints scenario
	BASE=HD17 FLOP=0 MODE=C MEM=16 EXPECT=fail WLSEED= KIND=$1
	local c=$1
	case $c in
	COPY-*)
		KIND=copy
		local g=${c#COPY-}; BASE=${g%-*}; MODE=${g#*-}
		[ $MODE = C ] && echo 'MC C: 128 -C' || echo "MC C: 2048 -$MODE"
		echo 'MKDIR C:\DST'
		echo 'XCOPY C:\SRC\*.* C:\DST > NUL'
		echo 'MKDIR C:\DST2'
		echo 'XCOPY C:\DST\*.* C:\DST2 > NUL'
		echo 'QBASIC /RUN C:\PATCH.BAS' ;;
	WL-*)
		KIND=wl EXPECT=any
		local g=${c#WL-}; BASE=${g%%-*}; g=${g#*-}; MODE=${g%-*}; WLSEED=${g#*-}
		[ $MODE = C ] && echo 'MC C: 128 -C' || echo "MC C: 2048 -$MODE"
		echo 'MKDIR C:\WL'
		echo 'QBASIC /RUN C:\WL.BAS' ;;
	BIGXMS)
		KIND=copy MODE=X MEM=64
		echo 'MC C: -X'
		echo 'MKDIR C:\DST'
		echo 'XCOPY C:\SRC\*.* C:\DST > NUL'
		echo 'MKDIR C:\DST2'
		echo 'XCOPY C:\DST\*.* C:\DST2 > NUL'
		echo 'QBASIC /RUN C:\PATCH.BAS' ;;
	FLOPPY-GEOM)
		FLOP=1
		echo 'DIR A:\ > NUL'
		echo 'MC A: 128 -C'
		echo 'MKDIR C:\FDST'
		echo 'XCOPY A:\*.* C:\FDST > NUL'
		echo 'MKDIR A:\NEW'
		echo 'XCOPY C:\SRC\*.* A:\NEW > NUL' ;;
	FORMAT)
		FLOP=1
		echo 'MC A: 128 -C'
		echo 'MKDIR C:\FDST'
		echo 'XCOPY A:\*.* C:\FDST > NUL'
		echo 'FORMAT A: /U /V:FMT /AUTOTEST > NUL'
		echo 'XCOPY C:\FDST\*.* A:\ > NUL' ;;
	DF)
		echo 'MC C: 128 -C'
		echo 'DFPROBE > C:\PROBE.LOG' ;;
	A20)
		MODE=X
		echo 'MC C: 256 -X'
		echo 'A20PROBE > C:\PROBE.LOG' ;;
	ERR-READ|ERR-READ-X)  # fix 4: a failed read into a reused CT must not leave it valid
		MODE=${c#ERR-READ}; MODE=${MODE#-}; MODE=${MODE:-C}
		[ $MODE = X ] && EXPECT=any
		echo "MC C: 64 -$MODE"
		local cy; for cy in 10 11 12 13 14 15 16; do sec R 128 $cy 0 1 17 'C:\JUNK.BIN'; done
		echo 'FAULT13 E 128 1 4 1'
		sec R 128 17 0 1 17 'C:\JUNK.BIN'
		sec R 128 10 0 1 17 'C:\T.BIN' ;;
	ERR-EXTEND)  # fix 7: a failed extend must not leave the CT valid
		echo "MC C: 64 -C -T:2"
		sec R 128 20 0 5 1 'C:\JUNK.BIN'
		echo 'FAULT13 E 128 1 4 2'
		sec R 128 20 0 1 10 'C:\JUNK.BIN'
		sec R 128 20 0 5 3 'C:\T.BIN' ;;
	CHANGE)      # fix 8: a disk change seen by the cache must flush it
		FLOP=1
		echo 'MC A: 64 -C'
		sec R 0 0 0 1 1 'C:\JUNK.BIN'
		sec R 0 1 0 1 18 'C:\JUNK.BIN'
		sec R 0 2 0 1 18 'C:\JUNK.BIN'
		sec X 0 1 0 1 18 77
		echo 'FAULT13 C 0'
		sec R 0 3 0 1 18 'C:\JUNK.BIN'
		sec R 0 3 0 1 18 'C:\JUNK.BIN'
		sec R 0 1 0 1 18 'C:\T.BIN' ;;
	DMA-C|DMA-X) # fix 11: no CT (or temp track) may cross a 64K boundary
		FLOP=1 MODE=${c#DMA-}
		[ $MODE = C ] && echo 'MC A: 192 -C' || echo 'MC A: 192 -X'
		echo 'FAULT13 D 0'
		sec R 0 0 0 1 1 'C:\JUNK.BIN'
		local cy; for cy in $(seq 0 39); do sec R 0 $cy 1 1 18 'C:\JUNK.BIN'; done ;;
	LOCKED)      # fix 6: a write partly over the locked boot CT
		FLOP=1
		echo 'MC A: 64 -C -T:2'
		sec R 0 0 0 1 1 'C:\JUNK.BIN'
		sec W 0 0 0 3 3 55
		local cy; for cy in $(seq 1 10); do sec R 0 $cy 0 1 1 'C:\JUNK.BIN'; done
		sec R 0 0 0 3 1 'C:\T.BIN' ;;
	*) echo "unknown case $c" >&2; return 1 ;;
	esac
}

# ---- host-side checks ----------------------------------------------------
same() { # DIR-A DIR-B : every F*.DAT / W*.DAT of A is identical in B
	local bad=0 f
	for f in "$1"/[FW]*.DAT; do
		[ -e "$f" ] || continue
		cmp -s "$f" "$2/$(basename "$f")" || { bad=$((bad+1)); echo "differs: $(basename "$2")/$(basename "$f")"; }
	done
	return $bad
}
expected_patched() { # SRC OUT : SRC with each file's last byte flipped
	mkdir -p "$2"
	perl -e 'for my $f (glob("$ARGV[0]/F*.DAT")) { open(my $i,"<:raw",$f); local $/; my $d=<$i>;
		substr($d,-1,1)=chr(ord(substr($d,-1,1))^255); (my $o=$f)=~s{.*/}{$ARGV[1]/};
		open(my $h,">:raw",$o); print $h $d }' "$1" "$2"
}
rawsec() { # IMG BASE C H S N -> raw bytes of those sectors on stdout
	local g=(${GEOM[$2]})
	local lba=$(( ($3 * ${g[1]} + $4) * ${g[2]} + $5 - 1 ))
	dd if="$1" bs=512 skip=$lba count=$6 status=none
}
pattern() { # V N -> the SEC13 W pattern for N sectors of value V
	perl -e 'my ($v,$n)=@ARGV; for my $k (0..$n-1) { my $a=($v+$k*7)&255;
		for (1..512) { print chr($a); $a=($a+3)&255 } }' "$1" "$2"
}

check() { # CASE RUNDIR OUTDIR
	local c=$1 r=$2 d=$3
	[ -f "$d/c/DONE.LOG" ] || { echo "did not finish (crash or hang)"; return 1; }
	if grep -qiE "lost allocation|cross-linked|errors? found|Invalid|bad sectors" "$d/c/CHK.LOG" 2>/dev/null; then
		echo "CHKDSK: $(tr -d '\r' < "$d/c/CHK.LOG" | grep -iE "lost|cross|error|invalid|bad" | head -2 | tr '\n' ' ')"
		return 1
	fi
	case $KIND in
	copy)
		same data/SRC "$d/c/DST" || return 1
		rm -rf "$d/exp"; expected_patched data/SRC "$d/exp"
		same "$d/exp" "$d/c/DST2" ;;
	wl)
		local bad=0
		same "$r/wl/exp" "$d/c/WL" || bad=1
		local n1=$(ls "$r/wl/exp" | wc -l) n2=$(ls "$d/c/WL" 2>/dev/null | wc -l)
		[ $n1 = $n2 ] || { echo "file count $n2, expected $n1"; bad=1; }
		cmp -s <(tr -d '\r' < "$r/wl/R.EXP") <(tr -d '\r' < "$d/c/WL.LOG") || { echo "read-back checksums differ"; bad=1; }
		return $bad ;;
	FLOPPY-GEOM)
		same data/FLOP "$d/c/FDST" || return 1
		same data/SRC "$d/a/NEW" ;;
	FORMAT)
		same data/FLOP "$d/c/FDST" || return 1
		same data/FLOP "$d/a" ;;
	DF|A20)
		grep -q " OK" "$d/c/PROBE.LOG" || { echo "$(tr -d '\r' < "$d/c/PROBE.LOG")"; return 1; } ;;
	ERR-READ|ERR-READ-X)
		cmp -s "$d/c/T.BIN" <(rawsec "$r/RUN.IMG" HD17 10 0 1 17) || { echo "track re-read after a failed read is wrong"; return 1; } ;;
	ERR-EXTEND)
		cmp -s "$d/c/T.BIN" <(rawsec "$r/RUN.IMG" HD17 20 0 5 3) || { echo "sectors re-read after a failed extend are wrong"; return 1; } ;;
	CHANGE)
		cmp -s "$d/c/T.BIN" <(pattern 77 18) || { echo "read after disk change returned the old disk's data"; return 1; } ;;
	DMA-C|DMA-X)
		local n=$(grep -c "ERR 09" "$d/c/SEC.LOG")
		[ "$n" = 0 ] || { echo "$n reads failed with DMA boundary error 09"; return 1; } ;;
	LOCKED)
		cmp -s "$d/c/T.BIN" <(pattern 55 1) || { echo "read after a write over the locked boot track returned old data"; return 1; } ;;
	esac
}

# ---- run one case with one build -----------------------------------------
config_sys() {
	printf 'FILES=30\r\nBUFFERS=10\r\n'
	case $1 in
	X) printf 'DEVICE=C:\\DOS\\HIMEM.SYS /TESTMEM:OFF\r\n' ;;
	E) printf 'DEVICE=C:\\DOS\\HIMEM.SYS /TESTMEM:OFF\r\nDEVICE=C:\\DOS\\EMM386.EXE RAM 4096\r\n' ;;
	esac
}
patch_bas() {
	cat <<-'EOF' | crlf
	DIM b AS STRING * 1
	FOR i = 0 TO 29
	f$ = "C:\DST2\F" + RIGHT$("0" + LTRIM$(STR$(i)), 2) + ".DAT"
	OPEN f$ FOR BINARY AS #1
	n& = LOF(1)
	GET #1, n&, b
	b = CHR$(ASC(b) XOR 255)
	PUT #1, n&, b
	CLOSE #1
	NEXT
	SYSTEM
	EOF
}

run_one() { # CASE BUILD ID
	local c=$1 b=$2 id=$3
	local r="$T/work/r/$id" rw="$TW\\work\\r\\$id" ry="y:\\work\\r\\$id"
	local d="$T/work/res/$c-$b"
	rm -rf "$r" "$d"; mkdir -p "$r" "$d"
	define $c > "$r/SCEN.TXT" || return
	cp work/base/$BASE.IMG "$r/RUN.IMG"
	[ $FLOP = 1 ] && cp work/base/FLOP.IMG "$r/FD.IMG"
	config_sys $MODE > "$r/CONFIG.SYS"
	printf '@ECHO OFF\r\nPATH C:\\DOS;C:\\\r\nFAULT13 > NUL\r\nCALL C:\\TEST.BAT\r\nPOWEROFF\r\n' > "$r/AUTOEXEC.BAT"
	{
		cat "$r/SCEN.TXT"
		echo 'SCRDUMP'
		echo 'CLS'
		echo 'MC /M'
		echo 'FAULT13 S'
		echo 'SCRDUMP'
		echo 'CHKDSK C: > C:\CHK.LOG'
		echo 'ECHO DONE > C:\DONE.LOG'
	} | crlf > "$r/TEST.BAT"
	patch_bas > "$r/PATCH.BAS"
	[ $b = orig ] && cp "$ORIG" "$r/MC.EXE" || cp "$FIX" "$r/MC.EXE"
	local extra=()
	if [ -n "$WLSEED" ]; then
		perl wl.pl $WLSEED 300 "$r/wl"
		cp "$r/wl/WL.TXT" "$r/WL.TXT"; crlf < guest/WL.BAS > "$r/WL.BAS"
		extra=("copy $ry\\WL.TXT c:\\ > nul" "copy $ry\\WL.BAS c:\\ > nul")
	fi
	# stage into the image (DOSBox-X's own DOS, not booted)
	printf '%s\r\n' "imgmount c \"$rw\\RUN.IMG\" -t hdd > nul" \
		"copy $ry\\CONFIG.SYS c:\\ > nul" "copy $ry\\AUTOEXEC.BAT c:\\ > nul" \
		"copy $ry\\TEST.BAT c:\\ > nul" "copy $ry\\PATCH.BAS c:\\ > nul" \
		"copy $ry\\MC.EXE c:\\ > nul" "copy y:\\tools\\*.COM c:\\dos > nul" \
		"${extra[@]}" \
		"mkdir c:\\src" "copy y:\\data\\SRC\\*.* c:\\src > nul" "exit" > "$r/STAGE.BAT"
	local boot=()
	[ $FLOP = 1 ] && boot+=("imgmount 0 \"$rw\\FD.IMG\" -t floppy -fs none > nul")
	boot+=("imgmount 2 \"$rw\\RUN.IMG\" -t hdd -fs none > nul" "boot c: -noconvertfat")
	printf '%s\r\n' "${boot[@]}" > "$r/BOOT.BAT"
	cat > "$r/boot.conf" <<-EOF
	[dosbox]
	memsize=$MEM
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
	local go=("$DBX" -silent -nogui -nomenu -conf "$(cygpath -w "$r/boot.conf")" -c "mount y \"$TW\"" -c "y:")
	timeout 60 "${go[@]}" -c "work\\r\\$id\\STAGE.BAT" >/dev/null 2>&1
	local t0=$SECONDS
	timeout 240 "${go[@]}" -c "work\\r\\$id\\BOOT.BAT" >/dev/null 2>&1
	local rc=$? dt=$((SECONDS - t0))
	"$SEVENZ" x -y -o"$d/c" "$r/RUN.IMG" > /dev/null 2>&1
	[ $FLOP = 1 ] && "$SEVENZ" x -y -o"$d/a" "$r/FD.IMG" > /dev/null 2>&1
	local out res
	if out=$(check $c "$r" "$d" 2>&1); then res=PASS; else res=FAIL; fi
	[ $rc = 124 ] && out="timed out; $out"
	local verdict=ok
	if [ $b = fix ] && [ $res != PASS ]; then verdict=BAD; fi
	if [ $b = orig ] && [ $EXPECT = fail ] && [ $res = PASS ]; then verdict=NOREPRO; fi
	printf '%-14s %-4s %-4s %-7s %3ss  %s\n' "$c" "$b" "$res" "$verdict" "$dt" \
		"$(echo "$out" | head -3 | tr '\n' ';' | cut -c1-110)" >> work/SUITE.TXT
	[ "$KEEP" ] || rm -f "$r/RUN.IMG" "$r/FD.IMG"
}

# ---- main ----------------------------------------------------------------
J=4
while getopts "j:lk" o; do
	case $o in
	j) J=$OPTARG ;;
	l) echo $CASES_ALL | tr ' ' '\n'; exit 0 ;;
	k) KEEP=1 ;;
	esac
done
shift $((OPTIND - 1))
if [ "$1" = --one ]; then run_one "$2" "$3" "$4"; exit; fi
[ -f "$FIX" ] || { echo "build first: ../build.sh"; exit 1; }
CASES=${*:-$CASES_ALL}
setup
mkdir -p work/r work/res
echo "=== $(date)  ($(echo $CASES | wc -w) cases x 2 builds, -j $J)" >> work/SUITE.TXT
n=0
for c in $CASES; do
	for b in orig fix; do
		n=$((n + 1)); printf '%s %s R%03d\n' "$c" "$b" $n
	done
done | xargs -P "$J" -L 1 bash "$0" ${KEEP:+-k} --one
echo "--- summary: $(grep -c ' BAD ' work/SUITE.TXT) BAD, $(grep -c NOREPRO work/SUITE.TXT) NOREPRO (whole file)"
