package Win32::GUI::DIBitmap;

# $Id: DIBitmap.pm,v 1.4 2006/10/15 14:07:46 robertemay Exp $

use strict;
use warnings;

use Carp 'croak','carp';

our $VERSION = "0.17";
our $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

our $AUTOLOAD;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);

our @EXPORT = qw(
    FIF_UNKNOWN FIF_BMP FIF_CUT FIF_ICO FIF_JPEG FIF_JNG FIF_KOALA
    FIF_LBM FIF_IFF FIF_MNG FIF_PBM FIF_PBMRAW FIF_PCD FIF_PCX
    FIF_PGM FIF_PGMRAW FIF_PNG FIF_PPM FIF_PPMRAW FIF_RAS FIF_TARGA
    FIF_TIFF FIF_WBMP FIF_PSD FIF_XBM FIF_DDS

    FIC_MINISWHITE FIC_MINISBLACK FIC_RGB FIC_PALETTE FIC_RGBALPHA
    FIC_CMYK

    FICC_RGB FICC_RED FICC_GREEN FICC_BLUE FICC_ALPHA FICC_BLACK
    FICC_REAL FICC_IMAG FICC_MAG FICC_PHASE

    FID_FS FID_BAYER4x4 FID_BAYER8x8 FID_CLUSTER6x6 FID_CLUSTER8x8
    FID_CLUSTER16x16

    FILTER_BOX FILTER_BICUBIC FILTER_BILINEAR FILTER_BSPLINE
    FILTER_CATMULLROM FILTER_LANCZOS3

    FIQ_WUQUANT FIQ_NNQUANT FIT_UNKNOWN FIT_BITMAP FIT_UINT16
    FIT_INT16 FIT_UINT32 FIT_INT32 FIT_FLOAT FIT_DOUBLE
    FIT_COMPLEX

    BMP_DEFAULT BMP_SAVE_RLE

    CUT_DEFAULT

    DDS_DEFAULT
   
    GIF_DEFAULT

    ICO_DEFAULT ICO_MAKEALPHA
   
    IFF_DEFAULT
   
    JPEG_DEFAULT JPEG_FAST JPEG_ACCURATE JPEG_QUALITYSUPERB
    JPEG_QUALITYGOOD JPEG_QUALITYNORMAL JPEG_QUALITYAVERAGE
    JPEG_QUALITYBAD

    KOALA_DEFAULT

    LBM_DEFAULT

    MNG_DEFAULT

    PCD_DEFAULT PCD_BASE PCD_BASEDIV4 PCD_BASEDIV16

    PCX_DEFAULT

    PNG_DEFAULT PNG_IGNOREGAMMA

    PNM_DEFAULT PNM_SAVE_RAW PNM_SAVE_ASCII

    PSD_DEFAULT

    RAS_DEFAULT

    TARGA_DEFAULT TARGA_LOAD_RGB888

    TIFF_DEFAULT TIFF_CMYK TIFF_PACKBITS TIFF_DEFLATE
    TIFF_ADOBE_DEFLATE TIFF_NONE TIFF_CCITTFAX3 TIFF_CCITTFAX4
    TIFF_LZW

    WBMP_DEFAULT

    XBM_DEFAULT XPM_DEFAULT
);

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
#        if ($! =~ /Invalid/) {
#            $AutoLoader::AUTOLOAD = $AUTOLOAD;
#            goto &AutoLoader::AUTOLOAD;
#        }
#        else {
            my($pack,$file,$line) = caller;
            die "Your vendor has not defined $pack\:\:$constname, used at $file line $line.\n";
#        }
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap Win32::GUI::DIBitmap $XS_VERSION;

# Initialise

Win32::GUI::DIBitmap::_Initialise();

# DeInitialise

END {
  Win32::GUI::DIBitmap::_DeInitialise();
}

# Preloaded methods go here.

sub newFromFile {
    croak("Usage: newFromFile(class,filename,[flag])") if @_ < 2;
    my ($class, $f, $flag) = @_;
    $flag = 0 unless defined $flag;
    my $fif = Win32::GUI::DIBitmap::GetFIFFromFilename($f);

    $fif = Win32::GUI::DIBitmap::GetFIFFromFile($f) if $fif == -1;
    return undef if $fif == -1;
    return undef unless Win32::GUI::DIBitmap::FIFSupportsReading($fif);
    return $class->_newFromFile($fif, $f, $flag);
}

sub newFromData {
    croak("Usage: newFromData(class,data,[flag])") if @_ < 2;
    my ($class, $data, $flag) = @_;
    $flag = 0 unless defined $flag;
    my $fif = Win32::GUI::DIBitmap::GetFIFFromData($data);

    return undef if $fif == -1;
    return undef unless Win32::GUI::DIBitmap::FIFSupportsReading($fif);
    return $class->_newFromData($fif, $data, $flag);
}

sub SaveToFile {
    croak("Usage: SaveToFile(object,filename,[fif],[flag])") if @_ < 2;
    my ($self, $f, $fif, $flag) = @_;

    $fif = Win32::GUI::DIBitmap::GetFIFFromFilename($f) unless defined $fif;
    $flag = 0 unless defined $flag;

    return 0 if $fif < 0 or $fif >= Win32::GUI::DIBitmap::GetFIFCount();
    return 0 unless Win32::GUI::DIBitmap::FIFSupportsWriting($fif);

    my $bpp = $self->GetBPP();
    # Convert 16bit PNG to 24 bits before saving
    if ($fif == Win32::GUI::DIBitmap::constant('FIF_PNG',0) && $bpp == 16)
    {
      my $dib = $self->ConvertTo24Bits();
      return $dib->_saveToFile($fif, $f, $flag);
    }
    # Convert 16-32bit JPEG to 24 bits before saving
    elsif ($fif == Win32::GUI::DIBitmap::constant('FIF_JPEG',0) &&
           ($bpp == 16 || $bpp == 32))
    {
      my $dib = $self->ConvertTo24Bits();
      return $dib->_saveToFile($fif, $f, $flag);
    }
    else
    {
     return $self->_saveToFile($fif, $f, $flag);
    }
}

sub SaveToData {
    croak("Usage: SaveToData(object,fif,[flag])") if @_ < 2;
    my ($self, $fif, $flag) = @_;

    $flag = 0 unless defined $flag;

    return 0 if ($fif < 0 or $fif >= Win32::GUI::DIBitmap::GetFIFCount());
    return 0 unless Win32::GUI::DIBitmap::FIFSupportsWriting($fif);

    my $bpp = $self->GetBPP();
    # Convert 16bit PNG to 24 bits before saving
    if ($fif == Win32::GUI::DIBitmap::constant('FIF_PNG',0) && $bpp == 16)
    {
      my $dib = $self->ConvertTo24Bits();
      return $dib->_saveToData($fif, $flag);
    }
    # Convert 16-32bit JPEG to 24 bits before saving
    elsif ($fif == Win32::GUI::DIBitmap::constant('FIF_JPEG',0) &&
           ($bpp == 16 || $bpp == 32))
    {
      my $dib = $self->ConvertTo24Bits();
      return $dib->_saveToData($fif, $flag);
    }
    else {
      return $self->_saveToData($fif, $flag);
    }
}

sub ConvertToBitmap {
    croak("Usage: ConvertToBitmap(object)") unless @_==1;
    my $self = shift;

    my $handle = $self->_convertToBitmap();

    if($handle) {
        my $class = 'Win32::GUI::Bitmap';
        my $newself = {};

        $newself->{-handle} = $handle;
        bless($newself, $class);
        return $newself;
    } else {
        return undef;
    }
}

# ColorQuantize : Convert to 24 bits if necessary
sub ColorQuantize {

    croak("Usage: ColorQuantize(object, [flag=FIQ_WUQUANT])") if @_ < 1;
    my ($self, $flag) = @_;

    $flag = Win32::GUI::DIBitmap::constant('FIQ_WUQUANT',0) unless defined $flag;

    if ($self->GetBPP() != 24) {
      my $dib = $self->ConvertTo24Bits();
      return $dib->_colorQuantize($flag);
    }
    else {
      return $self->_colorQuantize($flag);
    }
}

sub Width {
    my $self = shift;
    return $self->GetWidth();
}

sub Height {
    my $self = shift;
    return $self->GetHeight();
}

# Internal version for Win32::GUI::MDIBitmap
package Win32::GUI::DIBitmap::Ext;
our @ISA = qw(Win32::GUI::DIBitmap);

package Win32::GUI::MDIBitmap;

sub new {
    croak("Usage: new(class,filename,fif=-1,keep_cache_in_memory=0)") if (@_ < 2 or @_ > 4);
    my ($class, $f, $fif, $keep_cache_in_memory) = @_;

    $fif = Win32::GUI::DIBitmap::GetFIFFromFilename($f) unless (defined $fif);
    $keep_cache_in_memory = 0 unless (defined $keep_cache_in_memory);

    return undef if $fif == -1;
    return undef unless Win32::GUI::DIBitmap::FIFSupportsWriting($fif);
    return $class->_newFromFile($fif, $f, 1, 0, $keep_cache_in_memory);
}

sub newFromFile {
    croak("Usage: newFromFile(class,filename,read_only=1,keep_cache_in_memory=0)") if (@_ < 2 or @_ > 4);
    my ($class, $f, $read_only, $keep_cache_in_memory) = @_;
    my $fif = Win32::GUI::DIBitmap::GetFIFFromFilename($f);

    $read_only  = 1           unless (defined $read_only);
    $keep_cache_in_memory = 0 unless (defined $keep_cache_in_memory);

    $fif = Win32::GUI::DIBitmap::GetFIFFromFile($f) if $fif == -1;
    return undef if $fif == -1;
    return undef unless Win32::GUI::DIBitmap::FIFSupportsReading($fif);
    return undef if ($read_only == 0 and not Win32::GUI::DIBitmap::FIFSupportsWriting($fif));
    return $class->_newFromFile($fif, $f, 0, $read_only, $keep_cache_in_memory);
}

1; # End of DIBitmap.pm
__END__

=head1 NAME

Win32::GUI::DIBitmap - add new reading/writing image formats to Win32::GUI
and some image manipulation.

=head1 SYNOPSIS

  use Win32::GUI();
  use Win32::GUI::DIBitmap;

  $W = new Win32::GUI::Window (
              -title    => "Win32::GUI::DIBitmap test",
              -pos      => [100, 100],
              -size     => [400, 400],
              -name     => "Window",
              );

  $dib = newFromFile Win32::GUI::DIBitmap ('image.jpg');
  $hbitmap = $dib->ConvertToBitmap();
  undef $dib;

  $W->AddButton (
    -pos     => [100, 100],
    -size    => [200, 200],
    -bitmap  => $hbitmap,
    -name    => "Button",
    -visible => 1,
    );

  $W->Show();
  Win32::GUI::Dialog();
  sub Window_Terminate { -1 }

=head1 DESCRIPTION

Win32::GUI::DIBitmap adds new reading/writing image formats to Win32::GUI
and some image manipulation.

This package use FreeImage 3.8.0, an open source image library supporting
all common image formats L<http://freeimage.sourceforge.net/>.

Supports many formats, such as:

   Format  Reading Writing Description
   BMP     Y       Y       Windows or OS/2 Bitmap [Export = 1 4 8 16 24 32]
   ICO     Y       Y       Windows Icon [Export = 1 4 8 16 24 32]
   JPEG    Y       Y       JPEG - JFIF Compliant [Export = 8 24]
   JNG     Y       N       JPEG Network Graphics
   KOALA   Y       N       C64 Koala Graphics
   IFF     Y       N       IFF Interleaved Bitmap
   MNG     Y       N       Multiple Network Graphics
   PBM     Y       Y       Portable Bitmap (ASCII) [Export = 1 8 24]
   PBMRAW  Y       Y       Portable Bitmap (RAW) [Export = 1 8 24]
   PCD     Y       N       Kodak PhotoCD
   PCX     Y       N       Zsoft Paintbrush
   PGM     Y       Y       Portable Greymap (ASCII) [Export = 1 8 24]
   PGMRAW  Y       Y       Portable Greymap (RAW) [Export = 1 8 24]
   PNG     Y       Y       Portable Network Graphics [Export = 1 4 8 24 32]
   PPM     Y       Y       Portable Pixelmap (ASCII) [Export = 1 8 24]
   PPMRAW  Y       Y       Portable Pixelmap (RAW) [Export = 1 8 24]
   RAS     Y       N       Sun Raster Image
   TARGA   Y       Y       Truevision Targa [Export = 8 16 24 32]
   TIFF    Y       Y       Tagged Image File Format [Export = 1 4 8 24 32]
   WBMP    Y       Y       Wireless Bitmap [Export = 1]
   PSD     Y       N       Adobe Photoshop
   CUT     Y       N       Dr. Halo
   XBM     Y       N       X11 Bitmap Format
   XPM     Y       Y       X11 Pixmap Format [Export = 8 24]
   DDS     Y       N       DirectX Surface
   GIF     Y       Y       Graphics Interchange Format [Export = 8]

FreeImage can handle multi-page file (TIFF and ICO support only).

=head1 PACKAGE FUNCTIONS

=head2 FreeImage Library Info functions

=over

=item C<GetVersion> ()

Return the FreeImage version string.

=item C<GetCopyright> ()

Return the FreeImage copyright string.

=back

=head2 FIF functions

=over

=item C<Constant>

C<FIF> = Format Identifier File.

  FIF_UNKNOWN = -1
  FIF_BMP     FIF_ICO    FIF_JPEG   FIF_JNG
  FIF_KOALA   FIF_LBM    FIF_MNG    FIF_PBM
  FIF_PBMRAW  FIF_PCD    FIF_PCX    FIF_PGM
  FIF_PGMRAW  FIF_PNG    FIF_PPM    FIF_PPMRAW
  FIF_RAS     FIF_TARGA  FIF_TIFF   FIF_WBMP
  FIF_PSD     FIF_IFF    FIF_LBM    FIF_CUT
  FIF_XBM     FIF_XPM    FIF_DDS    FIF_GIF

=item C<GetFIFCount> ()

Return the max FIF value.

=item C<GetFormatFromFIF> (fif)

Return the string format from FIF value.

=item C<GetFIFFromFormat> (format)

Return FIF value from the string format.

=item C<GetFIFFromMime> (mime)

Return FIF value from the Mime string.

=item C<GetFIFFromFilename> (filename)

Return FIF value from the filename string.

=item C<GetFIFFromFile> (filename)

Return FIF value from file data.

=item C<GetFIFFromData> (data)

Return FIF value from memory data.

=back

=head2 FIF info functions

=over

=item C<FIFExtensionList> (fif)

Return a coma separated string of extension filenname.

=item C<FIFDescription> (fif)

Return a description string of the format.

=item C<FIFRegExpr> (fif)

Return a regexp string for identify format.

=item C<FIFMimeType> (fif)

Return a mime-type string of the format.

=item C<FIFSupportsReading> (fif)

This format can be read ?

=item C<FIFSupportsWriting> (fif)

This format can be write ?

=item C<FIFSupportsExportBPP> (fif, bpp)

This format can be write bpp image ?

=item C<FIFSupportsExportType> (fif, type)

This format can export as image format type ?

=item C<FIFSupportsICCProfiles> (fif)

This format support ICC profile ?

=back

=head2 Colors functions

=over

=item C<LookupX11Color> (string_color)

Return Color of string color or undef if error.
This color value can be an integer value or a [B,G,R,A] array.

=item C<LookupSVGColor> (string_color)

Return Color of string color or undef if error.
This color value can be an integer value or a [B,G,R,A] array.

=back

=head1 DIBITMAP OBJECT

=head2 DIBitmap New methods

=over

=item C<new> ([width=100, height=100, bpp=24, redmask=0, bluemask=0, greemask=0, type=FIT_BITMAP])

Allocate a Win32::GUI::DIBitmap object.

Image storage types availlable.

  FIT_UNKNOWN = 0 : unknown type
  FIT_BITMAP  = 1 : standard image           : 1-, 4-, 8-, 16-, 24-, 32-bit
  FIT_UINT16  = 2 : array of unsigned short  : unsigned 16-bit
  FIT_INT16   = 3 : array of short           : signed 16-bit
  FIT_UINT32  = 4 : array of unsigned long   : unsigned 32-bit
  FIT_INT32   = 5 : array of long            : signed 32-bit
  FIT_FLOAT   = 6 : array of float           : 32-bit IEEE floating point
  FIT_DOUBLE  = 7 : array of double          : 64-bit IEEE floating point
  FIT_COMPLEX = 8 : array of FICOMPLEX       : 2 x 64-bit IEEE floating point

=item C<newFromFile> (filename, [flag])

Create a Win32::GUI::DIBBitmap from a image file.

Some format have special load flag :

  Type   | Flag              | Description
  -------+-------------------+----------------------------------------
  ICO    | ICO_MAKEALPHA     | Convert to 32bpp and create an alpha
         |                   | channel from the AND-mask when loading
  JPEG   | JPEG_FAST         | Load file fast (sacrifing quality)
         | JPEG_ACCURATE     | Load file with best quality (sacrifing speed)
  PCD    | PCD_BASE          | Load picture sized 768 * 512.
  PCD    | PCD_BASEDIV4      | Load picture sized 384 * 256.
  PCD    | PCD_BASEDIV16     | Load picture sized 192 * 128.
  PNG    | PNG_IGNOREGAMMA   | Avoid gamma correction
  TARGA  | TARGA_LOAD_RGB888 | Convert RGB555 and ARGB8888 to RGB888
  TIFF   | TIFF_CMYK         | Load CMYK bitmap as 32 bit separated CMYK.

=item C<newFromData> (data, [flag])

Create a Win32::GUI::DIBitmap from memory data.

=item C<newFromBitmap> (hbitmap)

Create a Win32::GUI::DIBitmap from a Win32::GUI::Bitmap.

=item C<newFromDC> (hdc, [x, y, w, h] )

Create a Win32::GUI::DIBitmap from a Win32::GUI::DC.

You can capture only a portion of the HDC with x,y,w,h option.

=item C<newFromWindow> (hwnd, [flag = 0])

Create a Win32::GUI::DIBitmap from a Win32::GUI::Window.

  flag = 0 : All the window is capture (with border)
  flag = 1 : Only the Client window is capture

=back

=head2 DIBitmap Save methods

=over

=item C<SaveToFile> (filename, [fif, flag])

Save a Win32::GUI::DIBitmap in a file.

Some format have special save format :

  Type  | Flag                | Description
  ------+---------------------+---------------------------------------
  BMP   | BMP_SAVE_RLE        | Compress bitmap using RLE
  JPEG  | JPEG_DEFAULT        | Save with good quality (75:1)
        | JPEG_QUALITYSUPERB  | Save with superb quality (100:1)
        | JPEG_QUALITYGOOD    | Save with good quality (75:1)
        | JPEG_QUALITYNORMAL  | Save with normal quality (50:1)
        | JPEG_QUALITYAVERAGE | Save with average quality (25:1)
        | JPEG_QUALITYBAD     | Save with bad quality (10:1)
  PxM   | PNM_DEFAULT         | Save bitmap as a binary file
        | PNM_SAVE_RAW        | Save bitmap as a binary file
        | PNM_SAVE_ASCII      | Save bitmap as a ascii file
  TIFF  | TIFF_DEFAULT        | Save using CCITFAX4 compression for
        |                     | 1bit and PACKBITS for other
        | TIFF_CMYK           | Store tags for separated CMYK
        |                     | (combine with compresion flag)
        | TIFF_PACKBITS       | Save using PACKBITS compression
        | TIFF_DEFLATE        | Save using DEFLATE compression
        | TIFF_ADOBE_DEFLATE  | Save using Adobe DEFLATE compression
        | TIFF_NONE           | Save without compression
        | TIFF_CCITTFAX3      | Save using CCITT Group 3 fax encoding
        | TIFF_CCITTFAX4      | Save using CCITT Group 4 fax encoding
        | TIFF_LZW            | Save using LZW compression

  A tempory convertion is done for 16-32bit JPEG and 16bit PNG before saving.

=item C<SaveToData> (fif, [flag])

  Save a Win32::GUI::DIBitmap in memory.

=back

=head2 DIBitmap information methods

=over

=item C<GetWidth> () or C<Width>

Return the Width of the image.

=item C<GetHeight> () or C<Height>

Return the Height of the image.

=item C<GetColorsUsed> ()

Return the number of color use in the image.

=item C<GetBPP> ()

Return the bit per pixel use in the image.

=item C<GetRedMask> ()

Return a bit pattern describing the red color copmponent of a pixel.

=item C<GetGreenMask> ()

Return a bit pattern describing the green color copmponent of a pixel.

=item C<GetBlueMask> ()

Return a bit pattern describing the blue color copmponent of a pixel.

=item C<GetColorType> ()

Return the color type of the image.

Values :
    FIC_MINISWHITE = 0 : Monochrome bitmap, with first palette entry is white
    FIC_MINISBLACK = 1 : Monochrome bitmap, with first palette entry is black
                         Palletised bitmap, with greyscale palette
    FIC_RGB        = 2 : RGB color model
    FIC_PALETTE    = 3 : Color map indexed
    FIC_RGBALPHA   = 4 : RGB color model with alpha channel
    FIC_CMYK       = 5 : CMYK color model

=item C<GetLine> ()

Return width of data image in bytes.

=item C<GetPitch> ()

Return pitch of data image.
Pitch it's the width of the bitmap in bytes, rounded to the next
32 bit boundary.

=item C<GetDotsPerMeterX> ()

Return dots per meter on X.

=item C<GetDotsPerMeterY> ()

Return dots per meter on Y.

=item C<GetInfoHeader> ()

Return a windows BITMAPINFOHEADER struct.

=item C<GetInfo> ()

Return a window BITMAPINFO struct.

=item C<GetSize> ()

Return memory size of data for the image

=item C<GetBits> ()

Return data of the image

=item C<IsTransparent> ()

Image is transparent.

=item C<GetImageType> ()

Return image type.

=back

=head2 DIBitmap and GD

=over

=item C<newFromGD> (gd, newGD=0)

Create a Win32::GUI::DIBitmap from a GD image
New object have same size and format, gd image copy into.

Flag newGD is for new GD version (> 2.0) with trueColor bitmap.
Default value force 8 bit bitmap.

=item C<CopyFromGD> (gd, newGD=0)

Copy GD image into Win32::GUI::DIBitmap.
GD and Win32::GUI::DIBitmap must have same size and format.

=item C<CopyToGD> (gd, newGD=0)

Copy Win32::GUI::DIBitmap into GD image.
GD and Win32::GUI::DIBitmap must have same size and format.

=back

=head2 DIBitmap Pixels and Background methods

=over

=item C<GetPixel> (x, y)

Return pixel value color at x, y or undef if error.
For image with BPP <= 8 return palette index color.
For image with BPP > 8  return color value.
This color value can be an integer value or a [B,G,R,A] array.

=item C<SetPixel> (x, y, color | Blue, Green, Red, [Alpha])

Set pixel value color at x, y.
Return boolean value.
For image with BPP <= 8, it's palette color index.
For image with BPP > 8, arguments can an integer color
value or B,G,R,[A] values.

=item C<HasBackgroundColor> ()

Indicate if image have Background Color.

=item C<GetBackgroundColor> ()

Return Background Color or undef if error.
This color value can be an integer value or a [B,G,R,A] array.

=item C<SetBackgroundColor> (color | Blue, Green, Red, [Alpha])

Set Background Color.
Return boolean value.

=back

=head2 DIBitmap Convertion methods

=over

=item C<ConvertToBitmap> ()

Convert a Win32::GUI::DIBitmap to a new Win32::GUI::Bitmap.

=item C<ConvertTo4Bits> ()

Convert a Win32::GUI::DIBitmap to a new 4 bits Win32::GUI::DIBitmap.

=item C<ConvertTo8Bits> ()

Convert a Win32::GUI::DIBitmap to a new 8 bits (grayscale)
Win32::GUI::DIBitmap.
See ColorQuantize for convert to 8 bits colors.

=item C<ConvertTo16Bits555> ()

Convert a Win32::GUI::DIBitmap to a new 16 bits
Win32::GUI::DIBitmap (555 format).

=item C<ConvertTo16Bits565> ()

Convert a Win32::GUI::DIBitmap to a new 16 bits
Win32::GUI::DIBitmap (565 format).

=item C<ConvertTo24Bits> ()

Convert a Win32::GUI::DIBitmap to a new 24 bits Win32::GUI::DIBitmap.

=item C<ConvertTo32Bits> ()

Convert a Win32::GUI::DIBitmap to a new 32 bits Win32::GUI::DIBitmap.

=item C<ColorQuantize> ([flag = FIQ_WUQUANT])

Convert a Win32::GUI::DIBitmap to a new 8 bits
(colorscale) Win32::GUI::DIBitmap.
None 24 bits image are converted to 24bits before.

Flag possible value :
  FIQ_WUQUANT = Xiaolin Wu color quantization algorithm
  FIQ_NNQUANT = NeuQuant neural-net quantization algorithm by Anthony Dekker

=item C<Threshold> (T)

Convert a Win32::GUI::DIBitmap to a new 1 bit Win32::GUI::DIBitmap
using a Threshold between 0..255.

=item C<Dither> ([flag = FID_FS])

Convert a Win32::GUI::DIBitmap to a new 1 bit Win32::GUI::DIBitmap.

Flag possible value :
  FID_FS            = Floyd and Steinberg error diffusion algorithm.
  FID_BAYER4x4      = Bayer ordered dispersed dot dithering (order 2 - 4*4 matrix)
  FID_BAYER8x8      = Bayer ordered dispersed dot dithering (order 3 - 8*8 matrix)
  FID_CLUSTER6x6    = Ordered clustered dot dithering (order 3 - 6*6 matrix)
  FID_CLUSTER8x8    = Ordered clustered dot dithering (order 4 - 8*8 matrix)
  FID_CLUSTER16x16  = Ordered clustered dot dithering (order 8 - 16*16 matrix)


=item C<ConvertToStandardType> ([scale_linear=TRUE])

TBD

=item C<ConvertToType> (type, [scale_linear=TRUE])

For type see new method.

=back

=head2 DIBitmap Rotating and flipping

=over

=item C<Rotate> (angle)

Create a new rotated Win32::GUI::DIBitmap (8,24,32 bits only)

This function rotates an 8-bit greyscale, 24- or 32-bit image by
means of 3 shears. The angle of rotation is specified by the angle
parameter in degrees. Rotation occurs around the center of the image
area. Rotated image retains size and aspect ratio of source image
(destination image size is usually bigger), so that this function
should be used when rotating an image by 90°, 180° or 270°.

=item C<RotateEx> (angle, x_shift, y_shift, x_origin, y_origin, use_mask)

Create a new rotated/translated Win32::GUI::DIBitmap
(8,24,32 bits only)

This function performs a rotation and / or translation of an 8-bit
greyscale, 24- or 32-bit image, using a 3rd order (cubic) B-Spline.
The rotated image will have the same width and height as the source
image, so that this function is better suited for computer vision and
robotics.  The angle of rotation is specified by the angle parameter
in degrees. Horizontal and vertical image translations (in pixel
units) are specified by the x_shift and y_shift parameters.  Rotation
occurs around the center specified by x_origin and y_origin, also
given in pixel units.  When use_mask is set to TRUE, the irrelevant
part of the image is set to a black color, otherwise, a mirroring
technique is used to fill irrelevant pixels.

=item C<FlipHorizontal> ()

Flip DIBitmap dib horizontally along the vertical axis.

=item C<FlipVertical> ()

Flip DIBitmap vertically along the horizontal axis.

=back

=head2 DIBitmap UpSampling / DownSampling

=over

=item C<Rescale> (new_width, new_heigth, filter=FILTER_BOX)

Create a new size Win32::GUI::DIBitmap (32 bits only)

This function performs resampling (or scaling, zooming) of a 32-bit
image to the desired destination width and height.  Resampling refers
to changing the pixel dimensions (and therefore display size) of an
image.  When you downsample (or decrease the number of pixels),
information is deleted from the image. When you upsample (or increase
the number of pixels), new pixels are added based on color values of
existing pixels. You specify an interpolation filter to determine how
pixels are added or deleted.

The following filters can be used as resampling filters:
  FILTER_BOX        = Box, pulse, Fourier window, 1st order (constant) B-Spline
  FILTER_BILINEAR   = Bilinear filter
  FILTER_BSPLINE    = 4th order (cubic) B-Spline
  FILTER_BICUBIC    = Mitchell and Netravali's two-param cubic filter
  FILTER_CATMULLROM = Catmull-Rom spline, Overhauser spline
  FILTER_LANCZOS3   = Lanczos-windowed sinc filter

=back

=head2 DIBitmap Color manipulation

=over

=item C<AdjustGamma> (gamma)

Adjust Gamma of Win32::GUI::DIBitmap (8,24,32 bits only)

The gamma parameter represents the gamma value to use (gamma > 0).
A value of 1.0 leaves the image alone, less than one darkens it, and
greater than one lightens it.

=item C<AdjustBrightness> (percentage)

Adjust Brightness of Win32::GUI::DIBitmap (8,24,32 bits only)

Adjusts the brightness of a 8-, 24- or 32-bit image by a certain
amount.  This amount is given by the percentage parameter, where
percentage is a value between [-100..100].  A value 0 means no change,
less than 0 will make the image darker and greater than 0 will make
the image brighter.

=item C<AdjustContrast> (percentage)

Adjust ContrastCreate of Win32::GUI::DIBitmap (8,24,32 bits only)

Adjusts the contrast of a 8-, 24- or 32-bit image by a certain amount.
This amount is given by the percentage parameter, where percentage is
a value between [-100..100].  A value 0 means no change, less than 0
will decrease the contrast and greater than 0 will increase the
contrast of the image.

=item C<Invert> ()

Inverts each pixel data.

=item C<GetHistogram> (channel)

Return a histogram array[0..255] of a Win32::GUI::DIBitmap
(8,24,32 bits only)

Computes the image histogram.
For 24-bit and 32-bit images, histogram can be computed from red,
green, blue and black channels.  For 8-bit images, histogram is
computed from the black channel.

=back

=head2 DIBitmap Channel methods

=over

=item C<Channel Constant>

  FICC_RGB     = 0 : Use red, green and blue channels
  FICC_RED     = 1 : Use red channel
  FICC_GREEN   = 2 : Use green channel
  FICC_BLUE    = 3 : Use blue channel
  FICC_ALPHA   = 4 : Use alpha channel
  FICC_BLACK   = 5 : Use black channel
  FICC_REAL    = 6 : Complex images: use real part
  FICC_IMAG    = 7 : Complex images: use imaginary part
  FICC_MAG     = 8 : Complex images: use magnitude
  FICC_PHASE   = 9 : Complex images: use phase

=item C<GetChannel> (channel)

Return an 8-bit channel Win32::GUI::DIBitmap.

Retrieves the red, green, blue or alpha channel of a 24 or 32-bit
BGR[A] image.  Channel is the color channel to extract.

=item C<SetChannel> (channel, 8bit_image)

Set the red, green, blue or alpha channel of a 24 or 32-bit BGR[A]
image.  Channel is the color channel to set.

=item C<GetComplexChannel> (channel)

Return a complex channel Win32::GUI::DIBitmap.

Retrieves the red, green, blue or alpha channel of a 24 or 32-bit
BGR[A] image.  Channel is the color channel to extract.

=item C<SetComplexChannel> (channel, 8bit_image)

Set the red, green, blue or alpha channel of a 24 or 32-bit BGR[A]
image.  Channel is the complex channel to set.

=back

=head2 DIBitmap Copy/Paste methods

=over

=item C<Clone> ()

Clone a Win32::GUI::DIBitmap to a new Win32::GUI::Bitmap.

=item C<Copy> (left, top, right, botton)

Return a new Win32::GUI::Bitmap with a sub part Win32::GUI::DIBitmap
(8, 16, 24 or 32 only).

  Left specifies the left position of the cropped rectangle.
  Top specifies the top position of the cropped rectangle.
  Right specifies the right position of the cropped rectangle.
  Bottom specifies the bottom position of the cropped rectangle.

=item C<Paste> (source_image, left, top, alpha)

Returns TRUE if successful, FALSE otherwise ( 8, 16, 24 or 32 only).

Alpha blend or combine a sub part image with the current dib image.
The bit depth must be greater than or equal to the bit depth of source
image.

Alpha is alpha blend factor. The source and destination images are
alpha blended if alpha=0..255. If alpha > 255, then the source image
is combined to the destination image.

=item C<Composite> ([useFileBkg=FALSE, imageBkg=undef appBkColor=undef)

TBD

=back

=head2 DIBitmap Device Context methods

=over

=item C<CopyToDC> (hdc, [xd=0, yd=0, w=0, h=0, xs=0, ys=0])

Copy Win32::GUI::DIBitmap to a Win32::GUI::DC.

Specify the destination rectangle with xd,yd,w,h option.
Specify the begining of the image with xs,ys option.
The image copy keep the same size.

=item C<AlphaCopyToDC> (hdc, [xd=0, yd=0, w=0, h=0, xs=0, ys=0])

Copy Win32::GUI::DIBitmap to a Win32::GUI::DC with
transparency/alpha channel support.

Specify the destination rectangle with xd,yd,w,h option.
Specify the begining of the image with xs,ys option.
The image copy keep the same size.

=item C<StretchToDC> (hdc, [xd=0, yd=0, wd=0, hd=0, xs=0, ys=0, ws=0, hs=0, flag=SRCCOPY])

Copy Win32::GUI::DIBitmap to a Win32::GUI::DC.

Specify the destination rectangle with xd,yd,wd,hd option.
Specify the image source rectangle ith xs,ys,ws,hs option.
The image copy is resize if necessary.

For flag option, see StretchDIBits win32 function.

=item C<AlphaStretchToDC> (hdc, [xd=0, yd=0, wd=0, hd=0, xs=0, ys=0, ws=0, hs=0)

Copy Win32::GUI::DIBitmap to a Win32::GUI::DC with
transparency/alpha channel support.

Specify the destination rectangle with xd,yd,wd,hd option.
Specify the image source rectangle ith xs,ys,ws,hs option.
The image copy is resize if necessary.

=back

=head1 MDIBITMAP OBJECT

=head2 MDIBitmap New methods

=over

=item C<new> (filename, fif=-1, keep_cache_in_memory=0)

Create a new Win32::GUI::MDIBitmap in edit mode.

=item C<newFromFile> (filename, read_only=1, keep_cache_in_memory=0)

Create a Win32::GUI::MDIBitmap from a image file.

=back

=head2 MDIBitmap Get methods

=over

=item C<GetPageCount>

Return page count.

=item C<GetLockedPageNumbers>

Return a list of locked page index.

=back

=head2 MDIBitmap Lock methods

=over

=item C<LockPage> ([index = 0])

Lock and return a page (Win32::GUI::DIBitmap object).

=item C<UnlockPage> (Win32::GUI::DIBitmap, [update = 0])

Unlock a locked page (Win32::GUI::DIBitmap object).
Update indicate if the page must be updated.

=back

=head2 MDIBitmap Edit methods

=over

=item C<AppendPage> (Win32::GUI::DIBitmap)

Append a Win32::GUI::DIBitmap to a Win32::GUI::MDIBBitmap.

=item C<InsertPage> (Win32::GUI::DIBitmap, [index = 0])

Insert a Win32::GUI::DIBitmap in a Win32::GUI::MDIBBitmap.

=item C<DeletePage> ([index = 0])

Delete a page from a Win32::GUI::MDIBBitmap.

=item C<MovePage> (to_index, [from_index = 0])

Move a page in a Win32::GUI::MDIBBitmap.

=back

=head1 SEE ALSO

=over

=item L<Win32::GUI|Win32::GUI>

=item L<http://freeimage.sourceforge.net/>

=back

=head1 AUTHOR

Laurent Rocher (lrocher@cpan.org)

=head1 COPYRIGHT AND LICENCE

Copyright 2003 by Laurent Rocher (lrocher@cpan.org).

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
See L<http://www.perl.com/perl/misc/Artistic.html>

Unmodified code from the FreeImage project (L<http://freeimage.sourceforge.net>) is
statically linked into this module.  The FreeImage code is released under the
GNU General Public Licence (L<http://www.opensource.org/licenses/gpl-license.php>)
and the FreeImage Public Licence
(L<http://freeimage.sourceforge.net/freeimage-license.txt>)

=cut
