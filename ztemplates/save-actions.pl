#!/usr/bin/perl

open(MYFILE, ">>/tmp/lock") || die;
flock(MYFILE, 2) || die;

system("echo 'running...' >> /tmp/run.log");

use  strict;
use File::Spec;

my $outdir = "@_REPLACE_MOZ_SRC_DIR@";
my $pkg = "@_REPLACE_PACKAGE_NAME@";
my @pkgsplit = split(/\./, $pkg);
my $pkgname = @pkgsplit[-1];

my $sources_index=`cat scripts/sources.index`;
my $sources = {};
while ($sources_index =~ /^(.*)$/gm) {
  my $line = $1;
  my @splitline = split(/:/, $line);
  $sources->{@splitline[2]} = { "src" => @splitline[1],
                                "type" => @splitline[0],
                                "found" => 0 };
}

my $infiles = `find res/ -type f -o -type l`;
while ($infiles=~/^(.*)$/gm) {
    my $infile = $1;
    chomp($infile);
    my $outfile = "$outdir/$infile";
    $outfile =~ s|/res/|/resources/|;
    my $entry = $sources->{$infile};

    my $stat = stat $infile;
    if (length $stat > 0) {
        #print "  found\n";
    } else {
        #BRN: should be fixed with file removals
        print "$infile not found\n";
        next;
    }

    open(my $fh, '<', $infile) or die $!;
    my $line = <$fh>;
    chomp($line);
    if ($line ne "<!--gen-presource-->") {
        if (length $entry == 0) {
            # file was created in eclipse; add it to working tree
            $sources->{$infile} = { "src" => $outfile,
                                    "type" => "link",
                                    "found" => 1 };
            system("cp $infile $outfile &> /dev/null");
            system("ln -sf $outfile $infile");
        } else {
            # link already exists; mark it as found
            $sources->{$infile}->{"found"} = 1;
        }
        next;
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

    if (length $entry == 0) {
        # file was created in eclipse; add it to working tree
        $sources->{$infile} = { "src" => $outfile,
                                "type" => "presource",
                                "found" => 1 };
    } else {
        # presource already exists; mark it as found
        $sources->{$infile}->{"found"} = 1;
    }
}


my $infiles = `find src -name "*.java"`;
while ($infiles=~/^(.*)$/gm) {
    my $infile = $1;
    chomp($infile);
    my ($volume,$directories,$file) = File::Spec->splitpath($infile);
    my $entry = $sources->{$infile};

    my $stat = stat $infile;
    if (length $stat > 0) {
        #print "  found\n";
    } else {
        #BRN: should be fixed with file removals
        print "$infile not found\n";
        system("echo '$infile not found' >> /tmp/run.log");
        next;
    }

    open(my $fh, '<', $infile) or die $!;
    my $line = <$fh>;
    chomp($line);
    if ($line ne "//gen-presource") {
        if (length $entry == 0) {
            # file was created in eclipse; add it to working tree
            my $outfile = "$outdir/$file";
            $sources->{$infile} = { "src" => $outfile,
                                    "type" => "link",
                                    "found" => 1 };
            system("cp $infile $outfile");
            system("ln -sf $outfile $infile");
        } else {
            # link already exists; mark it as found
            $entry->{"found"} = 1;
        }
        next;
    }

    my $outfile = "$outdir/$file.in";
    if (length $entry > 0) {
        $outfile = $entry->{"src"};
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

    if (length $entry == 0) {
        # file was created in eclipse; add it to working tree
        $sources->{$infile} = { "src" => $outfile,
                                "type" => "presource",
                                "found" => 1 };
    } else {
        # presource already exists; mark it as found
        $entry->{"found"} = 1;
    }
}

open(my $sources_index_fh, '>', "scripts/sources.index");
foreach my $key ( keys $sources ) {
  my $entry = $sources->{$key};
  if ($entry->{"found"} == 1) {
      # file found; write it back out
      print $sources_index_fh "$entry->{type}:$entry->{src}:$key\n";
  } else {
      # file not found in eclipse; delete it from tree
      system("echo 'removing $key' >> /tmp/run.log");
      system("rm $entry->{src}");
      system("echo 'done removing $key' >> /tmp/run.log");
  }
}
close($sources_index_fh);
system("echo 'closing index' >> /tmp/run.log\n");

close(MYFILE);
