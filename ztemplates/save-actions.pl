#!/usr/bin/perl

use  strict;
use File::Spec;

my $infile = $ARGV[0];
my $outdir = "@_REPLACE_MOZ_SRC_DIR@";
my ($volume,$directories,$file) = File::Spec->splitpath($infile);
my $outfile = `find $outdir -name $file.in`;
chomp($outfile);

if (length $outfile > 1) {
    open(my $fh, '<', $infile) or die $!;
    open(my $out, '>', $outfile) or die $!;
    my $skip = 0;
    while (<$fh>) {
        if ($skip == 1) {
            $skip = 0;
            next;
        }

        my $line = $_;
        if ($line =~ /^\/\/gen-var:/) {
            $line =~ s/^\/\/gen-var://;
            $skip = 1;
        } elsif ($line =~ /^\/\/gen-preproc:/) {
            $line =~ s/^\/\/gen-preproc://;
        }
        
        print $out $line;
    }
    close($fh);
    close($out);
} else {
    $outfile = `find $outdir -name $file`;
    if (length $outfile == 0) {
        # file was created in eclipse; add it to src/base
        system("cp $infile $outdir/$file");
    }
}
