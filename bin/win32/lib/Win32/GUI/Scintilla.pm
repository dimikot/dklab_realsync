#------------------------------------------------------------------------
# Scintilla control for Win32::GUI
# by Laurent ROCHER (lrocher@cpan.org)
#------------------------------------------------------------------------
#perl2exe_bundle 'SciLexer.dll'

# This file created by the build process from Scintilla.PL
# change made here will be lost.  Edit Scintilla.PL instead.
# $Id: Scintilla.PL,v 1.8 2008/02/09 12:53:44 robertemay Exp $

package Win32::GUI::Scintilla;

use strict;
use warnings;

use Win32::GUI qw(WS_CLIPCHILDREN WS_TABSTOP WS_VISIBLE WS_HSCROLL WS_VSCROLL);

require DynaLoader;

our @ISA = qw(DynaLoader Win32::GUI::Window);

our $VERSION = "1.91";
our $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

bootstrap Win32::GUI::Scintilla $XS_VERSION;

#------------------------------------------------------------------------

# Load Scintilla DLL from somewhere on @INC or standard LoadLibrary search
my ($SCILEXER_FILE,$SCILEXER_DLL);
for my $path (@INC) {
    my $lexer_file = $path . '/auto/Win32/GUI/Scintilla/SciLexer.dll';
    if (-f $lexer_file) {
        $SCILEXER_FILE = $lexer_file;
        last;
    }
}

if ($SCILEXER_FILE) {
    $SCILEXER_DLL = Win32::GUI::LoadLibrary($SCILEXER_FILE);
    warn qq(Failed to load SciLexer.dll from "$SCILEXER_FILE") unless $SCILEXER_DLL;
}

unless ($SCILEXER_DLL) {
    warn qq(Final attempt to find SciLexer.dll in PATH);
    $SCILEXER_DLL = Win32::GUI::LoadLibrary('SciLexer');
}

die qq(Failed to load 'SciLexer.dll') unless $SCILEXER_DLL;

Win32::GUI::Scintilla::_Initialise();

END {
  # Free Scintilla DLL
  Win32::GUI::Scintilla::_UnInitialise();
  #Win32::GUI::FreeLibrary($SCILEXER_DLL); 
  #The above line causes some scripts to crash - such as test2.pl in the samples when running under 5.8.7
}

#------------------------------------------------------------------------

#
# Notify event code
#

use constant SCN_STYLENEEDED        => 2000;
use constant SCN_CHARADDED          => 2001;
use constant SCN_SAVEPOINTREACHED   => 2002;
use constant SCN_SAVEPOINTLEFT      => 2003;
use constant SCN_MODIFYATTEMPTRO    => 2004;
use constant SCN_KEY                => 2005;
use constant SCN_DOUBLECLICK        => 2006;
use constant SCN_UPDATEUI           => 2007;
use constant SCN_MODIFIED           => 2008;
use constant SCN_MACRORECORD        => 2009;
use constant SCN_MARGINCLICK        => 2010;
use constant SCN_NEEDSHOWN          => 2011;
use constant SCN_PAINTED            => 2013;
use constant SCN_USERLISTSELECTION  => 2014;
use constant SCN_URIDROPPED         => 2015;
use constant SCN_DWELLSTART         => 2016;
use constant SCN_DWELLEND           => 2017;
use constant SCN_ZOOM               => 2018;
use constant SCN_HOTSPOTCLICK       => 2019;
use constant SCN_HOTSPOTDOUBLECLICK => 2020;
use constant SCN_CALLTIPCLICK       => 2021;

#------------------------------------------------------------------------

#
# New scintilla control
#

sub new {

  my $class  = shift;

  my (%in)   = @_;
  my %out;

  ### Filtering option
  for my $option qw(
        -name -parent
        -left -top -width -height -pos -size
        -pushstyle -addstyle -popstyle -remstyle -notstyle -negstyle
        -exstyle -pushexstyle -addexstyle -popexstyle -remexstyle -notexstyle
        ) {
    $out{$option} = $in{$option} if exists $in{$option};
  }

  ### Default window
  my $constant     = ($Win32::GUI::VERSION < 1.0303 ?
                       Win32::GUI::constant("WIN32__GUI__STATIC",0) :
                       Win32::GUI::_constant("WIN32__GUI__STATIC"));
  $out{-addstyle}  = WS_CLIPCHILDREN;
  $out{-class}     = "Scintilla";

  ### Window style
  $out{-addstyle} |= WS_TABSTOP unless exists $in{-tabstop} && $in{-tabstop} == 0; #Default to -tabstop => 1
  $out{-addstyle} |= WS_VISIBLE unless exists $in{-visible} && $in{-visible} == 0; #Default to -visible => 1
  $out{-addstyle} |= WS_HSCROLL if     exists $in{-hscroll} && $in{-hscroll} == 1;
  $out{-addstyle} |= WS_VSCROLL if     exists $in{-vscroll} && $in{-vscroll} == 1;

  my $self = Win32::GUI->_new($constant, $class, -remstyle => 0xFFFFFFFF, %out);
  if (defined ($self)) {

    # Option Text :
    $self->SetText($in{-text}) if exists $in{-text};
    $self->SetReadOnly($in{-readonly}) if exists $in{-readonly};
  }

  return $self;
}

#
# Win32 shortcut
#

sub Win32::GUI::Window::AddScintilla {
  my $parent  = shift;
  return Win32::GUI::Scintilla->new (-parent => $parent, @_);
}

#------------------------------------------------------------------------
# Miscolous function
#------------------------------------------------------------------------

#
# Clear Scintilla Text
#

sub NewFile {
  my $self = shift;

  $self->ClearAll();
  $self->EmptyUndoBuffer();
  $self->SetSavePoint();
}

#
# Load text file to Scintilla
#

sub LoadFile {
  my ($self, $file) = @_;

  $self->ClearAll();
  $self->Cancel();
  $self->SetUndoCollection(0);

  open my $fh, "<$file" or return 0;
  while ( <$fh> ) {
    $self->AppendText($_);
  }
  close $fh;

  $self->SetUndoCollection(1);
  $self->EmptyUndoBuffer();
  $self->SetSavePoint();
  $self->GotoPos(0);

  return 1;
}

#
# Save Scintilla text to file
#

sub SaveFile {
  my ($self, $file) = @_;

  open my $fh, ">$file" or return 0;

  for my $i (0 .. ($self->GetLineCount() - 1)) {
    print $fh $self->GetLine ($i);
  }

  close $fh;

  $self->SetSavePoint();

  return 1;
}

#
# Help routine for StyleSet
#

sub StyleSetSpec {
  my ($self, $style, $textstyle) = @_;

  foreach my $prop (split (/,/, $textstyle)) {

    my ($key, $value) = split (/:/, $prop);

    $self->StyleSetFore($style, $value) if $key eq 'fore';
    $self->StyleSetBack($style, $value) if $key eq 'back';

    $self->StyleSetFont($style, $value) if $key eq 'face';

    $self->StyleSetSize($style, int ($value) )  if $key eq 'size';

    $self->StyleSetBold($style, 1)      if $key eq 'bold';
    $self->StyleSetBold($style, 0)      if $key eq 'notbold';
    $self->StyleSetItalic($style, 1)    if $key eq 'italic';
    $self->StyleSetItalic($style, 0)    if $key eq 'notitalic';
    $self->StyleSetUnderline($style, 1) if $key eq 'underline';
    $self->StyleSetUnderline($style, 0) if $key eq 'notunderline';
    $self->StyleSetEOLFilled ($style, 1) if $key eq 'eolfilled';
    $self->StyleSetEOLFilled ($style, 0) if $key eq 'noteolfilled';
  }
}

#------------------------------------------------------------------------
# Begin Autogenerate
#------------------------------------------------------------------------

use constant INVALID_POSITION => -1 ;
# Define start of Scintilla messages to be greater than all Windows edit (EM_*) messages
# as many EM_ messages can be used although that use is deprecated.
use constant SCI_START => 2000 ;
use constant SCI_OPTIONAL_START => 3000 ;
use constant SCI_LEXER_START => 4000 ;
# Add text to the document at current position.
# AddText(text)
sub AddText {
  my ($self, $text) = @_;
  my $length = length $text;
  return $self->SendMessageNP (2001, $length, $text);
}
# Add array of cells to document.
# AddStyledText(styledtext)
sub AddStyledText {
  my ($self, $text) = @_;
  my $length = length $text;
  return $self->SendMessageNP (2002, $length, $text);
}
# Insert string at a position.
sub InsertText {
  my ($self, $pos, $text) = @_;
  return $self->SendMessageNP (2003, $pos, $text);
}
# Delete all text in the document.
sub ClearAll {
  my $self = shift;
  return $self->SendMessage (2004, 0, 0);
}
# Set all style bytes to 0, remove all folding information.
sub ClearDocumentStyle {
  my $self = shift;
  return $self->SendMessage (2005, 0, 0);
}
# Returns the number of characters in the document.
sub GetLength {
  my $self = shift;
  return $self->SendMessage (2006, 0, 0);
}
# Returns the character byte at the position.
sub GetCharAt {
  my ($self, $pos) = @_;
  return chr $self->SendMessage (2007, $pos, 0);
}
# Returns the position of the caret.
sub GetCurrentPos {
  my $self = shift;
  return $self->SendMessage (2008, 0, 0);
}
# Returns the position of the opposite end of the selection to the caret.
sub GetAnchor {
  my $self = shift;
  return $self->SendMessage (2009, 0, 0);
}
# Returns the style byte at the position.
sub GetStyleAt {
  my ($self, $pos) = @_;
  return $self->SendMessage (2010, $pos, 0);
}
# Redoes the next action on the undo history.
sub Redo {
  my $self = shift;
  return $self->SendMessage (2011, 0, 0);
}
# Choose between collecting actions into the undo
# history and discarding them.
sub SetUndoCollection {
  my ($self, $collectUndo) = @_;
  return $self->SendMessage (2012, $collectUndo, 0);
}
# Select all the text in the document.
sub SelectAll {
  my $self = shift;
  return $self->SendMessage (2013, 0, 0);
}
# Remember the current position in the undo history as the position
# at which the document was saved.
sub SetSavePoint {
  my $self = shift;
  return $self->SendMessage (2014, 0, 0);
}
# Retrieve a buffer of cells.
# Returns the number of bytes in the buffer not including terminating NULs.
sub GetStyledText {
  my $self = shift;
  my $start = shift || 0;
  my $end = shift || $self->GetLength();

  return undef if $start >= $end;

  my $text = " " x (($end - $start + 1)*2);
  my $textrange = pack("LLp", $start, $end, $text);
  $self->SendMessageNP (2015, 0, $textrange);
  return $text;
}
# Are there any redoable actions in the undo history?
sub CanRedo {
  my $self = shift;
  return $self->SendMessage (2016, 0, 0);
}
# Retrieve the line number at which a particular marker is located.
sub MarkerLineFromHandle {
  my ($self, $handle) = @_;
  return $self->SendMessage (2017, $handle, 0);
}
# Delete a marker.
sub MarkerDeleteHandle {
  my ($self, $handle) = @_;
  return $self->SendMessage (2018, $handle, 0);
}
# Is undo history being collected?
sub GetUndoCollection {
  my $self = shift;
  return $self->SendMessage (2019, 0, 0);
}
use constant SCWS_INVISIBLE => 0 ;
use constant SCWS_VISIBLEALWAYS => 1 ;
use constant SCWS_VISIBLEAFTERINDENT => 2 ;
# Are white space characters currently visible?
# Returns one of SCWS_* constants.
sub GetViewWS {
  my $self = shift;
  return $self->SendMessage (2020, 0, 0);
}
# Make white space characters invisible, always visible or visible outside indentation.
sub SetViewWS {
  my ($self, $viewWS) = @_;
  return $self->SendMessage (2021, $viewWS, 0);
}
# Find the position from a point within the window.
sub PositionFromPoint {
  my ($self, $x, $y) = @_;
  return $self->SendMessage (2022, $x, $y);
}
# Find the position from a point within the window but return
# INVALID_POSITION if not close to text.
sub PositionFromPointClose {
  my ($self, $x, $y) = @_;
  return $self->SendMessage (2023, $x, $y);
}
# Set caret to start of a line and ensure it is visible.
sub GotoLine {
  my ($self, $line) = @_;
  return $self->SendMessage (2024, $line, 0);
}
# Set caret to a position and ensure it is visible.
sub GotoPos {
  my ($self, $pos) = @_;
  return $self->SendMessage (2025, $pos, 0);
}
# Set the selection anchor to a position. The anchor is the opposite
# end of the selection from the caret.
sub SetAnchor {
  my ($self, $posAnchor) = @_;
  return $self->SendMessage (2026, $posAnchor, 0);
}
# Retrieve the text of the line containing the caret.
# Returns the index of the caret on the line.
# GetCurline () : Return curent line Text
sub GetCurLine {
  my ($self) = @_;
  my $line   = $self->GetLineFromPosition ($self->GetCurrentPos());
  my $length = $self->LineLength($line);
  my $text   = " " x $length;

  if ($self->SendMessageNP (2027, $length, $text)) {
    return $text;
  } else {
    return undef;
  }
}
# Retrieve the position of the last correctly styled character.
sub GetEndStyled {
  my $self = shift;
  return $self->SendMessage (2028, 0, 0);
}
use constant SC_EOL_CRLF => 0 ;
use constant SC_EOL_CR => 1 ;
use constant SC_EOL_LF => 2 ;
# Convert all line endings in the document to one mode.
sub ConvertEOLs {
  my ($self, $eolMode) = @_;
  return $self->SendMessage (2029, $eolMode, 0);
}
# Retrieve the current end of line mode - one of CRLF, CR, or LF.
sub GetEOLMode {
  my $self = shift;
  return $self->SendMessage (2030, 0, 0);
}
# Set the current end of line mode.
sub SetEOLMode {
  my ($self, $eolMode) = @_;
  return $self->SendMessage (2031, $eolMode, 0);
}
# Set the current styling position to pos and the styling mask to mask.
# The styling mask can be used to protect some bits in each styling byte from modification.
sub StartStyling {
  my ($self, $pos, $mask) = @_;
  return $self->SendMessage (2032, $pos, $mask);
}
# Change style from current styling position for length characters to a style
# and move the current styling position to after this newly styled segment.
sub SetStyling {
  my ($self, $length, $style) = @_;
  return $self->SendMessage (2033, $length, $style);
}
# Is drawing done first into a buffer or direct to the screen?
sub GetBufferedDraw {
  my $self = shift;
  return $self->SendMessage (2034, 0, 0);
}
# If drawing is buffered then each line of text is drawn into a bitmap buffer
# before drawing it to the screen to avoid flicker.
sub SetBufferedDraw {
  my ($self, $buffered) = @_;
  return $self->SendMessage (2035, $buffered, 0);
}
# Change the visible size of a tab to be a multiple of the width of a space character.
sub SetTabWidth {
  my ($self, $tabWidth) = @_;
  return $self->SendMessage (2036, $tabWidth, 0);
}
# Retrieve the visible size of a tab.
sub GetTabWidth {
  my $self = shift;
  return $self->SendMessage (2121, 0, 0);
}
# The SC_CP_UTF8 value can be used to enter Unicode mode.
# This is the same value as CP_UTF8 in Windows
use constant SC_CP_UTF8 => 65001 ;
# The SC_CP_DBCS value can be used to indicate a DBCS mode for GTK+.
use constant SC_CP_DBCS => 1 ;
# Set the code page used to interpret the bytes of the document as characters.
# The SC_CP_UTF8 value can be used to enter Unicode mode.
sub SetCodePage {
  my ($self, $codePage) = @_;
  return $self->SendMessage (2037, $codePage, 0);
}
# In palette mode, Scintilla uses the environment's palette calls to display
# more colours. This may lead to ugly displays.
sub SetUsePalette {
  my ($self, $usePalette) = @_;
  return $self->SendMessage (2039, $usePalette, 0);
}
use constant MARKER_MAX => 31 ;
use constant SC_MARK_CIRCLE => 0 ;
use constant SC_MARK_ROUNDRECT => 1 ;
use constant SC_MARK_ARROW => 2 ;
use constant SC_MARK_SMALLRECT => 3 ;
use constant SC_MARK_SHORTARROW => 4 ;
use constant SC_MARK_EMPTY => 5 ;
use constant SC_MARK_ARROWDOWN => 6 ;
use constant SC_MARK_MINUS => 7 ;
use constant SC_MARK_PLUS => 8 ;
# Shapes used for outlining column.
use constant SC_MARK_VLINE => 9 ;
use constant SC_MARK_LCORNER => 10 ;
use constant SC_MARK_TCORNER => 11 ;
use constant SC_MARK_BOXPLUS => 12 ;
use constant SC_MARK_BOXPLUSCONNECTED => 13 ;
use constant SC_MARK_BOXMINUS => 14 ;
use constant SC_MARK_BOXMINUSCONNECTED => 15 ;
use constant SC_MARK_LCORNERCURVE => 16 ;
use constant SC_MARK_TCORNERCURVE => 17 ;
use constant SC_MARK_CIRCLEPLUS => 18 ;
use constant SC_MARK_CIRCLEPLUSCONNECTED => 19 ;
use constant SC_MARK_CIRCLEMINUS => 20 ;
use constant SC_MARK_CIRCLEMINUSCONNECTED => 21 ;
# Invisible mark that only sets the line background color.
use constant SC_MARK_BACKGROUND => 22 ;
use constant SC_MARK_DOTDOTDOT => 23 ;
use constant SC_MARK_ARROWS => 24 ;
use constant SC_MARK_PIXMAP => 25 ;
use constant SC_MARK_FULLRECT => 26 ;
use constant SC_MARK_CHARACTER => 10000 ;
# Markers used for outlining column.
use constant SC_MARKNUM_FOLDEREND => 25 ;
use constant SC_MARKNUM_FOLDEROPENMID => 26 ;
use constant SC_MARKNUM_FOLDERMIDTAIL => 27 ;
use constant SC_MARKNUM_FOLDERTAIL => 28 ;
use constant SC_MARKNUM_FOLDERSUB => 29 ;
use constant SC_MARKNUM_FOLDER => 30 ;
use constant SC_MARKNUM_FOLDEROPEN => 31 ;
use constant SC_MASK_FOLDERS => 0xFE000000 ;
# Set the symbol used for a particular marker number.
sub MarkerDefine {
  my ($self, $markerNumber, $markerSymbol) = @_;
  return $self->SendMessage (2040, $markerNumber, $markerSymbol);
}
# Set the foreground colour used for a particular marker number.
sub MarkerSetFore {
  my ($self, $markerNumber, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2041, $markerNumber, int hex $fore);
}
# Set the background colour used for a particular marker number.
sub MarkerSetBack {
  my ($self, $markerNumber, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2042, $markerNumber, int hex $back);
}
# Add a marker to a line, returning an ID which can be used to find or delete the marker.
sub MarkerAdd {
  my ($self, $line, $markerNumber) = @_;
  return $self->SendMessage (2043, $line, $markerNumber);
}
# Delete a marker from a line.
sub MarkerDelete {
  my ($self, $line, $markerNumber) = @_;
  return $self->SendMessage (2044, $line, $markerNumber);
}
# Delete all markers with a particular number from all lines.
sub MarkerDeleteAll {
  my ($self, $markerNumber) = @_;
  return $self->SendMessage (2045, $markerNumber, 0);
}
# Get a bit mask of all the markers set on a line.
sub MarkerGet {
  my ($self, $line) = @_;
  return $self->SendMessage (2046, $line, 0);
}
# Find the next line after lineStart that includes a marker in mask.
sub MarkerNext {
  my ($self, $lineStart, $markerMask) = @_;
  return $self->SendMessage (2047, $lineStart, $markerMask);
}
# Find the previous line before lineStart that includes a marker in mask.
sub MarkerPrevious {
  my ($self, $lineStart, $markerMask) = @_;
  return $self->SendMessage (2048, $lineStart, $markerMask);
}
# Define a marker from a pixmap.
sub MarkerDefinePixmap {
  my ($self, $markerNumber, $pixmap) = @_;
  return $self->SendMessageNP (2049, $markerNumber, $pixmap);
}
# Add a set of markers to a line.
sub MarkerAddSet {
  my ($self, $line, $set) = @_;
  return $self->SendMessage (2466, $line, $set);
}
use constant SC_MARGIN_SYMBOL => 0 ;
use constant SC_MARGIN_NUMBER => 1 ;
# Set a margin to be either numeric or symbolic.
sub SetMarginTypeN {
  my ($self, $margin, $marginType) = @_;
  return $self->SendMessage (2240, $margin, $marginType);
}
# Retrieve the type of a margin.
sub GetMarginTypeN {
  my ($self, $margin) = @_;
  return $self->SendMessage (2241, $margin, 0);
}
# Set the width of a margin to a width expressed in pixels.
sub SetMarginWidthN {
  my ($self, $margin, $pixelWidth) = @_;
  return $self->SendMessage (2242, $margin, $pixelWidth);
}
# Retrieve the width of a margin in pixels.
sub GetMarginWidthN {
  my ($self, $margin) = @_;
  return $self->SendMessage (2243, $margin, 0);
}
# Set a mask that determines which markers are displayed in a margin.
sub SetMarginMaskN {
  my ($self, $margin, $mask) = @_;
  return $self->SendMessage (2244, $margin, $mask);
}
# Retrieve the marker mask of a margin.
sub GetMarginMaskN {
  my ($self, $margin) = @_;
  return $self->SendMessage (2245, $margin, 0);
}
# Make a margin sensitive or insensitive to mouse clicks.
sub SetMarginSensitiveN {
  my ($self, $margin, $sensitive) = @_;
  return $self->SendMessage (2246, $margin, $sensitive);
}
# Retrieve the mouse click sensitivity of a margin.
sub GetMarginSensitiveN {
  my ($self, $margin) = @_;
  return $self->SendMessage (2247, $margin, 0);
}
# Styles in range 32..38 are predefined for parts of the UI and are not used as normal styles.
# Style 39 is for future use.
use constant STYLE_DEFAULT => 32 ;
use constant STYLE_LINENUMBER => 33 ;
use constant STYLE_BRACELIGHT => 34 ;
use constant STYLE_BRACEBAD => 35 ;
use constant STYLE_CONTROLCHAR => 36 ;
use constant STYLE_INDENTGUIDE => 37 ;
use constant STYLE_CALLTIP => 38 ;
use constant STYLE_LASTPREDEFINED => 39 ;
use constant STYLE_MAX => 127 ;
# Character set identifiers are used in StyleSetCharacterSet.
# The values are the same as the Windows *_CHARSET values.
use constant SC_CHARSET_ANSI => 0 ;
use constant SC_CHARSET_DEFAULT => 1 ;
use constant SC_CHARSET_BALTIC => 186 ;
use constant SC_CHARSET_CHINESEBIG5 => 136 ;
use constant SC_CHARSET_EASTEUROPE => 238 ;
use constant SC_CHARSET_GB2312 => 134 ;
use constant SC_CHARSET_GREEK => 161 ;
use constant SC_CHARSET_HANGUL => 129 ;
use constant SC_CHARSET_MAC => 77 ;
use constant SC_CHARSET_OEM => 255 ;
use constant SC_CHARSET_RUSSIAN => 204 ;
use constant SC_CHARSET_CYRILLIC => 1251 ;
use constant SC_CHARSET_SHIFTJIS => 128 ;
use constant SC_CHARSET_SYMBOL => 2 ;
use constant SC_CHARSET_TURKISH => 162 ;
use constant SC_CHARSET_JOHAB => 130 ;
use constant SC_CHARSET_HEBREW => 177 ;
use constant SC_CHARSET_ARABIC => 178 ;
use constant SC_CHARSET_VIETNAMESE => 163 ;
use constant SC_CHARSET_THAI => 222 ;
use constant SC_CHARSET_8859_15 => 1000 ;
# Clear all the styles and make equivalent to the global default style.
sub StyleClearAll {
  my $self = shift;
  return $self->SendMessage (2050, 0, 0);
}
# Set the foreground colour of a style.
sub StyleSetFore {
  my ($self, $style, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2051, $style, int hex $fore);
}
# Set the background colour of a style.
sub StyleSetBack {
  my ($self, $style, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2052, $style, int hex $back);
}
# Set a style to be bold or not.
sub StyleSetBold {
  my ($self, $style, $bold) = @_;
  return $self->SendMessage (2053, $style, $bold);
}
# Set a style to be italic or not.
sub StyleSetItalic {
  my ($self, $style, $italic) = @_;
  return $self->SendMessage (2054, $style, $italic);
}
# Set the size of characters of a style.
sub StyleSetSize {
  my ($self, $style, $sizePoints) = @_;
  return $self->SendMessage (2055, $style, $sizePoints);
}
# Set the font of a style.
sub StyleSetFont {
  my ($self, $style, $fontName) = @_;
  return $self->SendMessageNP (2056, $style, $fontName);
}
# Set a style to have its end of line filled or not.
sub StyleSetEOLFilled {
  my ($self, $style, $filled) = @_;
  return $self->SendMessage (2057, $style, $filled);
}
# Reset the default style to its state at startup
sub StyleResetDefault {
  my $self = shift;
  return $self->SendMessage (2058, 0, 0);
}
# Set a style to be underlined or not.
sub StyleSetUnderline {
  my ($self, $style, $underline) = @_;
  return $self->SendMessage (2059, $style, $underline);
}
use constant SC_CASE_MIXED => 0 ;
use constant SC_CASE_UPPER => 1 ;
use constant SC_CASE_LOWER => 2 ;
# Set a style to be mixed case, or to force upper or lower case.
sub StyleSetCase {
  my ($self, $style, $caseForce) = @_;
  return $self->SendMessage (2060, $style, $caseForce);
}
# Set the character set of the font in a style.
sub StyleSetCharacterSet {
  my ($self, $style, $characterSet) = @_;
  return $self->SendMessage (2066, $style, $characterSet);
}
# Set a style to be a hotspot or not.
sub StyleSetHotSpot {
  my ($self, $style, $hotspot) = @_;
  return $self->SendMessage (2409, $style, $hotspot);
}
# Set the foreground colour of the selection and whether to use this setting.
sub SetSelFore {
  my ($self, $useSetting, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2067, $useSetting, int hex $fore);
}
# Set the background colour of the selection and whether to use this setting.
sub SetSelBack {
  my ($self, $useSetting, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2068, $useSetting, int hex $back);
}
# Set the foreground colour of the caret.
sub SetCaretFore {
  my ($self, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2069, int hex $fore, 0);
}
# When key+modifier combination km is pressed perform msg.
sub AssignCmdKey {
  my ($self, $key, $modifiers, $msg) = @_;
  my $param = pack ('ss', $key, $modifiers);
  return $self->SendMessage (2070, $param, $msg);
}
# When key+modifier combination km is pressed do nothing.
sub ClearCmdKey {
  my ($self, $key, $modifiers) = @_;
  my $param = pack ('ss', $key, $modifiers);
  return $self->SendMessage (2071, $param, 0);
}
# Drop all key mappings.
sub ClearAllCmdKeys {
  my $self = shift;
  return $self->SendMessage (2072, 0, 0);
}
# Set the styles for a segment of the document.
sub SetStylingEx {
  my ($self, $length, $styles) = @_;
  return $self->SendMessageNP (2073, $length, $styles);
}
# Set a style to be visible or not.
sub StyleSetVisible {
  my ($self, $style, $visible) = @_;
  return $self->SendMessage (2074, $style, $visible);
}
# Get the time in milliseconds that the caret is on and off.
sub GetCaretPeriod {
  my $self = shift;
  return $self->SendMessage (2075, 0, 0);
}
# Get the time in milliseconds that the caret is on and off. 0 = steady on.
sub SetCaretPeriod {
  my ($self, $periodMilliseconds) = @_;
  return $self->SendMessage (2076, $periodMilliseconds, 0);
}
# Set the set of characters making up words for when moving or selecting by word.
# First sets deaults like SetCharsDefault.
sub SetWordChars {
  my ($self, $characters) = @_;
  return $self->SendMessageNP (2077, 0, $characters);
}
# Start a sequence of actions that is undone and redone as a unit.
# May be nested.
sub BeginUndoAction {
  my $self = shift;
  return $self->SendMessage (2078, 0, 0);
}
# End a sequence of actions that is undone and redone as a unit.
sub EndUndoAction {
  my $self = shift;
  return $self->SendMessage (2079, 0, 0);
}
use constant INDIC_MAX => 7 ;
use constant INDIC_PLAIN => 0 ;
use constant INDIC_SQUIGGLE => 1 ;
use constant INDIC_TT => 2 ;
use constant INDIC_DIAGONAL => 3 ;
use constant INDIC_STRIKE => 4 ;
use constant INDIC_HIDDEN => 5 ;
use constant INDIC_BOX => 6 ;
use constant INDIC_ROUNDBOX => 7 ;
use constant INDIC0_MASK => 0x20 ;
use constant INDIC1_MASK => 0x40 ;
use constant INDIC2_MASK => 0x80 ;
use constant INDICS_MASK => 0xE0 ;
# Set an indicator to plain, squiggle or TT.
sub IndicSetStyle {
  my ($self, $indic, $style) = @_;
  return $self->SendMessage (2080, $indic, $style);
}
# Retrieve the style of an indicator.
sub IndicGetStyle {
  my ($self, $indic) = @_;
  return $self->SendMessage (2081, $indic, 0);
}
# Set the foreground colour of an indicator.
sub IndicSetFore {
  my ($self, $indic, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2082, $indic, int hex $fore);
}
# Retrieve the foreground colour of an indicator.
sub IndicGetFore {
  my ($self, $indic) = @_;
  my $colour = $self->SendMessage (2083, $indic, 0);
  $colour = sprintf ('#%x', $colour);
  $colour =~ s/(.)(..)(..)(..)/$1$4$3$2/;
  return $colour;
}# Set the foreground colour of all whitespace and whether to use this setting.
sub SetWhitespaceFore {
  my ($self, $useSetting, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2084, $useSetting, int hex $fore);
}
# Set the background colour of all whitespace and whether to use this setting.
sub SetWhitespaceBack {
  my ($self, $useSetting, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2085, $useSetting, int hex $back);
}
# Divide each styling byte into lexical class bits (default: 5) and indicator
# bits (default: 3). If a lexer requires more than 32 lexical states, then this
# is used to expand the possible states.
sub SetStyleBits {
  my ($self, $bits) = @_;
  return $self->SendMessage (2090, $bits, 0);
}
# Retrieve number of bits in style bytes used to hold the lexical state.
sub GetStyleBits {
  my $self = shift;
  return $self->SendMessage (2091, 0, 0);
}
# Used to hold extra styling information for each line.
sub SetLineState {
  my ($self, $line, $state) = @_;
  return $self->SendMessage (2092, $line, $state);
}
# Retrieve the extra styling information for a line.
sub GetLineState {
  my ($self, $line) = @_;
  return $self->SendMessage (2093, $line, 0);
}
# Retrieve the last line number that has line state.
sub GetMaxLineState {
  my $self = shift;
  return $self->SendMessage (2094, 0, 0);
}
# Is the background of the line containing the caret in a different colour?
sub GetCaretLineVisible {
  my $self = shift;
  return $self->SendMessage (2095, 0, 0);
}
# Display the background of the line containing the caret in a different colour.
sub SetCaretLineVisible {
  my ($self, $show) = @_;
  return $self->SendMessage (2096, $show, 0);
}
# Get the colour of the background of the line containing the caret.
sub GetCaretLineBack {
  my $self = shift;
  my $colour = $self->SendMessage (2097, 0, 0);
  $colour = sprintf ('#%x', $colour);
  $colour =~ s/(.)(..)(..)(..)/$1$4$3$2/;
  return $colour;
}
# Set the colour of the background of the line containing the caret.
sub SetCaretLineBack {
  my ($self, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2098, int hex $back, 0);
}
# Set a style to be changeable or not (read only).
# Experimental feature, currently buggy.
sub StyleSetChangeable {
  my ($self, $style, $changeable) = @_;
  return $self->SendMessage (2099, $style, $changeable);
}
# Display a auto-completion list.
# The lenEntered parameter indicates how many characters before
# the caret should be used to provide context.
sub AutoCShow {
  my ($self, $lenEntered, $itemList) = @_;
  return $self->SendMessageNP (2100, $lenEntered, $itemList);
}
# Remove the auto-completion list from the screen.
sub AutoCCancel {
  my $self = shift;
  return $self->SendMessage (2101, 0, 0);
}
# Is there an auto-completion list visible?
sub AutoCActive {
  my $self = shift;
  return $self->SendMessage (2102, 0, 0);
}
# Retrieve the position of the caret when the auto-completion list was displayed.
sub AutoCPosStart {
  my $self = shift;
  return $self->SendMessage (2103, 0, 0);
}
# User has selected an item so remove the list and insert the selection.
sub AutoCComplete {
  my $self = shift;
  return $self->SendMessage (2104, 0, 0);
}
# Define a set of character that when typed cancel the auto-completion list.
sub AutoCStops {
  my ($self, $characterSet) = @_;
  return $self->SendMessageNP (2105, 0, $characterSet);
}
# Change the separator character in the string setting up an auto-completion list.
# Default is space but can be changed if items contain space.
sub AutoCSetSeparator {
  my ($self, $separatorCharacter) = @_;
  return $self->SendMessage (2106, $separatorCharacter, 0);
}
# Retrieve the auto-completion list separator character.
sub AutoCGetSeparator {
  my $self = shift;
  return $self->SendMessage (2107, 0, 0);
}
# Select the item in the auto-completion list that starts with a string.
sub AutoCSelect {
  my ($self, $text) = @_;
  return $self->SendMessageNP (2108, 0, $text);
}
# Should the auto-completion list be cancelled if the user backspaces to a
# position before where the box was created.
sub AutoCSetCancelAtStart {
  my ($self, $cancel) = @_;
  return $self->SendMessage (2110, $cancel, 0);
}
# Retrieve whether auto-completion cancelled by backspacing before start.
sub AutoCGetCancelAtStart {
  my $self = shift;
  return $self->SendMessage (2111, 0, 0);
}
# Define a set of characters that when typed will cause the autocompletion to
# choose the selected item.
sub AutoCSetFillUps {
  my ($self, $characterSet) = @_;
  return $self->SendMessageNP (2112, 0, $characterSet);
}
# Should a single item auto-completion list automatically choose the item.
sub AutoCSetChooseSingle {
  my ($self, $chooseSingle) = @_;
  return $self->SendMessage (2113, $chooseSingle, 0);
}
# Retrieve whether a single item auto-completion list automatically choose the item.
sub AutoCGetChooseSingle {
  my $self = shift;
  return $self->SendMessage (2114, 0, 0);
}
# Set whether case is significant when performing auto-completion searches.
sub AutoCSetIgnoreCase {
  my ($self, $ignoreCase) = @_;
  return $self->SendMessage (2115, $ignoreCase, 0);
}
# Retrieve state of ignore case flag.
sub AutoCGetIgnoreCase {
  my $self = shift;
  return $self->SendMessage (2116, 0, 0);
}
# Display a list of strings and send notification when user chooses one.
sub UserListShow {
  my ($self, $listType, $itemList) = @_;
  return $self->SendMessageNP (2117, $listType, $itemList);
}
# Set whether or not autocompletion is hidden automatically when nothing matches.
sub AutoCSetAutoHide {
  my ($self, $autoHide) = @_;
  return $self->SendMessage (2118, $autoHide, 0);
}
# Retrieve whether or not autocompletion is hidden automatically when nothing matches.
sub AutoCGetAutoHide {
  my $self = shift;
  return $self->SendMessage (2119, 0, 0);
}
# Set whether or not autocompletion deletes any word characters
# after the inserted text upon completion.
sub AutoCSetDropRestOfWord {
  my ($self, $dropRestOfWord) = @_;
  return $self->SendMessage (2270, $dropRestOfWord, 0);
}
# Retrieve whether or not autocompletion deletes any word characters
# after the inserted text upon completion.
sub AutoCGetDropRestOfWord {
  my $self = shift;
  return $self->SendMessage (2271, 0, 0);
}
# Register an XPM image for use in autocompletion lists.
sub RegisterImage {
  my ($self, $type, $xpmData) = @_;
  return $self->SendMessageNP (2405, $type, $xpmData);
}
# Clear all the registered XPM images.
sub ClearRegisteredImages {
  my $self = shift;
  return $self->SendMessage (2408, 0, 0);
}
# Retrieve the auto-completion list type-separator character.
sub AutoCGetTypeSeparator {
  my $self = shift;
  return $self->SendMessage (2285, 0, 0);
}
# Change the type-separator character in the string setting up an auto-completion list.
# Default is '?' but can be changed if items contain '?'.
sub AutoCSetTypeSeparator {
  my ($self, $separatorCharacter) = @_;
  return $self->SendMessage (2286, $separatorCharacter, 0);
}
# Set the maximum width, in characters, of auto-completion and user lists.
# Set to 0 to autosize to fit longest item, which is the default.
sub AutoCSetMaxWidth {
  my ($self, $characterCount) = @_;
  return $self->SendMessage (2208, $characterCount, 0);
}
# Get the maximum width, in characters, of auto-completion and user lists.
sub AutoCGetMaxWidth {
  my $self = shift;
  return $self->SendMessage (2209, 0, 0);
}
# Set the maximum height, in rows, of auto-completion and user lists.
# The default is 5 rows.
sub AutoCSetMaxHeight {
  my ($self, $rowCount) = @_;
  return $self->SendMessage (2210, $rowCount, 0);
}
# Set the maximum height, in rows, of auto-completion and user lists.
sub AutoCGetMaxHeight {
  my $self = shift;
  return $self->SendMessage (2211, 0, 0);
}
# Set the number of spaces used for one level of indentation.
sub SetIndent {
  my ($self, $indentSize) = @_;
  return $self->SendMessage (2122, $indentSize, 0);
}
# Retrieve indentation size.
sub GetIndent {
  my $self = shift;
  return $self->SendMessage (2123, 0, 0);
}
# Indentation will only use space characters if useTabs is false, otherwise
# it will use a combination of tabs and spaces.
sub SetUseTabs {
  my ($self, $useTabs) = @_;
  return $self->SendMessage (2124, $useTabs, 0);
}
# Retrieve whether tabs will be used in indentation.
sub GetUseTabs {
  my $self = shift;
  return $self->SendMessage (2125, 0, 0);
}
# Change the indentation of a line to a number of columns.
sub SetLineIndentation {
  my ($self, $line, $indentSize) = @_;
  return $self->SendMessage (2126, $line, $indentSize);
}
# Retrieve the number of columns that a line is indented.
sub GetLineIndentation {
  my ($self, $line) = @_;
  return $self->SendMessage (2127, $line, 0);
}
# Retrieve the position before the first non indentation character on a line.
sub GetLineIndentPosition {
  my ($self, $line) = @_;
  return $self->SendMessage (2128, $line, 0);
}
# Retrieve the column number of a position, taking tab width into account.
sub GetColumn {
  my ($self, $pos) = @_;
  return $self->SendMessage (2129, $pos, 0);
}
# Show or hide the horizontal scroll bar.
sub SetHScrollBar {
  my ($self, $show) = @_;
  return $self->SendMessage (2130, $show, 0);
}
# Is the horizontal scroll bar visible?
sub GetHScrollBar {
  my $self = shift;
  return $self->SendMessage (2131, 0, 0);
}
# Show or hide indentation guides.
sub SetIndentationGuides {
  my ($self, $show) = @_;
  return $self->SendMessage (2132, $show, 0);
}
# Are the indentation guides visible?
sub GetIndentationGuides {
  my $self = shift;
  return $self->SendMessage (2133, 0, 0);
}
# Set the highlighted indentation guide column.
# 0 = no highlighted guide.
sub SetHighlightGuide {
  my ($self, $column) = @_;
  return $self->SendMessage (2134, $column, 0);
}
# Get the highlighted indentation guide column.
sub GetHighlightGuide {
  my $self = shift;
  return $self->SendMessage (2135, 0, 0);
}
# Get the position after the last visible characters on a line.
sub GetLineEndPosition {
  my ($self, $line) = @_;
  return $self->SendMessage (2136, $line, 0);
}
# Get the code page used to interpret the bytes of the document as characters.
sub GetCodePage {
  my $self = shift;
  return $self->SendMessage (2137, 0, 0);
}
# Get the foreground colour of the caret.
sub GetCaretFore {
  my $self = shift;
  my $colour = $self->SendMessage (2138, 0, 0);
  $colour = sprintf ('#%x', $colour);
  $colour =~ s/(.)(..)(..)(..)/$1$4$3$2/;
  return $colour;
}
# In palette mode?
sub GetUsePalette {
  my $self = shift;
  return $self->SendMessage (2139, 0, 0);
}
# In read-only mode?
sub GetReadOnly {
  my $self = shift;
  return $self->SendMessage (2140, 0, 0);
}
# Sets the position of the caret.
sub SetCurrentPos {
  my ($self, $pos) = @_;
  return $self->SendMessage (2141, $pos, 0);
}
# Sets the position that starts the selection - this becomes the anchor.
sub SetSelectionStart {
  my ($self, $pos) = @_;
  return $self->SendMessage (2142, $pos, 0);
}
# Returns the position at the start of the selection.
sub GetSelectionStart {
  my $self = shift;
  return $self->SendMessage (2143, 0, 0);
}
# Sets the position that ends the selection - this becomes the currentPosition.
sub SetSelectionEnd {
  my ($self, $pos) = @_;
  return $self->SendMessage (2144, $pos, 0);
}
# Returns the position at the end of the selection.
sub GetSelectionEnd {
  my $self = shift;
  return $self->SendMessage (2145, 0, 0);
}
# Sets the print magnification added to the point size of each style for printing.
sub SetPrintMagnification {
  my ($self, $magnification) = @_;
  return $self->SendMessage (2146, $magnification, 0);
}
# Returns the print magnification.
sub GetPrintMagnification {
  my $self = shift;
  return $self->SendMessage (2147, 0, 0);
}
# PrintColourMode - use same colours as screen.
use constant SC_PRINT_NORMAL => 0 ;
# PrintColourMode - invert the light value of each style for printing.
use constant SC_PRINT_INVERTLIGHT => 1 ;
# PrintColourMode - force black text on white background for printing.
use constant SC_PRINT_BLACKONWHITE => 2 ;
# PrintColourMode - text stays coloured, but all background is forced to be white for printing.
use constant SC_PRINT_COLOURONWHITE => 3 ;
# PrintColourMode - only the default-background is forced to be white for printing.
use constant SC_PRINT_COLOURONWHITEDEFAULTBG => 4 ;
# Modify colours when printing for clearer printed text.
sub SetPrintColourMode {
  my ($self, $mode) = @_;
  return $self->SendMessage (2148, $mode, 0);
}
# Returns the print colour mode.
sub GetPrintColourMode {
  my $self = shift;
  return $self->SendMessage (2149, 0, 0);
}
use constant SCFIND_WHOLEWORD => 2 ;
use constant SCFIND_MATCHCASE => 4 ;
use constant SCFIND_WORDSTART => 0x00100000 ;
use constant SCFIND_REGEXP => 0x00200000 ;
use constant SCFIND_POSIX => 0x00400000 ;
# Find some text in the document.
# FindText (textToFind, start=0, end=GetLength(), flag = SCFIND_WHOLEWORD)
sub FindText {
  my $self       = shift;
  my $text       = shift;
  my $start      = shift || 0;
  my $end        = shift || $self->GetLength();
  my $flag       = shift || SCFIND_WHOLEWORD;

  return undef if $start >= $end;

  my $texttofind =  pack("LLpLL", $start, $end, $text, 0, 0);
  my $pos = $self->SendMessageNP (2150, $flag, $texttofind);
  return $pos unless defined wantarray;
  my @res = unpack("LLpLL", $texttofind);
  return ($res[3], $res[4]); # pos , length
}
# On Windows, will draw the document into a display context such as a printer.
# FormatRange (start=0, end=GetLength(), draw=1)
sub FormatRange {
  my $self       = shift;
  my $start      = shift || 0;
  my $end        = shift || $self->GetLength();
  my $draw       = shift || 1;
  return undef if $start >= $end;

  my $formatrange = pack("LL", $start, $end);
  return $self->SendMessageNP (2151, $draw, $formatrange);
}
# Retrieve the display line at the top of the display.
sub GetFirstVisibleLine {
  my $self = shift;
  return $self->SendMessage (2152, 0, 0);
}
# Retrieve the contents of a line.
# Returns the length of the line.
# Getline (line)
sub GetLine {
  my ($self, $line)  = @_;
  my $length = $self->LineLength($line);
  my $text   = " " x $length;

  if ($self->SendMessageNP (2153, $line, $text)) {
    return $text;
  } else {
    return undef;
  }
}
# Returns the number of lines in the document. There is always at least one.
sub GetLineCount {
  my $self = shift;
  return $self->SendMessage (2154, 0, 0);
}
# Sets the size in pixels of the left margin.
sub SetMarginLeft {
  my ($self, $pixelWidth) = @_;
  return $self->SendMessage (2155, 0, $pixelWidth);
}
# Returns the size in pixels of the left margin.
sub GetMarginLeft {
  my $self = shift;
  return $self->SendMessage (2156, 0, 0);
}
# Sets the size in pixels of the right margin.
sub SetMarginRight {
  my ($self, $pixelWidth) = @_;
  return $self->SendMessage (2157, 0, $pixelWidth);
}
# Returns the size in pixels of the right margin.
sub GetMarginRight {
  my $self = shift;
  return $self->SendMessage (2158, 0, 0);
}
# Is the document different from when it was last saved?
sub GetModify {
  my $self = shift;
  return $self->SendMessage (2159, 0, 0);
}
# Select a range of text.
sub SetSel {
  my ($self, $start, $end) = @_;
  return $self->SendMessage (2160, $start, $end);
}
# Retrieve the selected text.
# Return the length of the text.
# GetSelText() : Return selected text
sub GetSelText {
  my $self  = shift;
  my $start = $self->GetSelectionStart();
  my $end   = $self->GetSelectionEnd();

  return undef if $start >= $end;
  my $text   = " " x ($end - $start + 1);

  $self->SendMessageNP (2161, 0, $text);
  return $text;
}
# Retrieve a range of text.
# Return the length of the text.
sub GetTextRange {
  my $self = shift;
  my $start = shift || 0;
  my $end = shift || $self->GetLength();

  return undef if $start >= $end;

  my $text = " " x ($end - $start + 1);
  my $textrange = pack("LLp", $start, $end, $text);
  $self->SendMessageNP (2162, 0, $textrange);
  return $text;
}
# Draw the selection in normal style or with selection highlighted.
sub HideSelection {
  my ($self, $normal) = @_;
  return $self->SendMessage (2163, $normal, 0);
}
# Retrieve the x value of the point in the window where a position is displayed.
sub PointXFromPosition {
  my ($self, $pos) = @_;
  return $self->SendMessage (2164, 0, $pos);
}
# Retrieve the y value of the point in the window where a position is displayed.
sub PointYFromPosition {
  my ($self, $pos) = @_;
  return $self->SendMessage (2165, 0, $pos);
}
# Retrieve the line containing a position.
sub LineFromPosition {
  my ($self, $pos) = @_;
  return $self->SendMessage (2166, $pos, 0);
}
# Retrieve the position at the start of a line.
sub PositionFromLine {
  my ($self, $line) = @_;
  return $self->SendMessage (2167, $line, 0);
}
# Scroll horizontally and vertically.
sub LineScroll {
  my ($self, $columns, $lines) = @_;
  return $self->SendMessage (2168, $columns, $lines);
}
# Ensure the caret is visible.
sub ScrollCaret {
  my $self = shift;
  return $self->SendMessage (2169, 0, 0);
}
# Replace the selected text with the argument text.
sub ReplaceSel {
  my ($self, $text) = @_;
  return $self->SendMessageNP (2170, 0, $text);
}
# Set to read only or read write.
sub SetReadOnly {
  my ($self, $readOnly) = @_;
  return $self->SendMessage (2171, $readOnly, 0);
}
# Null operation.
sub Null {
  my $self = shift;
  return $self->SendMessage (2172, 0, 0);
}
# Will a paste succeed?
sub CanPaste {
  my $self = shift;
  return $self->SendMessage (2173, 0, 0);
}
# Are there any undoable actions in the undo history?
sub CanUndo {
  my $self = shift;
  return $self->SendMessage (2174, 0, 0);
}
# Delete the undo history.
sub EmptyUndoBuffer {
  my $self = shift;
  return $self->SendMessage (2175, 0, 0);
}
# Undo one action in the undo history.
sub Undo {
  my $self = shift;
  return $self->SendMessage (2176, 0, 0);
}
# Cut the selection to the clipboard.
sub Cut {
  my $self = shift;
  return $self->SendMessage (2177, 0, 0);
}
# Copy the selection to the clipboard.
sub Copy {
  my $self = shift;
  return $self->SendMessage (2178, 0, 0);
}
# Paste the contents of the clipboard into the document replacing the selection.
sub Paste {
  my $self = shift;
  return $self->SendMessage (2179, 0, 0);
}
# Clear the selection.
sub Clear {
  my $self = shift;
  return $self->SendMessage (2180, 0, 0);
}
# Replace the contents of the document with the argument text.
sub SetText {
  my ($self, $text) = @_;
  return $self->SendMessageNP (2181, 0, $text);
}
# Retrieve all the text in the document.
# Returns number of characters retrieved.
# GetText() : Return all text
sub GetText {
  my $self   = shift;
  my $length = $self->SendMessage(2182, 0, 0); # includes trailing NUL
  my $text   = " " x $length;

  $self->SendMessageNP (2182, $length, $text);
  $text =~ s/.$//; # remove trailing NUL (regexp is faster than sbstr)
  return $text;
}
# Retrieve the number of characters in the document.
sub GetTextLength {
  my $self = shift;
  return $self->SendMessage (2183, 0, 0);
}
# Retrieve a pointer to a function that processes messages for this Scintilla.
sub GetDirectFunction {
  my $self = shift;
  return $self->SendMessage (2184, 0, 0);
}
# Retrieve a pointer value to use as the first argument when calling
# the function returned by GetDirectFunction.
sub GetDirectPointer {
  my $self = shift;
  return $self->SendMessage (2185, 0, 0);
}
# Set to overtype (true) or insert mode.
sub SetOvertype {
  my ($self, $overtype) = @_;
  return $self->SendMessage (2186, $overtype, 0);
}
# Returns true if overtype mode is active otherwise false is returned.
sub GetOvertype {
  my $self = shift;
  return $self->SendMessage (2187, 0, 0);
}
# Set the width of the insert mode caret.
sub SetCaretWidth {
  my ($self, $pixelWidth) = @_;
  return $self->SendMessage (2188, $pixelWidth, 0);
}
# Returns the width of the insert mode caret.
sub GetCaretWidth {
  my $self = shift;
  return $self->SendMessage (2189, 0, 0);
}
# Sets the position that starts the target which is used for updating the
# document without affecting the scroll position.
sub SetTargetStart {
  my ($self, $pos) = @_;
  return $self->SendMessage (2190, $pos, 0);
}
# Get the position that starts the target.
sub GetTargetStart {
  my $self = shift;
  return $self->SendMessage (2191, 0, 0);
}
# Sets the position that ends the target which is used for updating the
# document without affecting the scroll position.
sub SetTargetEnd {
  my ($self, $pos) = @_;
  return $self->SendMessage (2192, $pos, 0);
}
# Get the position that ends the target.
sub GetTargetEnd {
  my $self = shift;
  return $self->SendMessage (2193, 0, 0);
}
# Replace the target text with the argument text.
# Text is counted so it can contain NULs.
# Returns the length of the replacement text.
# ReplaceTarget(text)
sub ReplaceTarget {
  my ($self, $text) = @_;
  my $length = length $text;
  return $self->SendMessageNP (2194, $length, $text);
}
# Replace the target text with the argument text after \d processing.
# Text is counted so it can contain NULs.
# Looks for \d where d is between 1 and 9 and replaces these with the strings
# matched in the last search operation which were surrounded by \( and \).
# Returns the length of the replacement text including any change
# caused by processing the \d patterns.
# ReplaceTargetRE(text)
sub ReplaceTargetRE {
  my ($self, $text) = @_;
  my $length = length $text;
  return $self->SendMessageNP (2195, $length, $text);
}
# Search for a counted string in the target and set the target to the found
# range. Text is counted so it can contain NULs.
# Returns length of range or -1 for failure in which case target is not moved.
# SearchInTarget(text)
sub SearchInTarget {
  my ($self, $text) = @_;
  my $length = length $text;
  return $self->SendMessageNP (2197, $length, $text);
}
# Set the search flags used by SearchInTarget.
sub SetSearchFlags {
  my ($self, $flags) = @_;
  return $self->SendMessage (2198, $flags, 0);
}
# Get the search flags used by SearchInTarget.
sub GetSearchFlags {
  my $self = shift;
  return $self->SendMessage (2199, 0, 0);
}
# Show a call tip containing a definition near position pos.
sub CallTipShow {
  my ($self, $pos, $definition) = @_;
  return $self->SendMessageNP (2200, $pos, $definition);
}
# Remove the call tip from the screen.
sub CallTipCancel {
  my $self = shift;
  return $self->SendMessage (2201, 0, 0);
}
# Is there an active call tip?
sub CallTipActive {
  my $self = shift;
  return $self->SendMessage (2202, 0, 0);
}
# Retrieve the position where the caret was before displaying the call tip.
sub CallTipPosStart {
  my $self = shift;
  return $self->SendMessage (2203, 0, 0);
}
# Highlight a segment of the definition.
sub CallTipSetHlt {
  my ($self, $start, $end) = @_;
  return $self->SendMessage (2204, $start, $end);
}
# Set the background colour for the call tip.
sub CallTipSetBack {
  my ($self, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2205, int hex $back, 0);
}
# Set the foreground colour for the call tip.
sub CallTipSetFore {
  my ($self, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2206, int hex $fore, 0);
}
# Set the foreground colour for the highlighted part of the call tip.
sub CallTipSetForeHlt {
  my ($self, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2207, int hex $fore, 0);
}
# Enable use of STYLE_CALLTIP and set call tip tab size in pixels.
sub CallTipUseStyle {
  my ($self, $tabSize) = @_;
  return $self->SendMessage (2212, $tabSize, 0);
}
# Find the display line of a document line taking hidden lines into account.
sub VisibleFromDocLine {
  my ($self, $line) = @_;
  return $self->SendMessage (2220, $line, 0);
}
# Find the document line of a display line taking hidden lines into account.
sub DocLineFromVisible {
  my ($self, $lineDisplay) = @_;
  return $self->SendMessage (2221, $lineDisplay, 0);
}
# The number of display lines needed to wrap a document line
sub WrapCount {
  my ($self, $line) = @_;
  return $self->SendMessage (2235, $line, 0);
}
use constant SC_FOLDLEVELBASE => 0x400 ;
use constant SC_FOLDLEVELWHITEFLAG => 0x1000 ;
use constant SC_FOLDLEVELHEADERFLAG => 0x2000 ;
use constant SC_FOLDLEVELBOXHEADERFLAG => 0x4000 ;
use constant SC_FOLDLEVELBOXFOOTERFLAG => 0x8000 ;
use constant SC_FOLDLEVELCONTRACTED => 0x10000 ;
use constant SC_FOLDLEVELUNINDENT => 0x20000 ;
use constant SC_FOLDLEVELNUMBERMASK => 0x0FFF ;
# Set the fold level of a line.
# This encodes an integer level along with flags indicating whether the
# line is a header and whether it is effectively white space.
sub SetFoldLevel {
  my ($self, $line, $level) = @_;
  return $self->SendMessage (2222, $line, $level);
}
# Retrieve the fold level of a line.
sub GetFoldLevel {
  my ($self, $line) = @_;
  return $self->SendMessage (2223, $line, 0);
}
# Find the last child line of a header line.
sub GetLastChild {
  my ($self, $line, $level) = @_;
  return $self->SendMessage (2224, $line, $level);
}
# Find the parent line of a child line.
sub GetFoldParent {
  my ($self, $line) = @_;
  return $self->SendMessage (2225, $line, 0);
}
# Make a range of lines visible.
sub ShowLines {
  my ($self, $lineStart, $lineEnd) = @_;
  return $self->SendMessage (2226, $lineStart, $lineEnd);
}
# Make a range of lines invisible.
sub HideLines {
  my ($self, $lineStart, $lineEnd) = @_;
  return $self->SendMessage (2227, $lineStart, $lineEnd);
}
# Is a line visible?
sub GetLineVisible {
  my ($self, $line) = @_;
  return $self->SendMessage (2228, $line, 0);
}
# Show the children of a header line.
sub SetFoldExpanded {
  my ($self, $line, $expanded) = @_;
  return $self->SendMessage (2229, $line, $expanded);
}
# Is a header line expanded?
sub GetFoldExpanded {
  my ($self, $line) = @_;
  return $self->SendMessage (2230, $line, 0);
}
# Switch a header line between expanded and contracted.
sub ToggleFold {
  my ($self, $line) = @_;
  return $self->SendMessage (2231, $line, 0);
}
# Ensure a particular line is visible by expanding any header line hiding it.
sub EnsureVisible {
  my ($self, $line) = @_;
  return $self->SendMessage (2232, $line, 0);
}
use constant SC_FOLDFLAG_LINEBEFORE_EXPANDED => 0x0002 ;
use constant SC_FOLDFLAG_LINEBEFORE_CONTRACTED => 0x0004 ;
use constant SC_FOLDFLAG_LINEAFTER_EXPANDED => 0x0008 ;
use constant SC_FOLDFLAG_LINEAFTER_CONTRACTED => 0x0010 ;
use constant SC_FOLDFLAG_LEVELNUMBERS => 0x0040 ;
use constant SC_FOLDFLAG_BOX => 0x0001 ;
# Set some style options for folding.
sub SetFoldFlags {
  my ($self, $flags) = @_;
  return $self->SendMessage (2233, $flags, 0);
}
# Ensure a particular line is visible by expanding any header line hiding it.
# Use the currently set visibility policy to determine which range to display.
sub EnsureVisibleEnforcePolicy {
  my ($self, $line) = @_;
  return $self->SendMessage (2234, $line, 0);
}
# Sets whether a tab pressed when caret is within indentation indents.
sub SetTabIndents {
  my ($self, $tabIndents) = @_;
  return $self->SendMessage (2260, $tabIndents, 0);
}
# Does a tab pressed when caret is within indentation indent?
sub GetTabIndents {
  my $self = shift;
  return $self->SendMessage (2261, 0, 0);
}
# Sets whether a backspace pressed when caret is within indentation unindents.
sub SetBackSpaceUnIndents {
  my ($self, $bsUnIndents) = @_;
  return $self->SendMessage (2262, $bsUnIndents, 0);
}
# Does a backspace pressed when caret is within indentation unindent?
sub GetBackSpaceUnIndents {
  my $self = shift;
  return $self->SendMessage (2263, 0, 0);
}
use constant SC_TIME_FOREVER => 10000000 ;
# Sets the time the mouse must sit still to generate a mouse dwell event.
sub SetMouseDwellTime {
  my ($self, $periodMilliseconds) = @_;
  return $self->SendMessage (2264, $periodMilliseconds, 0);
}
# Retrieve the time the mouse must sit still to generate a mouse dwell event.
sub GetMouseDwellTime {
  my $self = shift;
  return $self->SendMessage (2265, 0, 0);
}
# Get position of start of word.
sub WordStartPosition {
  my ($self, $pos, $onlyWordCharacters) = @_;
  return $self->SendMessage (2266, $pos, $onlyWordCharacters);
}
# Get position of end of word.
sub WordEndPosition {
  my ($self, $pos, $onlyWordCharacters) = @_;
  return $self->SendMessage (2267, $pos, $onlyWordCharacters);
}
use constant SC_WRAP_NONE => 0 ;
use constant SC_WRAP_WORD => 1 ;
use constant SC_WRAP_CHAR => 2 ;
# Sets whether text is word wrapped.
sub SetWrapMode {
  my ($self, $mode) = @_;
  return $self->SendMessage (2268, $mode, 0);
}
# Retrieve whether text is word wrapped.
sub GetWrapMode {
  my $self = shift;
  return $self->SendMessage (2269, 0, 0);
}
use constant SC_WRAPVISUALFLAG_NONE => 0x0000 ;
use constant SC_WRAPVISUALFLAG_END => 0x0001 ;
use constant SC_WRAPVISUALFLAG_START => 0x0002 ;
# Set the display mode of visual flags for wrapped lines.
sub SetWrapVisualFlags {
  my ($self, $wrapVisualFlags) = @_;
  return $self->SendMessage (2460, $wrapVisualFlags, 0);
}
# Retrive the display mode of visual flags for wrapped lines.
sub GetWrapVisualFlags {
  my $self = shift;
  return $self->SendMessage (2461, 0, 0);
}
use constant SC_WRAPVISUALFLAGLOC_DEFAULT => 0x0000 ;
use constant SC_WRAPVISUALFLAGLOC_END_BY_TEXT => 0x0001 ;
use constant SC_WRAPVISUALFLAGLOC_START_BY_TEXT => 0x0002 ;
# Set the location of visual flags for wrapped lines.
sub SetWrapVisualFlagsLocation {
  my ($self, $wrapVisualFlagsLocation) = @_;
  return $self->SendMessage (2462, $wrapVisualFlagsLocation, 0);
}
# Retrive the location of visual flags for wrapped lines.
sub GetWrapVisualFlagsLocation {
  my $self = shift;
  return $self->SendMessage (2463, 0, 0);
}
# Set the start indent for wrapped lines.
sub SetWrapStartIndent {
  my ($self, $indent) = @_;
  return $self->SendMessage (2464, $indent, 0);
}
# Retrive the start indent for wrapped lines.
sub GetWrapStartIndent {
  my $self = shift;
  return $self->SendMessage (2465, 0, 0);
}
use constant SC_CACHE_NONE => 0 ;
use constant SC_CACHE_CARET => 1 ;
use constant SC_CACHE_PAGE => 2 ;
use constant SC_CACHE_DOCUMENT => 3 ;
# Sets the degree of caching of layout information.
sub SetLayoutCache {
  my ($self, $mode) = @_;
  return $self->SendMessage (2272, $mode, 0);
}
# Retrieve the degree of caching of layout information.
sub GetLayoutCache {
  my $self = shift;
  return $self->SendMessage (2273, 0, 0);
}
# Sets the document width assumed for scrolling.
sub SetScrollWidth {
  my ($self, $pixelWidth) = @_;
  return $self->SendMessage (2274, $pixelWidth, 0);
}
# Retrieve the document width assumed for scrolling.
sub GetScrollWidth {
  my $self = shift;
  return $self->SendMessage (2275, 0, 0);
}
# Measure the pixel width of some text in a particular style.
# NUL terminated text argument.
# Does not handle tab or control characters.
sub TextWidth {
  my ($self, $style, $text) = @_;
  return $self->SendMessageNP (2276, $style, $text);
}
# Sets the scroll range so that maximum scroll position has
# the last line at the bottom of the view (default).
# Setting this to false allows scrolling one page below the last line.
sub SetEndAtLastLine {
  my ($self, $endAtLastLine) = @_;
  return $self->SendMessage (2277, $endAtLastLine, 0);
}
# Retrieve whether the maximum scroll position has the last
# line at the bottom of the view.
sub GetEndAtLastLine {
  my $self = shift;
  return $self->SendMessage (2278, 0, 0);
}
# Retrieve the height of a particular line of text in pixels.
sub TextHeight {
  my ($self, $line) = @_;
  return $self->SendMessage (2279, $line, 0);
}
# Show or hide the vertical scroll bar.
sub SetVScrollBar {
  my ($self, $show) = @_;
  return $self->SendMessage (2280, $show, 0);
}
# Is the vertical scroll bar visible?
sub GetVScrollBar {
  my $self = shift;
  return $self->SendMessage (2281, 0, 0);
}
# Append a string to the end of the document without changing the selection.
# AppendText(text)
sub AppendText {
  my ($self, $text) = @_;
  my $length = length $text;
  return $self->SendMessageNP (2282, $length, $text);
}
# Is drawing done in two phases with backgrounds drawn before faoregrounds?
sub GetTwoPhaseDraw {
  my $self = shift;
  return $self->SendMessage (2283, 0, 0);
}
# In twoPhaseDraw mode, drawing is performed in two phases, first the background
# and then the foreground. This avoids chopping off characters that overlap the next run.
sub SetTwoPhaseDraw {
  my ($self, $twoPhase) = @_;
  return $self->SendMessage (2284, $twoPhase, 0);
}
# Make the target range start and end be the same as the selection range start and end.
sub TargetFromSelection {
  my $self = shift;
  return $self->SendMessage (2287, 0, 0);
}
# Join the lines in the target.
sub LinesJoin {
  my $self = shift;
  return $self->SendMessage (2288, 0, 0);
}
# Split the lines in the target into lines that are less wide than pixelWidth
# where possible.
sub LinesSplit {
  my ($self, $pixelWidth) = @_;
  return $self->SendMessage (2289, $pixelWidth, 0);
}
# Set the colours used as a chequerboard pattern in the fold margin
sub SetFoldMarginColour {
  my ($self, $useSetting, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2290, $useSetting, int hex $back);
}
sub SetFoldMarginHiColour {
  my ($self, $useSetting, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2291, $useSetting, int hex $fore);
}
# Move caret down one line.
sub LineDown {
  my $self = shift;
  return $self->SendMessage (2300, 0, 0);
}
# Move caret down one line extending selection to new caret position.
sub LineDownExtend {
  my $self = shift;
  return $self->SendMessage (2301, 0, 0);
}
# Move caret up one line.
sub LineUp {
  my $self = shift;
  return $self->SendMessage (2302, 0, 0);
}
# Move caret up one line extending selection to new caret position.
sub LineUpExtend {
  my $self = shift;
  return $self->SendMessage (2303, 0, 0);
}
# Move caret left one character.
sub CharLeft {
  my $self = shift;
  return $self->SendMessage (2304, 0, 0);
}
# Move caret left one character extending selection to new caret position.
sub CharLeftExtend {
  my $self = shift;
  return $self->SendMessage (2305, 0, 0);
}
# Move caret right one character.
sub CharRight {
  my $self = shift;
  return $self->SendMessage (2306, 0, 0);
}
# Move caret right one character extending selection to new caret position.
sub CharRightExtend {
  my $self = shift;
  return $self->SendMessage (2307, 0, 0);
}
# Move caret left one word.
sub WordLeft {
  my $self = shift;
  return $self->SendMessage (2308, 0, 0);
}
# Move caret left one word extending selection to new caret position.
sub WordLeftExtend {
  my $self = shift;
  return $self->SendMessage (2309, 0, 0);
}
# Move caret right one word.
sub WordRight {
  my $self = shift;
  return $self->SendMessage (2310, 0, 0);
}
# Move caret right one word extending selection to new caret position.
sub WordRightExtend {
  my $self = shift;
  return $self->SendMessage (2311, 0, 0);
}
# Move caret to first position on line.
sub Home {
  my $self = shift;
  return $self->SendMessage (2312, 0, 0);
}
# Move caret to first position on line extending selection to new caret position.
sub HomeExtend {
  my $self = shift;
  return $self->SendMessage (2313, 0, 0);
}
# Move caret to last position on line.
sub LineEnd {
  my $self = shift;
  return $self->SendMessage (2314, 0, 0);
}
# Move caret to last position on line extending selection to new caret position.
sub LineEndExtend {
  my $self = shift;
  return $self->SendMessage (2315, 0, 0);
}
# Move caret to first position in document.
sub DocumentStart {
  my $self = shift;
  return $self->SendMessage (2316, 0, 0);
}
# Move caret to first position in document extending selection to new caret position.
sub DocumentStartExtend {
  my $self = shift;
  return $self->SendMessage (2317, 0, 0);
}
# Move caret to last position in document.
sub DocumentEnd {
  my $self = shift;
  return $self->SendMessage (2318, 0, 0);
}
# Move caret to last position in document extending selection to new caret position.
sub DocumentEndExtend {
  my $self = shift;
  return $self->SendMessage (2319, 0, 0);
}
# Move caret one page up.
sub PageUp {
  my $self = shift;
  return $self->SendMessage (2320, 0, 0);
}
# Move caret one page up extending selection to new caret position.
sub PageUpExtend {
  my $self = shift;
  return $self->SendMessage (2321, 0, 0);
}
# Move caret one page down.
sub PageDown {
  my $self = shift;
  return $self->SendMessage (2322, 0, 0);
}
# Move caret one page down extending selection to new caret position.
sub PageDownExtend {
  my $self = shift;
  return $self->SendMessage (2323, 0, 0);
}
# Switch from insert to overtype mode or the reverse.
sub EditToggleOvertype {
  my $self = shift;
  return $self->SendMessage (2324, 0, 0);
}
# Cancel any modes such as call tip or auto-completion list display.
sub Cancel {
  my $self = shift;
  return $self->SendMessage (2325, 0, 0);
}
# Delete the selection or if no selection, the character before the caret.
sub DeleteBack {
  my $self = shift;
  return $self->SendMessage (2326, 0, 0);
}
# If selection is empty or all on one line replace the selection with a tab character.
# If more than one line selected, indent the lines.
sub Tab {
  my $self = shift;
  return $self->SendMessage (2327, 0, 0);
}
# Dedent the selected lines.
sub BackTab {
  my $self = shift;
  return $self->SendMessage (2328, 0, 0);
}
# Insert a new line, may use a CRLF, CR or LF depending on EOL mode.
sub NewLine {
  my $self = shift;
  return $self->SendMessage (2329, 0, 0);
}
# Insert a Form Feed character.
sub FormFeed {
  my $self = shift;
  return $self->SendMessage (2330, 0, 0);
}
# Move caret to before first visible character on line.
# If already there move to first character on line.
sub VCHome {
  my $self = shift;
  return $self->SendMessage (2331, 0, 0);
}
# Like VCHome but extending selection to new caret position.
sub VCHomeExtend {
  my $self = shift;
  return $self->SendMessage (2332, 0, 0);
}
# Magnify the displayed text by increasing the sizes by 1 point.
sub ZoomIn {
  my $self = shift;
  return $self->SendMessage (2333, 0, 0);
}
# Make the displayed text smaller by decreasing the sizes by 1 point.
sub ZoomOut {
  my $self = shift;
  return $self->SendMessage (2334, 0, 0);
}
# Delete the word to the left of the caret.
sub DelWordLeft {
  my $self = shift;
  return $self->SendMessage (2335, 0, 0);
}
# Delete the word to the right of the caret.
sub DelWordRight {
  my $self = shift;
  return $self->SendMessage (2336, 0, 0);
}
# Cut the line containing the caret.
sub LineCut {
  my $self = shift;
  return $self->SendMessage (2337, 0, 0);
}
# Delete the line containing the caret.
sub LineDelete {
  my $self = shift;
  return $self->SendMessage (2338, 0, 0);
}
# Switch the current line with the previous.
sub LineTranspose {
  my $self = shift;
  return $self->SendMessage (2339, 0, 0);
}
# Duplicate the current line.
sub LineDuplicate {
  my $self = shift;
  return $self->SendMessage (2404, 0, 0);
}
# Transform the selection to lower case.
sub LowerCase {
  my $self = shift;
  return $self->SendMessage (2340, 0, 0);
}
# Transform the selection to upper case.
sub UpperCase {
  my $self = shift;
  return $self->SendMessage (2341, 0, 0);
}
# Scroll the document down, keeping the caret visible.
sub LineScrollDown {
  my $self = shift;
  return $self->SendMessage (2342, 0, 0);
}
# Scroll the document up, keeping the caret visible.
sub LineScrollUp {
  my $self = shift;
  return $self->SendMessage (2343, 0, 0);
}
# Delete the selection or if no selection, the character before the caret.
# Will not delete the character before at the start of a line.
sub DeleteBackNotLine {
  my $self = shift;
  return $self->SendMessage (2344, 0, 0);
}
# Move caret to first position on display line.
sub HomeDisplay {
  my $self = shift;
  return $self->SendMessage (2345, 0, 0);
}
# Move caret to first position on display line extending selection to
# new caret position.
sub HomeDisplayExtend {
  my $self = shift;
  return $self->SendMessage (2346, 0, 0);
}
# Move caret to last position on display line.
sub LineEndDisplay {
  my $self = shift;
  return $self->SendMessage (2347, 0, 0);
}
# Move caret to last position on display line extending selection to new
# caret position.
sub LineEndDisplayExtend {
  my $self = shift;
  return $self->SendMessage (2348, 0, 0);
}
# These are like their namesakes Home(Extend)?, LineEnd(Extend)?, VCHome(Extend)?
# except they behave differently when word-wrap is enabled:
# They go first to the start / end of the display line, like (Home|LineEnd)Display
# The difference is that, the cursor is already at the point, it goes on to the start
# or end of the document line, as appropriate for (Home|LineEnd|VCHome)(Extend)?.
sub HomeWrap {
  my $self = shift;
  return $self->SendMessage (2349, 0, 0);
}
sub HomeWrapExtend {
  my $self = shift;
  return $self->SendMessage (2450, 0, 0);
}
sub LineEndWrap {
  my $self = shift;
  return $self->SendMessage (2451, 0, 0);
}
sub LineEndWrapExtend {
  my $self = shift;
  return $self->SendMessage (2452, 0, 0);
}
sub VCHomeWrap {
  my $self = shift;
  return $self->SendMessage (2453, 0, 0);
}
sub VCHomeWrapExtend {
  my $self = shift;
  return $self->SendMessage (2454, 0, 0);
}
# Copy the line containing the caret.
sub LineCopy {
  my $self = shift;
  return $self->SendMessage (2455, 0, 0);
}
# Move the caret inside current view if it's not there already.
sub MoveCaretInsideView {
  my $self = shift;
  return $self->SendMessage (2401, 0, 0);
}
# How many characters are on a line, not including end of line characters?
sub LineLength {
  my ($self, $line) = @_;
  return $self->SendMessage (2350, $line, 0);
}
# Highlight the characters at two positions.
sub BraceHighlight {
  my ($self, $pos1, $pos2) = @_;
  return $self->SendMessage (2351, $pos1, $pos2);
}
# Highlight the character at a position indicating there is no matching brace.
sub BraceBadLight {
  my ($self, $pos) = @_;
  return $self->SendMessage (2352, $pos, 0);
}
# Find the position of a matching brace or INVALID_POSITION if no match.
sub BraceMatch {
  my ($self, $pos) = @_;
  return $self->SendMessage (2353, $pos, 0);
}
# Are the end of line characters visible?
sub GetViewEOL {
  my $self = shift;
  return $self->SendMessage (2355, 0, 0);
}
# Make the end of line characters visible or invisible.
sub SetViewEOL {
  my ($self, $visible) = @_;
  return $self->SendMessage (2356, $visible, 0);
}
# Retrieve a pointer to the document object.
sub GetDocPointer {
  my $self = shift;
  return $self->SendMessage (2357, 0, 0);
}
# Change the document object used.
sub SetDocPointer {
  my ($self, $pointer) = @_;
  return $self->SendMessage (2358, 0, $pointer);
}
# Set which document modification events are sent to the container.
sub SetModEventMask {
  my ($self, $mask) = @_;
  return $self->SendMessage (2359, $mask, 0);
}
use constant EDGE_NONE => 0 ;
use constant EDGE_LINE => 1 ;
use constant EDGE_BACKGROUND => 2 ;
# Retrieve the column number which text should be kept within.
sub GetEdgeColumn {
  my $self = shift;
  return $self->SendMessage (2360, 0, 0);
}
# Set the column number of the edge.
# If text goes past the edge then it is highlighted.
sub SetEdgeColumn {
  my ($self, $column) = @_;
  return $self->SendMessage (2361, $column, 0);
}
# Retrieve the edge highlight mode.
sub GetEdgeMode {
  my $self = shift;
  return $self->SendMessage (2362, 0, 0);
}
# The edge may be displayed by a line (EDGE_LINE) or by highlighting text that
# goes beyond it (EDGE_BACKGROUND) or not displayed at all (EDGE_NONE).
sub SetEdgeMode {
  my ($self, $mode) = @_;
  return $self->SendMessage (2363, $mode, 0);
}
# Retrieve the colour used in edge indication.
sub GetEdgeColour {
  my $self = shift;
  my $colour = $self->SendMessage (2364, 0, 0);
  $colour = sprintf ('#%x', $colour);
  $colour =~ s/(.)(..)(..)(..)/$1$4$3$2/;
  return $colour;
}
# Change the colour used in edge indication.
sub SetEdgeColour {
  my ($self, $edgeColour) = @_;
  $edgeColour =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2365, int hex $edgeColour, 0);
}
# Sets the current caret position to be the search anchor.
sub SearchAnchor {
  my $self = shift;
  return $self->SendMessage (2366, 0, 0);
}
# Find some text starting at the search anchor.
# Does not ensure the selection is visible.
sub SearchNext {
  my ($self, $flags, $text) = @_;
  return $self->SendMessageNP (2367, $flags, $text);
}
# Find some text starting at the search anchor and moving backwards.
# Does not ensure the selection is visible.
sub SearchPrev {
  my ($self, $flags, $text) = @_;
  return $self->SendMessageNP (2368, $flags, $text);
}
# Retrieves the number of lines completely visible.
sub LinesOnScreen {
  my $self = shift;
  return $self->SendMessage (2370, 0, 0);
}
# Set whether a pop up menu is displayed automatically when the user presses
# the wrong mouse button.
sub UsePopUp {
  my ($self, $allowPopUp) = @_;
  return $self->SendMessage (2371, $allowPopUp, 0);
}
# Is the selection rectangular? The alternative is the more common stream selection.
sub SelectionIsRectangle {
  my $self = shift;
  return $self->SendMessage (2372, 0, 0);
}
# Set the zoom level. This number of points is added to the size of all fonts.
# It may be positive to magnify or negative to reduce.
sub SetZoom {
  my ($self, $zoom) = @_;
  return $self->SendMessage (2373, $zoom, 0);
}
# Retrieve the zoom level.
sub GetZoom {
  my $self = shift;
  return $self->SendMessage (2374, 0, 0);
}
# Create a new document object.
# Starts with reference count of 1 and not selected into editor.
sub CreateDocument {
  my $self = shift;
  return $self->SendMessage (2375, 0, 0);
}
# Extend life of document.
sub AddRefDocument {
  my ($self, $doc) = @_;
  return $self->SendMessage (2376, 0, $doc);
}
# Release a reference to the document, deleting document if it fades to black.
sub ReleaseDocument {
  my ($self, $doc) = @_;
  return $self->SendMessage (2377, 0, $doc);
}
# Get which document modification events are sent to the container.
sub GetModEventMask {
  my $self = shift;
  return $self->SendMessage (2378, 0, 0);
}
# Change internal focus flag.
sub SetFocus {
  my ($self, $focus) = @_;
  return $self->SendMessage (2380, $focus, 0);
}
# Get internal focus flag.
sub GetFocus {
  my $self = shift;
  return $self->SendMessage (2381, 0, 0);
}
# Change error status - 0 = OK.
sub SetStatus {
  my ($self, $statusCode) = @_;
  return $self->SendMessage (2382, $statusCode, 0);
}
# Get error status.
sub GetStatus {
  my $self = shift;
  return $self->SendMessage (2383, 0, 0);
}
# Set whether the mouse is captured when its button is pressed.
sub SetMouseDownCaptures {
  my ($self, $captures) = @_;
  return $self->SendMessage (2384, $captures, 0);
}
# Get whether mouse gets captured.
sub GetMouseDownCaptures {
  my $self = shift;
  return $self->SendMessage (2385, 0, 0);
}
use constant SC_CURSORNORMAL => -1 ;
use constant SC_CURSORWAIT => 4 ;
# Sets the cursor to one of the SC_CURSOR* values.
sub SetCursor {
  my ($self, $cursorType) = @_;
  return $self->SendMessage (2386, $cursorType, 0);
}
# Get cursor type.
sub GetCursor {
  my $self = shift;
  return $self->SendMessage (2387, 0, 0);
}
# Change the way control characters are displayed:
# If symbol is < 32, keep the drawn way, else, use the given character.
sub SetControlCharSymbol {
  my ($self, $symbol) = @_;
  return $self->SendMessage (2388, $symbol, 0);
}
# Get the way control characters are displayed.
sub GetControlCharSymbol {
  my $self = shift;
  return $self->SendMessage (2389, 0, 0);
}
# Move to the previous change in capitalisation.
sub WordPartLeft {
  my $self = shift;
  return $self->SendMessage (2390, 0, 0);
}
# Move to the previous change in capitalisation extending selection
# to new caret position.
sub WordPartLeftExtend {
  my $self = shift;
  return $self->SendMessage (2391, 0, 0);
}
# Move to the change next in capitalisation.
sub WordPartRight {
  my $self = shift;
  return $self->SendMessage (2392, 0, 0);
}
# Move to the next change in capitalisation extending selection
# to new caret position.
sub WordPartRightExtend {
  my $self = shift;
  return $self->SendMessage (2393, 0, 0);
}
# Constants for use with SetVisiblePolicy, similar to SetCaretPolicy.
use constant VISIBLE_SLOP => 0x01 ;
use constant VISIBLE_STRICT => 0x04 ;
# Set the way the display area is determined when a particular line
# is to be moved to by Find, FindNext, GotoLine, etc.
sub SetVisiblePolicy {
  my ($self, $visiblePolicy, $visibleSlop) = @_;
  return $self->SendMessage (2394, $visiblePolicy, $visibleSlop);
}
# Delete back from the current position to the start of the line.
sub DelLineLeft {
  my $self = shift;
  return $self->SendMessage (2395, 0, 0);
}
# Delete forwards from the current position to the end of the line.
sub DelLineRight {
  my $self = shift;
  return $self->SendMessage (2396, 0, 0);
}
# Get and Set the xOffset (ie, horizonal scroll position).
sub SetXOffset {
  my ($self, $newOffset) = @_;
  return $self->SendMessage (2397, $newOffset, 0);
}
sub GetXOffset {
  my $self = shift;
  return $self->SendMessage (2398, 0, 0);
}
# Set the last x chosen value to be the caret x position.
sub ChooseCaretX {
  my $self = shift;
  return $self->SendMessage (2399, 0, 0);
}
# Set the focus to this Scintilla widget.
sub GrabFocus {
  my $self = shift;
  return $self->SendMessage (2400, 0, 0);
}
# Caret policy, used by SetXCaretPolicy and SetYCaretPolicy.
# If CARET_SLOP is set, we can define a slop value: caretSlop.
# This value defines an unwanted zone (UZ) where the caret is... unwanted.
# This zone is defined as a number of pixels near the vertical margins,
# and as a number of lines near the horizontal margins.
# By keeping the caret away from the edges, it is seen within its context,
# so it is likely that the identifier that the caret is on can be completely seen,
# and that the current line is seen with some of the lines following it which are
# often dependent on that line.
use constant CARET_SLOP => 0x01 ;
# If CARET_STRICT is set, the policy is enforced... strictly.
# The caret is centred on the display if slop is not set,
# and cannot go in the UZ if slop is set.
use constant CARET_STRICT => 0x04 ;
# If CARET_JUMPS is set, the display is moved more energetically
# so the caret can move in the same direction longer before the policy is applied again.
use constant CARET_JUMPS => 0x10 ;
# If CARET_EVEN is not set, instead of having symmetrical UZs,
# the left and bottom UZs are extended up to right and top UZs respectively.
# This way, we favour the displaying of useful information: the begining of lines,
# where most code reside, and the lines after the caret, eg. the body of a function.
use constant CARET_EVEN => 0x08 ;
# Set the way the caret is kept visible when going sideway.
# The exclusion zone is given in pixels.
sub SetXCaretPolicy {
  my ($self, $caretPolicy, $caretSlop) = @_;
  return $self->SendMessage (2402, $caretPolicy, $caretSlop);
}
# Set the way the line the caret is on is kept visible.
# The exclusion zone is given in lines.
sub SetYCaretPolicy {
  my ($self, $caretPolicy, $caretSlop) = @_;
  return $self->SendMessage (2403, $caretPolicy, $caretSlop);
}
# Set printing to line wrapped (SC_WRAP_WORD) or not line wrapped (SC_WRAP_NONE).
sub SetPrintWrapMode {
  my ($self, $mode) = @_;
  return $self->SendMessage (2406, $mode, 0);
}
# Is printing line wrapped?
sub GetPrintWrapMode {
  my $self = shift;
  return $self->SendMessage (2407, 0, 0);
}
# Set a fore colour for active hotspots.
sub SetHotspotActiveFore {
  my ($self, $useSetting, $fore) = @_;
  $fore =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2410, $useSetting, int hex $fore);
}
# Set a back colour for active hotspots.
sub SetHotspotActiveBack {
  my ($self, $useSetting, $back) = @_;
  $back =~ s/.(..)(..)(..)/$3$2$1/;
  return $self->SendMessage (2411, $useSetting, int hex $back);
}
# Enable / Disable underlining active hotspots.
sub SetHotspotActiveUnderline {
  my ($self, $underline) = @_;
  return $self->SendMessage (2412, $underline, 0);
}
# Limit hotspots to single line so hotspots on two lines don't merge.
sub SetHotspotSingleLine {
  my ($self, $singleLine) = @_;
  return $self->SendMessage (2421, $singleLine, 0);
}
# Move caret between paragraphs (delimited by empty lines).
sub ParaDown {
  my $self = shift;
  return $self->SendMessage (2413, 0, 0);
}
sub ParaDownExtend {
  my $self = shift;
  return $self->SendMessage (2414, 0, 0);
}
sub ParaUp {
  my $self = shift;
  return $self->SendMessage (2415, 0, 0);
}
sub ParaUpExtend {
  my $self = shift;
  return $self->SendMessage (2416, 0, 0);
}
# Given a valid document position, return the previous position taking code
# page into account. Returns 0 if passed 0.
sub PositionBefore {
  my ($self, $pos) = @_;
  return $self->SendMessage (2417, $pos, 0);
}
# Given a valid document position, return the next position taking code
# page into account. Maximum value returned is the last position in the document.
sub PositionAfter {
  my ($self, $pos) = @_;
  return $self->SendMessage (2418, $pos, 0);
}
# Copy a range of text to the clipboard. Positions are clipped into the document.
sub CopyRange {
  my ($self, $start, $end) = @_;
  return $self->SendMessage (2419, $start, $end);
}
# Copy argument text to the clipboard.
# CopyText(text)
sub CopyText {
  my ($self, $text) = @_;
  my $length = length $text;
  return $self->SendMessageNP (2420, $length, $text);
}
use constant SC_SEL_STREAM => 0 ;
use constant SC_SEL_RECTANGLE => 1 ;
use constant SC_SEL_LINES => 2 ;
# Set the selection mode to stream (SC_SEL_STREAM) or rectangular (SC_SEL_RECTANGLE) or
# by lines (SC_SEL_LINES).
sub SetSelectionMode {
  my ($self, $mode) = @_;
  return $self->SendMessage (2422, $mode, 0);
}
# Get the mode of the current selection.
sub GetSelectionMode {
  my $self = shift;
  return $self->SendMessage (2423, 0, 0);
}
# Retrieve the position of the start of the selection at the given line (INVALID_POSITION if no selection on this line).
sub GetLineSelStartPosition {
  my ($self, $line) = @_;
  return $self->SendMessage (2424, $line, 0);
}
# Retrieve the position of the end of the selection at the given line (INVALID_POSITION if no selection on this line).
sub GetLineSelEndPosition {
  my ($self, $line) = @_;
  return $self->SendMessage (2425, $line, 0);
}
# Move caret down one line, extending rectangular selection to new caret position.
sub LineDownRectExtend {
  my $self = shift;
  return $self->SendMessage (2426, 0, 0);
}
# Move caret up one line, extending rectangular selection to new caret position.
sub LineUpRectExtend {
  my $self = shift;
  return $self->SendMessage (2427, 0, 0);
}
# Move caret left one character, extending rectangular selection to new caret position.
sub CharLeftRectExtend {
  my $self = shift;
  return $self->SendMessage (2428, 0, 0);
}
# Move caret right one character, extending rectangular selection to new caret position.
sub CharRightRectExtend {
  my $self = shift;
  return $self->SendMessage (2429, 0, 0);
}
# Move caret to first position on line, extending rectangular selection to new caret position.
sub HomeRectExtend {
  my $self = shift;
  return $self->SendMessage (2430, 0, 0);
}
# Move caret to before first visible character on line.
# If already there move to first character on line.
# In either case, extend rectangular selection to new caret position.
sub VCHomeRectExtend {
  my $self = shift;
  return $self->SendMessage (2431, 0, 0);
}
# Move caret to last position on line, extending rectangular selection to new caret position.
sub LineEndRectExtend {
  my $self = shift;
  return $self->SendMessage (2432, 0, 0);
}
# Move caret one page up, extending rectangular selection to new caret position.
sub PageUpRectExtend {
  my $self = shift;
  return $self->SendMessage (2433, 0, 0);
}
# Move caret one page down, extending rectangular selection to new caret position.
sub PageDownRectExtend {
  my $self = shift;
  return $self->SendMessage (2434, 0, 0);
}
# Move caret to top of page, or one page up if already at top of page.
sub StutteredPageUp {
  my $self = shift;
  return $self->SendMessage (2435, 0, 0);
}
# Move caret to top of page, or one page up if already at top of page, extending selection to new caret position.
sub StutteredPageUpExtend {
  my $self = shift;
  return $self->SendMessage (2436, 0, 0);
}
# Move caret to bottom of page, or one page down if already at bottom of page.
sub StutteredPageDown {
  my $self = shift;
  return $self->SendMessage (2437, 0, 0);
}
# Move caret to bottom of page, or one page down if already at bottom of page, extending selection to new caret position.
sub StutteredPageDownExtend {
  my $self = shift;
  return $self->SendMessage (2438, 0, 0);
}
# Move caret left one word, position cursor at end of word.
sub WordLeftEnd {
  my $self = shift;
  return $self->SendMessage (2439, 0, 0);
}
# Move caret left one word, position cursor at end of word, extending selection to new caret position.
sub WordLeftEndExtend {
  my $self = shift;
  return $self->SendMessage (2440, 0, 0);
}
# Move caret right one word, position cursor at end of word.
sub WordRightEnd {
  my $self = shift;
  return $self->SendMessage (2441, 0, 0);
}
# Move caret right one word, position cursor at end of word, extending selection to new caret position.
sub WordRightEndExtend {
  my $self = shift;
  return $self->SendMessage (2442, 0, 0);
}
# Set the set of characters making up whitespace for when moving or selecting by word.
# Should be called after SetWordChars.
sub SetWhitespaceChars {
  my ($self, $characters) = @_;
  return $self->SendMessageNP (2443, 0, $characters);
}
# Reset the set of characters for whitespace and word characters to the defaults.
sub SetCharsDefault {
  my $self = shift;
  return $self->SendMessage (2444, 0, 0);
}
# Get currently selected item position in the auto-completion list
sub AutoCGetCurrent {
  my $self = shift;
  return $self->SendMessage (2445, 0, 0);
}
# Enlarge the document to a particular size of text bytes.
sub Allocate {
  my ($self, $bytes) = @_;
  return $self->SendMessage (2446, $bytes, 0);
}
# Returns the target converted to UTF8.
# Return the length in bytes.
# TargetAsUTF8() :
# Returns the target converted to UTF8.
sub TargetAsUTF8 {
  my $self  = shift;
  my $len   = $self->SendMessage(2447,0,0);
  my $text   = " " x $len;

  $self->SendMessageNP (2447, 0, $text);
  return $text;
}
# Set the length of the utf8 argument for calling EncodedFromUTF8.
# Set to -1 and the string will be measured to the first nul.
sub SetLengthForEncode {
  my ($self, $bytes) = @_;
  return $self->SendMessage (2448, $bytes, 0);
}
# Translates a UTF8 string into the document encoding.
# Return the length of the result in bytes.
# On error return 0.
# EncodedFromUTF8() :
# Translates a UTF8 string into the document encoding.
# Return the length of the result in bytes.
# On error return 0.
sub EncodedFromUTF8 {
  my ($self, $src)  = @_;
  my $len   = $self->SendMessagePN(2449,$src,0);
  my $text   = " " x $len;

  if($self->SendMessagePP (2449, $src, $text)) {
    return $text;
  }
  else {
    return undef;
  }
}
# Find the position of a column on a line taking into account tabs and
# multi-byte characters. If beyond end of line, return line end position.
sub FindColumn {
  my ($self, $line, $column) = @_;
  return $self->SendMessage (2456, $line, $column);
}
# Can the caret preferred x position only be changed by explicit movement commands?
sub GetCaretSticky {
  my $self = shift;
  return $self->SendMessage (2457, 0, 0);
}
# Stop the caret preferred x position changing when the user types.
sub SetCaretSticky {
  my ($self, $useCaretStickyBehaviour) = @_;
  return $self->SendMessage (2458, $useCaretStickyBehaviour, 0);
}
# Switch between sticky and non-sticky: meant to be bound to a key.
sub ToggleCaretSticky {
  my $self = shift;
  return $self->SendMessage (2459, 0, 0);
}
# Enable/Disable convert-on-paste for line endings
sub SetPasteConvertEndings {
  my ($self, $convert) = @_;
  return $self->SendMessage (2467, $convert, 0);
}
# Get convert-on-paste setting
sub GetPasteConvertEndings {
  my $self = shift;
  return $self->SendMessage (2468, 0, 0);
}
# Duplicate the selection. If selection empty duplicate the line containing the caret.
sub SelectionDuplicate {
  my $self = shift;
  return $self->SendMessage (2469, 0, 0);
}
use constant SC_ALPHA_TRANSPARENT => 0 ;
use constant SC_ALPHA_OPAQUE => 255 ;
use constant SC_ALPHA_NOALPHA => 256 ;
# Set background alpha of the caret line.
sub SetCaretLineBackAlpha {
  my ($self, $alpha) = @_;
  return $self->SendMessage (2470, $alpha, 0);
}
# Get the background alpha of the caret line.
sub GetCaretLineBackAlpha {
  my $self = shift;
  return $self->SendMessage (2471, 0, 0);
}
# Start notifying the container of all key presses and commands.
sub StartRecord {
  my $self = shift;
  return $self->SendMessage (3001, 0, 0);
}
# Stop notifying the container of all key presses and commands.
sub StopRecord {
  my $self = shift;
  return $self->SendMessage (3002, 0, 0);
}
# Set the lexing language of the document.
sub SetLexer {
  my ($self, $lexer) = @_;
  return $self->SendMessage (4001, $lexer, 0);
}
# Retrieve the lexing language of the document.
sub GetLexer {
  my $self = shift;
  return $self->SendMessage (4002, 0, 0);
}
# Colourise a segment of the document using the current lexing language.
sub Colourise {
  my ($self, $start, $end) = @_;
  return $self->SendMessage (4003, $start, $end);
}
# Set up a value that may be used by a lexer for some optional feature.
sub SetProperty {
  my ($self, $key, $value) = @_;
  return $self->SendMessagePP (4004, $key, $value);
}
# Maximum value of keywordSet parameter of SetKeyWords.
use constant KEYWORDSET_MAX => 8 ;
# Set up the key words used by the lexer.
sub SetKeyWords {
  my ($self, $keywordSet, $keyWords) = @_;
  return $self->SendMessageNP (4005, $keywordSet, $keyWords);
}
# Set the lexing language of the document based on string name.
sub SetLexerLanguage {
  my ($self, $language) = @_;
  return $self->SendMessageNP (4006, 0, $language);
}
# Load a lexer library (dll / so).
sub LoadLexerLibrary {
  my ($self, $path) = @_;
  return $self->SendMessageNP (4007, 0, $path);
}
# Retrieve a "property" value previously set with SetProperty.
# GetProperty(): Retrieve a "property" value previously set with SetProperty.
# GetPropertyExpanded() with "$()" variable replacement on returned buffer.
sub GetProperty {
  my ($self, $key)   = @_;
  my $len = $self->SendMessagePN(4008, $key, 0);
  my $text   = " " x $len;

  $self->SendMessagePP (4008, $key, $text);
  return $text;
}
# Retrieve a "property" value previously set with SetProperty,
# with "$()" variable replacement on returned buffer.
# GetProperty(): Retrieve a "property" value previously set with SetProperty.
# GetPropertyExpanded() with "$()" variable replacement on returned buffer.
sub GetPropertyExpanded {
  my ($self, $key)   = @_;
  my $len = $self->SendMessagePN(4009, $key, 0);
  my $text   = " " x $len;

  $self->SendMessagePP (4009, $key, $text);
  return $text;
}
# Retrieve a "property" value previously set with SetProperty,
# interpreted as an int AFTER any "$()" variable replacement.
sub GetPropertyInt {
  my ($self, $key) = @_;
  return $self->SendMessagePP (4010, $key, '');
}
# Retrieve the number of bits the current lexer needs for styling.
sub GetStyleBitsNeeded {
  my $self = shift;
  return $self->SendMessage (4011, 0, 0);
}
# Notifications
# Type of modification and the action which caused the modification.
# These are defined as a bit mask to make it easy to specify which notifications are wanted.
# One bit is set from each of SC_MOD_* and SC_PERFORMED_*.
use constant SC_MOD_INSERTTEXT => 0x1 ;
use constant SC_MOD_DELETETEXT => 0x2 ;
use constant SC_MOD_CHANGESTYLE => 0x4 ;
use constant SC_MOD_CHANGEFOLD => 0x8 ;
use constant SC_PERFORMED_USER => 0x10 ;
use constant SC_PERFORMED_UNDO => 0x20 ;
use constant SC_PERFORMED_REDO => 0x40 ;
use constant SC_MULTISTEPUNDOREDO => 0x80 ;
use constant SC_LASTSTEPINUNDOREDO => 0x100 ;
use constant SC_MOD_CHANGEMARKER => 0x200 ;
use constant SC_MOD_BEFOREINSERT => 0x400 ;
use constant SC_MOD_BEFOREDELETE => 0x800 ;
use constant SC_MULTILINEUNDOREDO => 0x1000 ;
use constant SC_MODEVENTMASKALL => 0x1FFF ;
# For compatibility, these go through the COMMAND notification rather than NOTIFY
# and should have had exactly the same values as the EN_* constants.
# Unfortunately the SETFOCUS and KILLFOCUS are flipped over from EN_*
# As clients depend on these constants, this will not be changed.
use constant SCEN_CHANGE => 768 ;
use constant SCEN_SETFOCUS => 512 ;
use constant SCEN_KILLFOCUS => 256 ;
# Symbolic key codes and modifier flags.
# ASCII and other printable characters below 256.
# Extended keys above 300.
use constant SCK_DOWN => 300 ;
use constant SCK_UP => 301 ;
use constant SCK_LEFT => 302 ;
use constant SCK_RIGHT => 303 ;
use constant SCK_HOME => 304 ;
use constant SCK_END => 305 ;
use constant SCK_PRIOR => 306 ;
use constant SCK_NEXT => 307 ;
use constant SCK_DELETE => 308 ;
use constant SCK_INSERT => 309 ;
use constant SCK_ESCAPE => 7 ;
use constant SCK_BACK => 8 ;
use constant SCK_TAB => 9 ;
use constant SCK_RETURN => 13 ;
use constant SCK_ADD => 310 ;
use constant SCK_SUBTRACT => 311 ;
use constant SCK_DIVIDE => 312 ;
use constant SCMOD_NORM => 0 ;
use constant SCMOD_SHIFT => 1 ;
use constant SCMOD_CTRL => 2 ;
use constant SCMOD_ALT => 4 ;
# For SciLexer.h
use constant SCLEX_CONTAINER => 0 ;
use constant SCLEX_NULL => 1 ;
use constant SCLEX_PYTHON => 2 ;
use constant SCLEX_CPP => 3 ;
use constant SCLEX_HTML => 4 ;
use constant SCLEX_XML => 5 ;
use constant SCLEX_PERL => 6 ;
use constant SCLEX_SQL => 7 ;
use constant SCLEX_VB => 8 ;
use constant SCLEX_PROPERTIES => 9 ;
use constant SCLEX_ERRORLIST => 10 ;
use constant SCLEX_MAKEFILE => 11 ;
use constant SCLEX_BATCH => 12 ;
use constant SCLEX_XCODE => 13 ;
use constant SCLEX_LATEX => 14 ;
use constant SCLEX_LUA => 15 ;
use constant SCLEX_DIFF => 16 ;
use constant SCLEX_CONF => 17 ;
use constant SCLEX_PASCAL => 18 ;
use constant SCLEX_AVE => 19 ;
use constant SCLEX_ADA => 20 ;
use constant SCLEX_LISP => 21 ;
use constant SCLEX_RUBY => 22 ;
use constant SCLEX_EIFFEL => 23 ;
use constant SCLEX_EIFFELKW => 24 ;
use constant SCLEX_TCL => 25 ;
use constant SCLEX_NNCRONTAB => 26 ;
use constant SCLEX_BULLANT => 27 ;
use constant SCLEX_VBSCRIPT => 28 ;
use constant SCLEX_BAAN => 31 ;
use constant SCLEX_MATLAB => 32 ;
use constant SCLEX_SCRIPTOL => 33 ;
use constant SCLEX_ASM => 34 ;
use constant SCLEX_CPPNOCASE => 35 ;
use constant SCLEX_FORTRAN => 36 ;
use constant SCLEX_F77 => 37 ;
use constant SCLEX_CSS => 38 ;
use constant SCLEX_POV => 39 ;
use constant SCLEX_LOUT => 40 ;
use constant SCLEX_ESCRIPT => 41 ;
use constant SCLEX_PS => 42 ;
use constant SCLEX_NSIS => 43 ;
use constant SCLEX_MMIXAL => 44 ;
use constant SCLEX_CLW => 45 ;
use constant SCLEX_CLWNOCASE => 46 ;
use constant SCLEX_LOT => 47 ;
use constant SCLEX_YAML => 48 ;
use constant SCLEX_TEX => 49 ;
use constant SCLEX_METAPOST => 50 ;
use constant SCLEX_POWERBASIC => 51 ;
use constant SCLEX_FORTH => 52 ;
use constant SCLEX_ERLANG => 53 ;
use constant SCLEX_OCTAVE => 54 ;
use constant SCLEX_MSSQL => 55 ;
use constant SCLEX_VERILOG => 56 ;
use constant SCLEX_KIX => 57 ;
use constant SCLEX_GUI4CLI => 58 ;
use constant SCLEX_SPECMAN => 59 ;
use constant SCLEX_AU3 => 60 ;
use constant SCLEX_APDL => 61 ;
use constant SCLEX_BASH => 62 ;
use constant SCLEX_ASN1 => 63 ;
use constant SCLEX_VHDL => 64 ;
use constant SCLEX_CAML => 65 ;
use constant SCLEX_BLITZBASIC => 66 ;
use constant SCLEX_PUREBASIC => 67 ;
use constant SCLEX_HASKELL => 68 ;
use constant SCLEX_PHPSCRIPT => 69 ;
use constant SCLEX_TADS3 => 70 ;
use constant SCLEX_REBOL => 71 ;
use constant SCLEX_SMALLTALK => 72 ;
use constant SCLEX_FLAGSHIP => 73 ;
use constant SCLEX_CSOUND => 74 ;
use constant SCLEX_FREEBASIC => 75 ;
use constant SCLEX_INNOSETUP => 76 ;
use constant SCLEX_OPAL => 77 ;
# When a lexer specifies its language as SCLEX_AUTOMATIC it receives a
# value assigned in sequence from SCLEX_AUTOMATIC+1.
use constant SCLEX_AUTOMATIC => 1000 ;
# Lexical states for SCLEX_PYTHON
# Python=SCLEX_PYTHON SCE_P_
use constant SCE_P_DEFAULT => 0 ;
use constant SCE_P_COMMENTLINE => 1 ;
use constant SCE_P_NUMBER => 2 ;
use constant SCE_P_STRING => 3 ;
use constant SCE_P_CHARACTER => 4 ;
use constant SCE_P_WORD => 5 ;
use constant SCE_P_TRIPLE => 6 ;
use constant SCE_P_TRIPLEDOUBLE => 7 ;
use constant SCE_P_CLASSNAME => 8 ;
use constant SCE_P_DEFNAME => 9 ;
use constant SCE_P_OPERATOR => 10 ;
use constant SCE_P_IDENTIFIER => 11 ;
use constant SCE_P_COMMENTBLOCK => 12 ;
use constant SCE_P_STRINGEOL => 13 ;
use constant SCE_P_WORD2 => 14 ;
use constant SCE_P_DECORATOR => 15 ;
# Lexical states for SCLEX_CPP
# Cpp=SCLEX_CPP SCE_C_
# Pascal=SCLEX_PASCAL SCE_C_
# BullAnt=SCLEX_BULLANT SCE_C_
use constant SCE_C_DEFAULT => 0 ;
use constant SCE_C_COMMENT => 1 ;
use constant SCE_C_COMMENTLINE => 2 ;
use constant SCE_C_COMMENTDOC => 3 ;
use constant SCE_C_NUMBER => 4 ;
use constant SCE_C_WORD => 5 ;
use constant SCE_C_STRING => 6 ;
use constant SCE_C_CHARACTER => 7 ;
use constant SCE_C_UUID => 8 ;
use constant SCE_C_PREPROCESSOR => 9 ;
use constant SCE_C_OPERATOR => 10 ;
use constant SCE_C_IDENTIFIER => 11 ;
use constant SCE_C_STRINGEOL => 12 ;
use constant SCE_C_VERBATIM => 13 ;
use constant SCE_C_REGEX => 14 ;
use constant SCE_C_COMMENTLINEDOC => 15 ;
use constant SCE_C_WORD2 => 16 ;
use constant SCE_C_COMMENTDOCKEYWORD => 17 ;
use constant SCE_C_COMMENTDOCKEYWORDERROR => 18 ;
use constant SCE_C_GLOBALCLASS => 19 ;
# Lexical states for SCLEX_TCL
# TCL=SCLEX_TCL SCE_TCL_
use constant SCE_TCL_DEFAULT => 0 ;
use constant SCE_TCL_COMMENT => 1 ;
use constant SCE_TCL_COMMENTLINE => 2 ;
use constant SCE_TCL_NUMBER => 3 ;
use constant SCE_TCL_WORD_IN_QUOTE => 4 ;
use constant SCE_TCL_IN_QUOTE => 5 ;
use constant SCE_TCL_OPERATOR => 6 ;
use constant SCE_TCL_IDENTIFIER => 7 ;
use constant SCE_TCL_SUBSTITUTION => 8 ;
use constant SCE_TCL_SUB_BRACE => 9 ;
use constant SCE_TCL_MODIFIER => 10 ;
use constant SCE_TCL_EXPAND => 11 ;
use constant SCE_TCL_WORD => 12 ;
use constant SCE_TCL_WORD2 => 13 ;
use constant SCE_TCL_WORD3 => 14 ;
use constant SCE_TCL_WORD4 => 15 ;
use constant SCE_TCL_WORD5 => 16 ;
use constant SCE_TCL_WORD6 => 17 ;
use constant SCE_TCL_WORD7 => 18 ;
use constant SCE_TCL_WORD8 => 19 ;
# Lexical states for SCLEX_HTML, SCLEX_XML
# HTML=SCLEX_HTML SCE_H
# XML=SCLEX_XML SCE_H
# ASP=SCLEX_ASP SCE_H
# PHP=SCLEX_PHP SCE_H
use constant SCE_H_DEFAULT => 0 ;
use constant SCE_H_TAG => 1 ;
use constant SCE_H_TAGUNKNOWN => 2 ;
use constant SCE_H_ATTRIBUTE => 3 ;
use constant SCE_H_ATTRIBUTEUNKNOWN => 4 ;
use constant SCE_H_NUMBER => 5 ;
use constant SCE_H_DOUBLESTRING => 6 ;
use constant SCE_H_SINGLESTRING => 7 ;
use constant SCE_H_OTHER => 8 ;
use constant SCE_H_COMMENT => 9 ;
use constant SCE_H_ENTITY => 10 ;
# XML and ASP
use constant SCE_H_TAGEND => 11 ;
use constant SCE_H_XMLSTART => 12 ;
use constant SCE_H_XMLEND => 13 ;
use constant SCE_H_SCRIPT => 14 ;
use constant SCE_H_ASP => 15 ;
use constant SCE_H_ASPAT => 16 ;
use constant SCE_H_CDATA => 17 ;
use constant SCE_H_QUESTION => 18 ;
# More HTML
use constant SCE_H_VALUE => 19 ;
# X-Code
use constant SCE_H_XCCOMMENT => 20 ;
# SGML
use constant SCE_H_SGML_DEFAULT => 21 ;
use constant SCE_H_SGML_COMMAND => 22 ;
use constant SCE_H_SGML_1ST_PARAM => 23 ;
use constant SCE_H_SGML_DOUBLESTRING => 24 ;
use constant SCE_H_SGML_SIMPLESTRING => 25 ;
use constant SCE_H_SGML_ERROR => 26 ;
use constant SCE_H_SGML_SPECIAL => 27 ;
use constant SCE_H_SGML_ENTITY => 28 ;
use constant SCE_H_SGML_COMMENT => 29 ;
use constant SCE_H_SGML_1ST_PARAM_COMMENT => 30 ;
use constant SCE_H_SGML_BLOCK_DEFAULT => 31 ;
# Embedded Javascript
use constant SCE_HJ_START => 40 ;
use constant SCE_HJ_DEFAULT => 41 ;
use constant SCE_HJ_COMMENT => 42 ;
use constant SCE_HJ_COMMENTLINE => 43 ;
use constant SCE_HJ_COMMENTDOC => 44 ;
use constant SCE_HJ_NUMBER => 45 ;
use constant SCE_HJ_WORD => 46 ;
use constant SCE_HJ_KEYWORD => 47 ;
use constant SCE_HJ_DOUBLESTRING => 48 ;
use constant SCE_HJ_SINGLESTRING => 49 ;
use constant SCE_HJ_SYMBOLS => 50 ;
use constant SCE_HJ_STRINGEOL => 51 ;
use constant SCE_HJ_REGEX => 52 ;
# ASP Javascript
use constant SCE_HJA_START => 55 ;
use constant SCE_HJA_DEFAULT => 56 ;
use constant SCE_HJA_COMMENT => 57 ;
use constant SCE_HJA_COMMENTLINE => 58 ;
use constant SCE_HJA_COMMENTDOC => 59 ;
use constant SCE_HJA_NUMBER => 60 ;
use constant SCE_HJA_WORD => 61 ;
use constant SCE_HJA_KEYWORD => 62 ;
use constant SCE_HJA_DOUBLESTRING => 63 ;
use constant SCE_HJA_SINGLESTRING => 64 ;
use constant SCE_HJA_SYMBOLS => 65 ;
use constant SCE_HJA_STRINGEOL => 66 ;
use constant SCE_HJA_REGEX => 67 ;
# Embedded VBScript
use constant SCE_HB_START => 70 ;
use constant SCE_HB_DEFAULT => 71 ;
use constant SCE_HB_COMMENTLINE => 72 ;
use constant SCE_HB_NUMBER => 73 ;
use constant SCE_HB_WORD => 74 ;
use constant SCE_HB_STRING => 75 ;
use constant SCE_HB_IDENTIFIER => 76 ;
use constant SCE_HB_STRINGEOL => 77 ;
# ASP VBScript
use constant SCE_HBA_START => 80 ;
use constant SCE_HBA_DEFAULT => 81 ;
use constant SCE_HBA_COMMENTLINE => 82 ;
use constant SCE_HBA_NUMBER => 83 ;
use constant SCE_HBA_WORD => 84 ;
use constant SCE_HBA_STRING => 85 ;
use constant SCE_HBA_IDENTIFIER => 86 ;
use constant SCE_HBA_STRINGEOL => 87 ;
# Embedded Python
use constant SCE_HP_START => 90 ;
use constant SCE_HP_DEFAULT => 91 ;
use constant SCE_HP_COMMENTLINE => 92 ;
use constant SCE_HP_NUMBER => 93 ;
use constant SCE_HP_STRING => 94 ;
use constant SCE_HP_CHARACTER => 95 ;
use constant SCE_HP_WORD => 96 ;
use constant SCE_HP_TRIPLE => 97 ;
use constant SCE_HP_TRIPLEDOUBLE => 98 ;
use constant SCE_HP_CLASSNAME => 99 ;
use constant SCE_HP_DEFNAME => 100 ;
use constant SCE_HP_OPERATOR => 101 ;
use constant SCE_HP_IDENTIFIER => 102 ;
# PHP
use constant SCE_HPHP_COMPLEX_VARIABLE => 104 ;
# ASP Python
use constant SCE_HPA_START => 105 ;
use constant SCE_HPA_DEFAULT => 106 ;
use constant SCE_HPA_COMMENTLINE => 107 ;
use constant SCE_HPA_NUMBER => 108 ;
use constant SCE_HPA_STRING => 109 ;
use constant SCE_HPA_CHARACTER => 110 ;
use constant SCE_HPA_WORD => 111 ;
use constant SCE_HPA_TRIPLE => 112 ;
use constant SCE_HPA_TRIPLEDOUBLE => 113 ;
use constant SCE_HPA_CLASSNAME => 114 ;
use constant SCE_HPA_DEFNAME => 115 ;
use constant SCE_HPA_OPERATOR => 116 ;
use constant SCE_HPA_IDENTIFIER => 117 ;
# PHP
use constant SCE_HPHP_DEFAULT => 118 ;
use constant SCE_HPHP_HSTRING => 119 ;
use constant SCE_HPHP_SIMPLESTRING => 120 ;
use constant SCE_HPHP_WORD => 121 ;
use constant SCE_HPHP_NUMBER => 122 ;
use constant SCE_HPHP_VARIABLE => 123 ;
use constant SCE_HPHP_COMMENT => 124 ;
use constant SCE_HPHP_COMMENTLINE => 125 ;
use constant SCE_HPHP_HSTRING_VARIABLE => 126 ;
use constant SCE_HPHP_OPERATOR => 127 ;
# Lexical states for SCLEX_PERL
# Perl=SCLEX_PERL SCE_PL_
use constant SCE_PL_DEFAULT => 0 ;
use constant SCE_PL_ERROR => 1 ;
use constant SCE_PL_COMMENTLINE => 2 ;
use constant SCE_PL_POD => 3 ;
use constant SCE_PL_NUMBER => 4 ;
use constant SCE_PL_WORD => 5 ;
use constant SCE_PL_STRING => 6 ;
use constant SCE_PL_CHARACTER => 7 ;
use constant SCE_PL_PUNCTUATION => 8 ;
use constant SCE_PL_PREPROCESSOR => 9 ;
use constant SCE_PL_OPERATOR => 10 ;
use constant SCE_PL_IDENTIFIER => 11 ;
use constant SCE_PL_SCALAR => 12 ;
use constant SCE_PL_ARRAY => 13 ;
use constant SCE_PL_HASH => 14 ;
use constant SCE_PL_SYMBOLTABLE => 15 ;
use constant SCE_PL_VARIABLE_INDEXER => 16 ;
use constant SCE_PL_REGEX => 17 ;
use constant SCE_PL_REGSUBST => 18 ;
use constant SCE_PL_LONGQUOTE => 19 ;
use constant SCE_PL_BACKTICKS => 20 ;
use constant SCE_PL_DATASECTION => 21 ;
use constant SCE_PL_HERE_DELIM => 22 ;
use constant SCE_PL_HERE_Q => 23 ;
use constant SCE_PL_HERE_QQ => 24 ;
use constant SCE_PL_HERE_QX => 25 ;
use constant SCE_PL_STRING_Q => 26 ;
use constant SCE_PL_STRING_QQ => 27 ;
use constant SCE_PL_STRING_QX => 28 ;
use constant SCE_PL_STRING_QR => 29 ;
use constant SCE_PL_STRING_QW => 30 ;
use constant SCE_PL_POD_VERB => 31 ;
# Lexical states for SCLEX_RUBY
# Ruby=SCLEX_RUBY SCE_RB_
use constant SCE_RB_DEFAULT => 0 ;
use constant SCE_RB_ERROR => 1 ;
use constant SCE_RB_COMMENTLINE => 2 ;
use constant SCE_RB_POD => 3 ;
use constant SCE_RB_NUMBER => 4 ;
use constant SCE_RB_WORD => 5 ;
use constant SCE_RB_STRING => 6 ;
use constant SCE_RB_CHARACTER => 7 ;
use constant SCE_RB_CLASSNAME => 8 ;
use constant SCE_RB_DEFNAME => 9 ;
use constant SCE_RB_OPERATOR => 10 ;
use constant SCE_RB_IDENTIFIER => 11 ;
use constant SCE_RB_REGEX => 12 ;
use constant SCE_RB_GLOBAL => 13 ;
use constant SCE_RB_SYMBOL => 14 ;
use constant SCE_RB_MODULE_NAME => 15 ;
use constant SCE_RB_INSTANCE_VAR => 16 ;
use constant SCE_RB_CLASS_VAR => 17 ;
use constant SCE_RB_BACKTICKS => 18 ;
use constant SCE_RB_DATASECTION => 19 ;
use constant SCE_RB_HERE_DELIM => 20 ;
use constant SCE_RB_HERE_Q => 21 ;
use constant SCE_RB_HERE_QQ => 22 ;
use constant SCE_RB_HERE_QX => 23 ;
use constant SCE_RB_STRING_Q => 24 ;
use constant SCE_RB_STRING_QQ => 25 ;
use constant SCE_RB_STRING_QX => 26 ;
use constant SCE_RB_STRING_QR => 27 ;
use constant SCE_RB_STRING_QW => 28 ;
use constant SCE_RB_WORD_DEMOTED => 29 ;
use constant SCE_RB_STDIN => 30 ;
use constant SCE_RB_STDOUT => 31 ;
use constant SCE_RB_STDERR => 40 ;
use constant SCE_RB_UPPER_BOUND => 41 ;
# Lexical states for SCLEX_VB, SCLEX_VBSCRIPT, SCLEX_POWERBASIC
# VB=SCLEX_VB SCE_B_
# VBScript=SCLEX_VBSCRIPT SCE_B_
# PowerBasic=SCLEX_POWERBASIC SCE_B_
use constant SCE_B_DEFAULT => 0 ;
use constant SCE_B_COMMENT => 1 ;
use constant SCE_B_NUMBER => 2 ;
use constant SCE_B_KEYWORD => 3 ;
use constant SCE_B_STRING => 4 ;
use constant SCE_B_PREPROCESSOR => 5 ;
use constant SCE_B_OPERATOR => 6 ;
use constant SCE_B_IDENTIFIER => 7 ;
use constant SCE_B_DATE => 8 ;
use constant SCE_B_STRINGEOL => 9 ;
use constant SCE_B_KEYWORD2 => 10 ;
use constant SCE_B_KEYWORD3 => 11 ;
use constant SCE_B_KEYWORD4 => 12 ;
use constant SCE_B_CONSTANT => 13 ;
use constant SCE_B_ASM => 14 ;
use constant SCE_B_LABEL => 15 ;
use constant SCE_B_ERROR => 16 ;
use constant SCE_B_HEXNUMBER => 17 ;
use constant SCE_B_BINNUMBER => 18 ;
# Lexical states for SCLEX_PROPERTIES
# Properties=SCLEX_PROPERTIES SCE_PROPS_
use constant SCE_PROPS_DEFAULT => 0 ;
use constant SCE_PROPS_COMMENT => 1 ;
use constant SCE_PROPS_SECTION => 2 ;
use constant SCE_PROPS_ASSIGNMENT => 3 ;
use constant SCE_PROPS_DEFVAL => 4 ;
use constant SCE_PROPS_KEY => 5 ;
# Lexical states for SCLEX_LATEX
# LaTeX=SCLEX_LATEX SCE_L_
use constant SCE_L_DEFAULT => 0 ;
use constant SCE_L_COMMAND => 1 ;
use constant SCE_L_TAG => 2 ;
use constant SCE_L_MATH => 3 ;
use constant SCE_L_COMMENT => 4 ;
# Lexical states for SCLEX_LUA
# Lua=SCLEX_LUA SCE_LUA_
use constant SCE_LUA_DEFAULT => 0 ;
use constant SCE_LUA_COMMENT => 1 ;
use constant SCE_LUA_COMMENTLINE => 2 ;
use constant SCE_LUA_COMMENTDOC => 3 ;
use constant SCE_LUA_NUMBER => 4 ;
use constant SCE_LUA_WORD => 5 ;
use constant SCE_LUA_STRING => 6 ;
use constant SCE_LUA_CHARACTER => 7 ;
use constant SCE_LUA_LITERALSTRING => 8 ;
use constant SCE_LUA_PREPROCESSOR => 9 ;
use constant SCE_LUA_OPERATOR => 10 ;
use constant SCE_LUA_IDENTIFIER => 11 ;
use constant SCE_LUA_STRINGEOL => 12 ;
use constant SCE_LUA_WORD2 => 13 ;
use constant SCE_LUA_WORD3 => 14 ;
use constant SCE_LUA_WORD4 => 15 ;
use constant SCE_LUA_WORD5 => 16 ;
use constant SCE_LUA_WORD6 => 17 ;
use constant SCE_LUA_WORD7 => 18 ;
use constant SCE_LUA_WORD8 => 19 ;
# Lexical states for SCLEX_ERRORLIST
# ErrorList=SCLEX_ERRORLIST SCE_ERR_
use constant SCE_ERR_DEFAULT => 0 ;
use constant SCE_ERR_PYTHON => 1 ;
use constant SCE_ERR_GCC => 2 ;
use constant SCE_ERR_MS => 3 ;
use constant SCE_ERR_CMD => 4 ;
use constant SCE_ERR_BORLAND => 5 ;
use constant SCE_ERR_PERL => 6 ;
use constant SCE_ERR_NET => 7 ;
use constant SCE_ERR_LUA => 8 ;
use constant SCE_ERR_CTAG => 9 ;
use constant SCE_ERR_DIFF_CHANGED => 10 ;
use constant SCE_ERR_DIFF_ADDITION => 11 ;
use constant SCE_ERR_DIFF_DELETION => 12 ;
use constant SCE_ERR_DIFF_MESSAGE => 13 ;
use constant SCE_ERR_PHP => 14 ;
use constant SCE_ERR_ELF => 15 ;
use constant SCE_ERR_IFC => 16 ;
use constant SCE_ERR_IFORT => 17 ;
use constant SCE_ERR_ABSF => 18 ;
use constant SCE_ERR_TIDY => 19 ;
use constant SCE_ERR_JAVA_STACK => 20 ;
# Lexical states for SCLEX_BATCH
# Batch=SCLEX_BATCH SCE_BAT_
use constant SCE_BAT_DEFAULT => 0 ;
use constant SCE_BAT_COMMENT => 1 ;
use constant SCE_BAT_WORD => 2 ;
use constant SCE_BAT_LABEL => 3 ;
use constant SCE_BAT_HIDE => 4 ;
use constant SCE_BAT_COMMAND => 5 ;
use constant SCE_BAT_IDENTIFIER => 6 ;
use constant SCE_BAT_OPERATOR => 7 ;
# Lexical states for SCLEX_MAKEFILE
# MakeFile=SCLEX_MAKEFILE SCE_MAKE_
use constant SCE_MAKE_DEFAULT => 0 ;
use constant SCE_MAKE_COMMENT => 1 ;
use constant SCE_MAKE_PREPROCESSOR => 2 ;
use constant SCE_MAKE_IDENTIFIER => 3 ;
use constant SCE_MAKE_OPERATOR => 4 ;
use constant SCE_MAKE_TARGET => 5 ;
use constant SCE_MAKE_IDEOL => 9 ;
# Lexical states for SCLEX_DIFF
# Diff=SCLEX_DIFF SCE_DIFF_
use constant SCE_DIFF_DEFAULT => 0 ;
use constant SCE_DIFF_COMMENT => 1 ;
use constant SCE_DIFF_COMMAND => 2 ;
use constant SCE_DIFF_HEADER => 3 ;
use constant SCE_DIFF_POSITION => 4 ;
use constant SCE_DIFF_DELETED => 5 ;
use constant SCE_DIFF_ADDED => 6 ;
# Lexical states for SCLEX_CONF (Apache Configuration Files Lexer)
# Conf=SCLEX_CONF SCE_CONF_
use constant SCE_CONF_DEFAULT => 0 ;
use constant SCE_CONF_COMMENT => 1 ;
use constant SCE_CONF_NUMBER => 2 ;
use constant SCE_CONF_IDENTIFIER => 3 ;
use constant SCE_CONF_EXTENSION => 4 ;
use constant SCE_CONF_PARAMETER => 5 ;
use constant SCE_CONF_STRING => 6 ;
use constant SCE_CONF_OPERATOR => 7 ;
use constant SCE_CONF_IP => 8 ;
use constant SCE_CONF_DIRECTIVE => 9 ;
# Lexical states for SCLEX_AVE, Avenue
# Avenue=SCLEX_AVE SCE_AVE_
use constant SCE_AVE_DEFAULT => 0 ;
use constant SCE_AVE_COMMENT => 1 ;
use constant SCE_AVE_NUMBER => 2 ;
use constant SCE_AVE_WORD => 3 ;
use constant SCE_AVE_STRING => 6 ;
use constant SCE_AVE_ENUM => 7 ;
use constant SCE_AVE_STRINGEOL => 8 ;
use constant SCE_AVE_IDENTIFIER => 9 ;
use constant SCE_AVE_OPERATOR => 10 ;
use constant SCE_AVE_WORD1 => 11 ;
use constant SCE_AVE_WORD2 => 12 ;
use constant SCE_AVE_WORD3 => 13 ;
use constant SCE_AVE_WORD4 => 14 ;
use constant SCE_AVE_WORD5 => 15 ;
use constant SCE_AVE_WORD6 => 16 ;
# Lexical states for SCLEX_ADA
# Ada=SCLEX_ADA SCE_ADA_
use constant SCE_ADA_DEFAULT => 0 ;
use constant SCE_ADA_WORD => 1 ;
use constant SCE_ADA_IDENTIFIER => 2 ;
use constant SCE_ADA_NUMBER => 3 ;
use constant SCE_ADA_DELIMITER => 4 ;
use constant SCE_ADA_CHARACTER => 5 ;
use constant SCE_ADA_CHARACTEREOL => 6 ;
use constant SCE_ADA_STRING => 7 ;
use constant SCE_ADA_STRINGEOL => 8 ;
use constant SCE_ADA_LABEL => 9 ;
use constant SCE_ADA_COMMENTLINE => 10 ;
use constant SCE_ADA_ILLEGAL => 11 ;
# Lexical states for SCLEX_BAAN
# Baan=SCLEX_BAAN SCE_BAAN_
use constant SCE_BAAN_DEFAULT => 0 ;
use constant SCE_BAAN_COMMENT => 1 ;
use constant SCE_BAAN_COMMENTDOC => 2 ;
use constant SCE_BAAN_NUMBER => 3 ;
use constant SCE_BAAN_WORD => 4 ;
use constant SCE_BAAN_STRING => 5 ;
use constant SCE_BAAN_PREPROCESSOR => 6 ;
use constant SCE_BAAN_OPERATOR => 7 ;
use constant SCE_BAAN_IDENTIFIER => 8 ;
use constant SCE_BAAN_STRINGEOL => 9 ;
use constant SCE_BAAN_WORD2 => 10 ;
# Lexical states for SCLEX_LISP
# Lisp=SCLEX_LISP SCE_LISP_
use constant SCE_LISP_DEFAULT => 0 ;
use constant SCE_LISP_COMMENT => 1 ;
use constant SCE_LISP_NUMBER => 2 ;
use constant SCE_LISP_KEYWORD => 3 ;
use constant SCE_LISP_KEYWORD_KW => 4 ;
use constant SCE_LISP_SYMBOL => 5 ;
use constant SCE_LISP_STRING => 6 ;
use constant SCE_LISP_STRINGEOL => 8 ;
use constant SCE_LISP_IDENTIFIER => 9 ;
use constant SCE_LISP_OPERATOR => 10 ;
use constant SCE_LISP_SPECIAL => 11 ;
use constant SCE_LISP_MULTI_COMMENT => 12 ;
# Lexical states for SCLEX_EIFFEL and SCLEX_EIFFELKW
# Eiffel=SCLEX_EIFFEL SCE_EIFFEL_
# EiffelKW=SCLEX_EIFFELKW SCE_EIFFEL_
use constant SCE_EIFFEL_DEFAULT => 0 ;
use constant SCE_EIFFEL_COMMENTLINE => 1 ;
use constant SCE_EIFFEL_NUMBER => 2 ;
use constant SCE_EIFFEL_WORD => 3 ;
use constant SCE_EIFFEL_STRING => 4 ;
use constant SCE_EIFFEL_CHARACTER => 5 ;
use constant SCE_EIFFEL_OPERATOR => 6 ;
use constant SCE_EIFFEL_IDENTIFIER => 7 ;
use constant SCE_EIFFEL_STRINGEOL => 8 ;
# Lexical states for SCLEX_NNCRONTAB (nnCron crontab Lexer)
# NNCronTab=SCLEX_NNCRONTAB SCE_NNCRONTAB_
use constant SCE_NNCRONTAB_DEFAULT => 0 ;
use constant SCE_NNCRONTAB_COMMENT => 1 ;
use constant SCE_NNCRONTAB_TASK => 2 ;
use constant SCE_NNCRONTAB_SECTION => 3 ;
use constant SCE_NNCRONTAB_KEYWORD => 4 ;
use constant SCE_NNCRONTAB_MODIFIER => 5 ;
use constant SCE_NNCRONTAB_ASTERISK => 6 ;
use constant SCE_NNCRONTAB_NUMBER => 7 ;
use constant SCE_NNCRONTAB_STRING => 8 ;
use constant SCE_NNCRONTAB_ENVIRONMENT => 9 ;
use constant SCE_NNCRONTAB_IDENTIFIER => 10 ;
# Lexical states for SCLEX_FORTH (Forth Lexer)
# Forth=SCLEX_FORTH SCE_FORTH_
use constant SCE_FORTH_DEFAULT => 0 ;
use constant SCE_FORTH_COMMENT => 1 ;
use constant SCE_FORTH_COMMENT_ML => 2 ;
use constant SCE_FORTH_IDENTIFIER => 3 ;
use constant SCE_FORTH_CONTROL => 4 ;
use constant SCE_FORTH_KEYWORD => 5 ;
use constant SCE_FORTH_DEFWORD => 6 ;
use constant SCE_FORTH_PREWORD1 => 7 ;
use constant SCE_FORTH_PREWORD2 => 8 ;
use constant SCE_FORTH_NUMBER => 9 ;
use constant SCE_FORTH_STRING => 10 ;
use constant SCE_FORTH_LOCALE => 11 ;
# Lexical states for SCLEX_MATLAB
# MatLab=SCLEX_MATLAB SCE_MATLAB_
use constant SCE_MATLAB_DEFAULT => 0 ;
use constant SCE_MATLAB_COMMENT => 1 ;
use constant SCE_MATLAB_COMMAND => 2 ;
use constant SCE_MATLAB_NUMBER => 3 ;
use constant SCE_MATLAB_KEYWORD => 4 ;
# single quoted string
use constant SCE_MATLAB_STRING => 5 ;
use constant SCE_MATLAB_OPERATOR => 6 ;
use constant SCE_MATLAB_IDENTIFIER => 7 ;
use constant SCE_MATLAB_DOUBLEQUOTESTRING => 8 ;
# Lexical states for SCLEX_SCRIPTOL
# Sol=SCLEX_SCRIPTOL SCE_SCRIPTOL_
use constant SCE_SCRIPTOL_DEFAULT => 0 ;
use constant SCE_SCRIPTOL_WHITE => 1 ;
use constant SCE_SCRIPTOL_COMMENTLINE => 2 ;
use constant SCE_SCRIPTOL_PERSISTENT => 3 ;
use constant SCE_SCRIPTOL_CSTYLE => 4 ;
use constant SCE_SCRIPTOL_COMMENTBLOCK => 5 ;
use constant SCE_SCRIPTOL_NUMBER => 6 ;
use constant SCE_SCRIPTOL_STRING => 7 ;
use constant SCE_SCRIPTOL_CHARACTER => 8 ;
use constant SCE_SCRIPTOL_STRINGEOL => 9 ;
use constant SCE_SCRIPTOL_KEYWORD => 10 ;
use constant SCE_SCRIPTOL_OPERATOR => 11 ;
use constant SCE_SCRIPTOL_IDENTIFIER => 12 ;
use constant SCE_SCRIPTOL_TRIPLE => 13 ;
use constant SCE_SCRIPTOL_CLASSNAME => 14 ;
use constant SCE_SCRIPTOL_PREPROCESSOR => 15 ;
# Lexical states for SCLEX_ASM
# Asm=SCLEX_ASM SCE_ASM_
use constant SCE_ASM_DEFAULT => 0 ;
use constant SCE_ASM_COMMENT => 1 ;
use constant SCE_ASM_NUMBER => 2 ;
use constant SCE_ASM_STRING => 3 ;
use constant SCE_ASM_OPERATOR => 4 ;
use constant SCE_ASM_IDENTIFIER => 5 ;
use constant SCE_ASM_CPUINSTRUCTION => 6 ;
use constant SCE_ASM_MATHINSTRUCTION => 7 ;
use constant SCE_ASM_REGISTER => 8 ;
use constant SCE_ASM_DIRECTIVE => 9 ;
use constant SCE_ASM_DIRECTIVEOPERAND => 10 ;
use constant SCE_ASM_COMMENTBLOCK => 11 ;
use constant SCE_ASM_CHARACTER => 12 ;
use constant SCE_ASM_STRINGEOL => 13 ;
use constant SCE_ASM_EXTINSTRUCTION => 14 ;
# Lexical states for SCLEX_FORTRAN
# Fortran=SCLEX_FORTRAN SCE_F_
# F77=SCLEX_F77 SCE_F_
use constant SCE_F_DEFAULT => 0 ;
use constant SCE_F_COMMENT => 1 ;
use constant SCE_F_NUMBER => 2 ;
use constant SCE_F_STRING1 => 3 ;
use constant SCE_F_STRING2 => 4 ;
use constant SCE_F_STRINGEOL => 5 ;
use constant SCE_F_OPERATOR => 6 ;
use constant SCE_F_IDENTIFIER => 7 ;
use constant SCE_F_WORD => 8 ;
use constant SCE_F_WORD2 => 9 ;
use constant SCE_F_WORD3 => 10 ;
use constant SCE_F_PREPROCESSOR => 11 ;
use constant SCE_F_OPERATOR2 => 12 ;
use constant SCE_F_LABEL => 13 ;
use constant SCE_F_CONTINUATION => 14 ;
# Lexical states for SCLEX_CSS
# CSS=SCLEX_CSS SCE_CSS_
use constant SCE_CSS_DEFAULT => 0 ;
use constant SCE_CSS_TAG => 1 ;
use constant SCE_CSS_CLASS => 2 ;
use constant SCE_CSS_PSEUDOCLASS => 3 ;
use constant SCE_CSS_UNKNOWN_PSEUDOCLASS => 4 ;
use constant SCE_CSS_OPERATOR => 5 ;
use constant SCE_CSS_IDENTIFIER => 6 ;
use constant SCE_CSS_UNKNOWN_IDENTIFIER => 7 ;
use constant SCE_CSS_VALUE => 8 ;
use constant SCE_CSS_COMMENT => 9 ;
use constant SCE_CSS_ID => 10 ;
use constant SCE_CSS_IMPORTANT => 11 ;
use constant SCE_CSS_DIRECTIVE => 12 ;
use constant SCE_CSS_DOUBLESTRING => 13 ;
use constant SCE_CSS_SINGLESTRING => 14 ;
use constant SCE_CSS_IDENTIFIER2 => 15 ;
use constant SCE_CSS_ATTRIBUTE => 16 ;
# Lexical states for SCLEX_POV
# POV=SCLEX_POV SCE_POV_
use constant SCE_POV_DEFAULT => 0 ;
use constant SCE_POV_COMMENT => 1 ;
use constant SCE_POV_COMMENTLINE => 2 ;
use constant SCE_POV_NUMBER => 3 ;
use constant SCE_POV_OPERATOR => 4 ;
use constant SCE_POV_IDENTIFIER => 5 ;
use constant SCE_POV_STRING => 6 ;
use constant SCE_POV_STRINGEOL => 7 ;
use constant SCE_POV_DIRECTIVE => 8 ;
use constant SCE_POV_BADDIRECTIVE => 9 ;
use constant SCE_POV_WORD2 => 10 ;
use constant SCE_POV_WORD3 => 11 ;
use constant SCE_POV_WORD4 => 12 ;
use constant SCE_POV_WORD5 => 13 ;
use constant SCE_POV_WORD6 => 14 ;
use constant SCE_POV_WORD7 => 15 ;
use constant SCE_POV_WORD8 => 16 ;
# Lexical states for SCLEX_LOUT
# LOUT=SCLEX_LOUT SCE_LOUT_
use constant SCE_LOUT_DEFAULT => 0 ;
use constant SCE_LOUT_COMMENT => 1 ;
use constant SCE_LOUT_NUMBER => 2 ;
use constant SCE_LOUT_WORD => 3 ;
use constant SCE_LOUT_WORD2 => 4 ;
use constant SCE_LOUT_WORD3 => 5 ;
use constant SCE_LOUT_WORD4 => 6 ;
use constant SCE_LOUT_STRING => 7 ;
use constant SCE_LOUT_OPERATOR => 8 ;
use constant SCE_LOUT_IDENTIFIER => 9 ;
use constant SCE_LOUT_STRINGEOL => 10 ;
# Lexical states for SCLEX_ESCRIPT
# ESCRIPT=SCLEX_ESCRIPT SCE_ESCRIPT_
use constant SCE_ESCRIPT_DEFAULT => 0 ;
use constant SCE_ESCRIPT_COMMENT => 1 ;
use constant SCE_ESCRIPT_COMMENTLINE => 2 ;
use constant SCE_ESCRIPT_COMMENTDOC => 3 ;
use constant SCE_ESCRIPT_NUMBER => 4 ;
use constant SCE_ESCRIPT_WORD => 5 ;
use constant SCE_ESCRIPT_STRING => 6 ;
use constant SCE_ESCRIPT_OPERATOR => 7 ;
use constant SCE_ESCRIPT_IDENTIFIER => 8 ;
use constant SCE_ESCRIPT_BRACE => 9 ;
use constant SCE_ESCRIPT_WORD2 => 10 ;
use constant SCE_ESCRIPT_WORD3 => 11 ;
# Lexical states for SCLEX_PS
# PS=SCLEX_PS SCE_PS_
use constant SCE_PS_DEFAULT => 0 ;
use constant SCE_PS_COMMENT => 1 ;
use constant SCE_PS_DSC_COMMENT => 2 ;
use constant SCE_PS_DSC_VALUE => 3 ;
use constant SCE_PS_NUMBER => 4 ;
use constant SCE_PS_NAME => 5 ;
use constant SCE_PS_KEYWORD => 6 ;
use constant SCE_PS_LITERAL => 7 ;
use constant SCE_PS_IMMEVAL => 8 ;
use constant SCE_PS_PAREN_ARRAY => 9 ;
use constant SCE_PS_PAREN_DICT => 10 ;
use constant SCE_PS_PAREN_PROC => 11 ;
use constant SCE_PS_TEXT => 12 ;
use constant SCE_PS_HEXSTRING => 13 ;
use constant SCE_PS_BASE85STRING => 14 ;
use constant SCE_PS_BADSTRINGCHAR => 15 ;
# Lexical states for SCLEX_NSIS
# NSIS=SCLEX_NSIS SCE_NSIS_
use constant SCE_NSIS_DEFAULT => 0 ;
use constant SCE_NSIS_COMMENT => 1 ;
use constant SCE_NSIS_STRINGDQ => 2 ;
use constant SCE_NSIS_STRINGLQ => 3 ;
use constant SCE_NSIS_STRINGRQ => 4 ;
use constant SCE_NSIS_FUNCTION => 5 ;
use constant SCE_NSIS_VARIABLE => 6 ;
use constant SCE_NSIS_LABEL => 7 ;
use constant SCE_NSIS_USERDEFINED => 8 ;
use constant SCE_NSIS_SECTIONDEF => 9 ;
use constant SCE_NSIS_SUBSECTIONDEF => 10 ;
use constant SCE_NSIS_IFDEFINEDEF => 11 ;
use constant SCE_NSIS_MACRODEF => 12 ;
use constant SCE_NSIS_STRINGVAR => 13 ;
use constant SCE_NSIS_NUMBER => 14 ;
use constant SCE_NSIS_SECTIONGROUP => 15 ;
use constant SCE_NSIS_PAGEEX => 16 ;
use constant SCE_NSIS_FUNCTIONDEF => 17 ;
use constant SCE_NSIS_COMMENTBOX => 18 ;
# Lexical states for SCLEX_MMIXAL
# MMIXAL=SCLEX_MMIXAL SCE_MMIXAL_
use constant SCE_MMIXAL_LEADWS => 0 ;
use constant SCE_MMIXAL_COMMENT => 1 ;
use constant SCE_MMIXAL_LABEL => 2 ;
use constant SCE_MMIXAL_OPCODE => 3 ;
use constant SCE_MMIXAL_OPCODE_PRE => 4 ;
use constant SCE_MMIXAL_OPCODE_VALID => 5 ;
use constant SCE_MMIXAL_OPCODE_UNKNOWN => 6 ;
use constant SCE_MMIXAL_OPCODE_POST => 7 ;
use constant SCE_MMIXAL_OPERANDS => 8 ;
use constant SCE_MMIXAL_NUMBER => 9 ;
use constant SCE_MMIXAL_REF => 10 ;
use constant SCE_MMIXAL_CHAR => 11 ;
use constant SCE_MMIXAL_STRING => 12 ;
use constant SCE_MMIXAL_REGISTER => 13 ;
use constant SCE_MMIXAL_HEX => 14 ;
use constant SCE_MMIXAL_OPERATOR => 15 ;
use constant SCE_MMIXAL_SYMBOL => 16 ;
use constant SCE_MMIXAL_INCLUDE => 17 ;
# Lexical states for SCLEX_CLW
# Clarion=SCLEX_CLW SCE_CLW_
use constant SCE_CLW_DEFAULT => 0 ;
use constant SCE_CLW_LABEL => 1 ;
use constant SCE_CLW_COMMENT => 2 ;
use constant SCE_CLW_STRING => 3 ;
use constant SCE_CLW_USER_IDENTIFIER => 4 ;
use constant SCE_CLW_INTEGER_CONSTANT => 5 ;
use constant SCE_CLW_REAL_CONSTANT => 6 ;
use constant SCE_CLW_PICTURE_STRING => 7 ;
use constant SCE_CLW_KEYWORD => 8 ;
use constant SCE_CLW_COMPILER_DIRECTIVE => 9 ;
use constant SCE_CLW_RUNTIME_EXPRESSIONS => 10 ;
use constant SCE_CLW_BUILTIN_PROCEDURES_FUNCTION => 11 ;
use constant SCE_CLW_STRUCTURE_DATA_TYPE => 12 ;
use constant SCE_CLW_ATTRIBUTE => 13 ;
use constant SCE_CLW_STANDARD_EQUATE => 14 ;
use constant SCE_CLW_ERROR => 15 ;
use constant SCE_CLW_DEPRECATED => 16 ;
# Lexical states for SCLEX_LOT
# LOT=SCLEX_LOT SCE_LOT_
use constant SCE_LOT_DEFAULT => 0 ;
use constant SCE_LOT_HEADER => 1 ;
use constant SCE_LOT_BREAK => 2 ;
use constant SCE_LOT_SET => 3 ;
use constant SCE_LOT_PASS => 4 ;
use constant SCE_LOT_FAIL => 5 ;
use constant SCE_LOT_ABORT => 6 ;
# Lexical states for SCLEX_YAML
# YAML=SCLEX_YAML SCE_YAML_
use constant SCE_YAML_DEFAULT => 0 ;
use constant SCE_YAML_COMMENT => 1 ;
use constant SCE_YAML_IDENTIFIER => 2 ;
use constant SCE_YAML_KEYWORD => 3 ;
use constant SCE_YAML_NUMBER => 4 ;
use constant SCE_YAML_REFERENCE => 5 ;
use constant SCE_YAML_DOCUMENT => 6 ;
use constant SCE_YAML_TEXT => 7 ;
use constant SCE_YAML_ERROR => 8 ;
# Lexical states for SCLEX_TEX
# TeX=SCLEX_TEX SCE_TEX_
use constant SCE_TEX_DEFAULT => 0 ;
use constant SCE_TEX_SPECIAL => 1 ;
use constant SCE_TEX_GROUP => 2 ;
use constant SCE_TEX_SYMBOL => 3 ;
use constant SCE_TEX_COMMAND => 4 ;
use constant SCE_TEX_TEXT => 5 ;
# Metapost=SCLEX_METAPOST SCE_METAPOST_
use constant SCE_METAPOST_DEFAULT => 0 ;
use constant SCE_METAPOST_SPECIAL => 1 ;
use constant SCE_METAPOST_GROUP => 2 ;
use constant SCE_METAPOST_SYMBOL => 3 ;
use constant SCE_METAPOST_COMMAND => 4 ;
use constant SCE_METAPOST_TEXT => 5 ;
use constant SCE_METAPOST_EXTRA => 6 ;
# Lexical states for SCLEX_ERLANG
# Erlang=SCLEX_ERLANG SCE_ERLANG_
use constant SCE_ERLANG_DEFAULT => 0 ;
use constant SCE_ERLANG_COMMENT => 1 ;
use constant SCE_ERLANG_VARIABLE => 2 ;
use constant SCE_ERLANG_NUMBER => 3 ;
use constant SCE_ERLANG_KEYWORD => 4 ;
use constant SCE_ERLANG_STRING => 5 ;
use constant SCE_ERLANG_OPERATOR => 6 ;
use constant SCE_ERLANG_ATOM => 7 ;
use constant SCE_ERLANG_FUNCTION_NAME => 8 ;
use constant SCE_ERLANG_CHARACTER => 9 ;
use constant SCE_ERLANG_MACRO => 10 ;
use constant SCE_ERLANG_RECORD => 11 ;
use constant SCE_ERLANG_SEPARATOR => 12 ;
use constant SCE_ERLANG_NODE_NAME => 13 ;
use constant SCE_ERLANG_UNKNOWN => 31 ;
# Lexical states for SCLEX_OCTAVE are identical to MatLab
# Octave=SCLEX_OCTAVE SCE_MATLAB_
# Lexical states for SCLEX_MSSQL
# MSSQL=SCLEX_MSSQL SCE_MSSQL_
use constant SCE_MSSQL_DEFAULT => 0 ;
use constant SCE_MSSQL_COMMENT => 1 ;
use constant SCE_MSSQL_LINE_COMMENT => 2 ;
use constant SCE_MSSQL_NUMBER => 3 ;
use constant SCE_MSSQL_STRING => 4 ;
use constant SCE_MSSQL_OPERATOR => 5 ;
use constant SCE_MSSQL_IDENTIFIER => 6 ;
use constant SCE_MSSQL_VARIABLE => 7 ;
use constant SCE_MSSQL_COLUMN_NAME => 8 ;
use constant SCE_MSSQL_STATEMENT => 9 ;
use constant SCE_MSSQL_DATATYPE => 10 ;
use constant SCE_MSSQL_SYSTABLE => 11 ;
use constant SCE_MSSQL_GLOBAL_VARIABLE => 12 ;
use constant SCE_MSSQL_FUNCTION => 13 ;
use constant SCE_MSSQL_STORED_PROCEDURE => 14 ;
use constant SCE_MSSQL_DEFAULT_PREF_DATATYPE => 15 ;
use constant SCE_MSSQL_COLUMN_NAME_2 => 16 ;
# Lexical states for SCLEX_VERILOG
# Verilog=SCLEX_VERILOG SCE_V_
use constant SCE_V_DEFAULT => 0 ;
use constant SCE_V_COMMENT => 1 ;
use constant SCE_V_COMMENTLINE => 2 ;
use constant SCE_V_COMMENTLINEBANG => 3 ;
use constant SCE_V_NUMBER => 4 ;
use constant SCE_V_WORD => 5 ;
use constant SCE_V_STRING => 6 ;
use constant SCE_V_WORD2 => 7 ;
use constant SCE_V_WORD3 => 8 ;
use constant SCE_V_PREPROCESSOR => 9 ;
use constant SCE_V_OPERATOR => 10 ;
use constant SCE_V_IDENTIFIER => 11 ;
use constant SCE_V_STRINGEOL => 12 ;
use constant SCE_V_USER => 19 ;
# Lexical states for SCLEX_KIX
# Kix=SCLEX_KIX SCE_KIX_
use constant SCE_KIX_DEFAULT => 0 ;
use constant SCE_KIX_COMMENT => 1 ;
use constant SCE_KIX_STRING1 => 2 ;
use constant SCE_KIX_STRING2 => 3 ;
use constant SCE_KIX_NUMBER => 4 ;
use constant SCE_KIX_VAR => 5 ;
use constant SCE_KIX_MACRO => 6 ;
use constant SCE_KIX_KEYWORD => 7 ;
use constant SCE_KIX_FUNCTIONS => 8 ;
use constant SCE_KIX_OPERATOR => 9 ;
use constant SCE_KIX_IDENTIFIER => 31 ;
# Lexical states for SCLEX_GUI4CLI
use constant SCE_GC_DEFAULT => 0 ;
use constant SCE_GC_COMMENTLINE => 1 ;
use constant SCE_GC_COMMENTBLOCK => 2 ;
use constant SCE_GC_GLOBAL => 3 ;
use constant SCE_GC_EVENT => 4 ;
use constant SCE_GC_ATTRIBUTE => 5 ;
use constant SCE_GC_CONTROL => 6 ;
use constant SCE_GC_COMMAND => 7 ;
use constant SCE_GC_STRING => 8 ;
use constant SCE_GC_OPERATOR => 9 ;
# Lexical states for SCLEX_SPECMAN
# Specman=SCLEX_SPECMAN SCE_SN_
use constant SCE_SN_DEFAULT => 0 ;
use constant SCE_SN_CODE => 1 ;
use constant SCE_SN_COMMENTLINE => 2 ;
use constant SCE_SN_COMMENTLINEBANG => 3 ;
use constant SCE_SN_NUMBER => 4 ;
use constant SCE_SN_WORD => 5 ;
use constant SCE_SN_STRING => 6 ;
use constant SCE_SN_WORD2 => 7 ;
use constant SCE_SN_WORD3 => 8 ;
use constant SCE_SN_PREPROCESSOR => 9 ;
use constant SCE_SN_OPERATOR => 10 ;
use constant SCE_SN_IDENTIFIER => 11 ;
use constant SCE_SN_STRINGEOL => 12 ;
use constant SCE_SN_REGEXTAG => 13 ;
use constant SCE_SN_SIGNAL => 14 ;
use constant SCE_SN_USER => 19 ;
# Lexical states for SCLEX_AU3
# Au3=SCLEX_AU3 SCE_AU3_
use constant SCE_AU3_DEFAULT => 0 ;
use constant SCE_AU3_COMMENT => 1 ;
use constant SCE_AU3_COMMENTBLOCK => 2 ;
use constant SCE_AU3_NUMBER => 3 ;
use constant SCE_AU3_FUNCTION => 4 ;
use constant SCE_AU3_KEYWORD => 5 ;
use constant SCE_AU3_MACRO => 6 ;
use constant SCE_AU3_STRING => 7 ;
use constant SCE_AU3_OPERATOR => 8 ;
use constant SCE_AU3_VARIABLE => 9 ;
use constant SCE_AU3_SENT => 10 ;
use constant SCE_AU3_PREPROCESSOR => 11 ;
use constant SCE_AU3_SPECIAL => 12 ;
use constant SCE_AU3_EXPAND => 13 ;
use constant SCE_AU3_COMOBJ => 14 ;
# Lexical states for SCLEX_APDL
# APDL=SCLEX_APDL SCE_APDL_
use constant SCE_APDL_DEFAULT => 0 ;
use constant SCE_APDL_COMMENT => 1 ;
use constant SCE_APDL_COMMENTBLOCK => 2 ;
use constant SCE_APDL_NUMBER => 3 ;
use constant SCE_APDL_STRING => 4 ;
use constant SCE_APDL_OPERATOR => 5 ;
use constant SCE_APDL_WORD => 6 ;
use constant SCE_APDL_PROCESSOR => 7 ;
use constant SCE_APDL_COMMAND => 8 ;
use constant SCE_APDL_SLASHCOMMAND => 9 ;
use constant SCE_APDL_STARCOMMAND => 10 ;
use constant SCE_APDL_ARGUMENT => 11 ;
use constant SCE_APDL_FUNCTION => 12 ;
# Lexical states for SCLEX_BASH
# Bash=SCLEX_BASH SCE_SH_
use constant SCE_SH_DEFAULT => 0 ;
use constant SCE_SH_ERROR => 1 ;
use constant SCE_SH_COMMENTLINE => 2 ;
use constant SCE_SH_NUMBER => 3 ;
use constant SCE_SH_WORD => 4 ;
use constant SCE_SH_STRING => 5 ;
use constant SCE_SH_CHARACTER => 6 ;
use constant SCE_SH_OPERATOR => 7 ;
use constant SCE_SH_IDENTIFIER => 8 ;
use constant SCE_SH_SCALAR => 9 ;
use constant SCE_SH_PARAM => 10 ;
use constant SCE_SH_BACKTICKS => 11 ;
use constant SCE_SH_HERE_DELIM => 12 ;
use constant SCE_SH_HERE_Q => 13 ;
# Lexical states for SCLEX_ASN1
# Asn1=SCLEX_ASN1 SCE_ASN1_
use constant SCE_ASN1_DEFAULT => 0 ;
use constant SCE_ASN1_COMMENT => 1 ;
use constant SCE_ASN1_IDENTIFIER => 2 ;
use constant SCE_ASN1_STRING => 3 ;
use constant SCE_ASN1_OID => 4 ;
use constant SCE_ASN1_SCALAR => 5 ;
use constant SCE_ASN1_KEYWORD => 6 ;
use constant SCE_ASN1_ATTRIBUTE => 7 ;
use constant SCE_ASN1_DESCRIPTOR => 8 ;
use constant SCE_ASN1_TYPE => 9 ;
use constant SCE_ASN1_OPERATOR => 10 ;
# Lexical states for SCLEX_VHDL
# VHDL=SCLEX_VHDL SCE_VHDL_
use constant SCE_VHDL_DEFAULT => 0 ;
use constant SCE_VHDL_COMMENT => 1 ;
use constant SCE_VHDL_COMMENTLINEBANG => 2 ;
use constant SCE_VHDL_NUMBER => 3 ;
use constant SCE_VHDL_STRING => 4 ;
use constant SCE_VHDL_OPERATOR => 5 ;
use constant SCE_VHDL_IDENTIFIER => 6 ;
use constant SCE_VHDL_STRINGEOL => 7 ;
use constant SCE_VHDL_KEYWORD => 8 ;
use constant SCE_VHDL_STDOPERATOR => 9 ;
use constant SCE_VHDL_ATTRIBUTE => 10 ;
use constant SCE_VHDL_STDFUNCTION => 11 ;
use constant SCE_VHDL_STDPACKAGE => 12 ;
use constant SCE_VHDL_STDTYPE => 13 ;
use constant SCE_VHDL_USERWORD => 14 ;
# Lexical states for SCLEX_CAML
# Caml=SCLEX_CAML SCE_CAML_
use constant SCE_CAML_DEFAULT => 0 ;
use constant SCE_CAML_IDENTIFIER => 1 ;
use constant SCE_CAML_TAGNAME => 2 ;
use constant SCE_CAML_KEYWORD => 3 ;
use constant SCE_CAML_KEYWORD2 => 4 ;
use constant SCE_CAML_KEYWORD3 => 5 ;
use constant SCE_CAML_LINENUM => 6 ;
use constant SCE_CAML_OPERATOR => 7 ;
use constant SCE_CAML_NUMBER => 8 ;
use constant SCE_CAML_CHAR => 9 ;
use constant SCE_CAML_STRING => 11 ;
use constant SCE_CAML_COMMENT => 12 ;
use constant SCE_CAML_COMMENT1 => 13 ;
use constant SCE_CAML_COMMENT2 => 14 ;
use constant SCE_CAML_COMMENT3 => 15 ;
# Lexical states for SCLEX_HASKELL
# Haskell=SCLEX_HASKELL SCE_HA_
use constant SCE_HA_DEFAULT => 0 ;
use constant SCE_HA_IDENTIFIER => 1 ;
use constant SCE_HA_KEYWORD => 2 ;
use constant SCE_HA_NUMBER => 3 ;
use constant SCE_HA_STRING => 4 ;
use constant SCE_HA_CHARACTER => 5 ;
use constant SCE_HA_CLASS => 6 ;
use constant SCE_HA_MODULE => 7 ;
use constant SCE_HA_CAPITAL => 8 ;
use constant SCE_HA_DATA => 9 ;
use constant SCE_HA_IMPORT => 10 ;
use constant SCE_HA_OPERATOR => 11 ;
use constant SCE_HA_INSTANCE => 12 ;
use constant SCE_HA_COMMENTLINE => 13 ;
use constant SCE_HA_COMMENTBLOCK => 14 ;
use constant SCE_HA_COMMENTBLOCK2 => 15 ;
use constant SCE_HA_COMMENTBLOCK3 => 16 ;
# Lexical states of SCLEX_TADS3
# TADS3=SCLEX_TADS3 SCE_T3_
use constant SCE_T3_DEFAULT => 0 ;
use constant SCE_T3_X_DEFAULT => 1 ;
use constant SCE_T3_PREPROCESSOR => 2 ;
use constant SCE_T3_BLOCK_COMMENT => 3 ;
use constant SCE_T3_LINE_COMMENT => 4 ;
use constant SCE_T3_OPERATOR => 5 ;
use constant SCE_T3_KEYWORD => 6 ;
use constant SCE_T3_NUMBER => 7 ;
use constant SCE_T3_IDENTIFIER => 8 ;
use constant SCE_T3_S_STRING => 9 ;
use constant SCE_T3_D_STRING => 10 ;
use constant SCE_T3_X_STRING => 11 ;
use constant SCE_T3_LIB_DIRECTIVE => 12 ;
use constant SCE_T3_MSG_PARAM => 13 ;
use constant SCE_T3_HTML_TAG => 14 ;
use constant SCE_T3_HTML_DEFAULT => 15 ;
use constant SCE_T3_HTML_STRING => 16 ;
use constant SCE_T3_USER1 => 17 ;
use constant SCE_T3_USER2 => 18 ;
use constant SCE_T3_USER3 => 19 ;
# Lexical states for SCLEX_REBOL
# Rebol=SCLEX_REBOL SCE_REBOL_
use constant SCE_REBOL_DEFAULT => 0 ;
use constant SCE_REBOL_COMMENTLINE => 1 ;
use constant SCE_REBOL_COMMENTBLOCK => 2 ;
use constant SCE_REBOL_PREFACE => 3 ;
use constant SCE_REBOL_OPERATOR => 4 ;
use constant SCE_REBOL_CHARACTER => 5 ;
use constant SCE_REBOL_QUOTEDSTRING => 6 ;
use constant SCE_REBOL_BRACEDSTRING => 7 ;
use constant SCE_REBOL_NUMBER => 8 ;
use constant SCE_REBOL_PAIR => 9 ;
use constant SCE_REBOL_TUPLE => 10 ;
use constant SCE_REBOL_BINARY => 11 ;
use constant SCE_REBOL_MONEY => 12 ;
use constant SCE_REBOL_ISSUE => 13 ;
use constant SCE_REBOL_TAG => 14 ;
use constant SCE_REBOL_FILE => 15 ;
use constant SCE_REBOL_EMAIL => 16 ;
use constant SCE_REBOL_URL => 17 ;
use constant SCE_REBOL_DATE => 18 ;
use constant SCE_REBOL_TIME => 19 ;
use constant SCE_REBOL_IDENTIFIER => 20 ;
use constant SCE_REBOL_WORD => 21 ;
use constant SCE_REBOL_WORD2 => 22 ;
use constant SCE_REBOL_WORD3 => 23 ;
use constant SCE_REBOL_WORD4 => 24 ;
use constant SCE_REBOL_WORD5 => 25 ;
use constant SCE_REBOL_WORD6 => 26 ;
use constant SCE_REBOL_WORD7 => 27 ;
use constant SCE_REBOL_WORD8 => 28 ;
# Lexical states for SCLEX_SQL
# SQL=SCLEX_SQL SCE_SQL_
use constant SCE_SQL_DEFAULT => 0 ;
use constant SCE_SQL_COMMENT => 1 ;
use constant SCE_SQL_COMMENTLINE => 2 ;
use constant SCE_SQL_COMMENTDOC => 3 ;
use constant SCE_SQL_NUMBER => 4 ;
use constant SCE_SQL_WORD => 5 ;
use constant SCE_SQL_STRING => 6 ;
use constant SCE_SQL_CHARACTER => 7 ;
use constant SCE_SQL_SQLPLUS => 8 ;
use constant SCE_SQL_SQLPLUS_PROMPT => 9 ;
use constant SCE_SQL_OPERATOR => 10 ;
use constant SCE_SQL_IDENTIFIER => 11 ;
use constant SCE_SQL_SQLPLUS_COMMENT => 13 ;
use constant SCE_SQL_COMMENTLINEDOC => 15 ;
use constant SCE_SQL_WORD2 => 16 ;
use constant SCE_SQL_COMMENTDOCKEYWORD => 17 ;
use constant SCE_SQL_COMMENTDOCKEYWORDERROR => 18 ;
use constant SCE_SQL_USER1 => 19 ;
use constant SCE_SQL_USER2 => 20 ;
use constant SCE_SQL_USER3 => 21 ;
use constant SCE_SQL_USER4 => 22 ;
use constant SCE_SQL_QUOTEDIDENTIFIER => 23 ;
# Lexical states for SCLEX_SMALLTALK
# Smalltalk=SCLEX_SMALLTALK SCE_ST_
use constant SCE_ST_DEFAULT => 0 ;
use constant SCE_ST_STRING => 1 ;
use constant SCE_ST_NUMBER => 2 ;
use constant SCE_ST_COMMENT => 3 ;
use constant SCE_ST_SYMBOL => 4 ;
use constant SCE_ST_BINARY => 5 ;
use constant SCE_ST_BOOL => 6 ;
use constant SCE_ST_SELF => 7 ;
use constant SCE_ST_SUPER => 8 ;
use constant SCE_ST_NIL => 9 ;
use constant SCE_ST_GLOBAL => 10 ;
use constant SCE_ST_RETURN => 11 ;
use constant SCE_ST_SPECIAL => 12 ;
use constant SCE_ST_KWSEND => 13 ;
use constant SCE_ST_ASSIGN => 14 ;
use constant SCE_ST_CHARACTER => 15 ;
use constant SCE_ST_SPEC_SEL => 16 ;
# Lexical states for SCLEX_FLAGSHIP (clipper)
# FlagShip=SCLEX_FLAGSHIP SCE_B_
use constant SCE_FS_DEFAULT => 0 ;
use constant SCE_FS_COMMENT => 1 ;
use constant SCE_FS_COMMENTLINE => 2 ;
use constant SCE_FS_COMMENTDOC => 3 ;
use constant SCE_FS_COMMENTLINEDOC => 4 ;
use constant SCE_FS_COMMENTDOCKEYWORD => 5 ;
use constant SCE_FS_COMMENTDOCKEYWORDERROR => 6 ;
use constant SCE_FS_KEYWORD => 7 ;
use constant SCE_FS_KEYWORD2 => 8 ;
use constant SCE_FS_KEYWORD3 => 9 ;
use constant SCE_FS_KEYWORD4 => 10 ;
use constant SCE_FS_NUMBER => 11 ;
use constant SCE_FS_STRING => 12 ;
use constant SCE_FS_PREPROCESSOR => 13 ;
use constant SCE_FS_OPERATOR => 14 ;
use constant SCE_FS_IDENTIFIER => 15 ;
use constant SCE_FS_DATE => 16 ;
use constant SCE_FS_STRINGEOL => 17 ;
use constant SCE_FS_CONSTANT => 18 ;
use constant SCE_FS_ASM => 19 ;
use constant SCE_FS_LABEL => 20 ;
use constant SCE_FS_ERROR => 21 ;
use constant SCE_FS_HEXNUMBER => 22 ;
use constant SCE_FS_BINNUMBER => 23 ;
# Lexical states for SCLEX_CSOUND
# Csound=SCLEX_CSOUND SCE_CSOUND_
use constant SCE_CSOUND_DEFAULT => 0 ;
use constant SCE_CSOUND_COMMENT => 1 ;
use constant SCE_CSOUND_NUMBER => 2 ;
use constant SCE_CSOUND_OPERATOR => 3 ;
use constant SCE_CSOUND_INSTR => 4 ;
use constant SCE_CSOUND_IDENTIFIER => 5 ;
use constant SCE_CSOUND_OPCODE => 6 ;
use constant SCE_CSOUND_HEADERSTMT => 7 ;
use constant SCE_CSOUND_USERKEYWORD => 8 ;
use constant SCE_CSOUND_COMMENTBLOCK => 9 ;
use constant SCE_CSOUND_PARAM => 10 ;
use constant SCE_CSOUND_ARATE_VAR => 11 ;
use constant SCE_CSOUND_KRATE_VAR => 12 ;
use constant SCE_CSOUND_IRATE_VAR => 13 ;
use constant SCE_CSOUND_GLOBAL_VAR => 14 ;
use constant SCE_CSOUND_STRINGEOL => 15 ;
# Lexical states for SCLEX_INNOSETUP
# Inno=SCLEX_INNOSETUP SCE_INNO_
use constant SCE_INNO_DEFAULT => 0 ;
use constant SCE_INNO_COMMENT => 1 ;
use constant SCE_INNO_KEYWORD => 2 ;
use constant SCE_INNO_PARAMETER => 3 ;
use constant SCE_INNO_SECTION => 4 ;
use constant SCE_INNO_PREPROC => 5 ;
use constant SCE_INNO_PREPROC_INLINE => 6 ;
use constant SCE_INNO_COMMENT_PASCAL => 7 ;
use constant SCE_INNO_KEYWORD_PASCAL => 8 ;
use constant SCE_INNO_KEYWORD_USER => 9 ;
use constant SCE_INNO_STRING_DOUBLE => 10 ;
use constant SCE_INNO_STRING_SINGLE => 11 ;
use constant SCE_INNO_IDENTIFIER => 12 ;
# Lexical states for SCLEX_OPAL
# Opal=SCLEX_OPAL SCE_OPAL_
use constant SCE_OPAL_SPACE => 0 ;
use constant SCE_OPAL_COMMENT_BLOCK => 1 ;
use constant SCE_OPAL_COMMENT_LINE => 2 ;
use constant SCE_OPAL_INTEGER => 3 ;
use constant SCE_OPAL_KEYWORD => 4 ;
use constant SCE_OPAL_SORT => 5 ;
use constant SCE_OPAL_STRING => 6 ;
use constant SCE_OPAL_PAR => 7 ;
use constant SCE_OPAL_BOOL_CONST => 8 ;
use constant SCE_OPAL_DEFAULT => 32 ;
# Events
# GTK+ Specific to work around focus and accelerator problems:
# CARET_POLICY changed in 1.47
sub SetCaretPolicy {
  my ($self, $caretPolicy, $caretSlop) = @_;
  return $self->SendMessage (2369, $caretPolicy, $caretSlop);
}
use constant CARET_CENTER => 0x02 ;
use constant CARET_XEVEN => 0x08 ;
use constant CARET_XJUMPS => 0x10 ;
# The old name for SCN_UPDATEUI
use constant SCN_CHECKBRACE => 2007 ;
# SCLEX_HTML should be used in preference to these.
use constant SCLEX_ASP => 29 ;
use constant SCLEX_PHP => 30 ;

#------------------------------------------------------------------------
# End Autogenerate
#------------------------------------------------------------------------

# Code Here because need constant

#------------------------------------------------------------------------
# BraceHighEvent Management
#------------------------------------------------------------------------

sub BraceHighEvent {

  my $self   = shift;
  my $braces = shift || "[]{}()";

  my $braceAtCaret = -1;
  my $braceOpposite = -1;
  my $caretPos = $self->GetCurrentPos();

  if ($caretPos > 0) {
    my $charBefore  = $self->GetCharAt($caretPos - 1);
    $braceAtCaret = $caretPos - 1 if (index ($braces, $charBefore) >= 0 );
  }

  if ($braceAtCaret < 0)
  {
    my $charAfter  = $self->GetCharAt($caretPos);
    my $styleAfter = $self->GetCharAt($caretPos);

    $braceAtCaret = $caretPos if (index ($braces, $charAfter) >= 0);
  }

  $braceOpposite = $self->BraceMatch($braceAtCaret) if ($braceAtCaret >= 0);

  if ($braceAtCaret != -1  and $braceOpposite == -1) {
    $self->BraceBadLight($braceAtCaret);
  }
  else {
    $self->BraceHighlight($braceAtCaret, $braceOpposite);
  }
}

#------------------------------------------------------------------------
# Folder Management
#------------------------------------------------------------------------

# Folder Event call
# If Shift and Control are pressed, open or close all folder
# Otherwise
#  if shift is pressed, Toggle 1 level of current folder
#  else if control is pressed, expand all subfolder of current folder
#  else Toggle current folder
sub FolderEvent {

  my $self  = shift;
  my (%evt) = @_;

  if ($evt{-shift} and $evt{-control}) {
    $self->FolderAll();
  }
  else {
    my $lineClicked = $self->LineFromPosition($evt{-position});

    if ($self->GetFoldLevel($lineClicked) & Win32::GUI::Scintilla::SC_FOLDLEVELHEADERFLAG) {
       if ($evt{-shift}) {
           $self->SetFoldExpanded($lineClicked, 1);
           $self->FolderExpand($lineClicked, 1, 1, 1);
       }
       elsif ($evt{-control}) {
           if ($self->GetFoldExpanded($lineClicked)) {
               $self->SetFoldExpanded($lineClicked, 0);
               $self->FolderExpand($lineClicked, 0, 1, 0);
           }
           else {
               $self->SetFoldExpanded($lineClicked, 1);
               $self->FolderExpand($lineClicked, 1, 1, 100);
           }
       }
       else {
          $self->ToggleFold($lineClicked);
       }
     }
  }
}

# Open All Folder
sub FolderAll {

  my $self = shift;
  my $lineCount = $self->GetLineCount();
  my $expanding = 1;
  my $lineNum;

  # find out if we are folding or unfolding
  for $lineNum (1..$lineCount) {    # XXX Should this be 0 .. $linecount - 1 ???
    if ($self->GetFoldLevel($lineNum) & Win32::GUI::Scintilla::SC_FOLDLEVELHEADERFLAG) {
      $expanding = not $self->GetFoldExpanded($lineNum);
      last;
    }
  }

  $lineNum = 0;
  while ($lineNum < $lineCount) {
    my $level = $self->GetFoldLevel($lineNum);
    if (($level & Win32::GUI::Scintilla::SC_FOLDLEVELHEADERFLAG) and
        ($level & Win32::GUI::Scintilla::SC_FOLDLEVELNUMBERMASK) == Win32::GUI::Scintilla::SC_FOLDLEVELBASE) {

      if ($expanding) {
        $self->SetFoldExpanded($lineNum, 1);
        $lineNum = $self->FolderExpand($lineNum, 1);
        $lineNum--;
      }
      else {
        my $lastChild = $self->GetLastChild($lineNum, -1);
        $self->SetFoldExpanded($lineNum, 0);
        $self->HideLines($lineNum+1, $lastChild) if ($lastChild > $lineNum);
      }
    }
    $lineNum++;
  }
}

# Expand folder
sub FolderExpand {
  my $self     = shift;
  my $line     = shift;
  my $doExpand = shift;
  my $force    = shift || 0;
  my $visLevels= shift || 0;
  my $level    = shift || -1;

  my $lastChild = $self->GetLastChild($line, $level);
  $line++;
  while ($line <= $lastChild) {
      if ($force) {
          if ($visLevels > 0) {
              $self->ShowLines($line, $line);
          }
          else {
              $self->HideLines($line, $line);
          }
      }
      else {
          $self->ShowLines($line, $line) if ($doExpand);
      }

      $level = $self->GetFoldLevel($line) if ($level == -1);

      if ($level & Win32::GUI::Scintilla::SC_FOLDLEVELHEADERFLAG) {
          if ($force) {
              if ($visLevels > 1) {
                  $self->SetFoldExpanded($line, 1);
              }
              else {
                  $self->SetFoldExpanded($line, 0);
              }
              $line = $self->FolderExpand($line, $doExpand, $force, $visLevels-1);
          }
          else {
              if ($doExpand and $self->GetFoldExpanded($line)) {
                  $line = $self->FolderExpand($line, 1, $force, $visLevels-1);
              }
              else {
                  $line = $self->FolderExpand($line, 0, $force, $visLevels-1);
              }
          }
      }
      else {
          $line ++;
      }
  }

  return $line;
}

#------------------------------------------------------------------------
# Find Management
#------------------------------------------------------------------------

sub FindAndSelect {

  my $self = shift;
  my $text = shift;
  my $flag = shift || Win32::GUI::Scintilla::SCFIND_WHOLEWORD;
  my $direction = shift || 1;
  my $wrap = shift || 1;

  my ($start, $end);

  # Set Search target
  if ($direction >= 0) {
    $start = $self->GetSelectionEnd ();
    $end   = $self->GetLength();
  }
  else {
    $start = $self->GetSelectionStart() - 1;
    $end   = 0;
  }

  $self->SetTargetStart ($start);
  $self->SetTargetEnd   ($end);
  $self->SetSearchFlags  ($flag);

  # Find text
  my $pos = $self->SearchInTarget($text);

  # Not found and Wrap mode
  if ($pos == -1 and $wrap == 1)
  {
    # New search target
    if ($direction >= 0) {
     $start = 0;
     $end = $self->GetLength();
    }
    else {
     $start = $self->GetLength();
     $end = 0;
    }

    $self->SetTargetStart ($start);
    $self->SetTargetEnd   ($end);

    # Find Text
    $pos = $self->SearchInTarget($text);
  }

  # Select and visible
  unless ($pos == -1)
  {
    # GetTarget
    $start = $self->GetTargetStart();
    $end   = $self->GetTargetEnd();

    # Ensure range visible
    my ($lstart, $lend);
    if ($start <= $end)
    {
      $lstart = $self->LineFromPosition($start);
      $lend   = $self->LineFromPosition($end);
    }
    else
    {
      $lstart = $self->LineFromPosition($end);
      $lend   = $self->LineFromPosition($start);
    }

    for my $i ($lstart .. $lend)
    {
      $self->EnsureVisible ($i);
    }

    # Select Target
    $self->SetSel ($start, $end);
  }
  else
  {
    $self->SetSelectionStart ($self->GetSelectionEnd());
  }

  return $pos;
}

1; # End of Scintilla.pm
__END__
