# MI-CACHE

A disk cache for MS-DOS, written by Colin Mackie in 1992 as **MI Systems MI-CACHE
Version 1.0**. It is a TSR that hooks INT 13h and caches whole disk tracks for one
drive, keeping the cache in extended memory (XMS), expanded memory (EMS) or
conventional memory. Writes go straight through to the disk.

It is written in **MIL**, Colin's own 1993 pre-processor language for 8086 assembly,
which compiles to MASM source.

## What is in this repository

- **The original 1992 beta**, exactly as found in `MICACHE.ZIP`. It is the first
  commit, dated 4 March 1992 to match the newest file in the archive.
- **Bug fixes made in 2026**, one commit per fix, each explaining the bug it fixes.
  They are listed below.
- **A test harness** (`test/`) that boots real MS-DOS 6.22 and runs MI-CACHE against
  scripted disk workloads and injected faults. It compares the original build with the
  fixed one: each case that targets a bug fails on the original and passes on the fix.

## The fixes

| Commit subject | Problem in the original |
|---|---|
| Commit | Problem in the original |
|---|---|
| Fix redundant-write check dropping writes that differ only in the last byte | a write whose only change was its last byte was never written to disk |
| Size CTs from the real hard-disk geometry | on hard disks with more than 18 sectors per track, cached tracks overran their buffers and corrupted memory |
| Don't cache a floppy until its geometry is known | on 1.44M floppies, wrong sectors were read or written until the boot sector had been read |
| Invalidate the right CT when a read into the cache fails | a failed read zeroed a stray byte and left the overwritten track marked valid |
| Flush a drive's cache when it is formatted or written behind our back | stale data after a format; files copied back after reformatting could be skipped |
| Invalidate, rather than demote, a CT that a write partly overlaps | a locked track (the floppy boot track) kept stale data |
| Drop a CT when reading extra sectors into it fails | sectors overwritten by a failed read stayed marked valid |
| Pass a disk-changed error back, and flush the drive, instead of retrying it | a floppy change could go unnoticed, so the old disk's data and FAT were used |
| Map every EMS page a CT spans, not just two | large tracks in EMS read and wrote past the mapped pages |
| Cap the number of CTs to what the descriptor space holds | caches over about 9 MB overwrote the loader while it ran |
| Keep CTs and the temp track off 64K DMA boundaries | floppy reads failed with DMA boundary errors |
| Stop 'restoring' A20 with unbalanced XMS local enable/disable calls | A20 enable counts drifted, or A20 was turned off under another program |
| Close two gaps found in review of the earlier fixes | a disk change was missed on one path; up to 64K too much memory stayed resident |
| Check for a floppy disk change before serving a cache hit | raw reads after a floppy swap got the old disk's data |

Two other commits leave the code unchanged: one strips TopCopy end-of-file bytes from
the source, and `build.sh` confirms that the untouched source rebuilds the 1992
`MICACHE.EXE` byte for byte. A fix that cleared the direction flag on entry was later
reverted as unnecessary, because MIL emits a `CLD` before every string move.

## Using it

Load it from `AUTOEXEC.BAT` after `HIMEM.SYS`. A typical setup:

```
MICACHE C: 1024 -X
```

The arguments are the drive to cache, the cache size in KB (minimum 64) and the memory
type. Always give a size: without one, MI-CACHE takes all the extended or expanded
memory it can find.

| Option | Meaning |
|---|---|
| `-X` / `-E` / `-C` | cache in extended (XMS) / expanded (EMS) / conventional memory; with none of these it tries XMS, then EMS, then conventional |
| `-T:nn` | read `nn` sectors ahead on a miss (default: the rest of the track) |
| `-A` | write every write to disk, even when it matches what is cached |
| `-R` | read recently written sectors from disk rather than the cache |
| `-H` | show an "H" on screen at each cache hit |
| `-D` | start with caching disabled |
| `-M` | accepted, but has no effect in this version |

Once it is loaded, `MICACHE -M` shows the hit statistics (they reset when the cache is
flushed), `-F` flushes the cache, `-D` / `-E` disable and enable it, `-O` shows the
options in use, and `-U` unloads it. Don't run it alongside SMARTDRV or another disk
cache.

## Files

| File | |
|---|---|
| `MICACHE.MIL` | the cache, in MIL |
| `MICACHE.TCD` | the beta-test user manual (a TopCopy word-processor document) |
| `MICACHE.CTL`, `MA.BAT` | the original 1992 makefile and the batch file that runs it |
| `DB.BAT`, `TEST.BAT` | 1992 helpers: debug with SYMDEB; load the cache, run Norton SI, unload it |
| `CATCH13.MIL` | a 1992 INT 13h monitor that shows each disk read and write |
| `UMB.MIL` | a 1992 experiment with DOS 5 upper-memory-block allocation |
| `build.sh` | rebuild `out/MICACHE.EXE` under DOSBox-X |
| `test/` | the test harness: `suite.sh` (DOSBox-X), `vbox/` (VirtualBox floppy swaps), `tools/` (DOS test programs, with their source) |

## Building

`build.sh` runs MIL 1.25, MASM 5.10, LINK and MAPSYM inside
[DOSBox-X](https://dosbox-x.com/), from Git Bash on Windows. It expects `MIL.EXE`,
`MASM5.EXE`, `LINK.EXE` and `MAPSYM.EXE` in the directory above this one, a DOSBox-X
config at `../_build/dbx.conf`, and DOSBox-X in `C:\DOSBox-X`. None of these tools are
included here. The result is `out/MICACHE.EXE`.

## Testing

`test/suite.sh` boots MS-DOS 6.22 in DOSBox-X from throwaway disk images, once per case
and build. The 31 cases cover hard disks of several geometries, floppies, XMS, EMS and
conventional memory, random file workloads, and faults injected under the cache (read
errors, disk changes, DMA boundaries, formats). Each run is checked afterwards from the
disk images on the host. `suite.sh -l` lists the cases; results go to
`test/work/SUITE.TXT`.

It needs MS-DOS 6.22 (a boot floppy image in `test/iso/` and the DOS files in
`test/dist/`), which is not included, plus DOSBox-X, 7-Zip and Perl. To compare
against the original, put the 1992 `MICACHE.EXE` from `MICACHE.ZIP` in this
directory.

`test/vbox/` runs floppy-swap cases on a VirtualBox host, where the floppy can really
be changed under the running guest (`VBHOST=user@host test/vbox/vbcase.sh SWAP-RAW fix`;
the VM setup is in `vbrun.sh`). Note that VirtualBox's BIOS reports "disk changed"
on every check, so those runs can't exercise MI-CACHE's swap handling through DOS.

## License

MIT, see [LICENSE](LICENSE).
