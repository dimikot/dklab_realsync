package Win32::GUI::Constants;

# $Id: Constants.pm,v 1.11 2008/02/09 08:51:27 robertemay Exp $
# Win32::GUI::Constants, part of the Win32::GUI package
# (c) Robert May, 2005..2006
# released under the same terms as Perl.

use 5.006;
use strict;
use warnings;
use warnings::register;

=head1 NAME

Win32::GUI::Constants - exporter for Win32 API constants

=cut

our $VERSION = '0.04';
our $XS_VERSION = $VERSION;
eval $VERSION;

require XSLoader;
XSLoader::load('Win32::GUI::Constants', $XS_VERSION);

our ($Verbose, $AUTOLOAD);

=head1 SYNOPSIS

  use Win32:GUI::Constants;

or

  use Win32:GUI::Constants ();

or

  use Win32::GUI::Constansts [@pragmata,] [@symbols];


Win32::GUI::Constants is a module that provides definitions and export
capabilities for Win32 API constant values.  There is access to more
than 1700 Win32 API constants.  Nothing is exported by default.

=head1 EXPORT SYNTAX

Win32::GUI::Constants provides its own 'import' funcion for performance
reasons, but follows the L<Exporter|Exporter> module's definition for the
syntax, with some additional pragmata to control the export behaviour.

=head2 Standard Syntax

=over 4

=item C<use Win32::GUI::Constants;>

This imports all the default symbols into your namespace.  Currently
there are no default symbols.

=item C<use Win32::GUI::Constants ();>

This loads the module without importing any symbols.

=item C<use Win32::GUI::Constants qw(...);>

This imports only the symbols listed into your namespace. An error
occurs if you try to import a symbol that does not exist.
The advanced export features are accessed like this,
but with list entries that are syntactically distinct from symbol names.

=back

=head2 Advanced Syntax

If any of the entries in an import list begins with !, : or / then
the list is treated as a series of specifications which either add to
or delete from the list of names to import. They are processed left to
right. Specifications are in the form:

  [!]name         This name only
  [!]:tag         All names in class 'tag'
  [!]/pattern/    All names which match pattern

A leading ! indicates that matching names should be deleted from the
list of names to import.

Remember that most patterns (using //) will need to be anchored
with a leading ^, e.g., C</^TPM_/> rather than C</TPM/>.

You can say C<BEGIN { $Win32::GUI::Constants::Verbose=1 }> before your
C<< use Win32::GUI::Constants qw( ... ); >> line to see how the
specifications are being processed and what is actually being imported
into your namespace.

If any of the entries in an import begins with a - then the entry is
treated as a pragma that affects the way in which the exporting is
performed.

=cut

# We're only exporting our own subroutines, write our own import function, simplifying
# Exporter::Heavy::heavy_export.  This implementation can only export subroutines, and
# export list must not pre-pend '&' to the subroutine names.
sub import
{
    my $pkg = shift;
    my $callpkg = caller;
    my @imports;
    my $inline = 0;
    my $export = 1;
    my $autoload = 0;
    my $oops = 0;
    my $compatibility_win32_gui = 0;

=head1 PRAGMATA

The following pragmata ae provided to affect the behaviour of the
export capabilities of Win32::GUI::Constants.

=over

=item B<-inline>

Causes the constant subroutine body to be generated at compile
time.  This sacrifices some compile time speed for the ability
for the constants that are listed to be inlined by the
compiler, which gains some runtime speed.

=item B<-noexport>

The same behaviour as B<-inline>, except that the constants
that are listed are not exported, and so must be used by their
fully qualified package names.
(e.g. C<Win32::GUI::Constants::CW_USEDEFAULT>)

=item B<-exportpkg>, I<pkgname>

Causes exported symbols to be exported to the I<pkgname>
namespace, rather than to the caller's namespace. I<pkgname>
must appear as the next item in the list. Omitting
I<pkgname> from the list is likely to cause behaviour
that is difficult to understand.

=item B<-autoload>

Causes Win32::GUI::Constants' C<AUTOLOAD()> subroutine
to be exported, making all non-exported constants
available in that namespace.  Don't do this if the
package you are exporting to already has an
C<AUTOLOAD()> subroutine.

=back

=head1 EXPORT TAGS

See the L<Win32::GUI::Constants::Tags|Win32::GUI::Constants::Tags>
documentation for available tag classes.

Use of :tag export definitions adds some overhead both in terms of compile-time
speed and memory usage.

=cut

    # detect and remove our pragmas from the import list, and do
    # version checking:
    my $setpkg = 0;
    foreach (@_) {
        # Always expect the export package name immediately after
        # the -exportpkg pragma
        $callpkg=$_,$setpkg=0, next if $setpkg;
        $inline=1,             next if /^-inline$/;
        # Always inline if not exporting, otherwise -noexport does nothing
        $export=0, $inline=1,  next if /^-noexport$/;
        $setpkg=1,             next if /^-exportpkg$/;
        $autoload=1,           next if /^-autoload$/;
        # warn if we see an unrecognised pragma
        ++$oops, warnings::warn qq("$_" is not a recognised pragma), next if /^-/;
        $pkg->VERSION($_),     next if /^\d/;    # inherit from UNIVERSAL
        push @imports, $_;
    }

    if(@imports) {
        # expand @imports, if necessary
        if (grep m{^[/!:]}, @imports) {
            my %imports;
            # negated first item implies starting with default set:
            # our default is empty, so don't add anything
            #unshift @imports, ':DEFAULT' if $imports[0] =~ m/^!/;
            foreach my $spec (@imports) {
                my @names;
                my $remove = $spec =~ s/^!//;

                if ($spec =~ s/^://){
                    # Only require Tags module if we need it
                    require Win32::GUI::Constants::Tags;
                    if(my $namesref = Win32::GUI::Constants::Tags::tag($spec)){
                        @names = @$namesref;
                    }
                    else {
                        warnings::warn qq(tag ":$spec" is not defined by $pkg);
                        ++$oops;
                        next;
                    }
                    # :compatibility_win32_gui has very special semantics if
                    # the calling package is Win32::GUI for backwards compatibility
                    if (($spec eq 'compatibility_win32_gui') and (caller eq 'Win32::GUI')) {
                        $compatibility_win32_gui = 1;
                    }
                }
                elsif ($spec =~ m:^/(.*)/$:){
                    my $patn = $1;
                    # If we expect to see lots of these, then we
                    # may want to store the reference rather than
                    # calling _export_ok() each time
                    @names = grep(/$patn/, @{_export_ok()}); # not anchored by default
                }
                else {
                    @names = ($spec); # is a normal symbol name
                }

                warn "Import ".($remove ? "del":"add").": @names " if $Verbose;

                if ($remove) {
                    foreach my $sym (@names) { delete $imports{$sym} } 
                }
                else {
                    @imports{@names} = (1) x @names;
                }
            }
            @imports = keys %imports;
        }
    }

    # If we did
    #   use Win32::GUI::Constants 0.01, '';
    # I.e. a version check with no imports, then imports contains a single entry with value ''
    if( @imports == 1 and $imports[0] eq '' ) {
        @imports = ();
    }

    # export @imports to caller's namespace
    if($Verbose) {
        my $t = join(", ", sort @imports) . "\n" . scalar(@imports) . " symbols being ";
        $t   .= "imported into $callpkg from $pkg " if $export;
        $t   .= "and " if $export and $inline;
        $t   .= "prepared for inlining " if $inline;
        warn $t;
    }

    {
        no strict 'refs';
        # Single loop with statement modifiers is faster than 2 loops,
        # unless both $export and $inline are false.  That doesn't
        # happen
        my @export_ok = @{_export_ok()};
        foreach my $sym (@imports) {
            #check that $sym can be exported, and croak if not.
            if(not grep /^$sym$/, @export_ok) {
                warnings::warn qq("$sym" is not exported by $pkg);
                ++$oops;
                next;
            }
            *{"${callpkg}::$sym"} = \&{"${pkg}::$sym"} if $export;
            &{"${pkg}::$sym"} if $inline;  # force AUTOLOAD
	    eval "sub Win32::GUI::$sym();" if $compatibility_win32_gui;
        }

        *{"${callpkg}::AUTOLOAD"} = \&{"${pkg}::AUTOLOAD"} if $autoload;
    }

    if($oops) {
        # only require Carp if we need it
        require Carp;
        Carp::croak(qq(Can't continue after import errors));
    }
}

sub AUTOLOAD
{
    my $constant = $AUTOLOAD;
    $constant =~ s/.*:://;

    my $val = constant($constant);

    if(defined $val) {
        {
            no warnings; # avoid perl 5.6 warning about prototype mismatches
            eval "sub $AUTOLOAD() {$val}";
        }
        goto &$AUTOLOAD;
    }

    #TODO: use Carp?  Change to 'Constant $constant is not found by Win32::GUI::Constants'
    warnings::warnif("AUTOLOAD failed to find '$constant'");
    return undef;
}

1; # End of Constants.pm
__END__

=head1 FUNCTIONS

=head2 constant

  my $value = Win32::GUI::Constants::constant('SOME_CONST');

The C<constant()> function may be used to perform the lookup of a string
constant identifier to its numeric value.  This has the advantage of not
resulting in any memory overhead due to created symbol table entries,
at the expense of speed, as the lookup must be performed every time this
function is called.

Returns the constant's numeric value on success, undef on failure.

=head1 REQUIRES

No prerequsites other than perl core modules (strict, warnings,
warnings::register, Carp).

Win32::GUI::Constants may be useful to other Win32::* packages.

=head1 SEE ALSO

MSDN L<http://msdn.microsoft.com> and individual api documentation
for more information on constants required for any particular call.

L<Win32::GUI|Win32::GUI>

=head1 SUPPORT

Homepage: L<http://perl-win32-gui.sourceforge.net/>.

For further support join the users mailing list
(C<perl-win32-gui-users@lists.sourceforge.net>) from the website
at L<http://lists.sourceforge.net/lists/listinfo/perl-win32-gui-users>.
There is a searchable list archive at
L<http://sourceforge.net/mail/?group_id=16572>

=head1 BUGS

Not all constants are covered.  If you find missing constants
please raise a feature request at
L<http://sourceforge.net/tracker/?group_id=16572&atid=366572>

=head1 AUTHORS

Robert May, E<lt>robertemay@users.sourceforge.netE<gt>

=head1 ACKNOWLEDGEMENTS

Many thanks to the Win32::GUI developers at
L<http://perl-win32-gui.sourceforge.net/> for suggestions
and assistance.

=head1 COPYRIGHT & LICENSE

Copyright 2005..2008 Robert May, All Rights Reserved.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
