# =============================================================================
# $Id: Alert.pm 462 2006-09-01 00:05:08Z HVRTWall $
# Copyright (c) 2005-2006 Thomas Walloschke (thw@cpan.org). All rights reserved.
# Alert - Win32 Taskbar Status Area Notification System
# ==============================================================================

package Win32::TSA::Notify::Alert;

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

# *** Methods ******************************************************************

sub alert {

    my $self = shift;
    my ( $alert_title, $alert_message, $icon_name, $message ) = @_;

    my $flags = &NIF_INFO | &NIF_ICON;

    # Limit title text to only 63 chars
    # (64 is the limit including terminating null)
    $alert_title =~ s/^(.{0,62}).*$/$1/s if $alert_title;

    # Limit alert text to only 254 chars
    # (255 is the limit including terminating null)
    $alert_message =~ s/^(.{0,254}).*$/$1/s if $alert_message;

    # Set missing icon_name to _default and wrong icon_name to _none
    $icon_name = '_default' unless $icon_name;
    $icon_name = '_none'    unless exists $self->{alert}{$icon_name};

    # Limit alert text to only 127 chars
    # (128 is the limit including terminating null)
    $message =~ s/^(.{0,127}).*$/$1/s if $message;

    $self->{data}{_alert_status} = 1;
    $self->{data}{balloon_title} = $alert_title;
    $self->{data}{balloon_text}  = $alert_message;
    $self->{data}{info_flags}    = $self->{alert}{$icon_name}{info_flags}
        || 0;
    $self->{alert}{_last}{icon} = $self->{data}{icon}
        || &UNDEFINED_ICON;
    $self->{data}{icon} = $self->{alert}{$icon_name}{icon};

    if ($message) {
        $self->{data}{hover_text} = $message;
        $flags |= &NIF_TIP if $message;
    }

    $self->_update_TSA_icon($flags);

    return $self;
}

sub clear_alert {

    my $self = shift;

    $self->{data}{_alert_status} = 0;
    $self->{data}{balloon_title} = "";
    $self->{data}{balloon_text}  = "";
    $self->{data}{info_flags}    = $self->{alert}{_none}{info_flags};
    $self->{data}{icon}          = $self->{alert}{_last}{icon}
        || $self->{list}{ $self->{alert}{none}{icon_name} }
        || &UNDEFINED_ICON;
    $self->{alert}{_last}{icon} = $self->{data}{icon};

    $self->_update_TSA_icon( &NIF_INFO | &NIF_ICON );

    return $self;
}

sub sleep { Time::HiRes::sleep( $_[1] / 1000 ); return $_[0] }

# Getter
sub alert_status { $_[0]->{data}{_alert_status} }

1;

__END__

=head1 NAME

Win32::TSA::Notify::Alert - Alert handling for Win32 TSA Notification System

=head1 SYNOPSIS

  use Win32::TSA::Notify::Alert;
  
  $icon = Win32::TSA::Notify::Alert->new();
  $icon->alert( 'Alert1', "Message1\nText1" );
  $icon->alert( 'Alert2', "Message2\nText2", 'info' );
  $icon->alert( 'Alert3', "Message3\nText3", 'warning', 'Attention please' );
  $icon->clear_alert;
  $self->clear_alert if $icon->alert_status;

=head1 DESCRIPTION

Internal module.

May be used directly by user to access this class methods only.

=head1 METHODS

=item * alert

=item * clear_alert

=item * alert_status

=head1 SEE ALSO

L<Win32::TSA::Notify>

=head1 AUTHOR

E<lt>Thomas Walloschke (thw@cpan.org)E<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 Thomas Walloschke (thw@cpan.org).

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 DATE

Last changed $Date: 2006-09-01 02:05:08 +0200 (Fr, 01 Sep 2006) $.

=cut
