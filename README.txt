dkLab RealSync: replicate developer's files over SSH in realtime
Dmitry Koterov, http://en.dklab.ru/lib/dklab_realsync/ (C)
License: GPL

RealSync allows you to establish a one-way realtime directory 
synchronization from your local folder (typically with a site's 
source code) to a server's remote directory (typically - a 
development web-server). 

When you create, change or delete any file/directory at your local 
folder, it will be automatically created, modified or deleted at the 
remote side, in realtime. 

Main RealSync benefits:

1. It is extremely stable, even on unstable internet connection. If internet
   is temporarily unavailable and then becomes alive, RealSync will recover
   and continue working, even if many files are changed during that period.

2. It is damned fast even on extremely large directories! Just change a file
   and you'll see these changes IMMEDIATELY at the remote side (it's true for
   Windows, MacOS X, Linux). If you change lots of files at once, RealSync will 
   run RSYNC automatically to reflect all changes if it thinks that a single
   RSYNC would be faster than individual files transfers.
      
3. It guarantees that no missynchronization happens, because it performs
   a full (but fast!) synchronization using the RSYNC utility when it knows
   that a missynchronization may take place (e.g. RSYNC is run when you run 
   RealSync initially).
   
4. On Windows - it minimizes to tray and dings a quiet sound on each change
   which is successfully transferred.
   
5. It has an installation wizard which automatically creates all needed SSH
   keys to access to your remote server with no need to enter your password
   each time.

So, RealSync is like RSYNC, but, in addition to RSYNC, it lives in the
background after an initial fast synchronization and watches for all
changes at your side.
   
      
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

1. Place contents of this directory somewhere, e.g. (or somewhere else):
     /opt/dklab_realsync/
   
2. Create a desktop shortcut for command-line:
     perl /opt/dklab_realsync/realsync SOURCE_DIRECTORY_WHICH_IS_REPLICATED
     
3. Click to that shortcut and follow interactive wizard's instructions
   (the wizard appears only first time; next time it will not bother you).


Why use RealSync?
-----------------

At the time I know no existed network filesystems which perform good caching 
on a slow or unstable internet connection. If you mount a remote directory from
a development web server into your local machine using Samba, NFS, sshfs etc.,
it becomes extremely slow when you perform e.g. a full project searching or
update files using SVN or GIT directly at your local machine.

RealSync allows you do use other method. You create a folder at your local
machine and then say RealSync to mirror all changes in this folder to
a remote web server. So you work at your local machine, you modify files as
you like (using various text editors if you want to), perform deep searhes
through all the files etc. And you are sure that the latest version of the
directory is always at the remote side.

So you edit your site locally, but view changes at the remote web server.


"But my Eclipse/NetBeans/PHPStorm supports SSH synchronization already!"
------------------------------------------------------------------------

They typically do it not very good. E.g. try to do the following:

1. Close your favorite Eclipse/NetBeans/PHPStorm temporarily.
2. Open e.g. Notepad and change a number or files (or, better, add a 
   directory with a couple of megabytes).
3. Break something at the remote side manually (e.g. remove a couple
   of directory directly at the server - just for fun).
3. Run Eclipse/NetBeans/PHPStorm again.
4. Enjoy your missynchronized directories!

Every IDE I test time to time have the same defect: they know nothing about 
RSYNC, and, of course, about other editors. They do not try to keep the local 
and remote directories identical all the time, because they have NO FEEDBACK 
from the remote side. RSYNC, which is used by RealSync as one of the 
synchronization method, has this feedback, so RealSync keeps local and remote 
directories identical. 


"Why a bi-directional synchronization is not supported?"
--------------------------------------------------------

Before answering this question, I'd like to say that typical RealSync usage
is to pass your local files to a remote development web-server, to allow
you to work with your favorite IDE with no lags and problems. Remote side
is only a mirror, it doesn't have its own meaning instead of the one:
it's an exact copy of the local side. So, if you want to work with console -
do it at your local machine. If you use Git or other version control
system - do it at your local machine, not at the remote one. If you need
grep - do not use grep, use your IDE's search, it is much more handy (or - use
grep at your local machine again; for Windows you may install e.g. UnxUtils
to work approximately as comfortable as you do it in Unix). You may even have 
no SSH access to a remote web-server you are syncing your local copy to.

So, RealSync supports only one-way synchronization: e.g. from your local
notebook to a remote server. All changes which are made directly at
the remote servers's side will be overriden by local files, even if the
local files are older than the remote ones.

This is "by design" and is not a problem. If you need a bi-directional
synchronization, you should possibly use another tool, not RealSync (and
be ready to the risk of losing your changes in non-obvious conflicts).


"Wait, but I have a notebook at work and a notebook at home, so I want
both of them to be synchronized to each other via the remote server!"
----------------------------------------------------------------------

I suppose you don't want THIS. You really want your two notebook to be 
synchronized to EACH OTHER. The remote server is fully independent of 
this case - remember, it's only a mirror to make a remove web-server
and a local developer happy.

But if you want two local notebooks to be synchronized to each other,
and RealSync works only between a noteboot and a remote server, why 
RealSync should help with that in realtime?

Use Dropbox, Luke! 

Seriously: http://dropbox.com - this is an amazing service to synchronize 
one computer's folder to another one. Store your local folders at Dropbox
subdirectories. It will help you perfectly, plus - it will backup your 
changes on a cloud storage, so you will never lose your changes.
When you want your two notebooks to be synchronized, Dropbox is a great 
choise, you do not need RealSync for that.


"But in our company we use a lot of console tools to work with the sources:
the tools must be run at the server and has hard-coded pathes etc."
---------------------------------------------------------------------------

Oh, that's not good. Consider to change your employer. :-) That was a joke. 
(Maybe.) So, RealSync does not fit your needs in this case. You should use
something else, e.g. Unison.


"I set up RSYNC invokation on Ctrl+S in my editor, and I am happy"
------------------------------------------------------------------

Congrats, you're a geek. But wait... geeks are typically seen to be working 
at home too. Is RSYNC fast enough when your connect to your office via
unstable internet connection with non-zero ping? I don't think so (or -
I envy your internet quality).


Programmers
-----------

Dmitry Koterov
  Author & maintainer of the RealSync Perl script and "notify" tool for win32.
  
Yuri Nasretdinov
  Found, adapted (mainly rewrote) source codes and built "notify" tool 
  for Linux and MacOS.
