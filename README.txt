dkLab RealSync: replicate developer's files over SSH in realtime
Dmitry Koterov, http://en.dklab.ru/lib/dklab_realsync/ (C)
License: GPL

RealSync allows you to establish one-way directory synchronization from your
folder at the local machine (typically with site's source code) to remote
directory at a server (typically - development web-server). 

When you create, change or delete any file at your local folder, it will 
automatically be created, modified or deleted at the remote side, in realtime. 

Main RealSync benefits:

1. It is extremely stable, even on unstable internet connection. If internet
   is temporarily unavailable and then becomes alive, RealSync will recover
   and continue working, even if many files are changed during that period.
   
2. It guarantees that no missynchronization happens, because it performs
   a full (but fast!) synchronization periodically using the fast RSYNC utility 
   (e.g. RSYNC is run when you run RealSync initially).
   
3. It is damned fast even on extremely large directories! Just change a file 
   and you'll see these changes immediately at the remote side (it's true for 
   Windows and MacOS X; Linux version is a bit slower still). If you change
   lots of files, RealSync will run RSYNC automatically to reflect all changes.
   
4. It minimizes to tray (on Windows) and dings a quiet sound on each change
   which is successfully transferred.
   
5. It has an installation wizard which automatically creates all needed SSH
   keys to access to your remote server with no need to enter your password
   each time.

      
Usage for Windows
-----------------

1. Place contents of this directory somewhere, e.g.:
     "C:/Program Files/dklab_realsync/"
   
2. Create a desktop shortcut for command-line:
     "C:/Program Files/dklab_realsync/realsync.exe" SOURCE_DIRECTORY_WHICH_IS_REPLICATED
     
3. Click to that shortcut and follow interactive wizard's instructions
   (the wizard appears only first time; next time it will not bother you).


Usage for Linux, FreeBSD, MacOS X (darwin)
------------------------------------------

1. Place contents of this directory somewhere, e.g.:
     /opt/dklab_realsync/
   
2. Create a desktop shortcut for command-line:
     perl /opt/dklab_realsync/realsync SOURCE_DIRECTORY_WHICH_IS_REPLICATED
     
3. Click to that shortcut and follow interactive wizard's instructions
   (the wizard appears only first time; next time it will not bother you).


Why use RealSync?
-----------------

Today there are no network filesystems exist which perform good caching on
a slow or unstable internet connection. If you mount a remote directory from
a development web server into yor local machine using Samba, NFS, sshfs etc.,
it becomes extremely slow when you perform e.g. a full project searching or
update files using SVN or GIT directly at your local machine.

RealSync allows you do use other method. You create a folder at your local
machine and then say RealSync to replicate all changes in this folder to
a remote web server. So you work at your local machine, you modify files as
you like (using multiple text editors if you want to), perform deep searhes
through all the files etc. And you sure that the latest version of the
directory is always at the remote side.

So you edit your site locally, but view changes at the remote web server.


"But my Eclipse/NetBeans/PHPStorm supports SSH synchronization already!"
------------------------------------------------------------------------

Really? Then - try to do the following:

1. Close your favorite Eclipse/NetBeans/PHPStorm temporarily.
2. Open e.g. Notepad and change a number or files (or, better, add a 
   directory with a couple of megabytes).
3. Break something at the remote side manually (e.g. remove a couple
   of directory directly at the server - just for fun).
3. Run Eclipse/NetBeans/PHPStorm again.
4. Enjoy your missynchronized directories!

Every IDE I tested time to time had the same defect: they know nothing about 
RSYNC and other editors. They do not try to keep the local and remote 
directories identical all the time, because they have NO FEEDBACK from the 
remote side. RSYNC, which is used by RealSync as one of the synchronization 
method, has this feedback, so RealSync keeps local and remote directories 
identical. 

So I had to create RealSync.
