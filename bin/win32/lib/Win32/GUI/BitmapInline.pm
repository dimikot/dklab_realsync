package Win32::GUI::BitmapInline;
use strict;
use warnings;

use Win32::GUI();
use MIME::Base64(); # Core since ???
use File::Spec();   # Core since ???

# Make Win32::GUI::BitmapInline thread-safe for ithreads.
# Stolen from Test::More
BEGIN {
    use Config;
    # Load threads::shared when threads are turned on.
    # 5.8.0's threads are so busted we no longer support them.
    if( $] >= 5.008001 && $Config{useithreads} && $INC{'threads.pm'}) {
        require threads::shared;

        # Hack around YET ANOTHER threads::shared bug.  It would 
        # occassionally forget the contents of the variable when sharing it.
        # So we first copy the data, then share, then put our copy back.
        *share = sub (\[$@%]) {
            my $type = ref $_[0];
            my $data;

            if( $type eq 'HASH' ) {
                %$data = %{$_[0]};
            }
            elsif( $type eq 'ARRAY' ) {
                @$data = @{$_[0]};
            }
            elsif( $type eq 'SCALAR' ) {
                $$data = ${$_[0]};
            }
            else {
                die("Unknown type: ".$type);
            }

            $_[0] = &threads::shared::share($_[0]);

            if( $type eq 'HASH' ) {
                %{$_[0]} = %$data;
            }
            elsif( $type eq 'ARRAY' ) {
                @{$_[0]} = @$data;
            }
            elsif( $type eq 'SCALAR' ) {
                ${$_[0]} = $$data;
            }
            else {
                die("Unknown type: ".$type);
            }

            return $_[0];
        };
    }
    # 5.8.0's threads::shared is busted when threads are off
    # and earlier Perls just don't have that module at all.
    else {
        *share = sub { return $_[0] };
        *lock  = sub { 0 };
    }
}

use Exporter();
our @ISA = qw(Exporter);
our @EXPORT = qw(inline);

our $VERSION = "0.03";
$VERSION = eval $VERSION;

# Thread-safe, temporary filename generator
# We'd like to use File::Temp, but it's not in core.  This
# is probably good enough
{
    my $file_count = 0;
    share($file_count);
    sub _tmp_filename {
        my $count;
        { lock($file_count); $count = ++$file_count; }

        return "~Win32GUIBitmapInLine.$$.$count.tmp";
    }
}

# new(), defaulting to $type = "Win32::GUI::Bitmap" exists as a public api
# for backwards compatibility
sub new {
    my($class, $data, $type) = @_;
    $type = 'Win32::GUI::Bitmap' unless $type;

    # Find a suitable temp directory.  File::Spec->tmpdir givs us
    # a writable tmp dir from a list, or the current directory (whether or not
    # writable) if it can't find a writable directory in any of the usual
    # places. It'd be nice to use IO::File->new_tmpfile(), but we need the
    # name of the file to pass to Win32::GUI::Bitmap->new().
    my $tmpfile = File::Spec->catfile(File::Spec->tmpdir(), _tmp_filename());

    # On perl 5.6 we have problems with tainted data in open().
    # so (naughtily) untaint our TMP file name.  In later versions
    # of File::Spec tmpdir() won't give us a tained answer.
    if($[ < 5.008000) {
        $tmpfile =~ /^(.*)$/;
        $tmpfile = $1;
    }

    open(my $tmpfh, '>', $tmpfile);
    if(!$tmpfh) {
        warn(qq(Failed to open tmp file '$tmpfile' for writing));
        return undef;
    }

    binmode($tmpfh);
    print $tmpfh MIME::Base64::decode($data);
    close($tmpfh) or warn(qq(Failed to close tmp file '$tmpfile')); 

    my $obj = $type->new($tmpfile);

    unlink($tmpfile) or warn(qq(Failed to remove tmp file '$tmpfile'));

    return $obj;  
}

sub newCursor {
    my($class, $data) = @_;

    return $class->new($data, 'Win32::GUI::Cursor');
}

sub newIcon {
    my($class, $data) = @_;

    return $class->new($data, 'Win32::GUI::Icon');
}

# Thread-safe counter
{
    my $object_count = 0;
    share($object_count);
    sub _new_count {
        my $count;
        {lock($object_count); $count = ++$object_count; }
        return $count;
    }
}

sub inline {
    my ($filename, $name) = @_;

    my $type = 'Bitmap';
    $type = 'Icon'   if $filename =~ /\.ico$/i;
    $type = 'Cursor' if $filename =~ /\.cur$/i;

    $name = $type . _new_count() unless $name;

    my $bmpfh;
    if(!open($bmpfh, '<', $filename)) {
        warn (qq(Can't open file '$filename' for reading));
        return undef;
    }
    binmode($bmpfh);

    # use new() (not newBitmap()) for backwards compatability
    $type = q() if $type eq 'Bitmap';
    my $ret = "\$$name = Win32::GUI::BitmapInline->new$type( q(\n";
    {
        local $/ = undef; # Slurp
        $ret .= MIME::Base64::encode( <$bmpfh> );
    }
    $ret .= ") );\n";

    close($bmpfh) or warn(qq(Failed to close '$filename')); 

    # print to currrently selected output filehandle
    print $ret;

    return length($ret);
}

1; # End of BitmapInline.pm

__END__

=head1 NAME

Win32::GUI::BitmapInline - Inline bitmap support for Win32::GUI

=head1 SYNOPSIS

To create a BitmapInline:

    perl -MWin32::GUI::BitmapInline -e "inline('image.bmp')" >>script.pl

To use a BitmapInline (in script.pl):

    use Win32::GUI();
    use Win32::GUI::BitmapInline ();
    
    $Bitmap1 = Win32::GUI::BitmapInline->new( q(
    Qk32AAAAAAAAAHYAAAAoAAAAEAAAABAAAAABAAQAAAAAAIAAAAAAAAAAAAAAABAAAAAQAAAAAAAA
    AACcnABjzs4A9/f3AJzO/wCc//8Azv//AP///wD///8A////AP///wD///8A////AP///wD///8A
    ////AHd3d3d3d3d3d3d3d3d3d3dwAAAAAAAABxIiIiIiIiIHFkVFRUVEQgcWVVRUVFRCBxZVVVVF
    RUIHFlVVVFRUUgcWVVVVVUVCBxZVVVVUVFIHFlVVVVVVQgcWZmZmZmZSBxIiIiIRERF3cTZlUQd3
    d3d3EREQd3d3d3d3d3d3d3d3
    ) );

=head1 DESCRIPTION

This module can be used to "inline" a bitmap file in your script, so
that the script doesn't need to be accompained by several external files 
(less hassle when you need to redistribute your script or move it 
to another location).

=head2 FUNCTIONS

=head3 inline

The C<inline> function is used to create an inlined bitmap resource; it
will print on the currently selected filehandle (STDOUT by default) the
packed data including the lines of Perl needed to use the inlined bitmap
resource; it is intended to be used as a one-liner whose output is
appended to your script.

The function takes the name of the bitmap file to inline as its first
parameter; an additional, optional parameter can be given which will be 
the name of the bitmap object in the resulting scriptlet, eg:

    perl -MWin32::GUI::BitmapInline -e "inline('image.bmp','IMAGE')"
    
    $IMAGE = new Win32::GUI::BitmapInline( q( ...

If no name is given, the resulting object name will be $Bitmap1 
(the next ones $Bitmap2 , $Bitmap3 and so on).

Note that the object returned by C<< Win32::GUI::BitmapInline->new( ... ) >> is
a regular L<Win32::GUI::Bitmap|Win32::GUI::Bitmap> object.

With version 0.02 and later you can inline icons and cursors too. Nothing
changes in the inlining process, just the file extension:

    perl -MWin32::GUI::BitmapInline -e "inline('harrow.cur')"  >>script.pl
    perl -MWin32::GUI::BitmapInline -e "inline('guiperl.ico')" >>script.pl

The module recognizes from the extension the type of object that it
should recreate, so it will add these lines to F<script.pl>:

    $Cursor1 = Win32::GUI::BitmapInline->newCursor( q( ...
    $Icon2 = Win32::GUI::BitmapInline->newIcon( q( ...
   
=head3 new

  my $bitmap = Win32::GUI::BitmapInline->new($data);

Returns a regular L<Win32::GUI::Bitmap|Win32::GUI::Bitmap> object from
the data created by the inlining process.

=head3 newCursor

Similar in behaviour to C<new()>, except it returns a
Win32::GUI::Cursor object.

=head3 newIcon

Similar in behaviour to C<new()>, except it returns a
Win32::GUI::Icon object.

=head1 REQUIRES

=over

=item L<Win32::GUI|Win32::GUI>

=item L<MIME::Base64|Mime::Base64>

=item L<File::Spec|File::Spec>

=item L<threads::shared|threads::shared>

=back

=head1 WARNINGS

=over

=item * Don't use it on large bitmap files!

BitmapInline was designed for small bitmaps, such as toolbar items,
icons, et alia; it is not at all performant. Inlined data takes
approximatively the size of your bitmap file plus a 30% overhead;
thus, if you inline a 100k bitmap you're adding about 130k of
bad-looking data to your script...

=item * File::Spec must be able to find a writable temporary directory.

When inlined data is used in your script (with
C<Win32::GUI::BitmapInline->new( ... )>),
then a temporary file is created, loaded as a regular bitmap and then
immediately deleted. This will fail if Win32::GUI::BitmapInline script
is not able to create and delete files in a suitable temporary
directory at the moment of the call.

Win32::GUI::BitmapInline uses L<File::Spec->tmpdir()|File::Spec/tmpdir>
to locate a suitable temporary directory.  This should be fine under most
circumstances, but if you find it returning the current directory (which means
that File::Spec was not able to find a writable temporary elesewhere), and you
are not confident that the current directory will always be writable, then 
one workaround is to change directory to a known safe place before constructing
the bitmap, and changing back afterwards:

    my $olddir = cwd();
    my $tmpdir = get_some_writable_dir();
    chdir($tmpdir);
    $Bitmap1 = Win32::GUI::BitmapInline->new( ... );
    chdir($olddir);

=item * The package exports the C<inline> function by default.

For practical reasons (see one-liners above), C<inline> is 
exported by default into the caller's namespace; to avoid
this side-effect is strongly recommended to use the module in your
production scripts as follows:

    use Win32::GUI::BitmapInline ();

=back

=head1 VERSION

Win32::GUI::BitmapInline version 0.03, 24 January 2001.

=head1 AUTHOR

Aldo Calpini ( C<dada@perl.it> ).
Modifications by Robert May ( C<robertemay@users.sourceforge.net> ).

=cut
