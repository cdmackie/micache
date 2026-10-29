#!/bin/bash
# Rebuild MICACHE.EXE from MICACHE.MIL under DOSBox-X (MIL 1.25 + MASM 5.10 + LINK).
# Builds in a scratch dir; output EXE/MAP/SYM + logs land in ./out.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
W="$HERE/out"
rm -rf "$W"; mkdir -p "$W"
cp "$HERE/MICACHE.MIL" "$ROOT/MIL.EXE" "$ROOT/MASM5.EXE" "$ROOT/LINK.EXE" "$ROOT/MAPSYM.EXE" "$W/"
printf 'mil -p micache > MIL.LOG\r\nmasm5 micache /Z; > MASM.LOG\r\nlink micache /m; > LINK.LOG\r\nmapsym micache.map > SYM.LOG\r\n' > "$W/RUN.BAT"
timeout 300 /c/DOSBox-X/dosbox-x.exe -silent -nogui -nomenu -conf "$ROOT/_build/dbx.conf" \
  -c "mount c \"$(cygpath -w "$W")\"" -c "c:" -c "RUN.BAT" -c "exit" >/dev/null 2>&1 || true
rm -f "$W"/MIL.EXE "$W"/MASM5.EXE "$W"/LINK.EXE "$W"/MAPSYM.EXE "$W"/MICACHE.MIL "$W"/RUN.BAT
grep -E "Errors|error|Error" "$W/MASM.LOG" "$W/LINK.LOG" "$W/MIL.LOG" || true
grep -B2 -iE "error|unknown|invalid" "$W/MIL.LOG" | grep -v "^--" | head -20 || true
ls -l "$W/MICACHE.EXE" 2>/dev/null || echo "NO EXE"
