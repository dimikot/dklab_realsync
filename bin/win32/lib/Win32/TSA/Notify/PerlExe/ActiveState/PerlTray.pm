# =============================================================================
# $Id: PerlTray.pm 462 2006-09-01 00:05:08Z HVRTWall $
# Copyright (c) 2005-2006 Thomas Walloschke (thw@cpan.org). All rights reserved.
# Win32 Taskbar Status Area Notification System
# ==============================================================================

package Win32::TSA::Notify::PerlExe::ActiveState::PerlTray;

# -- Pragmas
use 5.008006;
use strict;
use warnings;

# --
require Win32::TSA::Notify;
our @ISA = qw(Win32::TSA::Notify);

# -- Variable definitions
our ($VERSION);

# -- Version (reformatted 'major.minor(3)release(3)revision(3)')
$VERSION = do { my @r = ( q<Version value="0.01.01"> =~ /\d+/g, q$Revision: 462 $ =~ /\d+/g ); sprintf "%d." . "%03d" x $#r, @r };

package Win32::TSA::Notify;

# -- Pragmas
use strict;
use warnings;

use threads;            # Allow parallel icon animation
use threads::shared;    # Allow stopping icon animation

# -- Global modules
use Time::HiRes;

# *** Emulates PerlTray Functions (Ref. ...) ***********************************
#     $notify->SetIcon( icon [, frequency] )
#     $notify->SetAnimation( duration, frequency, icon [, ... icon] )
#     $notify->Ballon( info, title, icon, timeout)
#     $notify->Sleep( timeout );

# -- Shared variables
my $_animate_status = {};
share($_animate_status);

# -- Set Icon
*SetIcon = \&change_icon;

# --
sub SetAnimation {

    my $self = shift;
    my $_self : shared;
    $_self = sprintf "%s", $self;
    my ( $duration, $frequency, @icons ) = @_;

    $self->clear_alert() if $self->alert_status;
    $_animate_status->{$_self} = $self->_set_animate($_self);

    # Non blocking async animation
    async { $self->_SetAnimation( $_self, $duration, $frequency, @icons ) };

    return $self;
}

# --
sub Balloon {
    my $self = shift;
    my ( $info, $title, $icon, $timeout ) = @_;

    # Blocking sync balloon
    $self->_Balloon( $info, $title, $icon, $timeout );

    return $self;
}

# --
*Sleep = \&sleep;

# -- Suppress warnings 'SetIcon/Sleep used only once'
&SetIcon, &Sleep
    if 0;

# *** Internal methods *********************************************************

sub _SetAnimation {
    my $self = shift;

    my ( $_self, $duration, $frequency, @icons ) = @_;
    my $_stop_time = Time::HiRes::time() + $duration / 1000;

    while ( Time::HiRes::time() < $_stop_time
        and $self->_animate_status($_self) )
    {
        $self->change_icon( \@icons, $frequency );
    }

    $self->_clear_animate($_self);
}

# --
sub _Balloon {
    my $self = shift;
    my ( $info, $title, $icon, $timeout ) = @_;

    $self->_clear_animate if $self->_animate_status;
    $self->clear_alert()  if $self->alert_status;

    $self->alert( $title, $info, $icon );

    Time::HiRes::sleep( $timeout / 1000 );
    $self->clear_alert();
}

# -- Internal Setter and Getter
sub _set_animate { $_animate_status->{ $_[1] || $_[0] } = 1 }
sub _clear_animate  { delete $_animate_status->{ $_[1] || $_[0] } }
sub _animate_status { $_animate_status->{ $_[1]        || $_[0] } }

1;

__END__

=head1 NAME

Win32::TSA::Notify::PerlExe::ActiveState::PerlTray - Perltray emulation of "Tray" functions for Win32 TSA Notification System

=head1 SYNOPSIS

  use Win32::TSA::Notify::PerlExe::PerlTray;
  
  $icon = Win32::TSA::Notify::PerlExe::PerlTray->new();

  $icon->SetIcon( 'app' );
  $icon->SetIcon( 'app', 1000 );
  $icon->SetIcon( [ 'blue', 'red', 'green', 'yellow' ] , 250 );
  
  $icon->SetAnimation( 5000, 250, 'blue', 'red', 'green', 'yellow' );
  $icon->SetAnimation( 5000, 250, [ 'blue', 'red', 'green', 'yellow' ] );
  
  $icon->Balloon( 'Info1', 'Title1', 'warning', 3000 );
  $icon->Balloon( 'Info2', 'Title2', 'none', 5000 );

=head1 DESCRIPTION

Internal module.

May be used directly by user to access this class methods only.

=head1 METHODS

=item * $icon->SetIcon( ICON )

=item * $icon->SetIcon( ICON, FREQUENCY )

=item * $icon->SetIcon( [ ICONS ], FREQUENCY )

The SetIcon( ICON ) function changes the tray icon to ICON. After FREQUENCY
milliseconds SetIcon() will return.

The SetIcon( [ ICONS ] ...) function animates the object icon by cycling
through all icons in the ICONS list. The icon is changed every FREQUENCY
milliseconds.

ICON must be the name of one of the icons bundled with the application, but
without the application prefix and ".ico" extension.

I<Example:>

    Application Name:   Win32-TSA-Notify.pl
    ICON            :   info
    Icon Name       :   Win32-TSA-Notify_Info.ico
    

=item * $icon->SetAnimation( DURATION, FREQUENCY, ICONS )

=item * $icon->SetAnimation( DURATION, FREQUENCY, [ ICONS ] )

The SetAnimation() function animates the object icon by cycling through all
icons in the ICONS list for DURATION milliseconds. The icon is changed every
FREQUENCY milliseconds. After DURATION milliseconds the previous object icon
is restored.

ICON must be the name of one of the icons bundled with the application, but
without the application prefix and ".ico" extension.

I<Example:>

    Application Name:   Win32-TSA-Notify.pl
    ICONS           :   201 .. 203
    Icon Name       :   Win32-TSA-Notify_201.ico
                        Win32-TSA-Notify_202.ico
                        Win32-TSA-Notify_203.ico

=item * $icon->Balloon( INFO, TITLE, ICON, TIMEOUT )

The Balloon() function displays a balloon tooltip for TIMEOUT seconds. The
balloon displays the INFO text and TITLE title. In addition, one of these
icons can be specified: "info", "warning", "error", "none".

I<Example:>

    Application Name:   Win32-TSA-Notify.pl
    ICON            :   none
    Icon Name       :   Win32-TSA-Notify_None.ico

Balloon() terminates any icon animation that may be in progress.

[ ONLY STANDARD ALERT: Balloon will use the given timeout exactly]

    Windows limits the range of the timeout value to between 10 and 30
    seconds. For example, if you specify a value of '2', Windows displays
    the balloon for 10 seconds.

    Only one tooltip can display on the taskbar at any one time. If an
    application attempts to display a tooltip while another is already
    displayed, the tooltip will not display until the already-displayed
    tooltip has been visible for its miminum TIMEOUT value (10 seconds).

    For example, if a tooltip with a TIMEOUT value of 20 seconds is displayed,
    and another application attempts to display a tooltip 5 seconds later, the
    initial tooltip will continue to display for another 5 seconds before it
    is replaced by the second tooltip.

=head1 SEE ALSO

L<Win32::TSA::Notify>

PerlTray, Perl Development Kit (PDK)
L<http://www.activestate.com/Products/Perl_Dev_Kit/?mp=1>

=head1 AUTHOR

E<lt>Thomas Walloschke (thw@cpan.org)E<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 Thomas Walloschke (thw@cpan.org).

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 DATE

Last changed $Date: 2006-09-01 02:05:08 +0200 (Fr, 01 Sep 2006) $.

=cut
