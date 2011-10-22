# =============================================================================
# $Id: Text.pm 462 2006-09-01 00:05:08Z HVRTWall $
# Copyright (c) 2005-2006 Thomas Walloschke (thw@cpan.org). All rights reserved.
# Text - Win32 Taskbar Status Area Notification System
# ==============================================================================

package Win32::TSA::Notify::Text;

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

# -- Change tooltip (text)
sub change_text {
    my $self = shift;
    my ($message) = @_;

    # Limit message to only 127 chars
    # (128 is the limit including terminating null)
    $message =~ s/^(.{0,127}).*$/$1/s if $message;

    $self->{data}{hover_text} = $message;
    $self->_update_TSA_icon(&NIF_TIP);

    return $self;
}

1;

__END__

=head1 NAME

Win32::TSA::Notify:Text -  Tooltip handling for Win32 TSA Notification System

=head1 SYNOPSIS

  use Win32::TSA::Notify:Text;
  
  $icon = Win32::TSA::Notify::Text->new();
  $icon->change_text( qq(Tooltip ... etc.) );

=head1 DESCRIPTION

Internal module.

May be used directly by user to access this class methods only.

=head1 METHODS

=item * change_text

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
