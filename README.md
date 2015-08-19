dkLab RealSync: replicate developer's files over SSH in realtime
=====

Developed by _Dmitry Koterov, http://en.dklab.ru/lib/dklab_realsync/ (C)_

License: GPL

## What it is

RealSync allows you to establish a one-way synchronization between a local folder and a server's remote directory. The typical use case is to sync your local copy of a website's source code with the development server. The sync is kept over time, and happens in real-time.

When you create, change or delete any file/directory in your local folder, it will be automatically created, modified or deleted in the remote folder. The process is practically seamless.

### Main RealSync benefits:

1. It's extremely stable, even if the internet connection isn't. If the connection to the server is temporarily unavailable, and then comes back alive, RealSync will resume its operation as if nothing happened, even if many files were changed during the _offline_ period.

2. It's damned fast, even on extremely large directories! Change a file and you'll see that change reflected IMMEDIATELY on the remote server. Performance is maintained on Windows, MacOS X, and Linux. If you change a lot of files at once, RealSync will run _[rsync](https://rsync.samba.org/)_ automatically. It knows when _rsync_ is a faster choice for transfering those files.

3. It makes sure that no mis-synchronization takes place, as it performs a full (but fast) synchronization using _rsync_ when it knows that a mis-sync might take place. For example: _rsync_ is run every time you launch RealSync.

4. On Windows, it minimizes to the taskbar and makes a quiet sound on every change that is successfully transferred.

5. It includes an installation wizard which will automatically create all required SSH keys. This allows RealSync to access the remote server without asking you to enter your password every time.

So, RealSync is similar to _rsync_. But as a more complex utility, it lives in the background, is smarter about how to synchronize your files, and __watches for changes on the local folders__.

## Usage

Start by downloading RealSync as a ZIP file (then unzip it) or by cloning this repository. Then follow the instructions for your Operating System.

### Windows

1. Move the RealSync folder somewhere in your hard drive. `C:/Program Files/dklab_realsync/` is a good choice.

2. Go inside the folder, right click realsync.exe, and create a shortcut for it. Move the shortcut to your desktop.

3. Right click the shortcut (now in your desktop), select Properties, and in the Target text input, change the target to match this format:

  `C:\Program Files\dklab_realsync\realsync.exe SOURCE_DIRECTORY_TO_REPLICATE`

  If you wanted everything in your `C:\code` folder to replicate on the server, you'd use the target

  `C:\Program Files\dklab_realsync\realsync.exe C:\code`

4. Now double click the shortcut, and follow the instructions on the wizard to set up your synchronization. The wizard will only show up the first time, and won't bother you when you open RealSync after being set-up. You can always update the settings manually by modifying the .realsync file in the source directory.

### Linux, FreeBSD, MacOS X (darwin)

1. Move the RealSync folder somewhere in your hard drive. `/opt/dklab_realsync/` is a good choice.

2. Create a desktop shortcut for the realsync application. Specify a command-line for this shortcut: `perl /opt/dklab_realsync/realsync SOURCE_DIRECTORY_TO_REPLICATE`

3. Now open that shortcut, and follow the interactive wizard's instructions. The wizard will only show up the first time, and won't bother you after RealSync is set-up.

## Why use RealSync?

At the time, I didn't know of any network filesystem that was performant enough, or that had good enough caching to mitigate the lows of a slow or unstable internet connection. If you mount a remote directory from a development web server in your local machine (using Samba, NFS, sshfs, etc.) it becomes extremely slow when you perform larger operations, such as a full project search, or switching _git_ branches on your local machine.

RealSync allows you to use another method. You create a folder in your local machine and tell RealSync to mirror changes on this folder to the remote web server. This way you can work locally, modifying stuff as you go, and RealSync will take care of the sync for you. With this method, you can use your familiar text editor, search through all the project's files, etc. And you have the peace of mind of knowing the remote server as the most recent version of your local changes.

You will probably be editing your site locally, but viewing the changes on the remote web server.

### "But Eclipse/NetBeans/PHPStorm supports SSH synchronization already!"

Typically, they don't do it well. For example, try to do the following:

1. Close Eclipse/NetBeans/PHPStorm temporarily.
2. Open another editor (e.g. Notepad) and change a number or files. Or better yet, add a directory with a couple of megabytes to the project's folder.
3. Break something on the remote manually (e.g. remove a couple
   of directories directly at the server - just for fun).
3. Run Eclipse/NetBeans/PHPStorm again.
4. Enjoy your mis-synchronized directories!

Every IDE I tested at the time had the same defect: by not using _rsync_ they don't try to keep the local and remote directories identical all the time, as they don't have feedback from the remote. _rsync_, which RealSync uses as one of the synchronization methods, has this built-in feedback. This way RealSync can keep the local and remote directories identical.

### "Why isn't bi-directional synchronization supported?"

Before answering this question, it's important to point out that typical RealSync usage is to reflect changes on local files to a remote development server. This would allow you to work with your favorite IDE without lag or problems. The remote is merely a mirror. It doesn't have any meaning except being an exact copy of your local files.

This means you can work in any way you want. Use the console on your local machine, with local-level speed. If you use version control software, do so in your own system, not on the remote (it'll be way faster). If you need to search across the hundreds/thousands of files that your project has, you do so locally. If you need to use _grep_, _grep_ on your local machine. You may even install UNIX-like tools on your Windows computer (e.g. UnxUtils, cygwin) to work as comfortable as you would on a Unix-based system.

There's also the possibility that you don't have SSH access to the remote web-server, and working off FTP isn't a real solution for you.

So, RealSync only supports one-way synchronization: e.g. from your local
notebook to a remote server. __All changes made directly on the remote will be overriden by your local changes, even if your local files are older than the ones on the remote.__

This was intended _by design_, and isn't a problem/bug/issue. If you need bi-directional synchronization, you should use another tool. (Also, be ready to the risk of losing your changes in non-obvious conflicts.)

### "Wait, but I have a computer at work and another at home. I want both to be in sync via the remote server!"

I suppose you don't want THIS. What you really want is your two computers to be in sync with each other. The remote is supposed to be independent from this situation (remember: it's only a mirror to create a remote web server that you don't edit directly).

Bit if you really want two local computers to be in sync with each other, RealSync can't help you with that in real-time.

> Luke, use Dropbox!

Seriously, [Dropbox](http://dropbox.com) and its competitors is an amazing way to keep two (or more) computers in sync. You store your local copy of the source code as a Dropbox sub-directory, and the app will keep changes across computers in sync. Plus, you get a cloud-based backup for your files so you will never lose your stuff. If two-way sync between non-remote computers is what you want, then RealSync isn't want you want.

### "But in our company we use a lot of console tools to work with the code: the tools must be run at the server, and have hard-coded paths, etc."

Oh, that's not good. Consider changing your employer. :-) That was a joke. (Maybe.) In this case RealSync won't fit your needs, you should consider using something else (e.g. Unison).

### "I set up _rsync_ to be run when I hit _save_ on my editor, and I'm happy."

Congrats, you're a geek. But wait... geeks are typically seen working at home as well. Is _rsync_ fast enough when you connect to your office, on an unstable internet connection with a non-zero ping? I don't think so (or,
I envy your connection's quality).

## Developers

__Dmitry Koterov__: author & maintainer of the RealSync Perl script and the _notify_ tool for win32.

__Yuri Nasretdinov__: _notify_ tool for Linux and MacOS: found, adapted (mainly rewrote) the source code for _notify_ and built it.
