#!/usr/bin/perl
# mkdata.pl DIR N SEED - write N deterministic pseudo-random test files
# F00.DAT .. into DIR. Sizes mix odd sizes and whole sectors (so a file's
# last byte is the last byte of a sector).
use strict;
my ($dir, $n, $seed) = @ARGV;
use File::Path qw(make_path); make_path($dir);
my $x = $seed || 1;
sub rnd { $x = ($x * 1103515245 + 12345) & 0x7fffffff; return $x >> 8; }
for my $i (0 .. $n - 1) {
    my $size = ($i % 3 == 0) ? 512 * (1 + rnd() % 60) : 1 + rnd() % 40000;
    my $data = '';
    $data .= chr(rnd() & 255) for 1 .. $size;
    open(my $fh, '>:raw', sprintf("%s/F%02d.DAT", $dir, $i)) or die;
    print $fh $data;
    close $fh;
}
