#!/usr/bin/perl

use  strict;
use File::Spec;
use Data::Dumper;

my $MOZOBJDIR="";
my $MOZSRCDIR="";
my $WORKSPACEDIR="";
my $PROJECTNAME="";
my $configFile=`cat mozconfig_values`;
while ($configFile=~/^(.*)$/gm) {
  my $line = $1;
  if ($line=~/MOZOBJDIR\s*\=\s*(.*)/) {
    $MOZOBJDIR=$1;
  } elsif ($line=~/MOZSRCDIR\s*\=\s*(.*)/) {
    $MOZSRCDIR=$1;
  } elsif ($line=~/WORKSPACEDIR\s*\=\s*(.*)/) {
    $WORKSPACEDIR=$1;
  } elsif ($line=~/PROJECTNAME\s*\=\s*(.*)/) {
    $PROJECTNAME=$1;
  }
}
my $PROJECTDIR = "$WORKSPACEDIR/$PROJECTNAME";

print "OBJ:".$MOZOBJDIR."\n";
print "SRC:".$MOZSRCDIR."\n";
print "PROJECT:".$PROJECTDIR."\n";
mkdir $PROJECTDIR;
my $MOZAPPDIR="";
my $MOZAPPNAME="";
my $PKGNAME="";
my $autoConfR = `cat $MOZOBJDIR/config/autoconf.mk`;
while ($autoConfR=~/^(.*)$/gm) {
  my $line = $1;
  if ($line=~/^MOZ_BUILD_APP\s*\=\s*(.*)$/) {
    $MOZAPPDIR=$1;
  } elsif ($line=~/^MOZ_APP_NAME\s*\=\s*(.*)$/) {
    $MOZAPPNAME=$1;
  } elsif ($line=~/^ANDROID_PACKAGE_NAME\s*\=\s*(.*)$/) {
    $PKGNAME=$1;
  }
}
if ($MOZAPPDIR=~/^mobile$/ || $MOZAPPDIR=~/mobile\/xul/) {
  $MOZAPPDIR="embedding/android";
}
print "APPNAME:".$MOZAPPNAME."\n";
print "APPDIR:".$MOZAPPDIR."\n";
my $manifest = `find $MOZOBJDIR/$MOZAPPDIR/base -name AndroidManifest.xml`;
if (stat("$PROJECTDIR/AndroidManifest.xml")) {
  unlink("$PROJECTDIR/AndroidManifest.xml");
}
chomp($manifest);
my $smanifest = `find $MOZSRCDIR/$MOZAPPDIR/base -name AndroidManifest.xml.in`;
chomp($smanifest);
my ($manovolume,$manodirectories,$manofile) = File::Spec->splitpath($manifest);
my ($mansvolume,$mansdirectories,$mansfile) = File::Spec->splitpath($smanifest);
system("ln -s $manifest $PROJECTDIR/AndroidManifest.xml");
print "Adding Manifest from: $manifest\n";
my $mainactivityname = "";
my $projectName="";
open(my $mfh, '<', $manifest) or die $!;
while (<$mfh>) {
  if (/\s*package\s*\=\s*\"(.*)\"/) {
    $projectName = $1;
  } elsif (/\<activity android\:name\=\"(.*)\"/) {
    $mainactivityname = $1;
    print "Main Activity:".$mainactivityname."\n";
    last;
  }
}
close($mfh);
print "project: $projectName, activity: $mainactivityname\n";

system("sed 's|android:debuggable=\"false\"|android:debuggable=\"true\"|' -i $manifest");

mkdir("$PROJECTDIR/src");
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
      if (stat("$PROJECTDIR/src/$path/$file")) {
        unlink("$PROJECTDIR/src/$path/$file");
      }
      system("mkdir -p $PROJECTDIR/src/$path");
      symlink($source, "$PROJECTDIR/src/$path/$file");
      last;
    }
  }
  close($fh);
}

my $presources = `find $mansdirectories -name *.java.in`;
my $path = $PKGNAME;
$path=~s/\./\//g;
my $tmp = "/tmp/presources.out";
while ($presources=~/^(.*)$/gm) {
  my $source = $1;
  open(my $fh, '<', $source) or die $!;
  open(my $out, '>', $tmp) or die $!;
  my $path;
  my $ignored = 0;
  while (<$fh>) {
    my $replace = $_;
    my $replaced = 0;
    if ($_ =~ /\@ANDROID_PACKAGE_NAME@/) {
      $replace=~s/\@ANDROID_PACKAGE_NAME@/$PKGNAME/g;
      $replaced = 1;
    }
    if ($_ =~ /\@MOZ_MIN_CPU_VERSION@/) {
      $replace=~s/\@MOZ_MIN_CPU_VERSION@/0/g;
      $replaced = 1;
    }
    if ($_ =~ /\@MOZ_BUILD_TIMESTAMP@/) {
      $replace=~s/\@MOZ_BUILD_TIMESTAMP@/0/g;
      $replaced = 1;
    }
    if ($replaced == 1) {
      print $out "//gen-var:$_";
    }

    if ($ignored == 1) {
      $replace = "//gen-preproc:$replace";
    }

    my $replace2 = $_;
    $replace2=~s/\@ANDROID_PACKAGE_NAME@/$PKGNAME/g;

    if ($replace2 =~ /^package\s+(.*)\;/) {
      $path = $1;
      $path=~s/\./\//g;
      system("mkdir -p $PROJECTDIR/src/$path");
    } elsif (/^#/) {
      if (/^#ifdef/) {
        $ignored = 1;
        $replace = "//gen-preproc:$replace";
      } elsif (/^#endif/) {
        if ($ignored == 1) {
          $ignored = 0;
        } else {
          $replace = "//gen-preproc:$replace";
        }
      } elsif (/^#else/) {
        $ignored = 0;
      } else {
        $replace = "//gen-preproc:$replace";
      }
    }

    print $out $replace;
  }
  close($fh);
  close($out);

  my ($volume,$directories,$file) = File::Spec->splitpath($source);
  $file=~s/\.in$//g;
  rename $tmp, "$PROJECTDIR/src/$path/$file";
}

my $resources = "";
my $stop = 0;
system("rm -rf $PROJECTDIR/res");
mkdir("$PROJECTDIR/res");

$resources = `find $mansdirectories -name "*.png" -o -name "*.xml"`;
$stop = 0;
while ($resources=~/^(.*)$/gm && $stop == 0) {
  my $resource = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resource);
  my @dirs = File::Spec->splitdir($directories);
  my $folder = $dirs[scalar(@dirs)-2];
  print "resource: $resource, fold:$folder, file:$file\n";
  if (stat("$PROJECTDIR/res/$folder/$file")) {
    unlink("$PROJECTDIR/res/$folder/$file");
  }
  system("mkdir -p $PROJECTDIR/res/$folder");
  symlink($resource, "$PROJECTDIR/res/$folder/$file");
}

$resources = `find $manodirectories -name "*.png" -o -name "*.xml"`;
while ($resources=~/^(.*)$/gm && $stop == 0) {
  my $resource = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resource);
  next if ($file eq "AndroidManifest.xml");
  my @dirs = File::Spec->splitdir($directories);
  my $folder = $dirs[scalar(@dirs)-2];
  print "resource: $resource, fold:$folder, file:$file\n";
  if (stat("$PROJECTDIR/res/$folder/$file")) {
    next;
  }
  system("mkdir -p $PROJECTDIR/res/$folder");
  symlink($resource, "$PROJECTDIR/res/$folder/$file");
}

system("rm -rf $PROJECTDIR/bin");
mkdir("$PROJECTDIR/bin");
$resources = `find $manodirectories -type f -name "*.class"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
  my $folder = $directories;
  $folder=~s/$manodirectories//;
  $folder=~s/.*classes\/(.*)/$1/;
  if (stat("$PROJECTDIR/bin/classes/$folder/$file")) {
    unlink("$PROJECTDIR/bin/classes/$folder/$file");
  }
  system("mkdir -p $PROJECTDIR/bin/classes/$folder");
  symlink($resdir, "$PROJECTDIR/bin/classes/$folder/$file");
}

$resources = `find $manodirectories -type f -name "*.ap_"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
  if (stat("$PROJECTDIR/bin/resources.ap_")) {
    unlink("$PROJECTDIR/bin/resources.ap_");
  }
  symlink($resdir, "$PROJECTDIR/bin/resources.ap_");
}

$resources = `find $manodirectories -type f -name "*.dex"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
  if (stat("$PROJECTDIR/bin/classes.dex")) {
    unlink("$PROJECTDIR/bin/classes.dex");
  }
  symlink($resdir, "$PROJECTDIR/bin/classes.dex");
}

$resources = `find $MOZOBJDIR/dist -name "*.apk"`;
chomp($resources);
while ($resources=~/^(.*)$/gm) {
  my $resdir = $1;
  if ($resdir=~/$MOZAPPNAME/) {
    my ($volume,$directories,$file) = File::Spec->splitpath($resdir);
    if (stat("$PROJECTDIR/bin/$mainactivityname.apk")) {
      unlink("$PROJECTDIR/bin/$mainactivityname.apk");
    }
    symlink($resdir, "$PROJECTDIR/bin/$mainactivityname.apk");
  }
}
