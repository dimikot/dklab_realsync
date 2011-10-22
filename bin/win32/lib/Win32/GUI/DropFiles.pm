package Win32::GUI::DropFiles;

# $Id: DropFiles.pm,v 1.3 2006/10/15 14:07:46 robertemay Exp $
# Win32::GUI::DropFiles, part of the Win32::GUI package
# (c) Robert May, 2006
# released under the same terms as Perl.

use 5.006;
use strict;
use warnings;

use Win32::GUI 1.03_02,'';  # Check Win32:GUI version, ensure import not called

our $VERSION = '0.02';
our $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

require XSLoader;
XSLoader::load('Win32::GUI::DropFiles', $XS_VERSION);

sub DESTROY
{
    my $self = shift;
    $self->DragFinish();
}

sub GetDroppedFiles {

    # void context - optional warning and do nothing
    if(!defined wantarray) {
        if(warnings::enabled('void')) {
            require Carp;
            Carp::carp('Useless use of GetDroppedFiles in void context');
        }
        return;
    }

    my $self = shift;
    my $count = $self->DragQueryFile();

    # scalar context - return number of files dropped
    return $count unless wantarray;

    my @files = ();
    for my $item (0..$count-1) {
        push @files, $self->DragQueryFile($item);
    }

    # list context - return list of files
    return(@files);
}

sub GetDroppedFile {

    # void context - optional warning and do nothing
    if(!defined wantarray) {
        if(warnings::enabled('void')) {
            require Carp;
            Carp::carp('Useless use of GetDroppedFile in void context');
        }
        return;
    }

    my ($self, $item) = @_;
    $item ||= 0;

    # scalar context - return file name
    return $self->DragQueryFile($item);
}

sub GetDropPos {

    # void context - optional warning and do nothing
    if(!defined wantarray) {
        if(warnings::enabled('void')) {
            require Carp;
            Carp::carp('Useless use of GetDropPos in void context');
        }
        return;
    }

    my $self = shift;

    my ($x, $y, $client) = $self->DragQueryPoint();

    # scalar context - return boolean for whether drop is in
    # client area or not
    return $client unless wantarray;
    # list context - return x-pos, y-pos and boolean for
    # client area or not.
    return $x, $y, $client;
}

1; # End of DropFiles.pm
__END__

=head1 NAME

Win32::GUI::DropFiles - Extension to Win32::GUI for shell Drag&Drop integration

=head1 SYNOPSIS

  use Win32::GUI;
  use Win32::GUI::DropFiles;

  # Create droppable window:
  my $win = Win32::GUI::Window->new(
    -name => 'win',
    ...
    -acceptfiles => 1,
    -onDropFiles => \&dropfiles_callback,
    ...
  );

  # Change the drop state of a window
  $win->AcceptFiles(1);
  $win->AcceptFiles(0);

  # In the DropFiles callback
  sub win_DropFiles {
    my ($self, $dropObj) = @_;

    # Get the number of dropped files
    my $count = $dropObj->GetDroppedFiles();

    # Get a list of the dropped file names
    my @files = $dropObj->GetDroppedFiles();

    # Get a particular file name (0 based index)
    my $file  = $dropObj->GetDroppedFile($index);

    # determine if the drop happened in the client or
    # non-client area of the window
    my $clientarea = $dropObj->GetDropPos();

    # get the mouse co-ordinates of the drop point,
    # in client co-ordinates
    my ($x, $y) = $dropObj->GetDropPos();

    # get the drop point and (non-)client area information
    my ($x, $y, $client) = $dropObj->GetDropPos();

    return 0;
  }

=head1 DESCRIPTION

Win32::GUI::DropFiles provides integration with the windows shell,
allowing files to be dragged from the shell (e.g. explorer.exe),
dropped onto a Win32::GUI window/control, and the path and filename
of the dropped files to be retrieved.

In order for a window to become a 'drop target' it must be created
with the L<-acceptfiles|Win32::GUI::Reference::Options/acceptfiles>
option set, or have called its
L<AcceptFiles()|Win32::GUI::Reference::Methods/AcceptFiles>
method.

Once the window has been correctly initialised, then dropping a dragged
file on the window results in a
L<DropFiles|Win32::GUI::Reference::Events/DropFiles> event being
triggered.  The parameter to the event callback function is a
Win32::GUI::DropFiles object that can be used to retrieve the
names and paths of the dropped files.

=head1 Drop Object Methods

This section documents the public API for Win32::GUI::DropFiles
objects.

=head2 Constructor

The constructor is not public: Win32::GUI creates Win32::GUI::DropFiles
object when necessary, to pass to the DropFiles event handler subroutine.

=head2 GetDroppedFiles

  my $count = $dropObj->GetDroppedFiles();
  my @files = $dropObj->GetDroppedFiles();

In scalar context returns the number of files dropped.
In list context returns a list of fully qualified path/filename
for each dropped file.

=head2 GetDroppedFile

  my $file = $dropObj->GetDroppedFile($index);

returns the fully qualified path/filename for the file
referenced by the zero-based C<index>.

If C<index> is out of range, returns undef and sets C<$!>
and C<$^E>.

=head2 GetDropPos

  my $client = $dropObj->GetDropPos();
  my ($x, $y, $client) = $dropObj->GetDropPos();

In scalar context returns a flag indicating whether the mouse
was in the client or non-client area of the window when the files
were dropped.
In list context returns the x and y co-ordinates of the mouse when
the files were dropped (in client co-ordinates), as well as a
flag indicating whether the mouse was in the client or non-client
area of the window.

=head2 Destructor

The destructor is called automatically when the object goes out of
scope, and releases resources used by the system to store the
filnames.  Typically the object goes out of scope at the end of the
DropFiles callback.  Care should be taken to ensure that if a reference
is taken to the object that does not go out of scope at that time, that it
is eventually released, otherwise a memory leak will occur.

=head1 Win32 API functions

This section documents the Win32 API wrappers implemented by
Win32::GUI::DropFiles.  Although these APIs are available,
their use is not recommended - the public Object Methods
should provide better access to these APIs.

See MSDN (L<http://msdn.microsoft.com/>) for further details
of the Win32 API functions.

=head2 DragQueryFile

  Win32::GUI::DropFiles::DragQueryFile($dropHandle, [$item]);

C<dropHandle> is a win32 C<HDROP> handle.  C<item> is a zero-based
index to the filename to be retrieved.

Returns the number of files dropped if C<item> is omitted.  Returns
the filenmame if C<item> is provided.

Returns undef and sets C<$!> and C<$^E> on error.

=head2 DragQueryPoint

  Win32::GUI::DropFiles::DragQueryPoint($dropHandle);

C<dropHandle> is a win32 C<HDROP> handle.

Returns a 3 element list of the x-position and y-position
(in client co-ordinates) and a flag that indicates
whether the drop happened in the client or non-client
area of the window.

=head2 DragFinish

  Win32::GUI::DropFiles::DragFinish($dropHandle);

C<dropHandle> is a win32 C<HDROP> handle.

Releases the resources and invalidates C<dropHandle>.

Does not return any value.

=head1 Unicode filenmame support

Supports unicode filenames under WinNT, Win2k, WinXP and higher.

=head1 Backwards compatibility with Win32::GUI::DragDrop

The GUI Loft includes a Win32::GUI::DragDrop module that exposes
similar functionality.  If you want to continue to use that module,
then ensure that Win32::GUI::DropFiles is not used anywhere in your
program (even by other modules that you use).  Loading
Win32::GUI::DropFiles changes the DropFiles event callback signature,
and will result in Win32::GUI::DragDrop failing.

It is recommended to upgrade to Win32::GUI::DropFiles.

=head1 SEE ALSO

MSDN L<http://msdn.microsoft.com> for more information on
DragAcceptFiles, DragQueryFiles, DragQueryPos, DragFinish,
WS_EX_ACCEPTFILES, WM_DROPFILES

L<Win32::GUI|Win32::GUI>

=head1 SUPPORT

Homepage: L<http://perl-win32-gui.sourceforge.net/>.

For further support join the users mailing list
(C<perl-win32-gui-users@lists.sourceforge.net>) from the website
at L<http://lists.sourceforge.net/lists/listinfo/perl-win32-gui-users>.
There is a searchable list archive at
L<http://sourceforge.net/mail/?group_id=16572>

=head1 AUTHORS

Robert May (C<robertemay@users.sourceforge.net>)
Reini Urban (C<rurban@xray.net>)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Robert May

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
