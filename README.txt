0) hg clone http://hg.mozilla.org/users/romaxa_gmail.com/eclipse_mobile
   cd eclipse_mobile

1) edit mozconfig_values
   add path to obj-build-dir and source dir
   path must be absolute
Ex:
MOZOBJDIR=/home/romaxa/mozdev/mozillahg/mozilla-birch/objdir-droid
MOZSRCDIR=/home/romaxa/mozdev/mozillahg/mozilla-birch

2) run ./create_projects.pl
   eclipse project will be created in current folder

3) Open Eclipse
  1. File->New->Project
  2. Android Project
  3. Next, Create project from existing source
  4. Select current folder as Location, Next
  5. Select Build Target "Android 3.2 / API 13"
  6. Next and Finish

4) In eclipse Project->Build Project
5) Press Run App button
5.5) On first run, eclipse (some unknown beast removing bin/App.apk and resource.ap_)
  Don't know how to teach eclipse don't do that, but it breaks installable package.
  So in order to fix that problem
  after first Run App, execute in project folder
  ./fixup_links.pl
  It fill update *.apk and *.ap_ symlinks

6) Press Run App button again
   Try to setup breakpoint in onCreate() and press Debug App button.

Have a fun!


