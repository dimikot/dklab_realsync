package Win32::GUI::GridLayout;

$Win32::GUI::GridLayout::VERSION = "0.06";
$Win32::GUI::GridLayout::VERSION = eval $Win32::GUI::GridLayout::VERSION;

sub new {
    my($class, $c, $r, $w, $h, $xpad, $ypad) = @_;
    my $r_grid = {
        "cols"   => $c,
        "rows"   => $r,
        "width"  => $w,
        "height" => $h,
        "xPad"   => $xpad,
        "yPad"   => $ypad,
    };
    bless $r_grid, $class;
    return $r_grid;
}

sub apply {
    my($class, $to, $c, $r, $xpad, $ypad) = @_;
    my $w = $to->ScaleWidth();
    my $h = $to->ScaleHeight();
    my $r_grid = {
        "cols"   => $c,
        "rows"   => $r,
        "width"  => $w,
        "height" => $h,
        "xPad"   => $xpad,
        "yPad"   => $ypad,
        "source" => $to,
        "content" => [],
    };
    bless $r_grid, $class;
    return $r_grid;
}

sub add {
    my($grid, $o, $c, $r, $align) = @_;    
    my @content = @{$grid->{'content'}};
    my($halign, $valign) = split(/\s*,\s*|\s+/, $align);
    push(@content, [$o, $c, $r, $halign, $valign] );
    $grid->{'content'} = [@content];
}

sub recalc {
    my($grid) = @_;    
    $grid->{'width'}  = $grid->{'source'}->ScaleWidth();
    $grid->{'height'} = $grid->{'source'}->ScaleHeight();

    if(ref $grid->{'cols'} eq 'ARRAY') {
        my @colw = @{$grid->{'cols'}};
        my @absw = grep(/^\d+$/, @colw);
        my $absw = 0;
        map($absw+=$_, @absw);
        my $relw = int(($grid->{'width'}-$absw)/($#colw-$#absw));
        for my $i (0..$#colw) {
            $grid->{'_cols_w'}[$i] = ($colw[$i] eq '*') ? $relw : $colw[$i];
        }
    }
    else {
        my $relw = int($grid->{'width'}/$grid->{'cols'});
        for my $i (0..($grid->{'cols'}-1)) {
            $grid->{'_cols_w'}[$i] = $relw;
        }
    }

    if(ref $grid->{'rows'} eq 'ARRAY') {
        my @rowh = @{$grid->{'rows'}};
        my @absh = grep(/^\d+$/, @rowh);
        my $absh = 0;
        map($absh+=$_, @absh);
        my $relh = int(($grid->{'height'}-$absh)/($#rowh-$#absh));
        for my $i (0..$#rowh) {
            $grid->{'_rows_h'}[$i] = ($rowh[$i] eq '*') ? $relh : $rowh[$i];
        }
    }
    else {
        my $relh = int($grid->{'height'}/$grid->{'rows'});
        for my $i (0..($grid->{'rows'}-1)) {
            $grid->{'_rows_h'}[$i] = $relh;
        }
    }

    foreach my $inside (@{$grid->{'content'}}) {       
        $grid->{'widgetWidth'} = $inside->[0]->Width();
        $grid->{'widgetHeight'} = $inside->[0]->Height();
        if($inside->[3] =~ /^j/i) {
            $inside->[0]->Resize(
                $grid->col_w($inside->[1]),
                $inside->[0]->Height,
            );
        }
        
        if($inside->[4] =~ /^j/i) {
            $inside->[0]->Resize(
                $inside->[0]->Width,
                $grid->row_h($inside->[2]),
            );
        }
        
        $inside->[0]->Move(
            $grid->col($inside->[1], $inside->[3]),
            $grid->row($inside->[2], $inside->[4]),
        );
    }
}

sub draw {
    my($grid) = @_;
    return undef unless $grid->{'source'};
    my $DC = $grid->{'source'}->GetDC();
    my $colWidth = int($grid->{'width'} / $grid->{'cols'});
    my $rowHeight = int($grid->{'height'} / $grid->{'rows'});
    my($i, $s);
    $s = 0;
    for my $i (@{$grid->{'_cols_w'}}) {
        $s += $i;
        $DC->MoveTo($s, 0);
        $DC->LineTo($s, $grid->{'height'});
    }
    $s = 0;
    for my $i (@{$grid->{'_rows_h'}}) {
        $s += $i;
        $DC->MoveTo(0, $s);
        $DC->LineTo($grid->{'width'}, $s);
    }
}

sub column {
    my($grid_param, $col, $align) = @_;
    $col = [$col] unless(ref $col);
    $col = [map($_-1, @$col)];
    my $x = 0;
    my $colWidth = 0;
    if($grid_param->{'_cols_w'}) {
        my @colw = @{$grid_param->{'_cols_w'}};
        for(@$col) {
            $colWidth += $colw[$_];
        }
        for(my $i=0; $i<=$col->[0]-1; $i++) {
            $x += $colw[$i];
        }
        $x += $grid_param->{'xPad'};
    }
    else {
        $colWidth = int($grid_param->{'width'} / $grid_param->{'cols'}
            *($#$col+1));
        $x = ($col->[0] * $colWidth) + ($grid_param->{'xPad'});
    }
    $x += int(($colWidth - $grid_param->{'widgetWidth'}) / 2)
        if $align =~ /^c/i;
    $x += ($colWidth - $grid_param->{'widgetWidth'}) - 2*$grid_param->{'xPad'}
        if $align =~ /^r/i;
    $grid_param->{'widgetWidth'} = 0; # in case a width declaration is missed or not used
    return $x;
}
sub col { column @_; }

sub row {
    my($grid_param, $row, $align) = @_;
    $row = [$row] unless(ref $row);
    $row = [map($_-1, @$row)];
    my $y = 0;
    my $rowHeight = 0;
    if($grid_param->{'_rows_h'}) {
        my @rowh = @{$grid_param->{'_rows_h'}};
        for(@$row) {
            $rowHeight = $rowh[$_];
        }
        for(my $i=0; $i<=$row->[0]-1; $i++) {
            $y += $rowh[$i];
        }
        $y += $grid_param->{'yPad'};
    }
    else {
        $rowHeight = int($grid_param->{'height'} / $grid_param->{'rows'})
            *($#$row+1);
        $y = ($row->[0] * $rowHeight) + ($grid_param->{'yPad'});
    }

    $y += int(($rowHeight - $grid_param->{'widgetHeight'}) / 2)
        if $align =~ /^c/i;
    $y += ($rowHeight - $grid_param->{'widgetHeight'}) - 2*$grid_param->{'yPad'}
        if $align =~ /^b/i;
    $grid_param->{'widgetHeight'} = 0; # same reason as coment in &column
    return $y;
}

sub width {
    my ($grid_param,$w) = @_;
    $grid_param->{'widgetWidth'} = $w;
    return $grid_param->{'widgetWidth'};
}

sub height {
    my ($grid_param,$h) = @_;
    $grid_param->{'widgetHeight'} = $h;
    return $grid_param->{'widgetHeight'};
}

sub col_w {
    my($grid_param, $col) = @_;
    $col = [$col] unless(ref $col);
    my $w = 0;
    for my $col (@$col) {
        $w += $grid_param->{'_cols_w'}[$col-1];
    }
    
    $w -= 2*$grid_param->{'xPad'};
    return $w;
}

sub row_h {
    my($grid_param, $row) = @_;
    $row = [$row] unless(ref $row);
    my $h = 0;
    for my $row (@$row) {
        $h += $grid_param->{'_rows_h'}[$row-1];
    }
    
    $h -= 2*$grid_param->{'yPad'};
    return $h;
}

1;

__END__

=head1 NAME

Win32::GUI::GridLayout - Grid layout support for Win32::GUI

=head1 SYNOPSIS

    use Win32::GUI::
    use Win32::GUI::GridLayout;

    # 1. make a "static" grid
    $grid = new Win32::GUI::GridLayout(400, 300, 3, 3, 0, 0);
    
    $win = new Win32::GUI::Window(
    
    $win->AddLabel(
        -name => "label1",
        -text => "Label 1",
        -width  => $grid->width(35),
        -height => $grid->height(11),
        -left   => $grid->col(1, "left"),
        -top    => $grid->row(1, "top"),
    );
    
    # 2. make a "dynamic" grid
    $grid = apply Win32::GUI::GridLayout($win, 3, 3, 0, 0);
        or
    $grid = apply Win32::GUI::GridLayout($win,
        [qw(10 * * 10)],
        [qw(10 * 40)],
        0, 0);
    
    $win->AddLabel(
        -name => "label1",
        -text => "Label 1",
    );
    $grid->add($win->label1, 1, 1, "left top");
       or
    $grid->add($win->label1, [2..3], 1, "justify justify");

    $grid->recalc();

=head1 DESCRIPTION



=head2 Constructors

=over 4

=item new Win32::GUI::GridLayout(COLS, ROWS, WIDTH, HEIGHT, XPAD, YPAD)

=item apply Win32::GUI::GridLayout(WINDOW, COLS, ROWS, XPAD, YPAD)

COLS - quantity of columns or arrayref of width colomns (number - absolute width, * - relative width)

ROWS - quantity of rows or arrayref of height rows (number - absolute height, * - relative height)

=back

=head2 Methods

=over 4

=item add(CONTROL, COL, ROW, ALIGN)

Adds CONTROL to the grid at (COL, ROW).
ALIGN can specify both horizontal and vertical
alignment (see the col() and row() methods),
separated by at least one blank and/or a comma.

Example:

    $grid->add($win->label1, 1, 1, "left top");
        or
    $grid->add($win->label1, [2..3], 1, "justify top");

COL and ROW may be arrayref for adds CONTROL into more than one cell.
If ALIGN is justify (j) than CONTROL expands up to cell.


=item col(N, ALIGN)

Positions the control at the Nth column in the grid,
optionally with an ALIGN; this can be feed to a
C<-left> option when creating a control.

ALIGN can be C<left>, C<center> or C<right> (can be 
shortened to C<l>, C<c>, C<r>); default is C<left>.

Note that for alignment to work properly, the width()
and height() methods must have been previously
called.

Example:

    $win->AddLabel(
        -name => "label1",
        -text => "Label 1",
        -width  => $grid->width(35),
        -height => $grid->height(11),
        -left   => $grid->col(1, "left"),
        -top    => $grid->row(1, "top"),
    );      

=item draw()

Draws the GridLayout in the associated window
(may be useful for debugging); is only meaningful
if the GridLayout was created with the apply()
constructor.

=item height(N)

Sets the height of the control for subsequent
alignment; this can be feed to a C<-height> option
when creating a control.

Example: see col().

=item recalc()

Recalculates the grid and repositions all the add()ed 
controls, taking into account the actual window and
controls sizes; 
is only meaningful if the GridLayout was created 
with the apply() constructor.

Example:

    sub Window_Resize {
        $grid->recalc();
    }

=item row(N, ALIGN)

Positions the control at the Nth row in the grid,
optionally with an ALIGN; this can be feed to a
C<-top> option when creating a control.

ALIGN can be C<top>, C<center> or C<bottom> (can be 
shortened to t, c, b); default is top.

Note that for alignment to work properly, the width()
and height() methods must have been previously
called.

Example: see col().

=item width(N)

Sets the width of the control for subsequent
alignment; this can be feed to a C<-width> option
when creating a control.

Example: see col().

=back

=head1 VERSION

=over

=item Win32::GUI::GridLayout version 0.06, June  2006.

=item Win32::GUI::GridLayout version 0.05, 24 June  2005.

=item Win32::GUI::GridLayout version 0.04, 06 April 2005.

=item Win32::GUI::GridLayout version 0.03, 13 April 1999.

=back

=head1 AUTHOR

Original Author Mike Kangas ( C<kangas@anlon.com> );
additional coding by
Aldo Calpini ( C<dada@perl.it> ),
Alexander Romanenko ( C<alex@parom.biz> ),
Robert May ( C<robertemay@users.sourceforge.net> ).

=head1 COPYRIGHT AND LICENCE

Copyright (C) 1999..2005 by Mike Kangas
Copyright (C) 2006 by Robert May

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
