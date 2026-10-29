#!/usr/bin/perl
# wl.pl SEED NOPS OUTDIR - make a random file workload for WL.BAS
#
# Writes OUTDIR/WL.TXT (the ops, read by WL.BAS in the guest), and the
# expected results: OUTDIR/exp/W??.DAT (final files) and OUTDIR/R.EXP (the
# checksum each R op must print). Content is a pure function of the op's seed
# and the byte position, computed the same way in WL.BAS, so every sector of
# every write is distinct and a misplaced or stale sector is detectable.
#
# Op lines:  W,file,offset,len,seed   write len bytes at offset (extends)
#            K,file                   delete
#            C,from,to                copy whole file
#            R,file                   read whole file, print checksum
use strict;
use File::Path qw(make_path remove_tree);
my ($seed, $nops, $out) = @ARGV;
remove_tree("$out/exp"); make_path("$out/exp");
my $x = $seed;
sub rnd { my $n = shift; $x = ($x * 1103515245 + 12345) & 0x7fffffff; return ($x >> 8) % $n; }

my $NF = 12;            # files W00..W11
my $MAX = 30000;        # QBasic strings are < 32K
my @f;                  # model: file contents (undef = absent)
my $base = join '', map { chr((($_ * 7) + int($_ / 3)) & 255) } 0 .. 1023;

sub content {           # same as FUNCTION Gen$ in WL.BAS
	my ($s, $len) = @_;
	my $d = '';
	for (my $k = 0; length($d) < $len; $k++) {
		$d .= substr($base, ($s + $k * 61) % 512, 512);
	}
	return substr($d, 0, $len);
}
sub cksum {             # same as WL.BAS: sum and position-weighted sum, mod 65536
	my ($d) = @_;
	my ($a, $b) = (0, 0);
	for my $i (0 .. length($d) - 1) {
		my $c = ord(substr($d, $i, 1));
		$a = ($a + $c) % 65536;
		$b = ($b + $c * (($i % 251) + 1)) % 65536;
	}
	return "$a $b";
}

open(my $ops, '>:raw', "$out/WL.TXT") or die;
open(my $rexp, '>:raw', "$out/R.EXP") or die;
my $n = 0;
while ($n < $nops) {
	my $k = rnd(100);
	my $i = rnd($NF);
	if ($k < 55) {                                  # write
		my $cur = defined $f[$i] ? length $f[$i] : 0;
		my $off = ($cur && rnd(3)) ? rnd($cur) : (rnd(2) ? $cur : 0);
		$off = int($off / 512) * 512 if rnd(2);         # often sector aligned
		my $len = rnd(2) ? 512 * (1 + rnd(12)) : 1 + rnd(7000);
		next if $off + $len > $MAX;
		my $s = rnd(512);
		my $d = defined $f[$i] ? $f[$i] : '';
		$d .= "\0" x ($off - length $d) if $off > length $d;
		substr($d, $off, $len) = content($s, $len);
		$f[$i] = $d;
		print $ops "W,$i,$off,$len,$s\r\n";
	} elsif ($k < 65) {                             # delete
		next unless defined $f[$i];
		undef $f[$i];
		print $ops "K,$i\r\n";
	} elsif ($k < 80) {                             # copy
		my $j = rnd($NF);
		next unless defined $f[$i] && $i != $j;
		$f[$j] = $f[$i];
		print $ops "C,$i,$j\r\n";
	} else {                                        # read back
		next unless defined $f[$i];
		print $ops "R,$i\r\n";
		print $rexp cksum($f[$i]), "\r\n";
	}
	$n++;
}
print $ops "E\r\n";
close $ops; close $rexp;
for my $i (0 .. $NF - 1) {
	next unless defined $f[$i];
	open(my $h, '>:raw', sprintf("%s/exp/W%02d.DAT", $out, $i)) or die;
	print $h $f[$i];
	close $h;
}
