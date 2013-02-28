#!/usr/bin/perl

use  strict;

system("/usr/bin/perl refresh_projects.pl ");

my $MOZOBJDIR="";
my $MOZSRCDIR="";
my $PROJECTDIR="";
my $configFile=`cat mozconfig_values`;
while ($configFile=~/^(.*)$/gm) {
  my $line = $1;
  if ($line=~/MOZOBJDIR\s*\=\s*(.*)/) {
    $MOZOBJDIR=$1;
  }
  if ($line=~/MOZSRCDIR\s*\=\s*(.*)/) {
    $MOZSRCDIR=$1;
  }
  if ($line=~/WORKSPACEDIR\s*\=\s*(.*)/) {
    $PROJECTDIR=$1."/Fennec";
  }
}

my $MOZAPPDIR="";
my $autoConfR = `cat $MOZOBJDIR/config/autoconf.mk`;
while ($autoConfR=~/^(.*)$/gm) {
  my $line = $1;
  if ($line=~/^MOZ_BUILD_APP\s*\=\s*(.*)$/) {
    $MOZAPPDIR=$1;
  }
}

my $manifest = `find $MOZOBJDIR/$MOZAPPDIR -name AndroidManifest.xml`;
chomp($manifest);

my $mainactivityname = "";
my $projectName="";
open(my $mfh, '<', $manifest) or die $!;
while (<$mfh>) {
  if (/\s*package\s*\=\s*\"(.*)\"/) {
    $projectName = $1;
  } elsif (/\<activity android\:name\=\"(.*)\"/) {
    $mainactivityname = $1;
    print "Main Activity:".$mainactivityname."\n";
    close($mfh);
  }
}
close($mfh);

system("cp -rf ztemplates/.classpath $PROJECTDIR/");
system("cp -rf ztemplates/project.properties $PROJECTDIR/");
system("cp -rf ztemplates/.project $PROJECTDIR/");
system("sed \"s/\@_REPLACE_APP_NAME\@/".$mainactivityname."/\" -i $PROJECTDIR/.project");

mkdir "$PROJECTDIR/.externalToolBuilders";
system("cp -rf ztemplates/*.launch $PROJECTDIR/.externalToolBuilders/");
system("sed \"s|\@_REPLACE_OBJ_PROJECT_PATH\@|".$MOZOBJDIR."/".$MOZAPPDIR."|\" -i $PROJECTDIR/.externalToolBuilders/*.launch");
system("sed \"s|\@_REPLACE_OBJ_PATH\@|".$MOZOBJDIR."|\" -i $PROJECTDIR/.externalToolBuilders/*.launch");
system("cp -rf ztemplates/_PROJECT_ACTIVITY_TEMPLATE.launch $PROJECTDIR/bin/$mainactivityname.launch");
system("sed \"s/\@_REPLACE_APP_NAME\@/".$mainactivityname."/\" -i $PROJECTDIR/bin/$mainactivityname.launch");
system("sed \"s/\@_PACKAGE_NAME_\@/".$projectName."/\" -i $PROJECTDIR/bin/$mainactivityname.launch");

mkdir "$PROJECTDIR/.settings";
system("cp -rf ztemplates/org.eclipse.jdt.core.prefs $PROJECTDIR/.settings/");

