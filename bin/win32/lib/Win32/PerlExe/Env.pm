# =============================================================================
# $Id: Env.pm 486 2006-09-09 18:48:00Z HVRTWall $
# Copyright (c) 2005-2006 Thomas Walloschke (thw@cpan.org). All rights reserved.
# Get environment informations of Win32 Perl executables
# ==============================================================================

package Win32::PerlExe::Env;

BEGIN { warn "Warning: No MSWin32 System" unless $^O eq 'MSWin32' }

# -- Pragmas
use 5.008006;
use strict;
use warnings;

# -- Global modules
use File::Basename;

# -- Items to export into callers namespace
require Exporter;
our @ISA         = qw(Exporter);
our @EXPORT      = qw(get_tmpdir);
our %EXPORT_TAGS = (
    'tmp'  => [qw(get_tmpdir get_filename)],
    'vars' => [qw(get_build get_perl5lib get_runlib get_tool get_version)],
);

#$EXPORT_TAGS{all} =
#    [ map {$_} @{ $EXPORT_TAGS{tmp} }, @{ $EXPORT_TAGS{vars} } ];
$EXPORT_TAGS{all} = [ map { @{ $EXPORT_TAGS{$_} } } keys %EXPORT_TAGS ];
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our ( $VERSION, $v, $_VERSION );

# -- CPAN VERSION (='major.minor{2}')
$VERSION = do { my @r = ( ( $v = q<Version value="0.4.1"> ) =~ /\d+/g ); splice( @r, 2 ); sprintf "%d" . ".%02d" x $#r, @r };

# -- Mumified VERSION (='major.minor{3}release{3}revision{3}')
$_VERSION = do {
    my @r = ( $v =~ /\d+/g, q$Revision: 486 $ =~ /\d+/g );
    sprintf "%d." . "%03d" x $#r, @r;
};

# -- Build default filenames from package name chunks
my $_def_filenames = { map { $_ => 1 } split q{::}, __PACKAGE__ };

# -- Get internal temporary working dir of executable
sub get_tmpdir {

    # -- Try it easily
    ( my $_tmpdir ) = _get_tmpdir()
        if not defined $_[0]
        or $_def_filenames->{ $_[0] };

    # -- Try it harder
    do {
        $_tmpdir = get_filename( $_[0] );
        $_tmpdir = $_tmpdir
            ? dirname($_tmpdir) . q{/}
            : undef;
    } unless $_tmpdir;

    return $_tmpdir;
}

# -- Get internal temporary filename
sub get_filename {

    my $_filename;

    foreach ( $_[0] || keys %{$_def_filenames} ) {
        last if ($_filename) = _get_filename($_);
    }

    return $_filename;
}

# -- Get variables of executable
sub get_build    { ($_) = _get_var('BUILD');    $_ }
sub get_perl5lib { ($_) = _get_var('PERL5LIB'); $_ }
sub get_runlib   { ($_) = _get_var('RUNLIB');   $_ }
sub get_tool     { ($_) = _get_var('TOOL');     $_ }
sub get_version  { ($_) = _get_var('VERSION');  $_ }

# *** Internal functions *******************************************************

sub _get_tmpdir {

    return map { s|\\|/|g if defined; $_ }

        # -- Ignore unvalid files
        &_nowin32
        ? undef

        # -- ActiveState PDK
        #    Try to read temp dir if (win32-)parent (no win32 kids allowed)
        : ( eval "PerlApp::exe()" and $$ > 0 )
        ? eval { PerlApp::get_temp_dir() =~ /^(.*)(\\)$/; $1 . "-$$" . $2 }
        : ( eval "PerlSvc::exe()" and $$ > 0 )
        ? eval { PerlSvc::get_temp_dir() =~ /^(.*)(\\)$/; $1 . "-$$" . $2 }
        : ( eval "PerlTray::exe()" and $$ > 0 )
        ? eval { PerlTray::get_temp_dir() =~ /^(.*)(\\)$/; $1 . "-$$" . $2 }

        # -- PerlExe ... (assumed code :) )                                 XXX
        : eval "PerlExe::exe()" ? eval { PerlExe::get_temp_dir() }    #     XXX

        # -- No executable infos found
        : undef;
}

sub _get_filename {

    my $_file = shift;

    return map { s|\\|/|g if defined; $_ }

        # -- Ignore unvalid files
        &_nowin32
        ? undef

        # -- ActiveState PDK
        #    Try to extract bound file to get full filename
        : eval "PerlApp::exe()"  ? eval { PerlApp::extract_bound_file($_file) }
        : eval "PerlSvc::exe()"  ? eval { PerlSvc::extract_bound_file($_file) }
        : eval "PerlTray::exe()" ? eval { PerlTray::extract_bound_file($_file) }

        # -- PerlExe ... (assumed code :) )                                 XXX
        : eval "PerlExe::exe()" ? eval { PerlExe::get_file($_file) }    #   XXX

        # -- No executable infos found
        : undef;
}

sub _get_var {

    my $_var = shift;
    my $_map = {

        # -- PDK mapping
        'PerlApp::BUILD'    => eval "\$PerlApp::BUILD",
        'PerlApp::PERL5LIB' => eval "\$PerlApp::PERL5LIB",
        'PerlApp::RUNLIB'   => eval "\$PerlApp::RUNLIB",
        'PerlApp::TOOL'     => eval "\$PerlApp::TOOL",
        'PerlApp::VERSION'  => eval "\$PerlApp::VERSION",

        'PerlSvc::BUILD'    => eval "\$PerlSvc::BUILD",
        'PerlSvc::PERL5LIB' => eval "\$PerlSvc::PERL5LIB",
        'PerlSvc::RUNLIB'   => eval "\$PerlSvc::RUNLIB",
        'PerlSvc::TOOL'     => eval "\$PerlSvc::TOOL",
        'PerlSvc::VERSION'  => eval "\$PerlSvc::VERSION",

        'PerlTray::BUILD'    => eval "\$PerlTray::BUILD",
        'PerlTray::PERL5LIB' => eval "\$PerlTray::PERL5LIB",
        'PerlTray::RUNLIB'   => eval "\$PerlTray::RUNLIB",
        'PerlTray::TOOL'     => eval "\$PerlTray::TOOL",
        'PerlTray::VERSION'  => eval "\$PerlTray::VERSION",

        # -- PerlExe ... (assumed code :) )                                 XXX
        'PerlExe::BUILD'    => eval "\$PerlExe::foo",       #               XXX
        'PerlExe::PERL5LIB' => eval "\$PerlExe::bar",       #               XXX
        'PerlExe::RUNLIB'   => eval "\$PerlExe::foobar",    #               XXX
        'PerlExe::TOOL'     => eval "\$PerlExe::barfoo",    #               XXX
        'PerlExe::VERSION'  => eval "\$PerlExe::foofoo",    #               XXX
    };

    return map { s|\\|/|g if defined; $_ }

        # -- Ignore unvalid files
        &_nowin32
        ? undef

        # -- ActiveState PDK
        #    Try to read variables (via mapping)
        : $_map->{ 'PerlApp::' . $_var }  ? $_map->{ 'PerlApp::' . $_var }
        : $_map->{ 'PerlSvc::' . $_var }  ? $_map->{ 'PerlSvc::' . $_var }
        : $_map->{ 'PerlTray::' . $_var } ? $_map->{ 'PerlTray::' . $_var }

        # -- PerlExe ... (assumed code :) )                                 XXX
        : $_map->{ 'PerlExe::' . $_var } ? $_map->{ 'PerlExe::' . $_var }  # XXX

        # -- No executable infos found
        : undef;
}

# -- Valid Win32 executable has a length > 0
#    and is a binary .exe or .dll file
sub _nowin32 { not( -s $0 and -B $0 and $0 =~ /\.(exe|dll)$/ ) }

1;

__END__

=head1 NAME

Win32::PerlExe::Env - Get environment informations of Win32 Perl executables

=head1 VERSION

This documentation refers to Win32::PerlExe::Env Version 0.02.05
$Revision: 486 $

Precautions: Alpha Release.

=head1 SYNOPSYS

=over 2

=item :DEFAULT

    use Win32::PerlExe::Env;
    $dir  = get_tmpdir();
    $dir  = get_tmpdir( 'Copyright' );

=item :tmp

    use Win32::PerlExe::Env qw(:tmp);
    $dir  = get_tmpdir();
    $file = get_filename();

=item :vars

    use Win32::PerlExe::Env qw(:vars);
    my @vars =
        ( map {&$_} qw(get_build get_perl5lib get_runlib get_tool get_version) );

=item :all

    use Win32::PerlExe::Env qw(:all);
    %vars = (
        map { uc $_ => eval "&get_$_" }
            map {lc} qw(tmpdir filename BUILD PERL5LIB RUNLIB TOOL VERSION)
    );
    
=back

=head1 DESCRIPTION

Win32::PerlExe::Env provides special 'build-in' environment informations of
Perl .exe files.

The main goal of this module version is to receive the internal temporary
directory of packed Perl executables regardless of the used packer.

Additional packer specific environment informations like version, packername,
etc. will be supported.

This version assists ActiveState PDK packers.

=head2 EXPORT

=over 2

=item :DEFAULT

  get_tmpdir

=item :tmp

  get_tmpdir get_filename

=item :vars

  get_build get_perl5lib get_runlib get_tool get_version

=item :all

  get_tmpdir get_filename get_build get_perl5lib get_runlib get_tool get_version

=back

=head1 FUNCTIONS

=over 2

=item * get_tmpdir()

=item * get_tmpdir(filename)

Get internal temporary working directory of executable.

I<Hint for ActiveState PDK packer: The returned internal temporary working
directory will exist only if any packed file was extracted automactically or
explicitly L<SEE ALSO>. Therefore it is strongly recommended to test the
existence of the returned directory (-d) before usage>.

=item * get_filename()

=item * get_filename(filename)

Get internal temporary filename of executable.

I<Security hint for ActiveState packer: As a side effect the given file will be
extracted into internal temporary working directory L<SEE ALSO>>.

=item * get_build

Get the B<packers> build number.

=item * get_perl5lib

Get the PERL5LIB environment variable. If that does not exist, it contains the
value of the PERLLIB environment variable. If that one does not exists either,
result is undef. 

=item * get_runlib

Get the fully qualified path name to the runtime library directory.

ActiveState specifies this by the --runlib option. If the --norunlib
option is used, this variable is undef. 

=item * get_tool

Get string B<PerlApp|PerlSvc|PerlTray ...>, indicating that the
currently running executable has been produced by this packer (=tool). 

=item * get_version

Get the packers version number: 'major.minor.release', but not including the
build number.

=back

=head1 DIAGNOSTICS

Running this module as part of a normal script (.pl) 'undef' results will be
returned.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 [PDK] BOUND FILES

B<ActiveState PDK only:>

Bound files are additional files to be included in the executable which can
be extracted to an internal temporary directory or can be read directly like
normal files.

Win32::PerlExe::Env supports different strategies to find out the internal
temporary directory because basically inofficial PDK functions are used.

To get a stable configuration under all circumstances it is recommended that
the PDK configuration files (*.perlapp, *.perlsvc or *.perltray) contain one of
the following entries to define an internal B<default bound file>:

  Bind: Win32[data=Win32]
  Bind: PerlExe[data=PerlExe]
  Bind: Env[data=Env]

These 'identifiers' will be tested internally as defaults. See L<EXAMPLE>.

Alternatively the B<default bound file> can be omitted if one or more
B<user bound files> were bound into the executable instead, e. g.

  Bind: Get_Info.ico[file=res\icons\Get_Info.ico] and/or
  Bind: Copyright[data=Copyright (c) 2006 Thomas Walloschke.]

This means the ':tmp' functions can be called with one of these filenames:

  get_filename( 'Get_Info.ico' );
  get_tmpdir( 'Copyright' );

=head1 EXAMPLE

See source file F<exe/Win32-PerlExe-Env.pl>, packer configuration file
F<exe/Win32-PerlExe-Env.perlapp> and test executable files
F<exe/Win32-PerlExe-Env.exe> and F<exe/Win32-PerlExe-Env.bat>
of this distribution.

=for Executable file 'exe/Win32-PerlExe-Env.exe':
    The executable was packed with ActiveState PDK PerlApp 6.0.2. The size was
    optimized with packer options set to 'Make dependent executable' and
    'Exclude perl58.dll from executable'. To run this executable properly a
    Win32 Perl Distribution (e. g. ActivePerl) must be installed.
    This example uses the local (uninstalled!) module Win32::PerlExe::Env from
    the lib directory of this distribution.

=cut

=head1 DEPENDENCIES

An advantageous Win32 PerlExe Packer like Perl Development Kit [PDK].

=head1 BUGS

This version examines 'ActiveState PDK executables' only (PerlApp, PerlSvc and
PerlTray).

Win32::PerlExe::Env was tested only with MS Windows XP Professional
(5.1.2600 Service Pack 2) and ActiveState PDK 6.0.2.

Send bug reports to my email address or use the CPAN RT system.

=for Improvement Opportunities:
    I would be pleased if anyone could send me additional interface
    descriptions for other .exe distributions.
    Ref. in source: -- PerlExe ... (assumed code :) )

=cut

=head1 SEE ALSO

Perl Development Kit [PDK] L<http://www.activestate.com/Products/Perl_Dev_Kit/?mp=1>

=head1 AUTHOR

Thomas Walloschke E<lt>thw@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2006 Thomas Walloschke (thw@cpan.org). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=head1 DATE

Last changed $Date: 2006-09-09 20:48:00 +0200 (Sa, 09 Sep 2006) $.

=cut
