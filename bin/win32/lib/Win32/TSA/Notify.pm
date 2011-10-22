# ==============================================================================
# $Id: Notify.pm 462 2006-09-01 00:05:08Z HVRTWall $
# Copyright (c) 2005-2006 Thomas Walloschke (thw@cpan.org). All rights reserved.
# Win32 Taskbar Status Area Notification System
# ==============================================================================

package Win32::TSA::Notify;

# -- Pragmas
use 5.008006;
use strict;
use warnings;
no strict "refs";
no strict "subs";

# -- @INC support for local modules
use lib '../', '../../';

# -- Local modules
use Win32::TSA::Notify::Icon;
use Win32::TSA::Notify::Text;
use Win32::TSA::Notify::Alert;
use Win32::TSA::Notify::PerlExe::ActiveState::PerlTray;

use Win32::PerlExe::Env;    # PerlExe packer info

# -- Global modules
use File::Basename;
use Time::HiRes;

use Thread::Semaphore;
use Win32::API::Prototype;
use Memoize;

# -- Variable definitions
our ($VERSION);
my ($_TSA_reg,
    %CONSTANTS,

    $memoize,
    $_S_update_TSA_icon,

    $script_path,
    $script_name,
    $exe_path,
    $res_path,
    $path,
);

# -- Version (reformatted 'major.minor(3)release(3)revision(3)')
$VERSION = do { my @r = ( q<Version value="0.01.01"> =~ /\d+/g, q$Revision: 462 $ =~ /\d+/g ); sprintf "%d." . "%03d" x $#r, @r };

# -- Memoize on/off
$memoize = 1;    # Default is on = 1

# -- Semaphore
$_S_update_TSA_icon = new Thread::Semaphore();

# -- Default resources
$res_path = 'res/icons';

# -- Get script path and name
( $script_path, $script_name ) = Win32::GetFullPathName($0);
$script_name =~ s/(.*)\..+$/$1/;

# -- Find icon path
$path = _format_path( get_tmpdir() || res_path() || $script_path );

# -- Define Win32 constants ...
%CONSTANTS = (
    IMAGE_ICON          => 1,
    LR_LOADFROMFILE     => 0x0010,    # lädt das Bild von einer Datei
    LR_COPYFROMRESOURCE => 0x4000,
    LR_DEFAULTSIZE      => 0x0040,    # lädt das Bild in der Standardgröße des
                                      # Bildes
    LR_SHARED           => 0x8000,
    LR_CREATEDIBSECTION => 0x2000,    # lädt ein Bitmap mit Dib-Sektionen
    LR_DEFAULTCOLOR     => 0x0000,    # lädt das Bild in den Standardfarben
                                      # (Not LR_MONOCHROME)
    LR_LOADMAP3DCOLORS  => 0x1000,    # ersetzt bestimmte Grautöne
                                      # eines Bildes mit den Systemfarben für
                                      # 3D-Ramen die normalerweise den
                                      # Grautönen zugeordnet sind
    LR_LOADTRANSPARENT  => 0x0020,    # ersetzt alle Pixel des Bildes mit dem
                                      # Farbwert des ersten Pixels des Bitmaps
                                      # durch die Standard-Fenster-
                                      # hintergrundfarbe
    LR_MONOCHROME       => 0x0001,    # lädt das Bild in schwarzweiß

    NIM_ADD          => 0x00000000,
    NIM_MODIFY       => 0x00000001,
    NIM_DELETE       => 0x00000002,
    NIF_MESSAGE      => 0x00000001,
    NIF_ICON         => 0x00000002,
    NIF_TIP          => 0x00000004,
    NIF_INFO         => 0x00000010,
    NIIF_NONE        => 0x00000000,
    NIIF_INFO        => 0x00000001,
    NIIF_WARNING     => 0x00000002,
    NIIF_ERROR       => 0x00000003,
    WM_QUIT          => 0x0012,
    WM_APP           => 0x8000,
    WM_MOUSEMOVE     => 0x0200,
    WM_LBUTTONDBLCLK => 0x0203,       # Left button double click
    WM_LBUTTONDOWN   => 0x0201,       # Left button down
    WM_LBUTTONUP     => 0x0202,       # Left button up
    WM_MBUTTONDBLCLK => 0x0209,       # Middle button double click
    WM_MBUTTONDOWN   => 0x0207,       # Middle button down
    WM_MBUTTONUP     => 0x0208,       # Middle button up
    WM_RBUTTONDBLCLK => 0x0206,       # Right button double click
    WM_RBUTTONDOWN   => 0x0204,       # Right button down
    WM_RBUTTONUP     => 0x0205,       # Right button up

    NOTIFYICONDATA => "LLLLLLa128LLa256La64L",
    UNDEFINED_ICON => 0,
);

# ... and create the constants
my $_pckg = __PACKAGE__;
foreach my $_constant_name ( keys(%CONSTANTS) ) {
    *{"${_pckg}::${_constant_name}"}
        = eval("sub { return( $CONSTANTS{$_constant_name} ); }");
}

# -- Load DLLs and expose functions (In VBS: Declare Functions)
#    Functions will be imported into the main namespace!

# -- Function that can add, remove or modify an icon at the system tray
ApiLink( "shell32.dll",
    "BOOLEAN Shell_NotifyIcon ( DWORD dwMessage, PVOID pNotifyIconData )" )
    || die _print_error( $!,
    [ 'ApiLink=shell32.dll', 'Can\'t link to Shell_NotifyIcon' ] );

# -- Function that loads icons from file
ApiLink( "user32.dll",
          "HANDLE LoadImage( HANDLE hinst, LPCTSTR lpszName, UINT uType, "
        . "int cxDesired, int cyDesired, UINT fuLoad )" )
    || die _print_error( $!,
    [ 'ApiLink=user32.dll', 'Can\'t link to LoadImage' ] );

# -- Function that creates the "TSA window"
ApiLink( "user32.dll",
          "HANDLE CreateWindowEx( DWORD dwExStyle, LPCTSTR lpClassName, "
        . "LPCTSTR lpWindowName, DWORD dwStyle, int x, int y, int nWidth, "
        . "int nHeight, HANDLE hWndParent, HANDLE hMenu, HANDLE hInstance, "
        . "PVOID lpParam )" )
    || die _print_error( $!,
    [ 'ApiLink=user32.dll', 'Can\'t link to CreateWindowEx' ] );

# -- TSA object registry
#     Contains new icon objects for automatic icon removal at END
#     Autocleanup the System Tray (TSA), removal of all open "TSA window(s)"
$_TSA_reg = [];

# *** Methods ******************************************************************

# -- Constructor
sub new {
    my $class = shift;

    # -- Make object, load defaults
    my $self = bless {
        mask => "${path}${script_name}_*.ico",
        data => {
            title      => __PACKAGE__,
            icon       => &UNDEFINED_ICON,
            icon_id    => $$,
            message_id => &WM_APP + 1,
            window     => main::CreateWindowEx(
                0, 'GHOST', "Perl Message Only Window: $$",
                0, 100, 100, 500, 500, 0, 0, 0, 0
            ),
            hover_text      => '',
            balloon_text    => '',
            balloon_title   => '',
            balloon_timeout => 2,
            info_flags      => &NIIF_NONE,
        },
        list  => {},
        alert => {
            error => {
                info_flags => &NIIF_ERROR,
                icon_name  => 'error',
            },
            warning => {
                info_flags => &NIIF_WARNING,
                icon_name  => 'warning',
            },
            info => {
                info_flags => &NIIF_INFO,
                icon_name  => 'info',
            },
            help => {
                info_flags => &NIIF_NONE,
                icon_name  => 'help',
            },
            none => {
                info_flags => &NIIF_NONE,
                icon_name  => 'none',
            },
            _none => {
                info_flags => &NIIF_NONE,
                icon_name  => undef,
            },
            _default => {
                info_flags => &NIIF_ERROR,
                icon_name  => 'error',
            },
        },
    }, $class;

    # -- Load up all icons from file...
    $self->_load_icons;

    # -- Initialize TSA with new empty or program icon
    $self->_create_icon( $_[0] || '!', $_[1] || 0 );

    # -- Preset tooltip
    $self->change_text( $_[2] )
        if $_[2];

    # -- Register TSA object
    push @{$_TSA_reg}, $self;

    return $self;
}

# *** Internal methods *********************************************************

sub _load_icons {

    my $self = shift;

    # -- Register memoize subroutines
    memoize('main::LoadImage'), memoize('_fix_alert_icon')
        if $memoize;

    while ( glob( $self->{mask} ) ) {
        my ($name) = ( $_ =~ /([^_]+?)\.ico$/i );

        $self->{list}{ lc $name } = main::LoadImage(
            0, $_, &IMAGE_ICON, 0, 0,
            &LR_DEFAULTSIZE | &LR_SHARED | &LR_LOADFROMFILE | &LR_DEFAULTCOLOR
                | &LR_LOADMAP3DCOLORS | &LR_LOADTRANSPARENT

                # | &LR_MONOCHROME
        );
    }

    foreach ( keys %{ $self->{alert} } ) {
        $self->{alert}{$_}{icon} = $self->_fix_alert_icon($_);

    }

    %{ $self->{rlist} } = reverse %{ $self->{list} };

}

sub _fix_alert_icon {

    my $self = shift;
    my ($_entry) = @_;

    return (    exists $self->{alert}{$_entry}{icon_name}
            and $self->{alert}{$_entry}{icon_name}
            and exists $self->{list}{ $self->{alert}{$_entry}{icon_name} } )
        ? $self->{list}{ $self->{alert}{$_entry}{icon_name} }
        : &UNDEFINED_ICON;
}

sub _create_icon {

    my $self = shift;
    my ( $p_icon, $s_icon ) = @_;

    # $p_icon ||= '!';
    # $s_icon /= 1000 if $s_icon;
    my $flags = 0;

    # # Set valid icon id
    # $self->{data}{icon} = $self->{list}{$p_icon},
    # $flags = &NIF_ICON
    #   if exists $self->{list}{$p_icon};

    # Add icon window to task status bar
    $self->_update_TSA_icon( $flags, &NIM_ADD );

    # Time::HiRes::sleep( $s_icon ) if $flags and $s_icon;
    $self->change_icon( $p_icon, $s_icon );
}

# Function!
sub _remove_icons {

    my @_TSA_reg = @{$_TSA_reg};
    foreach my $obj (@_TSA_reg) {
        eval { $obj->remove_icon } if ref $obj;
    }
}

sub _update_TSA_icon {

    # -- Semaphore P operation
    $_S_update_TSA_icon->down;

    my $self = shift;
    my ( $flags, $function ) = @_;
    $! = undef;

    # -- Clear $pNotifyIconData buffer
    my ($pNotifyIconData) = pack( &NOTIFYICONDATA, (0) );

    $pNotifyIconData = pack(
        &NOTIFYICONDATA,
        (   length($pNotifyIconData),       # L     size of pNotifyIconData
            $self->{data}{window},          # L     handle Window
            $self->{data}{icon_id},         # L     ID used for the icon
            $flags | &NIF_MESSAGE,          # L     a set of flags that tells
                                            #       the sytem how the icon is
                                            #       going to act ( NIF_ICON,
                                            #       NIF_MESSAGE or NIF_TIP )
            $self->{data}{message_id},      # L     the event your icon is
                                            #       respond to
            $self->{data}{icon},            # L     a handle to the icon that
                                            #       will be placed in the tray
            $self->{data}{hover_text},      # a128  a variable containing the
                                            #       tooltip supposed to be shown
                                            #       when the user stops the
                                            #       mouse over the icon
            0,                              # L     WindowState
            0,                              # L     State mask
            $self->{data}{balloon_text},    # a256  ...
            $self->{data}{balloon_timeout}, # L     Balloon timeout value
                                            #       (milliseconds) (???)
                                            #       1 = 10 sec, 2 = 10 sec ...
                                            #       max. 6 = 30 sec (???)
            $self->{data}{balloon_title},   # a64   ...
            $self->{data}{info_flags},      # L     ...
        )
    );

    # -- Debug (alpha)
    _print_error(
        $!,
        [   '$self ' . Dumper($self),
            '$flags ' . Dumper($flags),
            '$function ' . Dumper($function),
        ]
    ) if $!;

    $function = &NIM_MODIFY unless defined $function;
    if ( !main::Shell_NotifyIcon( $function, $pNotifyIconData ) ) {
        _print_error(
            $!,
            [   '$function ' . $function, '$pNotifyIconData ' . $pNotifyIconData
            ]
        );
    }

    # -- Semaphore V operation
    $_S_update_TSA_icon->up;
}

sub _print_error {

    my $_err = shift;
    my ($_val) = @_;
    printf STDERR "Error: '$_err'\n" . "\t'%s'\n" x @{$_val}, @{$_val}
        if $_err;
}

sub _ident {

    my $self = shift;
    $self->change_text( shift || $script_name );
}

# Internal method
sub _format_file {

    local $_ = shift;
    s!\\!/!g;
    s!^/|/$!!g;
    s!/+!/!g;
    $_;

}

# Internal method
sub _format_path {

    local $_ = _format_file(shift);
    $_ .= '/';
    $_;

}

sub res_path {

    my $path = _format_path( $ENV{NOTIFY_RESOURCES} || $res_path );
    return -d $path ? $path : undef;
}

END {

    # Auto TSA cleanup
    _remove_icons($_TSA_reg);
}

1;

__END__

=head1 NAME

Win32::TSA::Notify - Win32 Taskbar Status Area Notification System

=head1 VERSION

This documentation refers to Win32::TSA::Notify Version 0.01.01
$Revision: 462 $

Precautions: Alpha Release.

=head1 SYNOPSIS

  use Win32::TSA::Notify;

=item * Standard

  $icon = Win32::TSA::Notify->new();
  $icon = Win32::TSA::Notify->new( 'myApp', 500, 'MyApp' );
  $icon = Win32::TSA::Notify->new( [ qw(myApp red green myApp) ], 500, 'MyApp' );

  $icon->change_icon( 'app' );
  $icon->change_icon( 'app', 1000 );
  $icon->change_icon( [ qw(blue red green yellow) ] , 250 );
  $icon->remove_icon;
  
  $icon->change_text( qq(Tooltip ... etc.) );
    
  $icon->alert( 'Alert1', "Message1\nText1" );
  $icon->alert( 'Alert2', "Message2\nText2", 'info' );
  $icon->alert( 'Alert3', "Message3\nText3", 'warning', 'Attention please' );
  $icon->clear_alert;
  $self->clear_alert if $icon->alert_status;

=item * PerlTray Emulation

  $icon->SetIcon( 'app' );
  $icon->SetIcon( 'app', 1000 );
  $icon->SetIcon( [ 'blue', 'red', 'green', 'yellow' ] , 250 );
  
  $icon->SetAnimation( 5000, 250, 'blue', 'red', 'green', 'yellow' );
  $icon->SetAnimation( 5000, 250, [ 'blue', 'red', 'green', 'yellow' ] );
  
  $icon->Balloon( 'Info1', 'Title1', 'warning', 3000 );
  $icon->Balloon( 'Info2', 'Title2', 'none', 5000 );

=head1 DESCRIPTION

C<Win32::TSA::Notify> is an Win32 Taskbar Status Area Notification System.

... tdb

=head1 METHODS

=item * change_icon

=item * remove_icon

=item * restore_icon

=item * change_text

=item * alert

=item * clear_alert

=item * alert_status

=item * SetIcon(ICON)

=item * SetAnimation(DURATION, FREQUENCY, ICONS)

=item * Balloon(INFO, TITLE, ICON, TIMEOUT)

=head1 EXAMPLE

See source file F<exe/Win32-TSA-Notify.pl>, packer configuration file
F<exe/Win32-TSA-Notify.perlapp> and test executable files
F<exe/Win32-TSA-Notify.exe> and F<exe/Win32-TSA-Notify.bat>
of this distribution.

=head1 CREDITS

The module C<Win32::TSA::Notify> is  based on code written by Dave Roth and was
rewritten by Thomas Walloschke.

Significant inspiration comes from code in

'How to Script In-Your-Face Alerts - A TSA notification system'
(L<http://www.windowsitpro.com/Article/ArticleID/45195/45195.html>),
application example in F<45195.zip> written by Dave Roth
(L<http://www.roth.net>).

=for WindowsITPro excerpt:
    '...if you're working on a computer when something goes wrong, you need an
    alert that jumps out and is in your face. You could decide to write code
    that pops open a dialog box with a message. But if you use that approach
    and many alerts occur while you're away from your computer, you have to
    wade through numerous dialog boxes and click OK in each one. A better way
    to provide alerts is to use the taskbar status area (TSA)...'

=cut

C<Win32::TSA::Notify> provides an object-oriented interface to handle more than
one TSA-window in one program.

=head BUGS

=head1 SEE ALSO

L<Win32::API::Prototype> at L<http://www.roth.net/perl/prototype/>

L<Win32::PerlExe::Env> at L<http://www.cpan.org>

=head1 AUTHOR

E<lt>Thomas Walloschke (thw@cpan.org)E<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 Thomas Walloschke (thw@cpan.org).

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 DATE

Last changed $Date: 2006-09-01 02:05:08 +0200 (Fr, 01 Sep 2006) $.

=cut
