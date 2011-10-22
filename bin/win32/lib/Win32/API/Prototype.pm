#   An API prototype package.
#   This simply creates a subroutine in the main namespace of Perl.
#
#   Copyright (c) 2000 -2002 by Dave Roth.  All rights reserved.
#   Courtesy of Roth Consulting
#   http://www.roth.net/
#

package Win32::API::Prototype;

use strict;
use vars qw( $VERSION @ISA @EXPORT %PROC_LIST %PROTOTYPE );
use Exporter;
use Win32::API;

$VERSION = 20021217;

@ISA = qw( Exporter );

@EXPORT = qw( ApiLink AllocMemory NewString CleanString );

%PROC_LIST = ();

# Pointers declared with an * or & character or by use of a
# macro that begins with "LP" such as LPCTSTR are checked
# in the new() function so they don't need to be in the
# %PROTOTYPE hash
%PROTOTYPE = (
    (map {($_ => 'V')} qw(void)),
    (map {($_ => 'N')} qw(dword long ulong handle hkey hwnd hresult hmodule colorref )),
    (map {($_ => 'I')} qw(ushort short uint int bool boolean word lparam wparam )),
    (map {($_ => 'P')} qw(pvoid callback )),
);

# Version 0.20 of Win32::API added support for float, double and byte...
if( .2 <= $Win32::API::VERSION )
{
  map{ $PROTOTYPE{$_} = 'F' } qw(float);
  map{ $PROTOTYPE{$_} = 'D' } qw(double);
  map{ $PROTOTYPE{$_} = 'B' } qw(byte uchar char);
}

################################################################
# Public functions

sub ApiLink
{
    my( $Library, $Function, $ParamList, $ReturnValue ) = @_;
    my $LCFunction;



    if( 2 == scalar @_ )
    {
        my @ParamList;
        $Function =~ /^\s*(\S+)\s+(\S+)\s*\(\s*(.*?)\s*\)\s*$/s || die "Unable to parse function definition '$Function'\n";
        my($ReturnValueType, $FunctionName, $Parameters) = ($1, $2, $3);
        $ReturnValue = $PROTOTYPE{lc $ReturnValueType} || die "Unable to handle return value type '$ReturnValueType'\n";
        $Function = $FunctionName;
    
        foreach my $Element ( split( /,/, $Parameters ) )
        {
            $Element =~ /^\s*([^\s*&]+)\s*([*&])?/s || die "Unable to parse parameter element '$Element'\n";
            my( $Type, $Symbol ) = ( $1, $2 );

            # Test for a pointer...
            # Test for a pointer...
            if( substr( $Type, 0, 2 ) eq 'LP' || $Symbol )
            {
                # Make sure "LPARAM" is not thought to be an LP pointer
                if( "LPARAM" ne $Type )
                {
                  $Type = "PVOID";
                }  
            }
            push( @$ParamList, $PROTOTYPE{lc $Type} );
        }
    }

    # Create the function...
    my $Subname = "main::$Function";
    {
        no strict;
        if( ! defined *{$Subname}{CODE} )
        {
            my $Proc = Win32::API->new( $Library, $Function, $ParamList, $ReturnValue );
            return( undef ) unless( defined $Proc );
            my $Method;
            *{$Subname} = $Method = sub { $Proc->Call( @_ ) };
            return( $Method );
        }
        else
        {
           return( \&{$Subname} );
        }
    }

}

sub NewString
{
    my( $Param ) = @_;
    my $Size;
    my $String = "";
     
    if( $Param =~ /^\d+$/ )
    {
        $Size = $Param;
    }
    else
    {
        $Size = 0;
        $String = $Param;
    }
    $String .= "\x00" x $Size;
    if( Win32::API::IsUnicode() )
    {
        $String =~ s/(.)/$1\x00/g;
    }
    return( $String );
}

sub AllocMemory
{
    my( $Length ) = @_;
    return( "\x00" x $Length );
}

sub CleanString
{
    my( $String, $ForceUnicode ) = @_;
    if( Win32::API::IsUnicode() || $ForceUnicode )
    {
        $String =~ tr/\0//d;
    }
    my $Pad = length( $String ) % 2 ? "\x00" : '';
    $String =~ s/(\x00\x00)*$Pad$//;
    return( $String );
}


# Return TRUE to indicate that the 'use' or 'require' command was successful
1;

=head1 NAME

Win32::API::Prototype - easily manage Win32::API calls

=head1 SYNOPSIS

        use Win32::API::Prototype;

=head1 DESCRIPTION

This module mimicks calling the Win32 API from C by allowing a script
to specify a C function prototype.

=head1 FUNCTIONS

=over 4

=item ApiLink( $Module, $Prototype, [\@ParameterTypes, $ReturnType] )

Declares a Win32 API prototype. There are two ways to call this:

=over 4

=item a) Traditional Win32::API 

The $Prototype is the name of the Win32 API function and the second and third
parameters are traditional Win32::API parameter and return types such as:

    ApiLink( 'kernel32.dll', 'FindFirstVolume', [P,N], N ) || die;

=item b) Prototype style

The $Prototype is the actual C prototype of the function as in:

    ApiLink( 'kernel32.dll', 'HANDLE FindFirstVolume(LPTSTR lpszVolumeName, DWORD chBufferLength)' ) || die;

=back

This will create a global function by the same name of the Win32 API function. Therefore
a script can call it as a C program would call the function.

B<Example:>

    use Win32::API::Prototype;
    @Days = qw(
        Sun
        Mon
        Tue
        Wed
        Thu
        Fri
        Sat
    );
    ApiLink( 'kernel32.dll', 'void GetLocalTime( LPSYSTEM  lpSystemTime )' ) || die;
    $lpSystemTime = pack( "S8", 0,0,0,0,0,0,0,0 );
    
    # This function does not return any value
    GetLocalTime( $lpSystemTime );
    
    @Time{ year, month, dow, day, hour, min, sec, mil } = unpack( "S*", $lpSystemTime );
    printf( "The time is: %d:%02d:%02d %s %04d.%02d.%02d\n", $Time{hour}, $Time{min}, $Time{sec}, $Days[$Time{dow}], $Time{year}, $Time{month}, $Time{day} );

=item AllocMemory( $Size )

This function will allocate a buffer of C<$String> bytes.  The string will be 
filled with NULL charcters.  This is the equivilent of the C++ code:

    LPBYTE pBuffer = new BYTE [ dwSize ];
    if( NULL != pBuffer )
    {
        ZeroMemory( pBuffer, dwSize );
    }

B<Example:>

    use Win32::API::Prototype;
    $pBuffer = AllocMemory( 256 );
    
      

=item NewString( $String | $Size )

This function will create either a string containing C<$String> or create an empty
string C<$Size> characters in length.  Regardless of what type of string is created
it will be created for UNICODE or ANSI depending on what the Win32 API function will
expect.

B<Example:>

    use Win32::API::Prototype;
    
    ApiLink( 'kernel32.dll', 'DWORD GetCurrentDirectory( DWORD nBufferLength, LPTSTR lpBuffer )' ) || die;
    $nBufferLength = 256;
    $lpBuffer = NewString( $nBufferLength );
    # GetCurrentDirectory() returns the length of the directory string
    $Result = GetCurrentDirectory( $nBufferLength, $lpBuffer );
    print "The current directory is: " . CleanString( $lpBuffer ) . "\n";


=item CleanString( $String )

This function will clean up and return the passed in C<$String>.  This means that
the any trailing NULL characters will be removed and if the string is UNICODE it
will be converted to ANSI.

B<Example:>

Refer to the C<NewString()> example.

=back

=head1 HISTORY

=over 4

=item v20001128

  -Initial release.

=item v20000613

  -Slight modification and clean up code.

=item v20020928

  -Fixed problem with parsing LPARAM parameters. This was parsed as a long pointer. Thanks to Alon Swartz [alon@datasourcing.co.il]
  -Added additional recognized types.
  -Added support for floating point types.

=item v20021217

  -Fixed pointer parsing logic to accept Type* Foo. Thanks to Glenn Phillips [Glenn.Phillips@simpl.co.nz]

=back

