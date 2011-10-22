# This file was created by configpm when Perl was built. Any changes
# made to this file will be lost the next time perl is built.

# for a description of the variables, please have a look at the
# Glossary file, as written in the Porting folder, or use the url:
# http://perl5.git.perl.org/perl.git/blob/HEAD:/Porting/Glossary

package Config;
use strict;
# use warnings; Pulls in Carp
# use vars pulls in Carp
@Config::EXPORT = qw(%Config);
@Config::EXPORT_OK = qw(myconfig config_sh config_vars config_re);

# Need to stub all the functions to make code such as print Config::config_sh
# keep working

sub myconfig;
sub config_sh;
sub config_vars;
sub config_re;

my %Export_Cache = map {($_ => 1)} (@Config::EXPORT, @Config::EXPORT_OK);

our %Config;

# Define our own import method to avoid pulling in the full Exporter:
sub import {
    my $pkg = shift;
    @_ = @Config::EXPORT unless @_;

    my @funcs = grep $_ ne '%Config', @_;
    my $export_Config = @funcs < @_ ? 1 : 0;

    no strict 'refs';
    my $callpkg = caller(0);
    foreach my $func (@funcs) {
	die sprintf qq{"%s" is not exported by the %s module\n},
	    $func, __PACKAGE__ unless $Export_Cache{$func};
	*{$callpkg.'::'.$func} = \&{$func};
    }

    *{"$callpkg\::Config"} = \%Config if $export_Config;
    return;
}

die "Perl lib version (5.10.1) doesn't match executable version ($])"
    unless $^V;

$^V eq 5.10.1
    or die "Perl lib version (5.10.1) doesn't match executable version (" .
	sprintf("v%vd",$^V) . ")";


sub FETCH {
    my($self, $key) = @_;

    # check for cached value (which may be undef so we use exists not defined)
    return $self->{$key} if exists $self->{$key};

    return $self->fetch_string($key);
}
sub TIEHASH {
    bless $_[1], $_[0];
}

sub DESTROY { }

sub AUTOLOAD {
    my $config_heavy = 'Config_heavy.pl';
    if (defined &ActivePerl::_CONFIG_HEAVY) {
       $config_heavy = ActivePerl::_CONFIG_HEAVY();
    }
    require $config_heavy;
    goto \&launcher unless $Config::AUTOLOAD =~ /launcher$/;
    die "&Config::AUTOLOAD failed on $Config::AUTOLOAD";
}

sub __unused {
    # XXX Keep PerlApp happy
    require 'Config_heavy.pl';
}

# tie returns the object, so the value returned to require will be true.
tie %Config, 'Config', {
    archlibexp => 'C:\Perl\\lib',
    archname => 'MSWin32-x86-multi-thread',
    d_readlink => undef,
    d_symlink => undef,
    dlext => 'dll',
    dlsrc => 'dl_win32.xs',
    dont_use_nlink => undef,
    exe_ext => '.exe',
    inc_version_list => '',
    intsize => '4',
    ldlibpthname => '',
    osname => 'MSWin32',
    osvers => '5.00',
    path_sep => ';',
    privlibexp => 'C:\Perl\\lib',
    scriptdir => 'C:\Perl\\bin',
    sitearchexp => 'C:\Perl\\site\\lib',
    sitelibexp => 'C:\Perl\\site\\lib',
    so => 'dll',
    useithreads => 'define',
    usevendorprefix => undef,
    version => '5.10.1',
};
