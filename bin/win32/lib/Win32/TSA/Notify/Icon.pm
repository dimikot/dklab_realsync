# =============================================================================
# $Id: Icon.pm 462 2006-09-01 00:05:08Z HVRTWall $
# Copyright (c) 2005-2006 Thomas Walloschke (thw@cpan.org). All rights reserved.
# Icon - Win32 Taskbar Status Area Notification System
# ==============================================================================

package Win32::TSA::Notify::Icon;

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

# -- Global modules
use Time::HiRes;

# *** Methods ******************************************************************

# -- Change icon
sub change_icon {

    my $self = shift;
    my ( $p_icon, $s_icon ) = @_;

    if ($p_icon) {
        $p_icon = [$p_icon] if ref $p_icon ne "ARRAY";
        $s_icon /= 1000 if $s_icon;

        $self->clear_alert if $self->alert_status;

        foreach my $_p_icon ( @{$p_icon} ) {
            next unless $_p_icon;

            $self->{alert}{_last}{icon} = $self->{data}{icon} || 0;
            $self->{data}{icon} = $self->{list}{$_p_icon} || 0;
            $self->_update_TSA_icon(&NIF_ICON);

            Time::HiRes::sleep($s_icon) if $s_icon;
        }
    }

    return $self;
}

# -- Restore to last icon
#    I believe that this method may be dispensable.
#    Please tell me, if you really need it.
sub restore_icon {

    my $self = shift;
    $self->change_icon( $self->{rlist}{ $self->{alert}{_last}{icon} }, shift );
    return $self;
}

# -- Remove icon
sub remove_icon {

    my $self = shift;

    # Delete this object from TSA registry
    foreach my $i ( 0 .. $#{$Win32::TSA::Notify::_TSA_reg} ) {
        splice( @{$Win32::TSA::Notify::_TSA_reg}, $i, 1 ), last
            if $Win32::TSA::Notify::_TSA_reg->[$i] eq $self;
    }

    # Delete icon from TSA
    $self->_update_TSA_icon( 0, &NIM_DELETE );

    return $self;
}

1;

__END__

=head1 NAME

Win32::TSA::Notify::Icon - Icon handling for Win32 Taskbar Status Area Notification System

=head1 SYNOPSIS

  use Win32::TSA::Notify::Icon;
  
  $icon = Win32::TSA::Notify::Icon->new();
  $icon->change_icon( 'app' );
  $icon->change_icon( 'app', 1000 );
  $icon->change_icon( [ 'blue', 'red', 'green', 'yellow' ], 250 );
  $icon->remove_icon;
  
  $icon->restore_icon();
  $icon->restore_icon( 1000 );

=head1 DESCRIPTION

Internal module.

May be used directly by user to access this class methods only.

=head1 METHODS

=item * change_icon( ICON )

=item * change_icon( ICON, FREQUENCY )

=item * change_icon( [ ICONS ], FREQUENCY )

The change_icon( ICON ) function changes the tray icon to ICON. After FREQUENCY
milliseconds SetIcon() will return.

The change_icon( [ ICONS ] ...) function animates the object icon by cycling
through all icons in the ICONS list. The icon is changed every FREQUENCY
milliseconds.

ICON must be the name of one of the icons bundled with the application, but
without the application prefix and ".ico" extension.

I<Example:>

    Application Name:   Win32-TSA-Notify.pl
    ICON            :   application
    Icon Name       :   Win32-TSA-Notify_Application.ico

change_icon() terminates any alert() that may be in progress.

=item * remove_icon

=item * restore_icon

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
