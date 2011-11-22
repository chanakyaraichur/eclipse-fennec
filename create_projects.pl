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
print "APPNAME:".$MOZAPPNAME."\n";
print "APPDIR:".$MOZAPPDIR."\n";
my $manifest = `find $MOZOBJDIR/$MOZAPPDIR -name AndroidManifest.xml`;
if (stat("AndroidManifest.xml")) {
  unlink("AndroidManifest.xml");
}
chomp($manifest);
my $smanifest = `find $MOZSRCDIR/$MOZAPPDIR -name AndroidManifest.xml.in`;
chomp($smanifest);
my ($manovolume,$manodirectories,$manofile) = File::Spec->splitpath($manifest);
my ($mansvolume,$mansdirectories,$mansfile) = File::Spec->splitpath($smanifest);
system("ln -s $manifest > /dev/null");
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
system("sed 's|android:debuggable=\"false\"|android:debuggable=\"true\"|' -i $manifest");

mkdir("src");
my $sources = `find $mansdirectories -name *.java`;
print "sources:".$sources.", mansdir: $mansdirectories \n";
while ($sources=~/^(.*)$/gm) {
  my $source = $1;
  open(my $fh, '<', $source) or die $!;
  while (<$fh>) {
    if (/^package\s+(.*)\;/) {
      my $namespace = $1;
      my $path = $namespace;
      $path=~s/\./\//g;
      my ($volume,$directories,$file) = File::Spec->splitpath($source);
      print "Link $source > src/$path/$file\n";
      if (stat("src/$path/$file")) {
        unlink("src/$path/$file");
      }
      system("mkdir -p src/$path");
      symlink($source, "src/$path/$file");
    }
  }
  close($fh);
}

my $presources = `find $mansdirectories -name *.java.in`;
while ($presources=~/^(.*)$/gm) {
  my $source = $1;
  mkdir("src/presources");
  my ($volume,$directories,$file) = File::Spec->splitpath($source);
  $file=~s/\.in$//g;
  print "$source > src/presources/$file\n";
  if (stat("src/presources/$file")) {
    unlink("src/presources/$file");
  }
  symlink($source, "src/presources/$file");
}

my $gensources = `find $manodirectories -name *.java`;
while ($gensources=~/^(.*)$/gm) {
  my $source = $1;
  open(my $fh, '<', $source) or die $!;
  while (<$fh>) {
    if (/^package\s+(.*)\;/) {
      my $namespace = $1;
      my $path = $namespace;
      $path=~s/\./\//g;
      my ($volume,$directories,$file) = File::Spec->splitpath($source);
      print "Link $source > src/$path/$file\n";
      if (stat("gen/$path/$file")) {
        unlink("gen/$path/$file");
      }
      system("mkdir -p gen/$path");
      symlink($source, "gen/$path/$file");
    }
  }
  close($fh);
}

my $resources = "";
my $stop = 0;
system("rm -rf ./res");
mkdir("res");

$resources = `find $mansdirectories -name "*.png" -o -name "*.xml"`;
$stop = 0;
while ($resources=~/^(.*)$/gm && $stop == 0) {
  my $resource = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resource);
  my @dirs = File::Spec->splitdir($directories);
  my $folder = $dirs[scalar(@dirs)-2];
  print "resource: $resource, fold:$folder, file:$file\n";
  if (stat("res/$folder/$file")) {
    unlink("res/$folder/$file");
  }
  system("mkdir -p res/$folder");
  symlink($resource, "res/$folder/$file");
}

$resources = `find $manodirectories -name "*.png" -o -name "*.xml"`;
while ($resources=~/^(.*)$/gm && $stop == 0) {
  my $resource = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resource);
  next if ($file eq "AndroidManifest.xml");
  my @dirs = File::Spec->splitdir($directories);
  my $folder = $dirs[scalar(@dirs)-2];
  print "resource: $resource, fold:$folder, file:$file\n";
  if (stat("res/$folder/$file")) {
    next;
  }
  system("mkdir -p res/$folder");
  symlink($resource, "res/$folder/$file");
}

system("rm -rf ./bin");
mkdir("bin");
$resources = `find $manodirectories -type f -name "*.class"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
  my $folder = $directories;
  $folder=~s/$manodirectories//;
  $folder=~s/.*classes\/(.*)/$1/;
  if (stat("bin/classes/$folder/$file")) {
    unlink("bin/classes/$folder/$file");
  }
  system("mkdir -p bin/classes/$folder");
  symlink($resdir, "bin/classes/$folder/$file");
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

$resources = `find $MOZOBJDIR/dist -name "*.apk"`;
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

system("cp -rf ztemplates/.classpath .");
system("cp -rf ztemplates/project.properties .");
system("cp -rf ztemplates/.project .");
system("sed \"s/\@_REPLACE_APP_NAME\@/".$mainactivityname."/\" -i .project");

mkdir ".externalToolBuilders";
system("cp -rf ztemplates/*.launch .externalToolBuilders/");
system("sed \"s|\@_REPLACE_OBJ_PROJECT_PATH\@|".$MOZOBJDIR."/".$MOZAPPDIR."|\" -i .externalToolBuilders/*.launch");
system("sed \"s|\@_REPLACE_OBJ_PATH\@|".$MOZOBJDIR."|\" -i .externalToolBuilders/*.launch");

mkdir ".settings";
system("cp -rf ztemplates/org.eclipse.jdt.core.prefs .settings/");

