package Win32::GUI::Grid;

# $Id: Grid.pm,v 1.4 2006/10/15 14:07:46 robertemay Exp $

use strict;
use warnings;

use Carp();
use Win32::GUI qw(WS_BORDER WS_TABSTOP WS_VISIBLE WS_DISABLED WS_CHILD);

require Exporter;
require DynaLoader;

our $VERSION = "0.08";
our $XS_VERSION = 0.08;
$VERSION = eval $VERSION;

our $AUTOLOAD;
our @ISA = qw(Exporter DynaLoader Win32::GUI::Window);

our @EXPORT = qw(
    GVL_NONE GVL_HORZ GVL_VERT GVL_BOTH

    GVS_DEFAULT GVS_HEADER GVS_DATA GVS_BOTH

    GVNI_FOCUSED GVNI_SELECTED GVNI_DROPHILITED GVNI_READONLY
    GVNI_FIXED GVNI_MODIFIED GVNI_ABOVE GVNI_BELOW GVNI_TOLEFT
    GVNI_TORIGHT GVNI_ALL GVNI_AREA

    GVHT_DATA GVHT_TOPLEFT GVHT_COLHDR GVHT_ROWHDR GVHT_COLSIZER
    GVHT_ROWSIZER GVHT_LEFT GVHT_RIGHT GVHT_ABOVE GVHT_BELOW

    GVN_BEGINDRAG GVN_BEGINLABELEDIT GVN_BEGINRDRAG GVN_COLUMNCLICK
    GVN_CHANGEDLABELEDIT GVN_DELETEITEM GVN_ENDLABELEDIT
    GVN_SELCHANGING GVN_SELCHANGED GVN_GETDISPINFO GVN_ODCACHEHINT

    GVIS_FOCUSED GVIS_SELECTED GVIS_DROPHILITED GVIS_READONLY
    GVIS_FIXED GVIS_FIXEDROW GVIS_FIXEDCOL GVIS_MODIFIED

    GVIT_DEFAULT GVIT_NUMERIC GVIT_DATE GVIT_DATECAL GVIT_TIME
    GVIT_CHECK GVIT_COMBO GVIT_LIST GVIT_URL

    DT_TOP DT_LEFT DT_CENTER DT_RIGHT DT_VCENTER DT_BOTTOM
    DT_WORDBREAK DT_SINGLELINE DT_EXPANDTABS DT_TABSTOP
    DT_NOCLIP DT_EXTERNALLEADING DT_CALCRECT DT_NOPREFIX
    DT_INTERNAL DT_EDITCONTROL DT_PATH_ELLIPSIS DT_END_ELLIPSIS
    DT_MODIFYSTRING DT_RTLREADING DT_WORD_ELLIPSIS
);

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.  If a constant is not found then control is passed
    # to the AUTOLOAD in AutoLoader.

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

bootstrap Win32::GUI::Grid $XS_VERSION;

Win32::GUI::Grid::_Initialise();

END {
  Win32::GUI::Grid::_UnInitialise();
}

#
# New method
#

sub new {

  my $class  = shift;
  my %in     = @_;

  ### Control option
  Carp::croak("-parent undefined") unless exists $in{-parent};
  Carp::croak("-name undefined")   unless exists $in{-name};

  my $parent = $in{-parent};
  my $name   = $in{-name};

  # print "Parent = $parent->{-name}\n";
  # print "Name = $name\n";

  ### Size
  my ($x, $y, $w, $h) = (0,0,0,0);

  $x = $in{-left}       if exists $in{-left};
  $y = $in{-top}        if exists $in{-top};
  $w = $in{-width}      if exists $in{-width};
  $h = $in{-height}     if exists $in{-height};
  ($x, $y) = ($in{-pos}[0] , $in{-pos}[1]) if exists $in{-pos};
  ($w, $h) = ($in{-size}[0],$in{-size}[1]) if exists $in{-size};
  # print "(x,y) = ($x,$y)\n(w,h) = ($w,$h)\n";

  ### Window style
  my $style = WS_CHILD | WS_BORDER | WS_TABSTOP;

  $style = $in{-style}      if exists $in{-style};
  $style |= $in{-pushstyle} if exists $in{-pushstyle};
  $style ^= $in{-poptyle}   if exists $in{-popstyle};
  $style |= WS_VISIBLE  unless exists $in{-visible} && $in{-visible} == 0;
  $style |= WS_DISABLED     if exists $in{-enable} && $in{-enable} == 0;

  # print "Style = $style\n";

  ### Create Object and Window
  my $self = {};
  bless $self, $class;

  my $hwnd = $self->_Create($parent, $name, $style, $x, $y, $w, $h);
  return undef if ($hwnd == 0);

  ### Store Data (Win32::GUI glue)
  $self->{-handle} = $hwnd;
  $self->{-name}   = $in{-name};
  $parent->{$name} = $self;

  ### Grid Options
  $self->SetVirtualMode($in{-virtual})          if exists $in{-virtual};
  $self->SetRows($in{-rows})                    if exists $in{-rows};
  $self->SetColumns($in{-columns})              if exists $in{-columns};
  $self->SetFixedRows($in{-fixedrows})          if exists $in{-fixedrows};
  $self->SetFixedColumns($in{-fixedcolumns})    if exists $in{-fixedcolumns};
  $self->SetEditable($in{-editable})            if exists $in{-editable};
  $self->SetDoubleBuffering($in{-doublebuffer}) if exists $in{-doublebuffer};

  return $self;
}

#
# Win32::GUI shortcut
#

sub Win32::GUI::Window::AddGrid {
  my $parent  = shift;
  return Win32::GUI::Grid->new (-parent => $parent, @_);
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Win32::GUI::Grid - add a grid control to Win32::GUI.

=head1 SYNOPSIS

  use strict;
  use Win32::GUI;
  use Win32::GUI::Grid;
  # main Window
  my $Window = new Win32::GUI::Window (
      -title    => "Win32::GUI::Grid",
      -pos     => [100, 100],
      -size    => [400, 400],
      -name     => "Window",
  ) or die "new Window";
  # Grid Window
  my $Grid = $Window->AddGrid (
      -name    => "Grid",
      -pos     => [0, 0],
      -rows    => 50,
      -columns => 10,
      -fixedrows    => 1,
      -fixedcolumns => 1,
      -editable => 1,
  ) or die "new Grid";
  # Fill Grid
  for my $row (0..$Grid->GetRows()) {
    for my $col (0..$Grid->GetColumns()) {
      if ($row == 0) {
        $Grid->SetCellText($row, $col,"Column : $col");
      }
      elsif ($col == 0) {
        $Grid->SetCellText($row, $col, "Row : $row");
      }
      else {
        $Grid->SetCellText($row, $col, "Cell : ($row,$col)");
      }
    }
  }
  # Resize Grid Cell
  $Grid->AutoSize();
  # Event loop
  $Window->Show();
  Win32::GUI::Dialog();
  # Main window event handler
  sub Window_Terminate {

    return -1;
  }
  sub Window_Resize {
    my ($width, $height) = ($Window->GetClientRect)[2..3];
    $Grid->Resize ($width, $height);
  }
  # Grid event handler
  sub Grid_Click {
    my ($col, $row) = @_;
    print "Click on Cell ($col, $row)\n";
  }

=head1 DESCRIPTION

This package uses the MFC Grid control 2.25 By Chris Maunder.
homepage: L<http://www.codeproject.com/miscctrl/gridctrl.asp>

=head1 PACKAGE FUNCTIONS

=head2 Grid creation

=over

=item C<new>

Create a new grid control.

  Parameter :
    -name         : Window name
    -parent       : Parent window

    -left         : Left position
    -top          : Top  position
    -width        : Width
    -height       : Heigth

    -pos          : [x, y] position
    -size         : [w, h] size

    -visible      : Visible
    -hscroll      : Horizontal scroll
    -vscroll      : Vertical scroll
    -enable       : Enable

    -style        : Default style
    -pushstyle    : Push style
    -popstyle     : Pop style

    -rows         : Total rows
    -columns      : Total columns
    -fixedrows    : Fixed rows
    -fixedcolumns : Fixed columns
    -editable     : Editable
    -doublebuffer : Double buffering display

=item C<Win32::GUI::Window::AddGrid>

A Win32::GUI short cut for create a grid.
Automaticly, create parent link.

=back

=head2 Grid object

=head3 Number of rows and columns

=over

=item C<SetRows> ([nRows=10])

Sets the number of rows (including fixed rows), Returning
TRUE on success.

=item C<GetRows> ()

Returns the number of rows (including fixed rows).

=item C<SetColumns> ([nCols=10])

Sets the number of columns (including fixed columns), Returning TRUE
on success.

=item C<GetColumns> ()

Returns the number of columns (including fixed columns)

=item C<SetFixedRows> ([nFixedRows = 1])

Sets the number of fixed rows, returning TRUE on success.

=item C<GetFixedRows> ()

Returns the number of fixed rows

=item C<SetFixedColumns> ([nFixedCols = 1])

Sets the number of columns, returning TRUE on success.

=item C<GetFixedColumns> ()

Returns the number of fixed columns

=back

=head3 Sizing and position functions

=over

=item C<SetRowHeight> (nRow, height)

Sets the height of row nRow.

=item C<GetRowHeight> (nRow)

Gets the height of row nRow.

=item C<SetColumnWidth> (nCol, width)

Sets the width of column nCol.

=item C<GetColumnWidth> (nCol)

Gets the width of column nCol

=item C<GetFixedRowsHeight> ()

Gets the combined height of the fixed rows.

=item C<GetFixedColumnsWidth> ()

Gets the combined width of the fixed columns.

=item C<GetVirtualHeight> ()

Gets the combined height of all the rows.

=item C<GetVirtualWidth> ()

Gets the combined width of all the columns.

=item C<GetCellOrigin> (row, col)

Gets the topleft point for cell (nRow,nCol).
Cell must be visible for success.
Return an [x, y] if successful.

=item C<GetCellRect> (row, col)

Gets the bounding rectangle for the given cell.
Cell must be visible for success.
Return an [left, top, right, bottom] array if successful.

=item C<GetTextRect> (row, col)

Gets the bounding rectangle for the text in the given cell.
Cell must be visible for success.
Return an [left, top, right, bottom] array if successful..

=item C<GetTextExtent> (nRow, nCol, str)

Gets the bounding rectangle for the given text for the given cell.
Return an [width, height] array if successful.

=item C<GetCellTextExtent> (nRow, nCol)

Gets the bounding rectangle for the text in the given cell.
Return an [width, height] array if successful.

=item C<GetCellFromPt> (x, y)

Gets the cell position from the given point.
Return an [row, col] if successful.

=back

=head3 Virtual Mode

=over

=item C<SetVirtualMode> ([mode = TRUE])

Sets grid in virtual mode.
See _GetData Event for provide data.

=item C<GetVirtualMode> ()

Gets virtual mode.

=back

=head3 General appearance and features

=over

=item C<SetImageList> (imagelist)

Sets the current image list for the grid.
The control only takes a copy of the pointer to the image list,
not a copy of the list itself.

=item C<GetImageList> ()

Gets the current image list for the grid.

=item C<SetGridLines> ([nWhichLines = GVL_BOTH])

Sets which (if any) gridlines are displayed.

Possible values.
    GVL_NONE = No grid lines
    GVL_HORZ = Horizontal lines only
    GVL_VERT = Vertical lines only
    GVL_BOTH = Both vertical and horizontal lines

=item C<GetGridLines> ()

Gets which (if any) gridlines are displayed.

Possible values.
    GVL_NONE = No grid lines
    GVL_HORZ = Horizontal lines only
    GVL_VERT = Vertical lines only
    GVL_BOTH = Both vertical and horizontal lines

=item C<SetEditable> ([bEditable = TRUE])

Sets if the grid is editable.

=item C<IsEditable> ()

Gets whether or not the grid is editable.

=item C<SetListMode> ([bEnableListMode = TRUE])

Sets the grid into (or out of) List mode.
When the grid is in list mode, full row selection is enabled
and clicking on the column header will sort the grid by rows.

=item C<GetListMode> ()

Get whether or not the grid is in list mode.

=item C<SetSingleRowSelection> ([bSingle = TRUE])

Sets the grid into (or out of) Single row selection mode.
This mode is only effective when in ListMode. When in this mode,
only a single row at a time can be selected, so the grid behaves
somewhat like a multicolumn listbox.

=item C<GetSingleRowSelection> ()

Get whether or not the grid is in single row selection mode.

=item C<SetSingleColSelection> ([bSing = TRUE])

Sets the grid into (or out of) Single column selection mode.
When in this mode, only a single column at a time can be selected.

=item C<GetSingleColSelection> ()

Get whether or not the grid is in single column selection mode.

=item C<EnableSelection> ([bEnable = TRUE])

Sets whether or not the grid cells can be selected.

=item C<IsSelectable> ()

Get whether or not grid cells are selectable.

=item C<SetFixedRowSelection> ([bSelect = TRUE])

Set whether or not clicking on a fixed row selects the cells
next to it.

=item C<GetFixedRowSelection> ()

Get whether or not clicking on a fixed row selects the cells
next to it.

=item C<SetFixedColumnSelection> ([bSelect = TRUE])

Set whether or not clicking on a fixed column selects the
cells underneath.

=item C<GetFixedColumnSelection> ()

Get whether or not clicking on a fixed column selects the
cells underneath.

=item C<EnableDragAndDrop> ([bAllow = TRUE]);

Sets whether drag and drop is enabled.

=item C<GetDragAndDrop> ()

Get whether drag and drop is allowed.

=item C<SetRowResize> ([bResize = TRUE])

Sets whether or not rows can be resized.

=item C<GetRowResize> ()

Gets whether or not rows can be resized.

=item C<SetColumnResize> ([bResize = TRUE])

Sets whether or not columns can be resized.

=item C<GetColumnResize> ()

Gets whether or not columns can be resized.

=item C<SetHandleTabKey> ([bHandleTab = TRUE])

Sets whether or not the TAB key is used to move the cell selection.

=item C<GetHandleTabKey> ()

Gets whether or not the TAB key is used to move the cell selection.

=item C<SetDoubleBuffering> ([bBuffer = TRUE])

Sets whether or not double buffering is used when
painting (avoids flicker).

=item C<GetDoubleBuffering> ()

Gets whether or not double buffering is used when painting.

=item C<EnableTitleTips> ([bEnable = TRUE])

Sets whether or not titletips are used.

=item C<GetTitleTips> ()

Gets whether or not titletips are used.

=item C<SetTrackFocusCell> ([bTrack = TRUE])

Sets whether or not the fixed cells on the same row/column
as the current focus cell are highlighted with a sunken border.

=item C<GetTrackFocusCell> ()

Gets whether or not the fixed cells on the same row/column as
the current focus cell are highlighted with a sunken border.

=item C<SetFrameFocusCell> ([bFrame = TRUE])

Sets whether or not the cell with the focus is highlighted
with a framed border.

=item C<GetFrameFocusCell> ()

Gets whether or not the focus cell is highlighted with a
framed border.

=item C<SetAutoSizeStyle> ([nStyle = GVS_BOTH])

Sets how the auto-sizing should be performed.

Possible values.
    GVS_BOTH   = use fixed and non fixed cells;
    GVS_HEADER = use only the fixed cells;
    GVS_DATA   = use only non-fixed cells.

=item C<GetAutoSizeStyle> ()

Gets how the auto-sizing should be performed

=item C<EnableHiddenColUnhide> ([bEnable = TRUE])

Sets whether or not hidden (0-width) columns can be unhidden
by the user resizing the column.

=item C<GetHiddenColUnhide> ()

Gets whether or not hidden (0-width) columns can be unhidden by the
user resizing the column.

=item C<void EnableHiddenRowUnhide> ([bEnable = TRUE])

Sets whether or not hidden (0-height) rows can be unhidden
by the user resizing the row.

=item C<GetHiddenRowUnhide> ()

Gets whether or not hidden (0-height) rows can be unhidden
by the user resizing the row.

=item C<EnableColumnHide> ([bEnable = TRUE])

Sets whether or columns can be contracted to 0 width via mouse.

=item C<GetColumnHide> ()

Gets whether or not columns can be contracted to 0
width via mouse.

=item C<void EnableRowHide> ([bEnable = TRUE])

Sets whether or not rows can be contracted to 0 height
via mouse.

=item C<GetRowHide> ()

Sets whether or not rows can be contracted to 0 height
via mouse.

=back

=head3 Colours

=over

=item C<SetGridBkColor> (color)

Sets the background colour of the control (the area outside
fixed and non-fixed cells).

=item C<GetGridBkColor> ()

Gets the background colour of the control.

=item C<SetGridLineColor> (color)

Sets the colour of the gridlines.

=item C<GetGridLineColor> ()

Gets the colour of the grid lines.

=item C<SetTitleTipBackClr> (clr = CLR_DEFAULT)

Sets the background colour of the titletips.

=item C<GetTitleTipBackClr> ()

Gets the background colour of the titletips.

=item C<SetTitleTipTextClr> (clr = CLR_DEFAULT)

Sets the text colour of the titletips.

=item C<GetTitleTipTextClr> ()

Gets the text colour of the titletips.

=back

=head3 Default Cell setting

Change and query the default cell implementation for the desired
cell type.  bFixedRow and bFixedCol specify whether the cell
is fixed (in row, column or both) or unfixed.
Use this to set default properties for the grid.
Actual cells in the grid have their values set as default values
when they are first created.
They will use GetDefCell to query the grids default cell
properties and use these values for drawing themselves.

=over

=item C<SetDefCellTextColor> (bFixedRow, bFixedCol, [clr = CLR_DEFAULT])

Sets the text colour of the default cell type.

=item C<GetDefCellTextColor> (bFixedRow, bFixedCol)

Gets the text colour of default cell type.

=item C<SetDefCellBackColor> (bFixedRow, bFixedCol, [clr = CLR_DEFAULT])

Sets the background colour of the default cell type.

=item C<GetDefCellBackColor> (bFixedRow, bFixedCol)

Sets the background colour of the default cell type.

=item C<SetDefCellWidth> (bFixedRow, bFixedCol, nWidth)

Sets the width of default cell type.

=item C<GetDefCellWidth> (bFixedRow, bFixedCol)

Gets the width of default cell type.

=item C<SetDefCellHeight> (bFixedRow, bFixedCol, height)

Sets the height of default cell type.

=item C<GetDefCellHeight> (bFixedRow, bFixedCol)

Gets the height of default cell type.

=item C<SetDefCellMargin> (bFixedRow, bFixedCol, nMargin)

Sets the Margin of default cell type.

=item C<GetDefCellMargin> (bFixedRow, bFixedCol)

Gets the Margin of default cell type.

=item C<SetDefCellFormat> (bFixedRow, bFixedCol, nFormat)

Sets the format of default cell type.

=item C<GetDefCellFormat> (bFixedRow, bFixedCol)

Gets the format of default cell type.

=item C<SetDefCellStyle> (bFixedRow, bFixedCol, dwStyle)

Sets the style of default cell type.

=item C<GetDefCellStyle> (bFixedRow, bFixedCol)

Gets the style of default cell type.

=item C<SetDefCellFont> (bFixedRow, bFixedCol, dwStyle)

Sets the font of default cell type.

=item C<GetDefCellFont> (bFixedRow, bFixedCol)

Gets the font of default cell type.

=back

=head3 Cell type

=over

=item C<SetDefCellType> (iType = GVIT_DEFAULT)

Change default cell type.

Cell type :

    GVIT_NUMERIC = Numeric control edit
    GVIT_DATE    = Date control
    GVIT_DATECAL = Date control with calendar control
    GVIT_TIME    = Time control
    GVIT_CHECK   = Check Box
    GVIT_COMBO   = Combo Box
    GVIT_LIST    = List Box
    GVIT_URL     = Url control

=item C<SetCellType> (nRow, nCol, iType = GVIT_DEFAULT)

Change cell type.

Cell type :

    GVIT_NUMERIC = Numeric control edit
    GVIT_DATE    = Date control
    GVIT_DATECAL = Date control with calendar control
    GVIT_TIME    = Time control
    GVIT_CHECK   = Check Box
    GVIT_COMBO   = Combo Box
    GVIT_LIST    = List Box
    GVIT_URL     = Url control

=item C<SetCellCheck> (nRow, nCol, bChecked = TRUE)

Set check box state. (GVIT_CHECK Only)

=item C<GetCellCheck> (nRow, nCol)

Get check box state. (GVIT_CHECK Only)

=item C<SetCellOptions> (nRow, nCol, ...)

Set cells options.

For GVIT_COMBO, GVIT_LIST : An array reference with list of
string value (["Option1","Option2"])

For GVIT_CHECK :
    -checked => 0/1 : Set check.

For GVIT_URL :
    -autolaunch => 0/1 : Set autolauch mode (default : 1).

=back

=head3 Cell Attribut

=over

=item C<SetModified> ([bModified = TRUE], [nRow = -1], [nCol = -1])

Sets the modified flag for a cell.
If no row or columns is specified, then change affects
the entire grid.

=item C<GetModified> ([nRow = -1], [nCol = -1])

Gets the modified flag for a cell, or if no cell, it returns
the status for the entire grid.

=item C<SetCellText> (nRow, nCol, str)

Sets the text for the given cell. Returns TRUE on success

=item C<GetCellText> (nRow, nCol)

Gets the text for the given cell.

=item C<SetCellData> (nRow, nCol, lParam)

Sets the lParam (user-defined data) field for the given cell.
Returns TRUE on success.

=item C<GetCellData> (nRow, nCol)

Gets the lParam (user-defined data) field for the given cell.

=item C<SetCellImage> (nRow, nCol, iImage)

Sets the image index for the given cell. Returns TRUE on success.

=item C<GetCellImage> (nRow, nCol)

Gets the image index for the given cell.

=item C<SetCellState> (nRow, nCol, state)

Sets the state of the given cell. Returns TRUE on success.

=item C<GetCellState> (nRow, nCol)

Gets the state of the given cell.

=item C<SetCellFormat> (nRow, nCol, nFormat)

Sets the format of the given cell.
Returns TRUE on success.

Default implementation of cell drawing uses CDC::DrawText, so
any of the DT_* formats are available:

    DT_TOP
    DT_LEFT
    DT_CENTER
    DT_RIGHT
    DT_VCENTER
    DT_BOTTOM
    DT_WORDBREAK
    DT_SINGLELINE
    DT_EXPANDTABS
    DT_TABSTOP
    DT_NOCLIP
    DT_EXTERNALLEADING
    DT_CALCRECT
    DT_NOPREFIX
    DT_INTERNAL
    DT_EDITCONTROL
    DT_PATH_ELLIPSIS
    DT_END_ELLIPSIS
    DT_MODIFYSTRING
    DT_RTLREADING
    DT_WORD_ELLIPSIS

=item C<GetCellFormat> (nRow, nCol)

Gets the format of the given cell (default returns a
CDC::DrawText DT_* format).

=item C<SetCellBkColor> (nRow, nCol, [color = CLR_DEFAULT])

Sets the background colour of the given cell.
Returns TRUE on success

=item C<GetCellBkColor> (nRow, nCol)

Gets the background colour of the given cell.

=item C<SetCellColor> (nRow, nCol, [color = CLR_DEFAULT])

Sets the foreground colour of the given cell.
Returns TRUE on success.

=item C<GetCellColor> (nRow, nCol)

Gets the foreground colour of the given cell.

=item C<SetCellFont> (nRow, nCol, ...)

Sets the font of the given cell. Returns TRUE on success.

=item C<GetCellFont> (nRow, nCol)

Gets the font of the given cell.

=item C<EnsureCellVisible> (nRow, nCol)

Ensures that the specified cell is visible.

=item C<IsCellVisible> (nRow, nCol)

Returns TRUE if the cell is visible.

=item C<IsCellSelected> (nRow, nCol)

Returns TRUE if the cell is selected

=item C<SetCellEditable> (nRow, nCol, [bEditable = TRUE])

Sets the edtitable state of the given cell.

=item C<IsCellEditable> (nRow, nCol)

Returns TRUE if the cell is editable.

=item C<IsCellEditing> (nRow, nCol)

Returns TRUE if the cell is currently being edited.

=item C<IsCellFixed> (nRow, nCol)

Returns TRUE if the cell is a fixed cell.

=item C<GetSelectedCount> ()

Gets the number of selected cells.

=item C<SetFocusCell> (nRow, nCol)

Sets the cell with the focus

=item C<GetFocusCell> ()

Gets the cell with the focus.

=back

=head3 Row and Column operation

=over

=item C<InsertColumn> (strHeading, [nFormat = DT_CENTER|DT_VCENTER|DT_SINGLELINE], [nColumn = -1])

Inserts a column at the position given by nCol, or at the end of
all columns if nCol is < 0.
strHeading is the column heading and nFormat the format.
Returns the position of the inserted column.

=item C<InsertRow> (strHeading, [nRow = -1])

Inserts a row at the position given by nRow, or at the end of
all rows if nRow is < 0.
strHeading is the row heading.
The format of each cell in the row will be that of the cell
in the first row of the same column.
Returns the position of the inserted row.

=item C<DeleteColumn> (nColumn)

Deletes column "nColumn", return TRUE on success.

=item C<DeleteRow> (nRow)

Deletes row "nRow", return TRUE on success.

=item C<DeleteAllCells> ()

Deletes all rows and contents in the grid.

=item C<DeleteNonFixedRows> ()

Deletes all non-fixed rows in the grid.

=item C<AutoSizeRow> (nRow, [bResetScroll = TRUE])

Auto sizes the row to the size of the largest item.
If bResetScroll is TRUE then the scroll bars will be reset.

=item C<AutoSizeColumn> (nCol, [nAutoSizeStyle = GVS_DEFAULT], [bResetScroll = TRUE])

Auto sizes the column to the size of the largest item.
nAutoSizeStyle sets the way the autosize will occur.
If bResetScroll is TRUE then the scroll bars will be reset.

AutoSizing options :

    GVS_DEFAULT = default
    GVS_HEADER  = Size using column fixed cells data only
    GVS_DATA    = Size using column non-fixed cells data only
    GVS_BOTH    =  Size using column fixed and non-fixed

=item C<AutoSizeRows> ()

Auto sizes all rows.

=item C<AutoSizeColumns> ([nAutoSizeStyle = GVS_DEFAULT])

Auto sizes all columns.
nAutoSizeStyle sets the way the autosize will occur.

AutoSizing options :

    GVS_DEFAULT = default
    GVS_HEADER  = Size using column fixed cells data only
    GVS_DATA    = Size using column non-fixed cells data only
    GVS_BOTH    =  Size using column fixed and non-fixed

=item C<AutoSize> ([nAutoSizeStyle = GVS_DEFAULT])

Auto sizes all rows and columns.
nAutoSizeStyle sets the way the autosize will occur.

AutoSizing options :

    GVS_DEFAULT = default
    GVS_HEADER  = Size using column fixed cells data only
    GVS_DATA    = Size using column non-fixed cells data only
    GVS_BOTH    =  Size using column fixed and non-fixed

=item C<ExpandColumnsToFit> ([bExpandFixed = TRUE])

Expands the column widths to fit the grid area.
If bExpandFixed is TRUE then fixed columns will be modified,
otherwise they will not be affected.

=item C<ExpandLastColumn> ()

Expands the last column width to fill any remaining grid area.

=item C<ExpandRowsToFit> ([bExpandFixed = TRUE])

Expands the row heights to fit the grid area.
If bExpandFixed is TRUE then fixed rows will be modified,
otherwise they will not be affected.

=item C<ExpandToFit> ([bExpandFixed = TRUE])

Expands the rows and columns to fit the grid area.
If bExpandFixed is TRUE then fixed cells will be modified,
otherwise they will not be affected.

=item C<SetRedraw> (bAllowDraw, [bResetScrollBars = FALSE])

Stops/starts redraws on things like changing the number of rows
and columns and autosizing, but not for user-intervention such
as resizes.

=item C<RedrawCell> (nRow, nCol, [hDC=0])

Redraws the given cell. Drawing will be via the hDC if
one is supplied.

=item C<RedrawRow> (row)

Redraws the given row.

=item C<RedrawColumn> (col);

Redraws the given column.

=item C<Refresh> ()

Redraws the entire grid.

=item C<GetCellRange> ()

Gets the range of cells for the entire grid.
Return an [nMinRow, nMinCol, nMaxRow, nMaxCol] array.

=item C<SetSelectedCellRange> (nMinRow, nMinCol, nMaxRow, nMaxCol, [bForceRepaint = FALSE], [bSelectCells = TRUE])

Sets the range of selected cells.

=item C<GetSelectedCellRange> ()

Gets the range of selected cells.
Return an [nMinRow, nMinCol, nMaxRow, nMaxCol] array.

=item C<IsValid> (nRow, nCol)

Returns TRUE if the given row and column is valid.

=item C<GetNextCell> (nRow, nCol, nFlags)

Searches for a cell that has the specified properties and
that bears the specified relationship to a given item.

Cell Searching options :

    GVNI_FOCUSED     = Search for focus cell
    GVNI_SELECTED    = Search for selected cells
    GVNI_DROPHILITED = Search for drop highlighted cells
    GVNI_READONLY    = Search for read-only cells
    GVNI_FIXED       = Search for fixed cells
    GVNI_MODIFIED    = Search for modified cells
    GVNI_ABOVE       = Search above initial cell
    GVNI_BELOW       = Search below initial cell
    GVNI_TOLEFT      = Search to the left of the initial cell
    GVNI_TORIGHT     = Search to the right of the initial cell
    GVNI_ALL         = Search all cells in the grid starting from the given cell
    GVNI_AREA        = Search all cells below and to the right of the given cell

=item C<ClearCells> (nMinRow, nMinCol, nMaxRow, nMaxCol)

Clear cell in range.

=item C<AutoFill> ()

Auto fill witk blank cell.

=back

=head3 Sorting

=over

=item C<SetHeaderSort> ([bSortOnClick = TRUE])

Sets whether or not rows are sorted on column header clicks
in ListMode.

=item C<GetHeaderSort> ()

Gets whether or not rows are sorted on column header clicks
in ListMode.

=item C<SetSortColumn> (nCol)

Sets the index of the currently sorted column.

=item C<GetSortColumn> ()

Gets the index of the currently sorted column.

=item C<SetSortAscending> ([bAscending = TRUE])

Sets whether the current sort column is sorted ascending.

=item C<GetSortAscending> ()

Gets whether the current sort column is sorted ascending.

=item C<SortTextCells> (nCol, bAscending)

Sorts the grid on the given column based on cell text.
Returns TRUE on success

=item C<SortNumericCells> (nCol, bAscending)

Sorts the grid on the given column based on cell numeric text.
Returns TRUE on success

=item C<SortCells> (nCol, bAscending, [pfun = NULL])

Sort given method and given sort order.
Optional a custom sort fonction.

Sort Function sample :

  sub { my ($e1, $e2) = @_; return (int($e1) - int ($e2)); }

=item C<SetSortFunction> ([pFun = NULL], [nCol = -1])

Set or Remove Perl sort function.

If nCol is -1, Set or remove a default sort method.
If nCol is a valid column , Set or remove a sort method
for this column only.

Sort Function sample :

  sub { my ($e1, $e2) = @_; return (int($e1) - int ($e2)); }

=back

=head3 Printing

  TODO

=head3 Save and load method

=over

=item C<Save> (filename, [chSeparator = ',']);

TBD

=item C<Load> (filename, [chSeparator = ',']);

TBD

=back

=head3 Clipboard

=over

=item C<OnEditCut> ()

Copies contents of selected cells to clipboard and deletes the
contents of the selected cells. (Ctrl-X)

=item C<OnEditCopy> ()

Copies contents of selected cells to clipboard. (Ctrl-C)

=item C<OnEditPaste> ()

Pastes the contents of the clipboard to the grid. (Ctrl-V)

=item C<OnEditSelectAll> ()

Not actually a clipboard function, but handy nevertheless.
This routine selects all cells in the grid. (Ctrl-A)

=back

=head2 Grid Event

=over

=item C<_Click> (nRow, nCol)

Simple left click event.

=item C<_RClick> (nRow, nCol)

Simple right click event.

=item C<_DblClick> (nRow, nCol)

Double left click event.

=item C<_Changing> (nRow, nCol)

Start changing selection event.

=item C<_Changed> (nRow, nCol)

Selection have change event.

=item C<_BeginEdit> (nRow, nCol)

Start Cell Edit event.
Return non zero value to prevent editing.

=item C<_ChangedEdit> (nRow, nCol, str)

ListBox selection change event.
str is current selected item.
Available with GVIT_COMBO, GVIT_LIST.

=item C<_EndEdit> (nRow, nCol, [str])

End Cell Edit event.
Return non zero value to prevent change.

  [virtual Mode Only]
  str contains edited cell data.

=item C<_BeginDrag> (nRow, nCol)

Begin drag event.

=item C<_GetData> (nRow, nCol)

  [virtual Mode Only]
  You must return cell data.

=item C<_CacheHint> (nMinRow, nMinCol, nMaxRow, nMaxCol)

  [virtual Mode Only]
  Range before request data.

=back

=head1 SEE ALSO

=over

=item L<Win32::GUI|Win32::GUI>

=item L<http://perl-win32-gui.sourceforge.net/>

=item L<http://www.codeproject.com/miscctrl/gridctrl.asp>

MFC Grid Control by Chris Maunder

=back

=head1 DEPENDENCIES

Win32::GUI
Microsoft Foundation Classes (MFC)

=head1 AUTHOR

Laurent Rocher (lrocher@cpan.org)

=head1 COPYRIGHT AND LICENCE

Copyright 2003..2006 by Laurent Rocher (lrocher@cpan.org).

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
See L<http://www.perl.com/perl/misc/Artistic.html>

Modified code from the MFC Grid control by Chris Maunder is statically linked
into this module.  The MFC Grid control is released with the following
notice:

  This code may be used in compiled form in any way you desire
  (including commercial use). The code may be redistributed unmodified
  by any means providing it is not sold for profit without the authors
  written consent, and providing that this notice and the authors name
  and all copyright notices remains intact. However, this file and the
  accompanying source code may not be hosted on a website or bulletin
  board without the authors written permission.

  This software is provided "as is" without express or implied
  warranty. Use it at your own risk!

  Whilst I have made every effort to remove any undesirable "features",
  I cannot be held responsible if it causes any damage or loss of time
  or data.

=cut
