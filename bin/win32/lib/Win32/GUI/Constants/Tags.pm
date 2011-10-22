package Win32::GUI::Constants::Tags;
# $Id: Tags.pm,v 1.7 2008/02/08 18:47:17 robertemay Exp $

use strict;
use warnings;

# On one line so MakeMaker will see it.
require Win32::GUI::Constants;  our $VERSION = $Win32::GUI::Constants::VERSION;

use AutoLoader 'AUTOLOAD';

=head1 NAME

Win32::GUI::Constants::Tags - export :tag definitions for Win32::GUI::Constants

=head1 SYNOPSIS

  use Win32::GUI::Constants qw ( :tag ... );

Win32::GUI::Constants::Tags provide export :tag definitions for use with
Win32::GUI::Constants.  It is implemented as a seperate module to improve
the speed and memory usage of Win32::GUI::Constants if no :tag symbols
are used on the import line.

=head1 EXPORT TAGS

The following tags are defined for use with Win32::GUI::Constants:

=head2 General Export Tags

=over

=item B<:common>

A somewhat subjective list of commonly used constants.

=item B<:customdraw>

Constants related to custom draw handling.

=item B<:stockobjects>

Constants defining the system objects that can be created with GetStockObject().

=item B<:compatibility_win32_gui>

All constants exported by default by Win32::GUI up to v1.03.  Note that this is a large list.

=item B<:all>

All defined constants.  Note that this is a very large list.

=back

=head2 Package Specific Export Tags

The following list of export tags is defined, each exporting constant that may be
useful with the related Win32::GUI package(s).  Note that some currently export nothing.

:accelerator, :animation, :bitmap, :brush, :button, :class, :combobox, :cursor,
:datetime, :dc, :font, :header, :icon, :imagelist, :label, :listbox, :listview, :mdi,
:menu, :monthcal, :notifyicon, :pen, :progressbar, :rebar, :region, :richedit,
:scrollbar, :slider, :splitter, :statusbar, :tabstrip, :textfield, :timer, :toolbar,
:tooltip, :treeview, :updown, :window

=cut

# tag spec's
# keys are tags, values are array ref containg regex patterns of
# constants to match.  If value is undef, then the definition will
# be the return value of a subroutine named tag_spec().  These
# subroutines are defined after the __END__ token in this file, and processed
# by AutoSplit and AutoLoader.
our %TAG_SPECS = (
    common      => [ qw( ^CW_USEDEFAULT$ ) ],
    customdraw  => [ qw( ^CDDS_ ^CDRF_ ) ],
    stockobjects=> undef,
    all         => [ qw( .* ) ],

    compatibility_win32_gui => undef,

    accelerator => [ qw( ^VK_ ) ],
    animation   => [ qw( ^ACS_ ^ACM_ ^ACN_ ) ],
    bitmap      => [ qw( ^OBM_ ) ],
    brush       => [ qw() ],
    button      => undef,
    class       => [ qw( ^COLOR_ ^CS_ ) ],
    combobox    => [ qw( ^CB_ ^CBS_ ^CBES_ ^CBN_ ) ],
    cursor      => [ qw( ^IDC_ ^OCR_ ) ],
    datetime    => [ qw( ^DTS_ ) ],
    dc          => undef,
    font        => [ qw() ],
    header      => [ qw( ^HDS_ ) ],
    icon        => [ qw( ^IDI_ ^OIC_ ) ],
    imagelist   => [ qw( ^ILC_ ^ILD_ ^ILS_ ^CLR_NONE$ ^CLR_DEFAULT$ ^IMAGE_ ) ],
    label       => [ qw( ^IMAGE_ ^STM_ ^STN_ ) ],
    listbox     => [ qw( ^LB_ ^LBN_ ^LBS_ ) ],
    listview    => [ qw( ^LVS_ ^LVIS_ ^LVIR_ ^LVSIL_ ^CLR_NONE$ ) ],
    mdi         => [ qw() ],
    menu        => [ qw( ^MF_ ^SC_ ^TPM_ ) ],
    monthcal    => [ qw( ^MCS_ ^MCSC_ ) ],
    notifyicon  => [ qw() ],
    pen         => [ qw( ^PS_ ) ],
    progressbar => [ qw( ^PBS_ ^PBM_ ^CLR_DEFAULT$ ) ],
    rebar       => [ qw( ^CLR_DEFAULT$ ^RBBS_ ) ],
    region      => [ qw( ^RGN_ ) ],
    richedit    => [ qw( ^CP_ ^EM_ ^ENM_ ^EN_ ^ES_ ^GT_ ^SF_ ^SFF_ ) ],
    scrollbar   => [ qw( ^SB_ ^SBM_ ^SBS_ ) ],
    slider      => [ qw( ^TBTS_ ) ],
    splitter    => [ qw() ],
    statusbar   => [ qw( ^CLR_DEFAULT$ ^SBT_ ) ],
    tabstrip    => [ qw() ],
    textfield   => [ qw( ^EM_ ^ES_ ) ],
    timer       => [ qw() ],
    toolbar     => [ qw( ^BTNS_ ^TBSTATE_ ^TBSTYLE_ ^I_ ^CLR_DEFAULT$ ^TRANSPARENT$
                         ^OPAQUE$ ^HINST_COMMCTRL$ ^IBD_ ) ],
    tooltip     => [ qw( ^TTDT_ ^TTF_ ^TTM_ ^TTN_ ) ],
    treeview    => [ qw( ^CLR_DEFAULT$ ^TVGN_ ^TVHT_ ) ],
    updown      => [ qw() ],
    window      => [ qw( ^DS_ ^ID.[^_]+ ^MA_ ^MK_ ^NM_ ^RDW_ ^SIZE_ ^SW_ ^WA_ ^WM_
                             ^WS_ ) ],
);

# tag() returns a reference to a list of constant names,
# or undef if the tag passed has no definition
sub tag {
    my $spec = shift;

    if(exists $TAG_SPECS{$spec}) {
        my $patterns;
        if(defined($TAG_SPECS{$spec})) {
            $patterns = $TAG_SPECS{$spec};
        }
        else {
            no strict 'refs';
            $patterns = &{"tag_$spec"};
        }
        my @names = ();
        my @syms = @{Win32::GUI::Constants::_export_ok()};
        foreach my $patn (@$patterns) {
            push @names, grep(/$patn/, @syms);
        }
        return \@names;
    }
       
    return undef;
}

1; #End of Tags.pm

=head1 SUPPORT

Homepage: L<http://perl-win32-gui.sourceforge.net/>.

For further support join the users mailing list
(C<perl-win32-gui-users@lists.sourceforge.net>) from the website
at L<http://lists.sourceforge.net/lists/listinfo/perl-win32-gui-users>.
There is a searchable list archive at
L<http://sourceforge.net/mail/?group_id=16572>

=head1 BUGS

No all constants are covered.  If you find missing constants
please raise a feature request at
L<http://sourceforge.net/tracker/?group_id=16572&atid=366572>

=head1 AUTHORS

Robert May, E<lt>robertemay@users.sourceforge.netE<gt>

=head1 ACKNOWLEDGEMENTS

Many thanks to the Win32::GUI developers at
L<http://perl-win32-gui.sourceforge.net/> for suggestions
and assistance.

=head1 COPYRIGHT & LICENSE

Copyright 2005..2006 Robert May, All Rights Reserved.

=cut

#AutoLoaded subs go after the __END__ token
# each sub here is the name of a tag, and returns an array ref
# to a list of patterns to match
__END__
sub tag_stockobjects() { [
qw( ^WHITE_BRUSH$ ^LTGRAY_BRUSH$ ^GRAY_BRUSH$ ^DKGRAY_BRUSH$ ^BLACK_BRUSH$ ^NULL_BRUSH$
    ^HOLLOW_BRUSH$ ^WHITE_PEN$ ^BLACK_PEN$ ^NULL_PEN$ ^OEM_FIXED_FONT$ ^ANSI_FIXED_FONT$
    ^ANSI_VAR_FONT$ ^SYSTEM_FONT$ ^DEVICE_DEFAULT_FONT$ ^DEFAULT_PALETTE$
    ^SYSTEM_FIXED_FONT$ ^DEFAULT_GUI_FONT$ ^DC_BRUSH$ ^DC_PEN$ )
] }
sub tag_button() { [
qw( ^BS_PUSHBUTTON$ ^BS_DEFPUSHBUTTON$ ^BS_CHECKBOX$ ^BS_AUTOCHECKBOX$ ^BS_RADIOBUTTON$
    ^BS_3STATE$ ^BS_AUTO3STATE$ ^BS_GROUPBOX$ ^BS_USERBUTTON$ ^BS_AUTORADIOBUTTON$
    ^BS_PUSHBOX$ ^BS_OWNERDRAW$ ^BS_TYPEMASK$ ^BS_LEFTTEXT$ ^BS_TEXT$ ^BS_ICON$
    ^BS_BITMAP$ ^BS_LEFT$ ^BS_RIGHT$ ^BS_CENTER$ ^BS_TOP$ ^BS_BOTTOM$ ^BS_VCENTER$
    ^BS_PUSHLIKE$ ^BS_MULTILINE$ ^BS_NOTIFY$ ^BS_FLAT$ ^BS_RIGHTBUTTON$ ^IMAGE_ 
    ^BM_ ^BCM_ ^BN_ )
] }
sub tag_dc() { [
qw( ^OPAQUE$ ^TRANSPARENT$ ^BDR_ ^EDGE_ ^BF_ ^CLR_INVALID$ ^HWND_DESKTOP$ ^DFC_ ^DFCS_
    ^DT_ ^FLOODFILL ^OBJ_ ^R2_ ^SRCCOPY$ ^SRCPAINT$ ^SRCAND$ ^SRCINVERT$ ^SRCERASE$
    ^NOTSRCCOPY$ ^NOTSRCERASE$ ^MERGECOPY$ ^MERGEPAINT$ ^PATCOPY$ ^PATPAINT$ ^PATINVERT$
    ^DSTINVERT$ ^BLACKNESS$ ^WHITENESS$ ^NOMIRRORBITMAP$ ^CAPTUREBLT$ ^ERROR$
    ^NULLREGION$ ^SIMPLEREGION$ ^COMPLEXREGION$ ^RGN_ ^BS_SOLID$ ^BS_NULL$ ^BS_HOLLOW$
    ^BS_HATCHED$ ^BS_PATTERN$ ^BS_INDEXED$ ^BS_DIBPATTERN$ ^BS_DIBPATTERNPT$
    ^BS_PATTERN8X8$ ^BS_DIBPATTERN8X8$ ^BS_MONOPATTERN$ ^HS_ ^PS_ ^BLACKONWHITE$
    ^WHITEONBLACK$ ^COLORONCOLOR$ ^HALFTONE$ ^STRETCH_ )
] }
sub tag_compatibility_win32_gui() { [
qw( ^BS_3STATE$ ^BS_AUTO3STATE$ ^BS_AUTOCHECKBOX$ ^BS_AUTORADIOBUTTON$ ^BS_CHECKBOX$
    ^BS_DEFPUSHBUTTON$ ^BS_GROUPBOX$ ^BS_LEFTTEXT$ ^BS_NOTIFY$ ^BS_OWNERDRAW$
    ^BS_PUSHBUTTON$ ^BS_RADIOBUTTON$ ^BS_USERBUTTON$ ^BS_BITMAP$ ^BS_BOTTOM$ ^BS_CENTER$
    ^BS_ICON$ ^BS_LEFT$ ^BS_MULTILINE$ ^BS_RIGHT$ ^BS_RIGHTBUTTON$ ^BS_TEXT$ ^BS_TOP$
    ^BS_VCENTER$ ^COLOR_3DFACE$ ^COLOR_ACTIVEBORDER$ ^COLOR_ACTIVECAPTION$
    ^COLOR_APPWORKSPACE$ ^COLOR_BACKGROUND$ ^COLOR_BTNFACE$ ^COLOR_BTNSHADOW$
    ^COLOR_BTNTEXT$ ^COLOR_CAPTIONTEXT$ ^COLOR_GRAYTEXT$ ^COLOR_HIGHLIGHT$
    ^COLOR_HIGHLIGHTTEXT$ ^COLOR_INACTIVEBORDER$ ^COLOR_INACTIVECAPTION$ ^COLOR_MENU$
    ^COLOR_MENUTEXT$ ^COLOR_SCROLLBAR$ ^COLOR_WINDOW$ ^COLOR_WINDOWFRAME$
    ^COLOR_WINDOWTEXT$ ^DS_3DLOOK$ ^DS_ABSALIGN$ ^DS_CENTER$ ^DS_CENTERMOUSE$
    ^DS_CONTEXTHELP$ ^DS_CONTROL$ ^DS_FIXEDSYS$ ^DS_LOCALEDIT$ ^DS_MODALFRAME$
    ^DS_NOFAILCREATE$ ^DS_NOIDLEMSG$ ^DS_SETFONT$ ^DS_SETFOREGROUND$ ^DS_SYSMODAL$
    ^DTS_UPDOWN$ ^DTS_SHOWNONE$ ^DTS_SHORTDATEFORMAT$ ^DTS_LONGDATEFORMAT$
    ^DTS_TIMEFORMAT$ ^DTS_APPCANPARSE$ ^DTS_RIGHTALIGN$ ^ES_AUTOHSCROLL$ ^ES_AUTOVSCROLL$
    ^ES_CENTER$ ^ES_LEFT$ ^ES_LOWERCASE$ ^ES_MULTILINE$ ^ES_NOHIDESEL$ ^ES_NUMBER$
    ^ES_OEMCONVERT$ ^ES_PASSWORD$ ^ES_READONLY$ ^ES_RIGHT$ ^ES_UPPERCASE$ ^ES_WANTRETURN$
    ^GW_CHILD$ ^GW_HWNDFIRST$ ^GW_HWNDLAST$ ^GW_HWNDNEXT$ ^GW_HWNDPREV$ ^GW_OWNER$
    ^IMAGE_BITMAP$ ^IMAGE_CURSOR$ ^IMAGE_ICON$ ^IDABORT$ ^IDCANCEL$ ^IDIGNORE$ ^IDNO$
    ^IDOK$ ^IDRETRY$ ^IDYES$ ^LR_DEFAULTCOLOR$ ^LR_MONOCHROME$ ^LR_COLOR$
    ^LR_COPYRETURNORG$ ^LR_COPYDELETEORG$ ^LR_LOADFROMFILE$ ^LR_LOADTRANSPARENT$
    ^LR_DEFAULTSIZE$ ^LR_LOADMAP3DCOLORS$ ^LR_CREATEDIBSECTION$ ^LR_COPYFROMRESOURCE$
    ^LR_SHARED$ ^MB_ABORTRETRYIGNORE$ ^MB_OK$ ^MB_OKCANCEL$ ^MB_RETRYCANCEL$ ^MB_YESNO$
    ^MB_YESNOCANCEL$ ^MB_ICONEXCLAMATION$ ^MB_ICONWARNING$ ^MB_ICONINFORMATION$
    ^MB_ICONASTERISK$ ^MB_ICONQUESTION$ ^MB_ICONSTOP$ ^MB_ICONERROR$ ^MB_ICONHAND$
    ^MB_DEFBUTTON1$ ^MB_DEFBUTTON2$ ^MB_DEFBUTTON3$ ^MB_DEFBUTTON4$ ^MB_APPLMODAL$
    ^MB_SYSTEMMODAL$ ^MB_TASKMODAL$ ^MB_DEFAULT_DESKTOP_ONLY$ ^MB_HELP$ ^MB_RIGHT$
    ^MB_RTLREADING$ ^MB_SETFOREGROUND$ ^MB_TOPMOST$ ^MB_SERVICE_NOTIFICATION$
    ^MB_SERVICE_NOTIFICATION_NT3X$ ^MF_STRING$ ^MF_POPUP$ ^RBBS_BREAK$ ^RBBS_CHILDEDGE$
    ^RBBS_FIXEDBMP$ ^RBBS_FIXEDSIZE$ ^RBBS_GRIPPERALWAYS$ ^RBBS_HIDDEN$ ^RBBS_NOGRIPPER$
    ^RBBS_NOVERT$ ^RBBS_VARIABLEHEIGHT$ ^SB_LINEUP$ ^SB_LINELEFT$ ^SB_LINEDOWN$
    ^SB_LINERIGHT$ ^SB_PAGEUP$ ^SB_PAGELEFT$ ^SB_PAGEDOWN$ ^SB_PAGERIGHT$
    ^SB_THUMBPOSITION$ ^SB_THUMBTRACK$ ^SB_TOP$ ^SB_LEFT$ ^SB_BOTTOM$ ^SB_RIGHT$
    ^SB_ENDSCROLL$ ^SBT_POPOUT$ ^SBT_RTLREADING$ ^SBT_NOBORDERS$ ^SBT_OWNERDRAW$
    ^SM_ARRANGE$ ^SM_CLEANBOOT$ ^SM_CMOUSEBUTTONS$ ^SM_CXBORDER$ ^SM_CYBORDER$
    ^SM_CXCURSOR$ ^SM_CYCURSOR$ ^SM_CXDLGFRAME$ ^SM_CYDLGFRAME$ ^SM_CXDOUBLECLK$
    ^SM_CYDOUBLECLK$ ^SM_CXDRAG$ ^SM_CYDRAG$ ^SM_CXEDGE$ ^SM_CYEDGE$ ^SM_CXFIXEDFRAME$
    ^SM_CYFIXEDFRAME$ ^SM_CXFRAME$ ^SM_CYFRAME$ ^SM_CXFULLSCREEN$ ^SM_CYFULLSCREEN$
    ^SM_CXHSCROLL$ ^SM_CYHSCROLL$ ^SM_CXHTHUMB$ ^SM_CXICON$ ^SM_CYICON$ ^SM_CXICONSPACING$
    ^SM_CYICONSPACING$ ^SM_CXMAXIMIZED$ ^SM_CYMAXIMIZED$ ^SM_CXMAXTRACK$ ^SM_CYMAXTRACK$
    ^SM_CXMENUCHECK$ ^SM_CYMENUCHECK$ ^SM_CXMENUSIZE$ ^SM_CYMENUSIZE$ ^SM_CXMIN$
    ^SM_CYMIN$ ^SM_CXMINIMIZED$ ^SM_CYMINIMIZED$ ^SM_CXMINSPACING$ ^SM_CYMINSPACING$
    ^SM_CXMINTRACK$ ^SM_CYMINTRACK$ ^SM_CXSCREEN$ ^SM_CYSCREEN$ ^SM_CXSIZE$ ^SM_CYSIZE$
    ^SM_CXSIZEFRAME$ ^SM_CYSIZEFRAME$ ^SM_CXSMICON$ ^SM_CYSMICON$ ^SM_CXSMSIZE$
    ^SM_CYSMSIZE$ ^SM_CXVSCROLL$ ^SM_CYVSCROLL$ ^SM_CYCAPTION$ ^SM_CYKANJIWINDOW$
    ^SM_CYMENU$ ^SM_CYSMCAPTION$ ^SM_CYVTHUMB$ ^SM_DBCSENABLED$ ^SM_DEBUG$
    ^SM_MENUDROPALIGNMENT$ ^SM_MIDEASTENABLED$ ^SM_MOUSEPRESENT$ ^SM_MOUSEWHEELPRESENT$
    ^SM_NETWORK$ ^SM_PENWINDOWS$ ^SM_SECURE$ ^SM_SHOWSOUNDS$ ^SM_SLOWMACHINE$
    ^SM_SWAPBUTTON$ ^TPM_LEFTBUTTON$ ^TPM_RIGHTBUTTON$ ^TPM_LEFTALIGN$ ^TPM_CENTERALIGN$
    ^TPM_RIGHTALIGN$ ^TPM_TOPALIGN$ ^TPM_VCENTERALIGN$ ^TPM_BOTTOMALIGN$ ^TPM_HORIZONTAL$
    ^TPM_VERTICAL$ ^TPM_NONOTIFY$ ^TPM_RETURNCMD$ ^TPM_RECURSE$ ^TBSTATE_CHECKED$
    ^TBSTATE_ELLIPSES$ ^TBSTATE_ENABLED$ ^TBSTATE_HIDDEN$ ^TBSTATE_INDETERMINATE$
    ^TBSTATE_MARKED$ ^TBSTATE_PRESSED$ ^TBSTATE_WRAP$ ^TBSTYLE_ALTDRAG$
    ^TBSTYLE_CUSTOMERASE$ ^TBSTYLE_FLAT$ ^TBSTYLE_LIST$ ^TBSTYLE_REGISTERDROP$
    ^TBSTYLE_TOOLTIPS$ ^TBSTYLE_TRANSPARENT$ ^TBSTYLE_WRAPABLE$ ^BTNS_AUTOSIZE$
    ^BTNS_BUTTON$ ^BTNS_CHECK$ ^BTNS_CHECKGROUP$ ^BTNS_DROPDOWN$ ^BTNS_GROUP$
    ^BTNS_NOPREFIX$ ^BTNS_SEP$ ^BTNS_SHOWTEXT$ ^BTNS_WHOLEDROPDOWN$ ^TBSTYLE_AUTOSIZE$
    ^TBSTYLE_BUTTON$ ^TBSTYLE_CHECK$ ^TBSTYLE_CHECKGROUP$ ^TBSTYLE_DROPDOWN$
    ^TBSTYLE_GROUP$ ^TBSTYLE_NOPREFIX$ ^TBSTYLE_SEP$ ^TBSTYLE_EX_DRAWDDARROWS$
    ^TBSTYLE_EX_HIDECLIPPEDBUTTONS$ ^TBSTYLE_EX_MIXEDBUTTONS$ ^TBTS_TOP$ ^TBTS_LEFT$
    ^TBTS_BOTTOM$ ^TBTS_RIGHT$ ^TVGN_CARET$ ^TVGN_CHILD$ ^TVGN_DROPHILITE$
    ^TVGN_FIRSTVISIBLE$ ^TVGN_NEXT$ ^TVGN_NEXTVISIBLE$ ^TVGN_PARENT$ ^TVGN_PREVIOUS$
    ^TVGN_PREVIOUSVISIBLE$ ^TVGN_ROOT$ ^WM_CREATE$ ^WM_DESTROY$ ^WM_MOVE$ ^WM_SIZE$
    ^WM_ACTIVATE$ ^WM_SETFOCUS$ ^WM_KILLFOCUS$ ^WM_ENABLE$ ^WM_SETREDRAW$ ^WM_COMMAND$
    ^WM_KEYDOWN$ ^WM_SETCURSOR$ ^WM_KEYUP$ ^WS_BORDER$ ^WS_CAPTION$ ^WS_CHILD$
    ^WS_CHILDWINDOW$ ^WS_CLIPCHILDREN$ ^WS_CLIPSIBLINGS$ ^WS_DISABLED$ ^WS_DLGFRAME$
    ^WS_GROUP$ ^WS_HSCROLL$ ^WS_ICONIC$ ^WS_MAXIMIZE$ ^WS_MAXIMIZEBOX$ ^WS_MINIMIZE$
    ^WS_MINIMIZEBOX$ ^WS_OVERLAPPED$ ^WS_OVERLAPPEDWINDOW$ ^WS_POPUP$ ^WS_POPUPWINDOW$
    ^WS_SIZEBOX$ ^WS_SYSMENU$ ^WS_TABSTOP$ ^WS_THICKFRAME$ ^WS_TILED$ ^WS_TILEDWINDOW$
    ^WS_VISIBLE$ ^WS_VSCROLL$ ^WS_EX_ACCEPTFILES$ ^WS_EX_APPWINDOW$ ^WS_EX_CLIENTEDGE$
    ^WS_EX_CONTEXTHELP$ ^WS_EX_CONTROLPARENT$ ^WS_EX_DLGMODALFRAME$ ^WS_EX_LEFT$
    ^WS_EX_LEFTSCROLLBAR$ ^WS_EX_LTRREADING$ ^WS_EX_MDICHILD$ ^WS_EX_NOPARENTNOTIFY$
    ^WS_EX_OVERLAPPEDWINDOW$ ^WS_EX_PALETTEWINDOW$ ^WS_EX_RIGHT$ ^WS_EX_RIGHTSCROLLBAR$
    ^WS_EX_RTLREADING$ ^WS_EX_STATICEDGE$ ^WS_EX_TOOLWINDOW$ ^WS_EX_TOPMOST$
    ^WS_EX_TRANSPARENT$ ^WS_EX_WINDOWEDGE$ )
] }
