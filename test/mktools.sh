#!/bin/bash
# mktools.sh - assemble tools/*.ASM into .COM files (MASM 5.10 + LINK /T)
T="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$T/../.." && pwd)"
W="$T/work/tools"
rm -rf "$W"; mkdir -p "$W"
cp "$T"/tools/*.ASM "$ROOT/MASM5.EXE" "$ROOT/LINK.EXE" "$W/"
: > "$W/RUN.BAT"
for f in "$T"/tools/*.ASM; do
	n=$(basename "$f" .ASM)
	printf 'masm5 %s; >> M.LOG\r\nlink /T %s; >> L.LOG\r\n' "$n" "$n" >> "$W/RUN.BAT"
done
timeout 120 /c/DOSBox-X/dosbox-x.exe -silent -nogui -nomenu -conf "$ROOT/_build/dbx.conf" \
	-c "mount c \"$(cygpath -w "$W")\"" -c "c:" -c "RUN.BAT" -c "exit" >/dev/null 2>&1
grep -E "^[^ ]+\([0-9]+\)|Severe|L[0-9]{4}" "$W/M.LOG" "$W/L.LOG" | grep -v " 0 Severe" | grep -v L4045
for f in "$T"/tools/*.ASM; do
	n=$(basename "$f" .ASM)
	if [ -f "$W/$n.COM" ]; then cp "$W/$n.COM" "$T/tools/"; echo "built $n.COM"; else echo "FAILED $n"; fi
done
