#!/usr/bin/perl

use  strict;
use File::Spec;

# rebuilds a single presource
my $builddir = "@_REPLACE_OBJ_PROJECT_PATH@";
my ($volume,$directories,$file) = File::Spec->splitpath($ARGV[0]);
my $objfilepath = `find $builddir -name $file`;
$objfilepath=~s/$builddir\///;
system("make $objfilepath");
