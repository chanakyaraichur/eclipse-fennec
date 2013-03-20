#!/usr/bin/perl

use strict;
use File::Spec;
use File::stat;

sub file_exists {
    `test -e $_[0]`;
    return ($? == 0);
}

my $outdir = "@_REPLACE_MOZ_SRC_DIR@";
my $pkg = "@_REPLACE_PACKAGE_NAME@";
my @pkgsplit = split(/\./, $pkg);
my $pkgname = @pkgsplit[-1];

sub copy_new_file {
    my $infile = $_[0];
    my $file = $_[1];

    my $existing = `find $outdir -name $file`;
    chomp $existing;
    if (length $existing == 0) {
        # file was created in eclipse; add it to working tree
        my $outfile = "$outdir/$file";
        system("cp $infile $outfile");
    }
}

my $infiles = `find res/ -type f`;
while ($infiles=~/^(.*)$/gm) {
    my $infile = $1;
    chomp($infile);
    my $outfile = "$outdir/$infile";
    $outfile =~ s|/res/|/resources/|;

    if (not file_exists($infile)) {
        # ignore missing files from dead links
        next;
    }

    open(my $fh, '<', $infile) or die $!;
    if (my $line = <$fh>) {
        chomp($line);
        if ($line ne "<!--gen-presource-->") {
            if (not stat($outfile)) {
                # file was created in eclipse; add it to working tree
                system("cp $infile $outfile");
            }
            next;
        }
    }

    if (stat "$outfile.in") {
        my $mtimedst = stat("$outfile.in")->mtime;
        my $mtimesrc = stat("$infile")->mtime;
        if ($mtimedst > $mtimesrc) {
            # dest is newer than src; abort
            next;
        }
    }

    open(my $out, '>', "$outfile.in") or die $!;

    while (<$fh>) {
        my $line = $_;
        if ($line =~ /^<!--gen-preproc:(.*)-->/) {
            $line = "$1\n";
        }
        $line =~ s/$pkg/\@ANDROID_PACKAGE_NAME@/g;

        print $out $line;
    }
    close($fh);
    close($out);
}

my $infiles = `find src/org/mozilla/gecko src/org/mozilla/$pkgname -name "*.java" -not -wholename "*/sync/*"`;
while ($infiles=~/^(.*)$/gm) {
    my $infile = $1;
    chomp($infile);
    my ($volume,$directories,$file) = File::Spec->splitpath($infile);

    if (not file_exists($infile)) {
        # ignore missing files from dead links
        next;
    }

    open(my $fh, '<', $infile) or die $!;
    if (my $line = <$fh>) {
        chomp($line);
        if ($line ne "//gen-presource") {
            copy_new_file($infile, $file);
            next;
        }
    }

    my $outfile = `find $outdir -name $file.in`;
    chomp($outfile);
    if (length $outfile == 0) {
        copy_new_file($infile, "$file.in");
        next;
    }

    if (stat "$outfile") {
        my $mtimedst = stat("$outfile")->mtime;
        my $mtimesrc = stat("$infile")->mtime;
        if ($mtimedst > $mtimesrc) {
            # dest is newer than src; abort
            next;
        }
    }

    open(my $out, '>', $outfile) or die $!;

    my $skip = 0;
    while (<$fh>) {
        if ($skip == 1) {
            $skip = 0;
            next;
        }

        my $line = $_;
        if ($line =~ /^\/\/gen-preproc:(.*)/) {
            $line = "$1\n";
        } elsif ($line =~ /^\/\/gen-var:(.*)/) {
            $line = "$1\n";
            $skip = 1;
        }

        print $out $line;
    }
    close($fh);
    close($out);
}
