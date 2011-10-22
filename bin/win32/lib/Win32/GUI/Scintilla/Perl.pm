package Win32::GUI::Scintilla::Perl;

# $Id: Perl.pm,v 1.4 2006/10/15 14:07:46 robertemay Exp $

use strict;
use warnings;

use Win32::GUI::Scintilla();

our $VERSION = "0.02";

=head1 NAME

Win32::GUI::Scintilla::Perl -- Scintilla control with Perl awareness.

=head1 SYNOPSIS

        use Win32::GUI::Scintilla::Perl;

        my $win = #Create window here

        my $sciViewer = $winMain->AddScintillaPerl  (
                -name    => "sciViewer",
                -left   => 0,
                -top    => 30,
                -width  => 400,
                -height => 240,
                -addexstyle => WS_EX_CLIENTEDGE,
                );

        #Change look and feel to your liking here.

=cut


=head1 METHODS

=head2 new(%hOption)

Create a Win32::GUI::Scintilla control which is in "Perl
mode". Other than this, it's a regular Scintilla object.

You can override any setting afterward.

=cut

my %hFontFace = (
                'times'  => 'Times New Roman',
                'mono'   => 'Courier New',
                'helv'   => 'Lucida Console',
                'lucida' => 'Lucida Console',
                'other'  => 'Comic Sans MS',
                'size'   => '10',
                'size2'  => '9',
                'backcol'=> '#FFFFFF',
                );

my $keywordPerl = q{
NULL __FILE__ __LINE__ __PACKAGE__ __DATA__ __END__ AUTOLOAD
BEGIN CORE DESTROY END EQ GE GT INIT LE LT NE CHECK abs accept
alarm and atan2 bind binmode bless caller chdir chmod chomp chop
chown chr chroot close closedir cmp connect continue cos crypt
dbmclose dbmopen defined delete die do dump each else elsif endgrent
endhostent endnetent endprotoent endpwent endservent eof eq eval
exec exists exit exp fcntl fileno flock for foreach fork format
formline ge getc getgrent getgrgid getgrnam gethostbyaddr gethostbyname
gethostent getlogin getnetbyaddr getnetbyname getnetent getpeername
getpgrp getppid getpriority getprotobyname getprotobynumber getprotoent
getpwent getpwnam getpwuid getservbyname getservbyport getservent
getsockname getsockopt glob gmtime goto grep gt hex if index
int ioctl join keys kill last lc lcfirst le length link listen
local localtime lock log lstat lt m map mkdir msgctl msgget msgrcv
msgsnd my ne next no not oct open opendir or ord our pack package
pipe pop pos print printf prototype push q qq qr quotemeta qu
qw qx rand read readdir readline readlink readpipe recv redo
ref rename require reset return reverse rewinddir rindex rmdir
s scalar seek seekdir select semctl semget semop send setgrent
sethostent setnetent setpgrp setpriority setprotoent setpwent
setservent setsockopt shift shmctl shmget shmread shmwrite shutdown
sin sleep socket socketpair sort splice split sprintf sqrt srand
stat study sub substr symlink syscall sysopen sysread sysseek
system syswrite tell telldir tie tied time times tr truncate
uc ucfirst umask undef unless unlink unpack unshift untie until
use utime values vec wait waitpid wantarray warn while write
x xor y
};

sub new {
  my $pkg = shift;
  $pkg = ref($pkg) || $pkg;
  my $sci = Win32::GUI::Scintilla->new(@_) or return(undef);

  SetupPerl($sci) or return(undef);

  return($sci);
}

=head1 ROUTINES

=head2 SetupPerl($sciControl)

Setup $sciControl in Perl mode.

Return 1 on success, else 0.

=cut
sub SetupPerl {
  my ($sci) = @_;

  # Set Perl Lexer
  $sci->SetLexer(Win32::GUI::Scintilla::SCLEX_PERL);

  # Set Perl Keyword
  $sci->SetKeyWords(0, $keywordPerl);

  # Folder ????
  $sci->SetProperty("fold", "1");
  $sci->SetProperty("tab.timmy.whinge.level", "1");

  # Indenetation
  $sci->SetIndentationGuides(1);
  $sci->SetUseTabs(1);
  $sci->SetTabWidth(4);
  $sci->SetIndent(4);

  # Edge Mode
  $sci->SetEdgeMode(Win32::GUI::Scintilla::EDGE_LINE); #Win32::GUI::Scintilla::EDGE_BACKGROUND
  $sci->SetEdgeColumn(80);

  # Define margin
  # $sci->SetMargins(0,0);
  $sci->SetMarginTypeN(1, Win32::GUI::Scintilla::SC_MARGIN_NUMBER);
  $sci->SetMarginWidthN(1, 25);

  $sci->SetMarginTypeN(2, Win32::GUI::Scintilla::SC_MARGIN_SYMBOL);
  $sci->SetMarginMaskN(2, Win32::GUI::Scintilla::SC_MASK_FOLDERS);
  $sci->SetMarginSensitiveN(2, 1);
  $sci->SetMarginWidthN(2, 12);

  # Define marker
  $sci->MarkerDefine(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEREND,     Win32::GUI::Scintilla::SC_MARK_BOXPLUSCONNECTED);
  $sci->MarkerSetFore(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEREND, '#FFFFFF');
  $sci->MarkerSetBack(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEREND, '#000000');
  $sci->MarkerDefine(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEROPENMID, Win32::GUI::Scintilla::SC_MARK_BOXMINUSCONNECTED);
  $sci->MarkerSetFore(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEROPENMID, '#FFFFFF');
  $sci->MarkerSetBack(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEROPENMID, '#000000');
  $sci->MarkerDefine(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERMIDTAIL, Win32::GUI::Scintilla::SC_MARK_TCORNER);
  $sci->MarkerSetFore(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERMIDTAIL, '#FFFFFF');
  $sci->MarkerSetBack(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERMIDTAIL, '#000000');
  $sci->MarkerDefine(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERTAIL,    Win32::GUI::Scintilla::SC_MARK_LCORNER);
  $sci->MarkerSetFore(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERTAIL, '#FFFFFF');
  $sci->MarkerSetBack(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERTAIL, '#000000');
  $sci->MarkerDefine(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERSUB,     Win32::GUI::Scintilla::SC_MARK_VLINE);
  $sci->MarkerSetFore(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERSUB, '#FFFFFF');
  $sci->MarkerSetBack(Win32::GUI::Scintilla::SC_MARKNUM_FOLDERSUB, '#000000');
  $sci->MarkerDefine(Win32::GUI::Scintilla::SC_MARKNUM_FOLDER,        Win32::GUI::Scintilla::SC_MARK_BOXPLUS);
  $sci->MarkerSetFore(Win32::GUI::Scintilla::SC_MARKNUM_FOLDER, '#FFFFFF');
  $sci->MarkerSetBack(Win32::GUI::Scintilla::SC_MARKNUM_FOLDER, '#000000');
  $sci->MarkerDefine(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEROPEN,    Win32::GUI::Scintilla::SC_MARK_BOXMINUS);
  $sci->MarkerSetFore(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEROPEN, '#FFFFFF');
  $sci->MarkerSetBack(Win32::GUI::Scintilla::SC_MARKNUM_FOLDEROPEN, '#000000');

  # Define Style

  # Global default styles for all languages
  $sci->StyleSetSpec(Win32::GUI::Scintilla::STYLE_DEFAULT,     "face:$hFontFace{'mono'},size:$hFontFace{'size'}");
  $sci->StyleClearAll();  # Apply STYLE_DEFAULT to all styles
  $sci->StyleSetSpec(Win32::GUI::Scintilla::STYLE_LINENUMBER,  "back:#C0C0C0");
  $sci->StyleSetSpec(Win32::GUI::Scintilla::STYLE_CONTROLCHAR, "");
  $sci->StyleSetSpec(Win32::GUI::Scintilla::STYLE_BRACELIGHT,  "fore:#FFFFFF,back:#0000FF,bold");
  $sci->StyleSetSpec(Win32::GUI::Scintilla::STYLE_BRACEBAD,    "fore:#000000,back:#FF0000,bold");

  # White space
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_DEFAULT, "fore:#808080");
  # Error
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_ERROR , "fore:#0000FF");
  # Comment
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_COMMENTLINE, "fore:#007F00");
  # POD: = at beginning of line
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_POD, "fore:#004000,back:#E0FFE0,eolfilled");
  # Number
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_NUMBER, "fore:#007F7F");
  # Keyword
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_WORD , "fore:#00007F,bold");
  # Double quoted string
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_STRING, "fore:#7F007F");
  # Single quoted string
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_CHARACTER, "fore:#7F0000");
  # Symbols / Punctuation. Currently not used by LexPerl.
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_PUNCTUATION, "fore:#00007F,bold");
  # Preprocessor. Currently not used by LexPerl.
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_PREPROCESSOR, "fore:#00007F,bold");
  # Operators
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_OPERATOR , "bold");
  # Identifiers (functions, etc.)
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_IDENTIFIER , "fore:#000000");
  # Scalars: $var
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_SCALAR, "fore:#000000,back:#FFE0E0");
  # Array: @var
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_ARRAY, "fore:#000000,back:#FFFFE0");
  # Hash: %var
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_HASH, "fore:#000000,back:#FFE0FF");
  # Symbol table: *var
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_SYMBOLTABLE, "fore:#000000,back:#E0E0E0");
  # Regex: /re/ or m{re}
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_REGEX, "fore:#000000,back:#A0FFA0");
  # Substitution: s/re/ore/
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_REGSUBST, "fore:#000000,back:#F0E080");
  # Long Quote (qq, qr, qw, qx) -- obsolete: replaced by qq, qx, qr, qw
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_LONGQUOTE, "fore:#FFFF00,back:#8080A0");
  # Back Ticks
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_BACKTICKS, "fore:#FFFF00,back:#A08080");
  # Data Section: __DATA__ or __END__ at beginning of line
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_DATASECTION, "#600000,back:#FFF0D8,eolfilled");
  # Here-doc (delimiter)
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_HERE_DELIM, "fore:#000000,back:#DDD0DD");
  # Here-doc (single quoted, q)
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_HERE_Q, "fore:#7F007F,back:#DDD0DD,eolfilled,notbold");
  # Here-doc (double quoted, qq)
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_HERE_QQ, "fore:#7F007F,back:#DDD0DD,eolfilled,bold");
  # Here-doc (back ticks, qx)
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_HERE_QX, "fore:#7F007F,back:#DDD0DD,eolfilled,italics");
  # Single quoted string, generic
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_STRING_Q, "fore:#7F007F,notbold");
  # qq = Double quoted string
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_STRING_QQ, "fore:#7F007F,italic");
  # qx = Back ticks
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_STRING_QX, "fore:#FFFF00,back:#A08080");
  # qr = Regex
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_STRING_QR, "fore:#000000,back:#A0FFA0");
  # qw = Array
  $sci->StyleSetSpec (Win32::GUI::Scintilla::SCE_PL_STRING_QW, "fore:#000000,back:#FFFFE0");

  return(1);
}

=head1 Win32::GUI::Window methods

=head2 AddScintillaPerl

Create and add a Win32::GUI::Scintilla::Perl control to this
window.

=cut
sub Win32::GUI::Window::AddScintillaPerl {
  my $parent  = shift;
  return Win32::GUI::Scintilla::Perl->new (-parent => $parent, @_);
}

1;

=head1 AUTHOR

Laurent Rocher (the hard work) and Johan Lindström (subclassing).

Same license as Perl.

=cut

__END__
