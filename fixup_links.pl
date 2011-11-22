#!/usr/bin/perl

use  strict;
use File::Spec;
use Data::Dumper;

my $MOZOBJDIR="";
my $MOZSRCDIR="";
my $configFile=`cat mozconfig_values`;
while ($configFile=~/^(.*)$/gm) {
  my $line = $1;
  if ($line=~/MOZOBJDIR\s*\=\s*(.*)/) {
    $MOZOBJDIR=$1;
  }
  if ($line=~/MOZSRCDIR\s*\=\s*(.*)/) {
    $MOZSRCDIR=$1;
  }
}
print "OBJ:".$MOZOBJDIR."\n";
print "SRC:".$MOZSRCDIR."\n";
my $MOZAPPDIR="";
my $MOZAPPNAME="";
my $autoConfR = `cat $MOZOBJDIR/config/autoconf.mk`;
while ($autoConfR=~/^(.*)$/gm) {
  my $line = $1;
  if ($line=~/^MOZ_BUILD_APP\s*\=\s*(.*)$/) {
    $MOZAPPDIR=$1;
  }
  if ($line=~/^MOZ_APP_NAME\s*\=\s*(.*)$/) {
    $MOZAPPNAME=$1;
  }
}

print "APPDIR:".$MOZAPPDIR."\n";
my $manifest = `find $MOZOBJDIR/$MOZAPPDIR -name AndroidManifest.xml`;
chomp($manifest);
my $smanifest = `find $MOZSRCDIR/$MOZAPPDIR -name AndroidManifest.xml.in`;
chomp($smanifest);
my ($manovolume,$manodirectories,$manofile) = File::Spec->splitpath($manifest);
my ($mansvolume,$mansdirectories,$mansfile) = File::Spec->splitpath($smanifest);
print "Adding Manifest from: $manifest\n";
my $mainactivityname = "";
open(my $mfh, '<', $manifest) or die $!;
while (<$mfh>) {
  if (/\<activity android\:name\=\"(.*)\"/) {
    $mainactivityname = $1;
    print "Main Activity:".$mainactivityname."\n";
    close($mfh);
  }
}
close($mfh);

my $resources = `find $MOZOBJDIR/dist -name "*.apk"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  if ($resdir=~/$MOZAPPNAME/) {
    my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
    if (stat("bin/$mainactivityname.apk")) {
      unlink("bin/$mainactivityname.apk");
    }
    symlink($resdir, "bin/$mainactivityname.apk");
  }
}

$resources = `find $manodirectories -type f -name "*.ap_"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
  if (stat("bin/resources.ap_")) {
    unlink("bin/resources.ap_");
  }
  symlink($resdir, "bin/resources.ap_");
}

$resources = `find $manodirectories -type f -name "*.dex"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
  if (stat("bin/classes.dex")) {
    unlink("bin/classes.dex");
  }
  symlink($resdir, "bin/classes.dex");
}

