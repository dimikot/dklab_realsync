###############################################################################
#
# Win32::GUI - Perl-Win32 Graphical User Interface Extension
#
# 29 Jan 1997 by Aldo Calpini <dada@perl.it>
#
# Copyright (c) 1997..2006 Aldo Calpini. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: GUI.pm,v 1.69 2008/02/13 15:24:04 robertemay Exp $
#
###############################################################################
package Win32::GUI;

require DynaLoader;     # to dynuhlode the module.
@ISA = qw( DynaLoader );

###############################################################################
# STATIC OBJECT PROPERTIES
#
$VERSION             = "1.06";        # For MakeMaker and CPAN
$XS_VERSION          = $VERSION;      # For dynaloader
$VERSION             = eval $VERSION; # For Perl  (see perldoc perlmodstyle)
$MenuIdCounter       = 101;
$TimerIdCounter      = 1;
$NotifyIconIdCounter = 1;
%Menus               = ();
%Accelerators        = ();
$AcceleratorCounter  = 9001;
%DefClassProc        = ();

###############################################################################
# SUPPORT FOR Win32 API defined constants
#

###############################################################################
# This import() function is used to delegate constants support to
# Win32::GUI::Constants.
# The default exports are deprecated, and will be removed in the future
sub import {
    my $pkg = shift;
    my $callpkg = caller;
    my @imports = @_;

    # Don't let this import() get inherited
    return unless $pkg eq 'Win32::GUI';

    # use Win32::GUI; currently exports a load of constants for
    # backwards compatibility with earlier Win32::GUI versions.
    # This is deprecated, and in the future
    #  use Win32::GUI;   and
    #  use Win32::GUI();   will have the same behaviour.
    if(@imports == 0) {
        use warnings;
	warnings::warnif 'deprecated',
       	    "'use Win32::GUI;' is currently exporting constants into ".
	    "the callers scope. This functionality is deprecated. ".
	    "Use 'use Win32::GUI();' or list your required exports ".
            "explicitly instead.";
	@imports = qw(:compatibility_win32_gui);
    }
    # Except for version checking, delegate everything else to
    # Win32::GUI::Constants directly, noting any -exportpkg pragma
    my @exports;
    my $setpkg = 0;
    for my $spec (@imports) {
        # Always expect the export package name immediately after
        # the -exportpkg pragma
        $callpkg=$spec,$setpkg=0, next if $setpkg;
        $setpkg=1,                next if $spec =~ /^-exportpkg$/;
        $pkg->VERSION($spec),     next if $spec =~ /^\d/;    # inherit from UNIVERSAL
	next if length $spec == 0;  # throw away ''.
        push @exports, $spec;
    }
    # if called by use Win32::GUI 1.03,''; for version check only
    # then there is nothign to export, so don't do require etc.
    if(@exports) {
        require Win32::GUI::Constants;
        Win32::GUI::Constants->import("-exportpkg", $callpkg, @exports);
    }
}

###############################################################################
# This constant() function is used to delegate constants support to
# Win32::GUI::Constants.  Usage of this is deprecated and will be removed
# in the future
sub constant {
    my $constant = shift;
    use warnings;
    if($constant =~ /^WIN32__GUI__/) {
        warnings::warnif 'deprecated', "Use of Win32::GUI::constant() is deprecated. ".
            "Use Win32::GUI::_constant() instead for WIN32__GUI__* constants.";
        return Win32::GUI::_constant($constant);
    }

    warnings::warnif 'deprecated', "Use of Win32::GUI::constant() is deprecated. ".
        "Use Win32::GUI::Constants::constant() instead.";
    require Win32::GUI::Constants;
    return Win32::GUI::Constants::constant($constant);
}

###############################################################################
# This AUTOLOAD is used to 'autoload' constants.  Constant support is now
# delegated to Win32::GUI::Constants.  Use of this is deprecated, and will be
# removed in the future

sub AUTOLOAD {
    my $constant = $AUTOLOAD;
    $constant =~ s/.*:://;
    my ($callpkg, $file, $line) = caller;
    require Win32::GUI::Constants;
    my $val = Win32::GUI::Constants::constant($constant);

    if(defined $val) {
        no warnings; # avoid perl 5.6 warning about prototype mismatches
        eval "sub $AUTOLOAD() {$val}";
        use warnings;
        warnings::warnif 'deprecated',
            "Use of '$AUTOLOAD' is deprecated. Use 'Win32::GUI::Constants::$constant' instead.";
        goto &$AUTOLOAD;
    }

    #TODO - should we die?  Many unknown methods may also end up here - can we find a better wording?
    die "Can't find '$constant' in package ". __PACKAGE__ .
                ". Used at $file line $line.\n";
}

sub bootstrap_subpackage {
    my($package) = @_;
    $package = 'Win32::GUI::' . $package;
    my $symbol = $package;
    $symbol =~ s/\W/_/g;
    no strict 'refs';
    DynaLoader::dl_install_xsub(
        "${package}::bootstrap",
        DynaLoader::dl_find_symbol_anywhere( "boot_$symbol" )
    );
    &{ "${package}::bootstrap" };
}

bootstrap Win32::GUI;

###############################################################################
# PUBLIC METHODS
# (@)PACKAGE:Win32::GUI
# Common Methods
# The Win32::GUI package defines a set of methods that apply to most windows and
# controls. Some of the methods are applicable to resources. See the individual
# method documentation for more details.

    ###########################################################################
    # (@)METHOD:Version()
    # Returns the module version number.
sub Version {
    return $VERSION;
}

    ###########################################################################
    # (@)INTERNAL:MakeMenu(...)
    # better used as new Win32::GUI::Menu(...)
sub MakeMenu {
    my(@menudata) = @_;
    my $i;
    my $M = new Win32::GUI::Menu();
    my $text;
    my %data;
    my $level;
    my %last;
    my $parent;
    for($i = 0; $i <= $#menudata; $i += 2) {
        $text = $menudata[$i];
        undef %data;
        if(ref($menudata[$i+1])) {
            %data = %{$menudata[$i+1]};
        } elsif ($menudata[$i+1] eq '' ) {
            $data{-name} = "dummy$MenuIdCounter";
        } else {
            $data{-name} = $menudata[$i+1];
        }
        $level = 0;
        $level++ while($text =~ s/^\s*>\s*//);

        # print "PM(MakeMenu) processing '$data{-name}', level=$level\n";

        if($level == 0) {
            $M->{$data{-name}} = $M->AddMenuButton(
                -id => $MenuIdCounter++,
                -text => $text,
                %data,
            );
            $last{$level} = $data{-name};
            $last{$level+1} = "";
        } elsif($level == 1) {
            $parent = $last{$level-1};
            if($text eq "-") {
                $M->{$data{-name}} = $M->{$parent}->AddMenuItem(
                    -item => 0,
                    -id => $MenuIdCounter++,
                    -separator => 1,
                    -name => $data{-name},
                );
            } else {
                $M->{$data{-name}} = $M->{$parent}->AddMenuItem(
                    -item => 0,
                    -id => $MenuIdCounter++,
                    -text => $text,
                    %data,
                );
            }
            $last{$level} = $data{-name};
            $last{$level+1} = "";
        } else {
            $parent = $last{$level-1};
            if(!$M->{$parent."_Submenu"}) {
                $M->{$parent."_Submenu"} = new Win32::GUI::Menu();
                $M->{$parent."_SubmenuButton"} =
                    $M->{$parent."_Submenu"}->AddMenuButton(
                        -id => $MenuIdCounter++,
                        -text => $parent,
                        -name => $parent."_SubmenuButton",
                    );
                $M->{$parent}->Change(
                    -submenu => $M->{$parent."_SubmenuButton"}
                );
            }
            if($text eq "-") {
                $M->{$data{-name}} =
                    $M->{$parent."_SubmenuButton"}->AddMenuItem(
                        -item => 0,
                        -id => $MenuIdCounter++,
                        -separator => 1,
                        -name => $data{-name},
                    );
            } else {
                $M->{$data{-name}} =
                    $M->{$parent."_SubmenuButton"}->AddMenuItem(
                        -item => 0,
                        -id => $MenuIdCounter++,
                        -text => $text,
                        %data,
                    );
            }
            $last{$level} = $data{-name};
            $last{$level+1} = "";
        }
    }
    return $M;
}

    ###########################################################################
    # (@)INTERNAL:_new(TYPE, %OPTIONS)
    # This is the generalized constructor;
    # it works pretty well for almost all controls.
    # However, other kind of objects may overload it.
sub _new {
    # this is always Win32::GUI (class of _new):
    my $xclass = shift;

    # the window type passed by new():
    my $type = shift;

    # this is the real class:
    my $class = shift;

    my %tier;
    my $oself = $tier{-OSELF} = {};
    tie %tier, $class, $oself;
    my $self = bless \%tier, $class;

    # print "OSELF = $oself\n";
    # print " SELF = $self\n";

    my (@input) = @_;
    # print "PM(Win32::GUI::_new) self='$self' type='$type' input='@input'\n";
    my $handle = Win32::GUI::Create($self, $type, @input);

    if($handle) {
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)METHOD:AcceptFiles([FLAG])
    # Gets/sets the L<-acceptfiles|Win32::GUI::Reference::Options/acceptfiles>
    # options on a window.  If C<FLAG> is not provided, returns the current
    # state.  If FLAG is provided it sets or unsets the state, returning the
    # previous state.
sub AcceptFiles {
    my $win = shift;
    my $accept = shift;

    # my $old_accept = $win->GetWindowLong(GWL_EXSTYLE) & WS_EX_ACCEPTFILES() ? 1 : 0;
    my $old_accept = $win->GetWindowLong(-20) & 0x00000010 ? 1 : 0;

    if(defined $accept) {
        $win->Change(-acceptfiles => $accept);
    }

    return $old_accept;
}

    ###########################################################################
    # (@)METHOD:UserData([value])
    # Sets or reads user data associated with the window or control.
    #
    #  my $data=$win->UserData();#retrieve any data associated with the window
    #  $win->UserData('some string');#associate user data to the window
    #
    # User data can be any perl scalar or reference.
    #
    # When reading returns the stored user data, or undef if nothing is stored.
    # When setting returns a true value if the user data is stored correctly, or
    # a false value on error
    #
    # If you are writing a class that you expect others to use, then this
    # method should B<NOT> be used to store class instance data. See
    # L<ClassData()|Win32::GUI::Reference::Methods/ClassData> instead.
sub UserData {
    my $win = shift;
    my $data = shift;

    if(@_) { # more items than expected passed: someone probably tried
             # passsing an array or hash
        warn("UserData: too many arguments");
        return 0;
    }

    if(defined $data) { # Setting user data
        $win->_UserData()->{UserData} = $data;
        return 1;
    }
    else {              # reading user data
        return $win->_UserData()->{UserData};
    }
}

    ###########################################################################
    # (@)METHOD:ClassData([value])
    # Sets or reads class instance data associated with the window or control.
    #
    #  my $data=$win->ClassData();#retrieve any data associated with the window
    #  $win->ClassData('some string');#associate data to the window
    #
    # Class instance data can be any perl scalar or reference.
    #
    # When reading returns the stored instance data, or undef if nothing is
    # stored.
    # When setting returns a true value if the instance data is stored
    # correctly, or a false value on error
    #
    # Class instance data is private to the package that sets the data.  I.e. it
    # is only accessable as a method call from within the package that sets the
    # data, not from a sub-class.  So, if you wish to make data stored this way
    # accessible to sub-classes you must proved assessor methods in your package.
sub ClassData {
    my $win = shift;
    my $data = shift;

    if(@_) { # more items than expected passed: someone probably tried
             # passsing an array or hash
        warn("ClassData: too many arguments");
        return 0;
    }

    my $callpkg = (caller())[0];

    if(defined $data) { # Setting user data
        $win->_UserData()->{$callpkg} = $data;
        return 1;
    }
    else {              # reading user data
        return $win->_UserData()->{$callpkg};
    }
}

    ###########################################################################
    # (@)METHOD:Animate(%OPTIONS)
    # Apply special effects when showing or hiding a window.  Used instead of
    # L<Show()|Win32::GUI::Reference::Methods/Show> or
    # L<Hide()|Win32::GUI::Reference::Methods/Hide>.
    #
    # OPTIONS can take the following values:
    #   -show      => (0|1)                             default: 1
    #     Hide(0) or Show(1) the window
    #
    #   -activate  => (0|1)                             default: 0
    #     Activate the window.  Ignored if hiding the
    #     window
    #
    #   -animation => (roll|slide|blend|center)         default: 'roll'
    #     Animation type:
    #         roll:   use roll animation
    #         slide:  use slide animation
    #         blend:  use a fade effect.  Top-level
    #                 windows only
    #         center: expand out if showing, collapse
    #                 in when hiding
    #
    #   -time      => time                              default: 200
    #     Animation time in milli-seconds
    #
    #   -direction => (lr|tlbr|tb|trbl|rl|brtl|bt|bltr) default: 'lr'
    #     Animation direction (l=left, r=right, t=top, b=bottom).
    #     Ignored for animation types blend and center
    #
    # Returns a true value on success or a false value on failure
    #
    # NOTE: blend animation does not work on Win98.  It is recomended
    # that you always check the return value from this function and
    # issue a suitable Show() or Hide() on failure.
sub Animate {
    my $win = shift;

   my %options = @_;
   my $show      = delete $options{-show};
   my $activate  = delete $options{-activate};
   my $animation = delete $options{-animation};
   my $time      = delete $options{-time};
   my $direction = delete $options{-direction};

   if(keys(%options) != 0) {
       require Carp;
       Carp::carp("Animate: Unrecognised options ".join(", ", keys(%options)));
       return undef
   }

   $show      = 1      unless defined $show;
   $activate  = 0      unless defined $activate;
   $animation = 'roll' unless defined $animation;
   $time      = 200    unless defined $time;
   $direction = 'lr'   unless defined $direction;

   if($animation !~ /roll|slide|blend|center/) {
       require Carp;
       Carp::carp("Animate: Unrecognised animation type: $animation");
       return undef;
   }

   if($direction !~ /lr|tlbr|tb|trbl|rl|brtl|bt|bltr/) {
       require Carp;
       Carp::carp("Animate: Unrecognised direction: $direction");
       return undef unless $direction eq 'blrt'; # blrt allowed for deprection cycle
   }

   # create the flags:
   my $flags = 0;
   $flags |= 65536  unless $show;              # AW_HIDE = 65536
   $flags |= 131072 if ($activate && $show);   # AW_ACTIVATE = 131072

   $flags |= 262144 if $animation eq 'slide';  # AW_SLIDE = 262144
   $flags |= 16     if $animation eq 'center'; # AW_CENTER = 16
   $flags |= 524288 if $animation eq 'blend';  # AW_BLEND = 524288

   # horizontal direction
   $direction =~ /([lr])/;
   $flags |= 1 if defined $1 and $1 eq 'l';    # AW_HOR_POSITIVE = 1
   $flags |= 2 if defined $1 and $1 eq 'r';    # AW_HOR_NEGATIVE = 2
   
   # vertical direction
   $direction =~ /([tb])/;
   $flags |= 4 if defined $1 and $1 eq 't';    # AW_VER_POSITIVE = 4
   $flags |= 8 if defined $1 and $1 eq 'b';    # AW_VER_NEGATIVE = 8

   # Do the animation
   # TODO: AW_BLEND doesn't work under Win98.  There are other failure
   # modes too (e.g. AW_BLEND on non-top-level window.  Should we detect
   # failure and use Show() in that case? Or is that just confusing?
   return $win->_Animate($time, $flags);
}
   
    
###############################################################################
# SUB-PACKAGES
#


###############################################################################
# (@)PACKAGE:Win32::GUI::Font
# Create font resources
package Win32::GUI::Font;
@ISA = qw(Win32::GUI);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Font(%OPTIONS)
    # Creates a new Font object. %OPTIONS are:
    #   -size
    #   -height
    #   -width
    #   -escapement
    #   -orientation
    #   -weight
    #   -bold => 0/1
    #   -italic => 0/1
    #   -underline => 0/1
    #   -strikeout => 0/1
    #   -charset
    #   -outputprecision
    #   -clipprecision
    #   -family
    #   -quality
    #   -name
    #   -face
sub new {
    my $class = shift;
    my $self = {};

    my $handle = Create(@_);

    if($handle) {
        $self->{-handle} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Bitmap
# Create bitmap resources
package Win32::GUI::Bitmap;
@ISA = qw(Win32::GUI);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Bitmap(FILENAME, [TYPE, X, Y, FLAGS])
    # Creates a new Bitmap object reading from FILENAME; all other arguments
    # are optional. TYPE can be:
    #   0  bitmap (this is the default)
    #   1  icon
    #   2  cursor
    # You can eventually specify your desired size for the image with X and
    # Y and pass some FLAGS to the underlying LoadImage API (at your own risk)
    #
    # If FILENAME is a string, then it is first tried as a resource
    # name, then a filename.  If FILENAME is a number it is tried
    # as a resource identifier.
    #
    # Resources are searched for in the current exe (perl.exe unless
    # you have packed your application using perl2exe, PAR or similar),
    # then in the Win32::GUI GUI.dll, and finally as an OEM resource
    # identifier
sub new {
    my $class = shift;
    my $self = {};

    my $handle = Win32::GUI::LoadImage(@_);

    # TODO: this gives us a bitmap object, even if we ask for a cursor!
    if($handle) {
        $self->{-handle} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Icon
# Create Icon resources
package Win32::GUI::Icon;
@ISA = qw(Win32::GUI);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Icon(FILENAME)
    # Creates a new Icon object reading from FILENAME.
    #
    # If FILENAME is a string, then it is first tried as a resource
    # name, then a filename.  If FILENAME is a number it is tried
    # as a resource identifier.
    #
    # Resources are searched for in the current exe (perl.exe unless
    # you have packed your application using perl2exe, PAR or similar),
    # then in the Win32::GUI GUI.dll, and finally as an OEM resource
    # identifier
sub new {
    my $class = shift;
    my $file = shift;
    my $self = {};

    my $handle = Win32::GUI::LoadImage(
        $file,
        1, #Win32::GUI::Constants::constant("IMAGE_ICON"),
    );

    if($handle) {
        $self->{-handle} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)INTERNAL:DESTROY()
sub DESTROY {
    my $self = shift;
    Win32::GUI::DestroyIcon($self);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::Cursor
# Create cursor resources
package Win32::GUI::Cursor;
@ISA = qw(Win32::GUI);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Cursor(FILENAME)
    # Creates a new Cursor object reading from FILENAME.
    #
    # If FILENAME is a string, then it is first tried as a resource
    # name, then a filename.  If FILENAME is a number it is tried
    # as a resource identifier.
    #
    # Resources are searched for in the current exe (perl.exe unless
    # you have packed your application using perl2exe, PAR or similar),
    # then in the Win32::GUI GUI.dll, and finally as an OEM resource
    # identifier
sub new {
    my $class = shift;
    my $file = shift;
    my $self = {};

    my $handle = Win32::GUI::LoadImage(
        $file,
        2, #Win32::GUI::Constants::constant("IMAGE_CURSOR"),
    );

    if($handle) {
        $self->{-handle} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)INTERNAL:DESTROY()
sub DESTROY {
    my $self = shift;
    Win32::GUI::DestroyCursor($self);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Class
# Create Window classes
package Win32::GUI::Class;

    ###########################################################################
    # (@)METHOD: new Win32::GUI::Class(%OPTIONS)
    # Creates a new window class object.
    # Allowed %OPTIONS are:
    #   -name => STRING
    #       the name for the class (it must be unique!).
    #   -icon => Win32::GUI::Icon object
    #   -cursor => Win32::GUI::Cursor object
    #   -color => COLOR
    #       system color use as window background.
    #   -brush => Win32::GUI::Brush object
    #       brush use as window background brush.
    #   -menu => STRING
    #       a menu name (not yet implemented).
    #   -extends => STRING
    #       name of the class to extend (aka subclassing).
    #   -widget => STRING
    #       name of a widget class procedure to use.
    #   -style => FLAGS
    #       use with caution!
    #
    # Don't use -color and -brush as same time.
    #
sub new {
    my $class = shift;
    my %args = @_;
    my $self = {};

    # figure out the correct background color
    # (to avoid the "white background" syndrome on XP)
    if(not exists($args{-color}) and not exists($args{-brush})) {
        my($undef, $major, $minor);
        eval { ($undef, $major, $minor) = Win32::GetOSVersion(); };
        # certain Win32 perls didn't have Win32 in core
        if ($@) {
          eval { require Win32 };
          ($undef, $major, $minor) = Win32::GetOSVersion();
        }
        if($major == 5 && $minor > 0) {
            $args{-color} = 16; #Win32::GUI::Constants::constant("COLOR_BTNFACE")+1;
        } else {
            $args{-color} = 5; #Win32::GUI::Constants::constant("COLOR_WINDOW");
        }
    }

    my $handle = Win32::GUI::RegisterClassEx(%args);

    if($handle) {
        $self->{-name}   = $args{-name};
        $self->{-handle} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}


###############################################################################
# (@)PACKAGE:Win32::GUI::Window
# Create and manipulate Windows
# This is the main container of a regular GUI; also known as "top level window".
#
package Win32::GUI::Window;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Window(%OPTIONS)
    # Creates a new Window object.
    #
    # Class specific B<%OPTIONS> are:
    #   -accel => Win32::GUI::Accelerator
    #   -accelerators => Win32::GUI::Accelerator
    #   -acceleratortable => Win32::GUI::Accelerator
    #     Associate accelerator table to Window
    #   -minsize => [X, Y]
    #     Specifies the minimum size (width and height) in pixels;
    #     X and Y must be passed in an array reference
    #   -maxsize => [X, Y]
    #     Specifies the maximum size (width and height) in pixels;
    #     X and Y must be passed in an array reference
    #   -minwidth  => N
    #   -minheight => N
    #   -maxwidht  => N
    #   -maxheight => N
    #     Specify the minimum and maximum size width and height, in pixels
    #   -hasmaximize => 0/1
    #   -maximizebox => 0/1
    #     Set/Unset maximize box.
    #   -hasminimize => 0/1
    #   -minimizebox => 0/1
    #     Set/Unset minimize box.
    #   -sizable => 0/1
    #   -resizable => 0/1
    #     Set/Unset tick frame style.
    #   -sysmenu => 0/1
    #   -menubox => 0/1
    #   -controlbox => 0/1
    #     Set/Unset system menu style.
    #   -titlebar => 0/1
    #     Set/Unset caption style.
    #   -helpbutton => 0/1
    #   -helpbox => 0/1
    #   -hashelp => 0/1
    #     Set/Unset help context extended style.
    #   -toolwindow => 0/1
    #     Set/Unset tool window extended style.
    #   -appwindow => 0/1
    #     Set/Unset app window extended style.
    #   -topmost => 0/1 (default 0)
    #     The window "stays on top" even when deactivated
    #   -controlparent => 0/1 (default 0)
    #     Set/Unset control parent extended style.
    #   -noflicker => 0/1 (default 0)
    #     Set to 1 to enable anti-flicker. This will eliminate all flicker from
    #     your window, but may prevent things like Graphic objects from showing
    #     correctly.
    #   -dialogui => 0/1
    #     Act as a dialog box.
sub new {
    my $self = Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__WINDOW"), @_);
    if($self) {
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)METHOD:AddButton(%OPTIONS)
    # See new Win32::GUI::Button().
sub AddButton      { return Win32::GUI::Button->new(@_); }

    ###########################################################################
    # (@)METHOD:AddLabel(%OPTIONS)
    # See new Win32::GUI::Label().
sub AddLabel       { return Win32::GUI::Label->new(@_); }

    ###########################################################################
    # (@)METHOD:AddCheckbox(%OPTIONS)
    # See new Win32::GUI::Checkbox().
sub AddCheckbox    { return Win32::GUI::Checkbox->new(@_); }

    ###########################################################################
    # (@)METHOD:AddRadioButton(%OPTIONS)
    # See new Win32::GUI::RadioButton().
sub AddRadioButton { return Win32::GUI::RadioButton->new(@_); }

    ###########################################################################
    # (@)METHOD:AddGroupbox(%OPTIONS)
    # See new Win32::GUI::Groupbox().
sub AddGroupbox    { return Win32::GUI::Groupbox->new(@_); }

    ###########################################################################
    # (@)METHOD:AddTextfield(%OPTIONS)
    # See new Win32::GUI::Textfield().
sub AddTextfield   { return Win32::GUI::Textfield->new(@_); }

    ###########################################################################
    # (@)METHOD:AddListbox(%OPTIONS)
    # See new Win32::GUI::Listbox().
sub AddListbox     { return Win32::GUI::Listbox->new(@_); }

    ###########################################################################
    # (@)METHOD:AddCombobox(%OPTIONS)
    # See new Win32::GUI::Combobox().
sub AddCombobox    { return Win32::GUI::Combobox->new(@_); }

    ###########################################################################
    # (@)METHOD:AddStatusBar(%OPTIONS)
    # See new Win32::GUI::StatusBar().
sub AddStatusBar   { return Win32::GUI::StatusBar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddProgressBar(%OPTIONS)
    # See new Win32::GUI::ProgressBar().
sub AddProgressBar { return Win32::GUI::ProgressBar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddTabStrip(%OPTIONS)
    # See new Win32::GUI::TabStrip().
sub AddTabStrip    { return Win32::GUI::TabStrip->new(@_); }

    ###########################################################################
    # (@)METHOD:AddToolbar(%OPTIONS)
    # See new Win32::GUI::Toolbar().
sub AddToolbar     { return Win32::GUI::Toolbar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddListView(%OPTIONS)
    # See new Win32::GUI::ListView().
sub AddListView    { return Win32::GUI::ListView->new(@_); }

    ###########################################################################
    # (@)METHOD:AddTreeView(%OPTIONS)
    # See new Win32::GUI::TreeView().
sub AddTreeView    { return Win32::GUI::TreeView->new(@_); }

    ###########################################################################
    # (@)METHOD:AddRichEdit(%OPTIONS)
    # See new Win32::GUI::RichEdit().
sub AddRichEdit    { return Win32::GUI::RichEdit->new(@_); }

    ###########################################################################
    # (@)INTERNAL:AddTrackbar(%OPTIONS)
    # Better used as AddSlider().
sub AddTrackbar    { return Win32::GUI::Trackbar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddSlider(%OPTIONS)
    # See new Win32::GUI::Slider().
sub AddSlider      { return Win32::GUI::Slider->new(@_); }

    ###########################################################################
    # (@)METHOD:AddUpDown(%OPTIONS)
    # See new Win32::GUI::UpDown().
sub AddUpDown      { return Win32::GUI::UpDown->new(@_); }

    ###########################################################################
    # (@)METHOD:AddAnimation(%OPTIONS)
    # See new Win32::GUI::Animation().
sub AddAnimation   { return Win32::GUI::Animation->new(@_); }

    ###########################################################################
    # (@)METHOD:AddRebar(%OPTIONS)
    # See new Win32::GUI::Rebar().
sub AddRebar       { return Win32::GUI::Rebar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddHeader(%OPTIONS)
    # See new Win32::GUI::Header().
sub AddHeader      { return Win32::GUI::Header->new(@_); }

    ###########################################################################
    # (@)METHOD:AddComboboxEx(%OPTIONS)
    # See new Win32::GUI::ComboboxEx().
sub AddComboboxEx  { return Win32::GUI::ComboboxEx->new(@_); }

    ###########################################################################
    # (@)METHOD:AddSplitter(%OPTIONS)
    # See new Win32::GUI::Splitter().
sub AddSplitter    { return Win32::GUI::Splitter->new(@_); }

    ###########################################################################
    # (@)METHOD:AddTimer(NAME, ELAPSE)
    # See new Win32::GUI::Timer().
sub AddTimer       { return Win32::GUI::Timer->new(@_); }

    ###########################################################################
    # (@)METHOD:AddNotifyIcon(%OPTIONS)
    # See new Win32::GUI::NotifyIcon().
sub AddNotifyIcon  { return Win32::GUI::NotifyIcon->new(@_); }

    ###########################################################################
    # (@)METHOD:AddDateTime(%OPTIONS)
    # See new Win32::GUI::DateTime().
sub AddDateTime  { return Win32::GUI::DateTime->new(@_); }

    ###########################################################################
    # (@)METHOD:AddMonthCal(%OPTIONS)
    # See new Win32::GUI::MonthCal().
sub AddMonthCal  { return Win32::GUI::MonthCal->new(@_); }

    ###########################################################################
    # (@)METHOD:AddGraphic(%OPTIONS)
    # See new Win32::GUI::Graphic().
sub AddGraphic  { return Win32::GUI::Graphic->new(@_); }

    ###########################################################################
    # (@)METHOD:AddTooltip(%OPTIONS)
    # See new Win32::GUI::Tooltip().
sub AddTooltip  { return Win32::GUI::Tooltip->new(@_); }

    ###########################################################################
    # (@)METHOD:AddMenu()
    # See new Win32::GUI::Menu().
sub AddMenu {
    my $self = shift;
    my $menu = Win32::GUI::Menu->new();
    my $r = Win32::GUI::SetMenu($self, $menu->{-handle});
    # print "SetMenu=$r\n";
    return $menu;
}

    ###########################################################################
    # (@)METHOD:GetDC()
    # Returns the DC object associated with the window.
sub GetDC {
    my $self = shift;
    return Win32::GUI::DC->new($self);
}

    ###########################################################################
    # (@)METHOD:Center([Parent])
    # Center the window vertically and horizontally in the Parent (Default: the Desktop window).
    # Parent can be either a Win32::GUI::Window or a hwind.
    # Return 1 on success, else 0.

sub Center {
    #Code taken from Win32::GUI::AdHoc by Johan Lindström
    my ($winSelf, $winParent) = @_;
    defined($winParent) or $winParent = Win32::GUI::GetDesktopWindow();

    #Avoid OO notation to enable us to use either a hwind or a Win32::GUI::Window object
    my $x = Win32::GUI::Left($winParent) + (Win32::GUI::Width($winParent) / 2) - (Win32::GUI::Width($winSelf) / 2);
    my $y = Win32::GUI::Top($winParent) + (Win32::GUI::Height($winParent) / 2) - (Win32::GUI::Height($winSelf) / 2);

    Win32::GUI::Move($winSelf, $x, $y) and return(1);
    return(0);
    }

    ###########################################################################
    # (@)INTERNAL:AUTOLOAD(HANDLE, METHOD)
sub AUTOLOAD {
    my($self, $method) = @_;
    $AUTOLOAD =~ s/.*:://;
    # print "Win32::GUI::Window::AUTOLOAD called for object '$self', method '$method', AUTOLOAD=$AUTOLOAD\n";
    if( exists $self->{$AUTOLOAD}) {
        return $self->{$AUTOLOAD};
    } else {
        $AutoLoader::AUTOLOAD = $AUTOLOAD;
        goto &AutoLoader::AUTOLOAD;
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::DialogBox
# Create and manipulate Windows
# Just like Window, but with a predefined dialog box look: by default, a DialogBox
# can not be sized, has no maximize box and has C<-dialogui> enabled (eg.
# interprets tab/enter/esc).
#
package Win32::GUI::DialogBox;
@ISA = qw(Win32::GUI::Window);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::DialogBox(%OPTIONS)
    # Creates a new DialogBox object. See new Win32::GUI::Window().
sub new {
    my $self = Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__DIALOG"), @_);
    if($self) {
        return $self;
    } else {
        return undef;
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::MDIFrame
# Create and manipulate MDI Windows
#
package Win32::GUI::MDIFrame;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::MDIFrame(%OPTIONS)
    # Creates a new MDI Client object.
    #
    # Class specific B<%OPTIONS> are:

sub new {
    my $self = Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__MDIFRAME"), @_);
    if($self) {
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)METHOD:AddMDIClient(%OPTIONS)
    # See new Win32::GUI::MDIClient().
sub AddMDIClient  { return Win32::GUI::MDIClient->new(@_); }

    ###########################################################################
    # (@)METHOD:AddStatusBar(%OPTIONS)
    # See new Win32::GUI::StatusBar().
sub AddStatusBar   { return Win32::GUI::StatusBar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddToolbar(%OPTIONS)
    # See new Win32::GUI::Toolbar().
sub AddToolbar     { return Win32::GUI::Toolbar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddRebar(%OPTIONS)
    # See new Win32::GUI::Rebar().
sub AddRebar       { return Win32::GUI::Rebar->new(@_); }

    ###########################################################################
    # (@)METHOD:AddSplitter(%OPTIONS)
    # See new Win32::GUI::Splitter().
sub AddSplitter    { return Win32::GUI::Splitter->new(@_); }

    ###########################################################################
    # (@)METHOD:AddTimer(NAME, ELAPSE)
    # See new Win32::GUI::Timer().
sub AddTimer       { return Win32::GUI::Timer->new(@_); }

    ###########################################################################
    # (@)METHOD:AddNotifyIcon(%OPTIONS)
    # See new Win32::GUI::NotifyIcon().
sub AddNotifyIcon  { return Win32::GUI::NotifyIcon->new(@_); }

    ###########################################################################
    # (@)METHOD:AddMenu()
    # See new Win32::GUI::Menu().
sub AddMenu {
    my $self = shift;
    my $menu = Win32::GUI::Menu->new();
    my $r = Win32::GUI::SetMenu($self, $menu->{-handle});
    # print "SetMenu=$r\n";
    return $menu;
}
    ###########################################################################
    # (@)METHOD:Center([Parent])
    # Center the window vertically and horizontally in the Parent (Default: the Desktop window).
    # Parent can be either a Win32::GUI::Window or a hwind.
    # Return 1 on success, else 0.

sub Center {
    return Win32::GUI::Window::Center(@_);
}

    ###########################################################################
    # (@)METHOD:GetDC()
    # Returns the DC object associated with the window.
sub GetDC {
    my $self = shift;
    return Win32::GUI::DC->new($self);
}

    ###########################################################################
    # (@)INTERNAL:AUTOLOAD(HANDLE, METHOD)
sub AUTOLOAD {
    Win32::GUI::Window::AUTOLOAD(@_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::MDIClient
# Create and manipulate MDI Windows
#
package Win32::GUI::MDIClient;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::MDIClient(%OPTIONS)
    # Creates a new MDI Client object.
    #
    # Class specific B<%OPTIONS> are:

sub new {
    my $self = Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__MDICLIENT"), @_);
    if($self) {
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)METHOD:AddMDIChild(%OPTIONS)
    # See new Win32::GUI::MDIChild().
sub AddMDIChild  { return Win32::GUI::MDIChild->new(@_); }

    ###########################################################################
    # (@)METHOD:GetDC()
    # Returns the DC object associated with the window.
sub GetDC {
    my $self = shift;
    return Win32::GUI::DC->new($self);
}

    ###########################################################################
    # (@)INTERNAL:AUTOLOAD(HANDLE, METHOD)
sub AUTOLOAD {
    Win32::GUI::Window::AUTOLOAD(@_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::MDIChild
# Create and manipulate MDI Windows
#
package Win32::GUI::MDIChild;
@ISA = qw(
    Win32::GUI::Window
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::MDIChild(%OPTIONS)
    # Creates a new MDI Child window object.
    #
    # Class specific B<%OPTIONS> are:

sub new {
    my $self = Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__MDICHILD"), @_);
    if($self) {
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)METHOD:GetDC()
    # Returns the DC object associated with the window.
sub GetDC {
    my $self = shift;
    return Win32::GUI::DC->new($self);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Button
# Create and manipulate button controls
#
package Win32::GUI::Button;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Button(PARENT, %OPTIONS)
    # Creates a new Button object;
    # can also be called as PARENT->AddButton(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #     -align   => left/center/right (default left)
    #       specify horizontal text align.
    #     -valign  => top/center/bottom
    #       specify vertical text align.
    #     -default => 0/1 (default 0)
    #       Set/Unset default push button style. A default Button has a black
    #       border drawn around it.
    #     -ok      => 0/1 (default 0)
    #       Set/Unset button id to ID_OK. If 1, the button will correspond to the OK
    #       action of a dialog, and its Click event will be fired by pressing the ENTER key.
    #     -cancel  => 0/1 (default 0)
    #       Set/Unset button id to ID_CANCEL. If 1, the button will correspond to the CANCEL
    #       action of a dialog, and its Click event will be fired by pressing the ESC key.
    #     -bitmap  => Win32::GUI::Bitmap object
    #       Create a bitmap button.
    #     -picture => see -bitmap
    #     -icon    => Win32::GUI::Icon object
    #       Create a icon button.
    #     -3state  => 0/1 (default 0)
    #       Set/Unset 3 state style.
    #     -flat  => 0/1 (default 0)
    #       Set/Unset flat style.
    #     -multiline  => 0/1 (default 0)
    #       Set/Unset multiline style.
    #     -notify  => 0/1 (default 0)
    #       Set/Unset notify style.
    #     -pushlike  => 0/1 (default 0)
    #       Set/Unset pushlike style.
    #     -rightbutton  => 0/1 (default 0)
    #       Set/Unset rightbutton style.

sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__BUTTON"), @_);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::RadioButton
# Create and manipulate radio button controls
#
package Win32::GUI::RadioButton;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::RadioButton(PARENT, %OPTIONS)
    # Creates a new RadioButton object;
    # can also be called as PARENT->AddRadioButton(%OPTIONS).
    #
    # B<%OPTIONS> are the same as Button (See new Win32::GUI::Button() ).
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__RADIOBUTTON"), @_);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::Checkbox
# Create and manipulate checkbox controls
#
package Win32::GUI::Checkbox;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Checkbox(PARENT, %OPTIONS)
    # Creates a new Checkbox object;
    # can also be called as PARENT->AddCheckbox(%OPTIONS).
    #
    # B<%OPTIONS> are the same of Button (See new Win32::GUI::Button() ).
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__CHECKBOX"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Groupbox
# Create and manipulate groupbox controls
#
package Win32::GUI::Groupbox;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Groupbox(PARENT, %OPTIONS)
    # Creates a new Groupbox object;
    # can also be called as PARENT->AddGroupbox(%OPTIONS).
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__GROUPBOX"), @_);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::Label
# Create and manipulate label controls
#
package Win32::GUI::Label;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Label(PARENT, %OPTIONS)
    # Creates a new Label object;
    # can also be called as PARENT->AddLabel(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #    -align    => left/center/right (default left)
    #      Set text align.
    #    -bitmap   => Win32::GUI::Bitmap object
    #    -fill     => black/gray/white/none (default none)
    #       Fills the control rectangle ("black", "gray" and "white" are
    #       the window frame color, the desktop color and the window
    #       background color respectively).
    #    -frame    => black/gray/white/etched/none (default none)
    #       Draws a border around the control. colors are the same
    #       of -fill, with the addition of "etched" (a raised border).
    #    -icon     => Win32::GUI::Icon object
    #    -noprefix => 0/1 (default 0)
    #       Disables the interpretation of "&" as accelerator prefix.
    #    -notify   => 0/1 (default 0)
    #       Enables the Click(), DblClick, etc. events.
    #    -picture  => see -bitmap
    #    -sunken   => 0/1 (default 0)
    #       Draws a half-sunken border around the control.
    #    -truncate => 0/1/word/path (default 0)
    #       Specifies how the text is to be truncated:
    #          0 the text is not truncated
    #          1 the text is truncated at the end
    #         path the text is truncated before the last "\"
    #              (used to shorten paths).
    #    -wrap     => 0/1 (default 1)
    #       The text wraps automatically to a new line.
    #    -simple   => 0/1 (default 1)
    #       Set/Unset simple style.
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__STATIC"), @_);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::Textfield
# Create and manipulate textfield controls
#
package Win32::GUI::Textfield;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Textfield(PARENT, %OPTIONS)
    # Creates a new Textfield object;
    # can also be called as PARENT->AddTextfield(%OPTIONS).
    # Class specific %OPTIONS are:
    #   -align         => left/center/right (default left)
    #       aligns the text in the control accordingly.
    #   -keepselection => 0/1 (default 0)
    #       the selection is not hidden when the control loses focus.
    #   -multiline     => 0/1 (default 0)
    #       the control can have more than one line (note that newline
    #       is "\r\n", not "\n"!).
    #   -password      => 0/1 (default 0)
    #       masks the user input (like password prompts).
    #   -passwordchar  => CHAR (default '*')
    #       The specified CHAR that is shown instead of the text with -password => 1
    #   -lowercase     => 0/1 (default 0)
    #       Convert all caracter into lowercase
    #   -uppercase     => 0/1 (default 0)
    #       Convert all caracter into uppercase
    #   -autohscroll   => 0/1 (default 1 (0 for a multiline Textfield))
    #       Automatically scroll to right as text is typed past the right
    #       margin;  If 0 for a multiline Textfield, then wrap to the next
    #       line.
    #   -autovscroll   => 0/1 (default 1)
    #       For a multiline Textfiled automatically scroll down as lines
    #       pass the bottom of the control. 
    #   -number        => 0/1 (default 0)
    #       Allows only digits to be entered into the edit control
    #   -prompt        => (see below)
    #   -readonly      => 0/1 (default 0)
    #       text can't be changed.
    #   -wantreturn    => 0/1 (default 0)
    #       when dialogui => 1 is in effect, stops the <ENTER> key
    #       behaving as a click on the default button, and allows the
    #       key to be entered in a multi-line Textfield
    #
    # The C<-prompt> option is very special; if a string is passed, a
    # Win32::GUI::Label object (with text set to the string passed) is created
    # to the left of the Textfield.
    # Example:
    #     $Window->AddTextfield(
    #         -name   => "Username",
    #         -left   => 75,
    #         -top    => 150,
    #         -width  => 100,
    #         -height => 20,
    #         -prompt => "Your name:",
    #     );
    # Furthermore, the value to -prompt can be a reference to a list containing
    # the string and an additional parameter, which sets the width for
    # the Label (eg. [ STRING, WIDTH ] ). If WIDTH is negative, it is calculated
    # relative to the Textfield left coordinate. Example:
    #
    #     -left => 75,                          (Label left) (Textfield left)
    #     -prompt => [ "Your name:", 30 ],       75           105 (75+30)
    #
    #     -left => 75,
    #     -prompt => [ "Your name:", -30 ],      45 (75-30)   75
    #
    # Note that the Win32::GUI::Label object is named like the Textfield, with
    # a "_Prompt" suffix (in the example above, the Label is named
    # "Username_Prompt").
sub new {
    my($class, $parent, @options) = @_;
    my %options = @options;

    # Create the textfield, invisible, and we'll
    # make it visible if necessary at the end
    my $visible = exists $options{-visible} ? $options{-visible} : 1;
    my $textfield = Win32::GUI->_new(
        Win32::GUI::_constant("WIN32__GUI__EDIT"),
        $class, $parent, @options, '-visible', 0
    );

    # If we failed to create it, then return undef
    return undef unless $textfield;

    # If we have a -prompt option, then we need to
    # create a label, and position it and the
    # textfield correctly
    if(exists $options{-prompt}) {
        my ($text, $adjust);

        # extract the information we need from
        # the -prompt option
        if(ref($options{-prompt}) eq "ARRAY") {
            $text   = shift(@{$options{'-prompt'}});
            $adjust = shift(@{$options{'-prompt'}}) || 0;
        }
        else {
            $text = $options{-prompt};
        }

        # Convert -pos to -left and -top,
        if (exists $options{-pos}) {
          $options{-left} = $options{-pos}[0];
          $options{-top}  = $options{-pos}[1];
        }

        ## Create the label; Setting width and height to
        # zero creates it the right size for the text.
        # XXX: This will inherit the font from the
        # parent window, ignoring any -font option
        # passed.
        my $prompt = new Win32::GUI::Label(
            $parent,
            -name    => $textfield->{-name} . '_Prompt',
            -text    => $text,
            -left    => $options{-left} || 0,
            -top     => ($options{-top} || 0) + 3,
            -width   => 0,
            -height  => 0,
            -visible => 0,
        );

        # If we failed to create it, then return undef
        return undef unless $prompt;

        # Adjust the positions:
        # $adjust < 0 : the textfield is in the correct
        #               position, move the label left
        # $adjust > 0 : the label is in the correct
        #               position, move the textfield right
        # $adjust == 0: both are correct, do nothing
        # $adjust undefined: label needs moving to
        #    the left of the textfield, which we will
        #    do by setting $adjust appropriately
        if(!defined $adjust) {
            $adjust = -($prompt->Width() + 5);
        }

        if($adjust < 0) {
            my $left = $prompt->Left();
            $prompt->Left($left + $adjust);
        }
        elsif ($adjust > 0) {
            my $left = $textfield->Left();
            $textfield->Left($left + $adjust);
        }
        else {
            # Adjust is zero, or we have
            # an error;  in either case
            # do nothing
        }

        # Make the prompt visible if needed
        $prompt->Show() if $visible;
    } # finish processing prompt

    # Make the textfield visible if needed
    $textfield->Show() if $visible;

    return $textfield;
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Listbox
# Create and manipulate listbox controls
#
package Win32::GUI::Listbox;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Listbox(PARENT, %OPTIONS)
    # Creates a new Listbox object;
    # can also be called as PARENT->AddListbox(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #    -multisel => 0/1/2 (default 0)
    #        specifies the selection type:
    #            0 single selection
    #            1 multiple selection
    #            2 multiple selection ehnanced (with Shift, Control, etc.)
    #    -sort     => 0/1 (default 0)
    #        items are sorted alphabetically.
    #    -multicolumn => 0/1 (default 0)
    #    -nointegralheight => 0/1 (default 0)
    #    -noredraw => 0/1 (default 0)
    #    -notify => 0/1 (default 0)
    #    -usetabstop => 0/1 (default 0)
    #    -disablenoscroll => 0/1 (default 0)

sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__LISTBOX"), @_);
}

    ###########################################################################
    # (@)METHOD:List ()
    # Return a list of Listbox::Item.

sub List {
    my $self = shift;
    my $index = shift;
    if(not defined $index) {
        my @list = ();
        for my $i (0..($self->Count-1)) {
            push @list, Win32::GUI::Listbox::Item->new($self, $i);
        }
        return @list;
    } else {
        return Win32::GUI::Listbox::Item->new($self, $index);
    }
}

    ###########################################################################
    # (@)METHOD:Item (INDEX)
    # Return an Listbox::Item.

sub Item { &List; }

###############################################################################
# (@)PACKAGE:Win32::GUI::Listbox::Item
# Create and manipulate listbox entries
#
package Win32::GUI::Listbox::Item;

sub new {
    my($class, $listbox, $index) = @_;
    $self = {
        -parent => $listbox,
        -index  => $index,
        -string => $listbox->GetString($index),
    };
    return bless $self, $class;
}

    ###########################################################################
    # (@)METHOD:Remove()
    # Remove Item.
sub Remove {
    my($self) = @_;
    $self->{-parent}->RemoveItem($self->{-index});
    undef $_[0];
}

    ###########################################################################
    # (@)METHOD:Select()
    # Select Item.
sub Select {
    my($self) = @_;
    $self->{-parent}->Select($self->{-index});
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Combobox
# Create and manipulate combobox controls
#
package Win32::GUI::Combobox;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Combobox(PARENT, %OPTIONS)
    # Creates a new Combobox object;
    # can also be called as PARENT->AddCombobox(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #  -autohscroll => 0/1 (default 0)
    #    Set/Unset autohscroll style
    #  -disablenoscroll => 0/1 (default 0)
    #    Set/Unset disablenoscroll style
    #  -dropdown => 0/1 (default 0)
    #    Set/Unset dropdown style
    #  -dropdownlist => 0/1 (default 0)
    #    Set/Unset dropdownlist style
    #  -hasstring => 0/1 (default 0)
    #    Set/Unset hasstring style
    #  -lowercase => 0/1 (default 0)
    #    Set/Unset lowercase style
    #  -nointegraleheight => 0/1 (default 0)
    #    Set/Unset nointegraleheight style
    #  -simple => 0/1 (default 0)
    #    Set/Unset simple style
    #  -sort => 0/1 (default 0)
    #    Set/Unset sort style
    #  -uppercase => 0/1 (default 0)
    #    Set/Unset uppercase style
    #
    # Only one of -simple, -dropdown and -dropdownlist should be used. If
    # more than one is used, only the last one will be acted on.

sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__COMBOBOX"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::ProgressBar
# Create and manipulate progress bar controls
#
package Win32::GUI::ProgressBar;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::ProgressBar(PARENT, %OPTIONS)
    # Creates a new ProgressBar object;
    # can also be called as PARENT->AddProgressBar(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #     -smooth   => 0/1 (default 0)
    #         uses a smooth bar instead of the default segmented bar.
    #     -vertical => 0/1 (default 0)
    #         display progress status vertically (from bottom to top).
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__PROGRESS"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::StatusBar
# Create and manipulate status bar controls
#
package Win32::GUI::StatusBar;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::StatusBar(PARENT, %OPTIONS)
    # Creates a new StatusBar object;
    # can also be called as PARENT->AddStatusBar(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #     -sizegrip   => 0/1 (default 0)
    #         Set/Unset size grip style.

sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__STATUS"), @_);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::TabStrip
# Create and manipulate tab strip controls
#
package Win32::GUI::TabStrip;
@ISA = qw(
    Win32::GUI::Window
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::TabStrip(PARENT, %OPTIONS)
    # Creates a new TabStrip object;
    # can also be called as PARENT->AddTabStrip(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -alignright=> 0/1 (default 0)
    #   -bottom    => 0/1 (default 0)
    #   -buttons   => 0/1 (default 0)
    #     if enabled items look like push buttons
    #   -hottrack  => 0/1 (default 0)
    #   -imagelist => Win32::GUI::ImageList object
    #   -justify   => 0/1 (default 0)
    #   -forceiconleft => 0/1 (default 0)
    #   -forcelabelleft => 0/1 (default 0)
    #   -fixedwidth => 0/1 (default 0)
    #   -focusbottondown => 0/1 (default 0)
    #   -focusnever => 0/1 (default 0)
    #   -flat      => 0/1 (default 0)
    #   -flatseparator => 0/1 (default 0)
    #   -raggedright => 0/1 (default 0)
    #   -multiline => 0/1 (default 0)
    #     The control can have more than one line
    #   -multiselect => 0/1 (default 0)
    #   -vertical  => 0/1 (default 0)
    #   -tooltip => Win32::GUI::Tooltip object
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__TAB"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Toolbar
# Create and manipulate toolbar controls
#
package Win32::GUI::Toolbar;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Toolbar(PARENT, %OPTIONS)
    # Creates a new Toolbar object;
    # can also be called as PARENT->AddToolbar(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -adjustable => 0/1
    #   -altdrag => 0/1
    #   -flat => 0/1
    #   -list => 0/1
    #   -transparent => 0/1
    #   -imagelist => IMAGELIST
    #   -multiline => 0/1
    #     The control can have more than one line
    #   -nodivider => 0/1
    #   -tooltip => Win32::GUI::Tooltip object
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__TOOLBAR"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::RichEdit
# Create and manipulate Richedit controls.
# Most of the methods and events that apply to a L<Textfield|Win32::GUI::Textfield>
# also apply to Win32::GUI::RichEdit.
#
# Note that in order for most events to be triggered you must call the
# SetEventMask() method, to set the events that you want to be triggered.
# See SetEventMask().
#
# By default Win32::GUI::RichEdit uses Rich Edit 1.0.
package Win32::GUI::RichEdit;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::RichEdit(PARENT, %OPTIONS)
    # Creates a new RichEdit object;
    # can also be called as PARENT->AddRichEdit(%OPTIONS).
    # See new Win32::GUI::Textfield() for B<%OPTIONS>
sub new {
    $Win32::GUI::RICHED = Win32::GUI::LoadLibrary("RICHED32") unless defined $Win32::GUI::RICHED;
    #TODO: should FreeLibrary when last RichEdit control gets DESTROYed, rather than
    #allowing the process tidy-up to do it.
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__RICHEDIT"), @_);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::ListView
# Create and manipulate listview controls
#
package Win32::GUI::ListView;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::ListView(PARENT, %OPTIONS)
    # Creates a new ListView object;
    # can also be called as PARENT->AddListView(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -align => left, top
    #   -imagelist => IMAGELIST
    #   -report => 0/1
    #   -list => 0/1
    #   -singlesel => 0/1
    #   -showselalways => 0/1
    #   -sortascending => 0/1
    #   -sortdescending => 0/1
    #   -nolabelwrap => 0/1
    #   -autoarrange => 0/1
    #   -editlabel => 0/1
    #   -noscroll => 0/1
    #   -alignleft => 0/1
    #   -ownerdrawfixed => 0/1
    #   -nocolumnheader => 0/1
    #   -nosortheader => 0/1
    #   -gridlines => 0/1
    #   -subitemimages => 0/1
    #   -checkboxes => 0/1
    #   -hottrack => 0/1
    #   -reordercolumns => 0/1
    #   -fullrowselect => 0/1
    #   -oneclickactivate => 0/1
    #   -twoclickactivate => 0/1
    #   -flatsb => 0/1
    #   -regional => 0/1
    #   -infotip => 0/1
    #   -underlinehot => 0/1
    #   -underlinecold => 0/1
    #   -multiworkareas => 0/1
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__LISTVIEW"), @_);
}

    ###########################################################################
    # (@)METHOD:Item(INDEX)
    # Return an Win32::GUI::ListView::Item.

sub Item {
    my($self, $index) = @_;
    return Win32::GUI::ListView::Item->new($self, $index);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::ListView::Item
# Create and manipulate listview entries
#
package Win32::GUI::ListView::Item;

sub new {
    my($class, $listview, $index) = @_;
    my $self = {
        -parent => $listview,
        -index  => $index,
    };
    return bless $self, $class;
}

    ###########################################################################
    # (@)METHOD:SubItem(INDEX)
    # Return a Win32::GUI::ListView::SubItem object.
sub SubItem {
    my($self, $index) = @_;
    return Win32::GUI::ListView::SubItem->new($self, $index);
}

    ###########################################################################
    # (@)METHOD:Remove()
    # Remove listview item.
sub Remove {
    my($self) = @_;
    $self->{-parent}->DeleteItem($self->{-index});
    undef $_[0];
}

    ###########################################################################
    # (@)METHOD:Select()
    # Select listview item.
sub Select {
    my($self) = @_;
    $self->{-parent}->Select($self->{-index});
}

    ###########################################################################
    # (@)METHOD:Text([TEXT])
    # Set or Get item text.
sub Text {
    my($self, $text) = @_;
    if(not defined $text) {
        my %data = $self->{-parent}->ItemInfo($self->{-index});
        return $data{-text};
    } else {
        return $self->{-parent}->ChangeItem(
            -item => $self->{-index},
            -text => $text,
        );
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::ListView::SubItem
# Create and manipulate listview entries
#
package Win32::GUI::ListView::SubItem;

sub new {
    my($class, $parent, $index) = @_;
    my $self = {
        -parent    => $parent->{-parent},
        -index     => $parent->{-index},
        -subindex  => $index,
    };
    return bless $self, $class;
}

    ###########################################################################
    # (@)METHOD:Text([TEXT])
    # Set or Get sub item text.
sub Text {
    my($self, $text) = @_;
    if(not defined $text) {
        my %data = $self->{-parent}->ItemInfo(
            $self->{-index},
            $self->{-subindex},
        );
        return $data{-text};
    } else {
        return $self->{-parent}->ChangeItem(
            -item => $self->{-index},
            -subitem => $self->{-subindex},
            -text => $text,
        );
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::TreeView
# Create and manipulate treeview controls
#
package Win32::GUI::TreeView;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::TreeView(PARENT, %OPTIONS)
    # Creates a new TreeView object
    # can also be called as PARENT->AddTreeView(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -imagelist => IMAGELIST
    #   -tooltip => Win32::GUI::Tooltip
    #   -lines => 0/1
    #   -rootlines => 0/1
    #   -buttons => 0/1
    #        enables or disables the +/- buttons to expand/collapse tree items.
    #   -showselalways => 0/1
    #   -checkboxes => 0/1
    #   -trackselect => 0/1
    #   -disabledragdrop => 0/1
    #   -editlabels => 0/1
    #   -fullrowselect => 0/1
    #   -nonevenheight => 0/1
    #   -noscroll => 0/1
    #   -notooltips => 0/1
    #   -rtlreading => 0/1
    #   -singleexpand => 0/1
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__TREEVIEW"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Slider
# Create and manipulate slider controls
#
# See L<Win32::GUI::Trackbar|Win32::GUI::TrackBar>
#
package Win32::GUI::Trackbar;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Slider(PARENT, %OPTIONS)
    # Creates a new Slider object;
    # can also be called as PARENT->AddSlider(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -tooltip => Win32::GUI::Tooltip
    #   -vertical => 0/1
    #   -aligntop => 0/1
    #   -alignleft => 0/1
    #   -noticks => 0/1
    #   -nothumb => 0/1
    #   -selrange => 0/1
    #   -autoticks => 0/1
    #   -both => 0/1
    #   -fixedlength => 0/1
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__TRACKBAR"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Slider
#
package Win32::GUI::Slider;
@ISA = qw(Win32::GUI::Trackbar);

###############################################################################
# (@)PACKAGE:Win32::GUI::UpDown
# Create and manipulate up-down controls
#
package Win32::GUI::UpDown;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::UpDown(PARENT, %OPTIONS)
    # Creates a new UpDown object;
    # can also be called as PARENT->AddUpDown(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -align => left,right
    #     When Left, positions the up-down control next to the left edge of the buddy window.
    #     The buddy window is moved to the right, and its width is decreased to accommodate the
    #     width of the up-down control.
    #     When right, positions the up-down control next to the right edge of the buddy window.
    #     The width of the buddy window is decreased to accommodate the width of the up-down control.
    #   -nothousands => 0/1
    #     Does not insert a thousands separator between every three decimal digits.
    #   -wrap => 0/1 (default 0)
    #     Causes the position to "wrap" if it is incremented or decremented beyond the ending or beginning of the range.
    #   -horizontal => 0/1
    #     Causes the up-down control's arrows to point left and right instead of up and down.
    #   -autobuddy => 0/1
    #     Automatically selects the previous window in the z-order as the up-down control's buddy window.
    #   -setbuddy => 0/1
    #     Causes the up-down control to set the text of the buddy window (using the WM_SETTEXT message)
    #     when the position changes. The text consists of the position formatted as a decimal or hexadecimal string.
    #   -arrowkeys => 0/1
    #     Causes the up-down control to increment and decrement the position when the UP ARROW and
    #     DOWN ARROW keys are pressed.
    #
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__UPDOWN"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Tooltip
# Create and manipulate Tooltip controls
#
# Tooltip controls are probably one of the most unintuitave of the Win32
# controls when you first come accross them.  A Tooltip control is a
# single window that supports one or more 'tools'.  A tool is a window,
# or an area of a window that when the mouse hovers over, the tooltip
# window is displayed.  The Tooltip is always a top level window (so
# don't try adding the WS_CHILD window style), and is typically owned
# by the top level window of your application/dialog.
#
# Create a tooltip window:
#
#   my $tt = Win32::GUI::Tooltip->new(
#     $main_window,
#   );
#
# Add a tool to the tooltip:
#
#   $tt->AddTool(
#     -window => $main_window,
#     -text   => "Text that pops up",
#   );
#
# and hover the mouse over an area of your main window.
package Win32::GUI::Tooltip;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Tooltip(PARENT, %OPTIONS)
    # Creates a new Tooltip object.
    # Can also be called as PARENT->AddTooltip(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -alwaystip => 0/1 (default: 1)
    #      Show the tooltip, even if the window is not active.
    #   -noprefix  => 0/1 (default: 0)
    #      Prevent the tooltip control stripping '&' prefixes
    #   -noanimate => 0/1 (default: 0)
    #      Turn off tooltip window animation
    #   -nofade    => 0/1 (default: 0)
    #      Turn off tooltip window fading effect
    #   -balloon   => 0/1 (default: 0)
    #      Give the tooltip window 'balloon' style
sub new {
    my $parent = $_[1];
    my $new = Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__TOOLTIP"), @_);
    if($new) {
        if($parent->{-tooltips}) {
            push(@{$parent->{-tooltips}}, $new->{-handle});
        } else {
            $parent->{-tooltips} = [ $new->{-handle} ];
        }
    }
    return $new;
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Animation
# Create and manipulate animation controls
# The Animation control displays an AVI animation.
# To load an AVI file you can use the L<Open()|/Open> method;
# you can then use L<Play()|/Play> to start the animation
# (note it will start automatically with the B<-autoplay> option),
# L<Stop()|/Stop> to stop it, and L<Seek()|/Seek> to position it to
# a specified frame.
package Win32::GUI::Animation;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Animation(PARENT, %OPTIONS)
    # Creates a new Animation object;
    # can also be called as PARENT->AddAnimation(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -autoplay    => 0/1 (default 0)
    #     Starts playing the animation as soon as an AVI clip is loaded.
    #   -center      => 0/1 (default 0)
    #     Centers the animation in the control window.
    #   -transparent => 0/1 (default 0)
    #     Draws the animation using a transparent background.
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__ANIMATION"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Rebar
# Create and manipulate Rebar (aka Coolbar) controls
#
package Win32::GUI::Rebar;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Rebar(PARENT, %OPTIONS)
    # Creates a new Rebar object;
    # can also be called as PARENT->AddRebar(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -autosize => 0/1 (default 0)
    #     Set/Unset autosize style.
    #   -bandborders => 0/1 (default 0)
    #     display a border to separate bands.
    #   -doubleclick => 0/1 (default 0)
    #     Set/Unset double click toggle style.
    #   -fixedorder => 0/1 (default 0)
    #     band position cannot be swapped.
    #   -imagelist => Win32::GUI::ImageList object
    #     Set imagelist.
    #   -nodivider => 0/1 (default 1)
    #     Set/Unset nodivider style.
    #   -varheight => 0/1 (default 1)
    #     display bands using the minimum required height.
    #   -vertical => 0/1 (default 0)
    #     Set/Unset vertical style.
    #   -vgripper => 0/1 (default 0)
    #     Set/Unset vertical gripper style.
    #   -tooltip => Win32::GUI::Tooltip
    #     Set tooltip window.

sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__REBAR"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Header
# Create and manipulate list header controls
#
package Win32::GUI::Header;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Header(PARENT, %OPTIONS)
    # Creates a new Header object;
    # can also be called as PARENT->AddHeader(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -buttons => 0/1 (default 0)
    #     Set/Unset buttons style.
    #     Header items look like push buttons and can be clicked.
    #   -dragdrop => 0/1 (default 0)
    #     Set/Unset dragdrop style.
    #   -fulldrag => 0/1 (default 0)
    #     Set/Unset fulldrag style.
    #   -hidden => 0/1 (default 0)
    #     Set/Unset hidden style.
    #   -horizontal => 0/1 (default 0)
    #     Set/Unset horizontal style.
    #   -hottrack => 0/1 (default 0)
    #     Set/Unset hottrack style.
    #   -hottrack => 0/1 (default 0)
    #     Set/Unset hottrack style.
    #   -imagelist => Win32::GUI::ImageList object.
    #     Set imagelist.
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__HEADER"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Splitter
# Create and manipulate window splitter controls
#
package Win32::GUI::Splitter;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Splitter(PARENT, %OPTIONS)
    # Creates a new Splitter object;
    # can also be called as PARENT->AddSplitter(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -horizontal => 0/1 (default 0)
    #     Set/Unset horizontal orientation
    #   -min => VALUE
    #     Set minimum range value.
    #   -max => VALUE
    #     Set maximum range value.
    #   -range => [ MIN, MAX ]
    #     Set range values.

sub new {
    my $new = Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__SPLITTER"), @_);
    if($new) {
        $new->{-tracking} = 0;
        return $new;
    } else {
        return undef;
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::ComboboxEx
# Create and manipulate extended combobox controls
#
package Win32::GUI::ComboboxEx;
@ISA = qw(
    Win32::GUI::Combobox
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::ComboboxEx(PARENT, %OPTIONS)
    # Creates a new ComboboxEx object;
    # can also be called as PARENT->AddComboboxEx(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -imagelist => Win32::GUI::ImageList object
    #     Set Imagelist object
    #   -casesensitive => 0/1 (default 0)
    #     Set/Unset casesensitive extended style.
    #   -noeditimage => 0/1 (default 0)
    #     Set/Unset noeditimage extended style.
    #   -noeditimageindent => 0/1 (default 0)
    #     Set/Unset noeditimageindent extended style.
    #   -nosizelimit => 0/1 (default 0)
    #     Set/Unset nosizelimit extended style.
    #
    # Except for images, a ComboboxEx object acts like a Win32::GUI::Combobox
    # object. See also new Win32::GUI::Combobox().
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__COMBOBOXEX"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::DateTime
# Create and manipulate datetime controls
#
package Win32::GUI::DateTime;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::DateTime(PARENT, %OPTIONS)
    # Creates a new DateTime object;
    # can also be called as PARENT->AddDateTime(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -align  => 'right'/'left' (default 'left')
    #     The drop-down month calendar alignement.
    #   -format => 'shortdate', 'longdate', 'time'
    #     Control format type (Use local format date/time).
    #   -shownone => 0/1 (default 0)
    #     Allow no datetime (add a prefix checkbox).
    #   -updown   => 0/1 (default 0 for date, 1 for time format)
    #     Use updown control instead of the drop-down month calendar.
sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__DTPICK"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::MonthCal
# Create and manipulate MonthCal controls
#
package Win32::GUI::MonthCal;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::MonthCal(PARENT, %OPTIONS)
    # Creates a new MonthCal object;
    # can also be called as PARENT->AddMonthCal(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -daystate  => 0/1 (default 0)
    #     Set/Unset daystate style.
    #   -multiselect  => 0/1 (default 0)
    #     Set/Unset multiselect style.
    #   -notoday  => 0/1 (default 0)
    #     Set/Unset notoday style.
    #   -notodaycircle  => 0/1 (default 0)
    #     Set/Unset notodaycircle style.
    #   -weeknumber  => 0/1 (default 0)
    #     Set/Unset weeknumber style.

sub new {
    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__MONTHCAL"), @_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Graphic
# Create and manipulate Graphic Windows
#
package Win32::GUI::Graphic;
@ISA = qw(
    Win32::GUI
    Win32::GUI::WindowProps
);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Graphic(PARENT, %OPTIONS)
    # Creates a new Graphic object;
    # can also be called as PARENT->AddGraphic(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #   -intercative => 0/1 (default 0)
    #     Set/Unset interactive graphic.
sub new {

    return Win32::GUI->_new(Win32::GUI::_constant("WIN32__GUI__GRAPHIC"), @_);
}

    ###########################################################################
    # (@)METHOD:GetDC()
    # Returns the DC object associated with the window.
sub GetDC {
    my $self = shift;
    return Win32::GUI::DC->new($self);
}


###############################################################################
# (@)PACKAGE:Win32::GUI::ImageList
# Create and manipulate imagelist resources
#
package Win32::GUI::ImageList;
@ISA = qw(Win32::GUI);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::ImageList(X, Y, FLAGS, INITAL, GROW)
    # Creates an ImageList object; X and Y specify the size of the images,
    # FLAGS [TBD]. INITIAL and GROW specify the number of images the ImageList
    # actually contains (INITIAL) and the number of images for which memory
    # is allocated (GROW).
sub new {
    my $class = shift;
    my $self = {};
    my $handle = Win32::GUI::ImageList::Create(@_);
    if($handle) {
        $self->{-handle} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)METHOD:Add(BITMAP, [BITMAPMASK])
    # Adds a bitmap to the ImageList; both B<BITMAP> and B<BITMAPMASK> can be either
    # Win32::GUI::Bitmap objects or filenames.
sub Add {
    my($self, $bitmap, $bitmapMask) = @_;
    $bitmap = new Win32::GUI::Bitmap($bitmap) unless ref($bitmap);
    if(defined($bitmapMask)) {
        $bitmapMask = new Win32::GUI::Bitmap($bitmapMask) unless ref($bitmapMask);
        $self->AddBitmap($bitmap, $bitmapMask);
    } else {
        $self->AddBitmap($bitmap);
    }
}

    ###########################################################################
    # (@)METHOD:AddMasked(BITMAP, COLORMASK)
    # Adds a bitmap to the ImageList; B<BITMAP> can be either Win32::GUI::Bitmap
    # object or filename.
sub AddMasked {
    my($self, $bitmap, $colorMask) = @_;
    $bitmap = new Win32::GUI::Bitmap($bitmap) unless ref($bitmap);
    return $self->AddBitmapMasked($bitmap, $colorMask);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Menu
# Create and manipulate menu resources
#
package Win32::GUI::Menu;
@ISA = qw(Win32::GUI);

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Menu(...)
sub new {
    my $class = shift;
    my $self = {};

    if($#_ > 0) {
        return Win32::GUI::MakeMenu(@_);
    } else {
        my $handle = Win32::GUI::CreateMenu();

        if($handle) {
            $self->{-handle} = $handle;
            bless($self, $class);
            return $self;
        } else {
            return undef;
        }
    }
}

    ###########################################################################
    # (@)METHOD:AddMenuButton()
    # See new Win32::GUI::MenuButton()
sub AddMenuButton {
    return Win32::GUI::MenuButton->new(@_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::MenuButton
# Create and manipulate menu entries
#
package Win32::GUI::MenuButton;

    ###########################################################################
    # (@)METHOD:new Win32::GUI::MenuButton()
sub new {
    my $class = shift;
    my $menu = shift;
    $menu = $menu->{-handle} if ref($menu);
    # print "new MenuButton: menu=$menu\n";
    my %args = @_;
    my $self = {};

    my $handle = Win32::GUI::CreatePopupMenu();

    if($handle) {
        $args{-submenu} = $handle;
        # print "PM(MenuButton::new) calling InsertMenuItem with menu=$menu, args=", join(", ", %args), "\n";
        Win32::GUI::MenuButton::InsertMenuItem($menu, %args);
        # print "PM(MenuButton::new) back from InsertMenuItem\n";
        $self->{-handle} = $handle;
        bless($self, $class);
        $Win32::GUI::Menus{ $args{-id} } = $handle;
        #if($args{-name}) {
        #    $Win32::GUI::Menus{$args{-id}} = $self;
        #    $self->{-name} = $args{-name};
        #}
        # print "PM(MenuButton::new) returning self=$self\n";
        return $self;
    } else {
        return undef;
    }
}

    ###########################################################################
    # (@)METHOD:AddMenuItem()
    # See new Win32::GUI::MenuItem()
sub AddMenuItem {
    return Win32::GUI::MenuItem->new(@_);
}

###############################################################################
# (@)PACKAGE:Win32::GUI::MenuItem
# Create and manipulate menu entries
#
package Win32::GUI::MenuItem;

    ###########################################################################
    # (@)METHOD:new Win32::GUI::MenuItem()
    # Creates a new MenuItem object;
    # can also be called as PARENT->AddMenuItem(%OPTIONS).
    #
    # Class specific B<%OPTIONS> are:
    #     -default => 0/1 (default 0)
    #       Set/Unset default push menu item style. A default menu item is
    #       drawn in a bold font.
sub new {
    my $class = shift;
    my $menu = shift;
    return undef unless ref($menu) =~ /^Win32::GUI::Menu/;
    my %args = @_;
    my $self = {};

    # print "PM(MenuItem::new) calling InsertMenuItem with menu=$menu, args=", join(", ", %args), "\n";
    my $handle = Win32::GUI::MenuButton::InsertMenuItem($menu, %args);
    # print "PM(MenuItem::new) back from InsertMenuItem\n";

    if($handle) {
        # $self->{-handle} = $handle;
        # $Win32::GUI::menucallbacks{$args{-id}} = $args{-function} if $args{-function};
        $self->{-id} = $args{-id};
        $self->{-menu} = $menu->{-handle};
        bless($self, $class);
        $Win32::GUI::Menus{ $args{-id} } = $menu->{-handle};
        #if($args{-name}) {
        #    $Win32::GUI::Menus{$args{-id}} = $self;
        #    $self->{-name} = $args{-name};
        #}
        # print "PM(MenuItem::new) returning self=$self\n";
        return $self;
    } else {
        return undef;
    }
}

###############################################################################
# (@)PACKAGE: Win32::GUI::Timer
# Create and manipulate periodic Timer events
#
# The Timer object is a special kind of control: it has no appearance, its only
# purpose is to trigger an event every specified amount of time.  You can create a
# Timer object in either of these ways:
#   new Win32::GUI::Timer( PARENT, NAME, ELAPSE )
#   PARENT->AddTimer( NAME, ELAPSE )
# where C<NAME> is the name for the Timer object (used to lookup the associated event).
# and C<ELAPSE> is the number of milliseconds after which the Timer() event will
# be periodically triggered.
#
# Once you've created the Timer object, you can change the ELAPSE parameter
# with the L<Interval()|/Interval> method, or disable the Timer with the
# L<Kill()|/Kill> method.
#
# The triggered OEM event is called as "$name_Timer"()
# The triggered NEM event is defined as -onTimer => sub{} method of the parent window.
package Win32::GUI::Timer;

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Timer(PARENT, [NAME, [ELAPSE]])
    # Creates a new timer in the PARENT window named NAME that will
    # trigger its Timer() event after ELAPSE milliseconds.
    # Can also be called as PARENT->AddTimer(NAME, ELAPSE).
    #
    # If NAME is not supplied, then an internal name will be allocated.
    #
    # ELAPSE must by an integer greater than or equal to zero.  If ELAPSE
    # is 0, then the timer object is created, but the timer will be disabled.
    # You can then start the timer by calling the L<Interval()|/Interval> method
    # and setting ELAPSE to a non-zero number. If ELASPE is not supplied, then
    # 0 will be used.
    #
    # Note: Different OS versions might change too low or large intervals for ELAPSE
    # to more appropriate values. E.g. > 0x7fffffff or < 10
sub new {
    my $class = shift;
    my $window = shift;
    my $name = shift;
    my $elapse = shift;

    my %args = @_;

    # Get a new Id
    $id = $Win32::GUI::TimerIdCounter++;

    # Force a name if havent.
    $name = "_Timer".$id unless defined $name;
    $elapse = 0 unless defined $elapse;

    # check $elapse
    if($elapse != int($elapse) or $elapse < 0) {
	    warn qq(ELAPSE must be an integer greater than or equal to 0, not "$elapse". Using ELAPSE=0.);
	    $elapse = 0;
    }

    my $self = {};
    bless($self, $class);

    # store object propeties
    $self->{-id} = $id;
    $self->{-name} = $name;
    $self->{-handle} = $window->{-handle};
    $self->{-interval} = $elapse;

    # Store name in parent's timers hash
    $window->{-timers}->{$id} = $name;
    # Add Timer into parent hash.
    $window->{$name} = $self;

    Win32::GUI::SetTimer($window, $id, $elapse) if $elapse > 0;

    return $self;
}

    ###########################################################################
    # (@)METHOD:Interval(ELAPSE)
    # Get or set the periodic timer interval. Unit: ms
    # When setting a new interval, any existing timer is reset.  When setting
    # returns the previous interval.
    #
    # Setting ELAPSE to 0 suspends the timer (i.e. it will not fire timer events).
    # The timer can be restarted later by setting ELAPSE to a positive value.
    #
    # Note: Different OS versions might change too low or large intervals for ELAPSE
    # to more appropriate values. E.g. > 0x7fffffff or < 10
sub Interval {
    my $self = shift;
    my $elapse = shift;

    #Get
    return $self->{-interval} unless defined $elapse;

    my $previous = $self->{-interval};
    # check $elapse
    if($elapse != int($elapse) or $elapse < 0) {
        warn qq(ELAPSE must be an integer greater than or equal to 0, not "$elapse". Using previous value($previous ms));
        $elapse = $previous;
    }
    $self->{-interval} = $elapse;
    if ($elapse > 0) { # match Win32::GUI::Tutorial::Part4
        Win32::GUI::SetTimer($self->{-handle}, $self->{-id}, $elapse);
    } else {
        Win32::GUI::KillTimer($self->{-handle}, $self->{-id});
    }

    return $previous;
}

    ###########################################################################
    # (@)METHOD:Kill([REMOVE=0])
    # Remove the periodic timer event.
    #
    # Kill() with no parameters, or a False parameter suspends the timer,
    # exactly as $timer->Interval(0); In this case it return the previous
    # interval.
    #
    # Kill() with a True parameter will stop and remove all traces of the timer.
    # To use system resources efficiently, applications should Kill(1)
    # timers that are no longer necessary.
sub Kill {
    my $self = shift;
    my $remove = shift;

    if($remove) {
	    $self->DESTROY();
    }
    else {
	    return $self->Interval(0);
    }
    return undef;
}

    ###########################################################################
    # (@)INTERNAL:DESTROY(HANDLE)
sub DESTROY {
    my $self = shift;

    # Kill timer
    Win32::GUI::KillTimer($self->{-handle}, $self->{-id});

    # We put this code to tidy up the parent here, rather than
    # in Timer->Kill(1), so that we still tidy up, even in the
    # unlikely event of someone doing PARENT->{Timer name} = undef;
    my $window = Win32::GUI::GetWindowObject($self->{-handle});
    if(defined $window && tied %$window) {
        # Remove id from -timers hash
        delete $window->{-timers}->{$self->{-id}};
        # Remove name from parent
        delete $window->{$self->{-name}};
    }
}


###############################################################################
# (@)PACKAGE:Win32::GUI::NotifyIcon
# Create and manipulate icons and tooltips in the system tray
#
# The functionality of Win32::GUI::NotifyIcon is affected by the version
# of shell32.dll installed with the windows system running your script. You
# can find this version from $Win32::GUI::NotifyIcon::SHELLDLL_VERSION,
# which contains the major version number of the shell32.dll library that
# has been loaded.
package Win32::GUI::NotifyIcon;
our $SHELLDLL_VERSION = (Win32::GUI::GetDllVersion('shell32'))[0];

    ###########################################################################
    # (@)METHOD:new Win32::GUI::NotifyIcon(PARENT, %OPTIONS)
    # Creates a new NotifyIcon (also known as system tray icon) object;
    # can also be called as PARENT->AddNotifyIcon(%OPTIONS).
    #
    # B<%OPTIONS> are:
    #     -icon => Win32::GUI::Icon object
    #         the icon to display in the taskbar
    #     -name => STRING
    #         the name for the object
    #     -tip => STRING
    #         the text that will appear as a tooltip when the mouse is
    #         hovering over the NotifyIcon.  For shell32.dll versions prior
    #         to 5.0 the text length is limited to 63 characters;  For
    #         later versions it is limited to 127 characters.  The string
    #         provided will be truncated as necessary.
    #     -event => NEM Event Hash
    #        Set NEM event handler (you can also use -on Event Option).
    #
    # For shell32.dll version 5.0 and later balloon tooltips can be used,
    # the following options control balloon tooltips.  If your version
    # of shell32.dll does not support balloon tooltips, then these options
    # are silently ignored:
    #     -balloon => 0/1
    #        A flag controlling whether the ballon tip is displayed by
    #        new() or Change(), or whether the ShowBalloon() method
    #        must be called to display the balloon tooltip.  Defaults
    #        to 0 (not displayed).
    #     -balloon_tip => STRING
    #        Sets the text that will appear in the body of the balloon tip.
    #        Will cause the balloon tip to be removed from the screen if set
    #        to the empty string and displayed. The string is limited to
    #        255 characters and will be truncated as necessary.
    #     -balloon_title => STRING
    #        Sets the text that appears as a title at the top of the balloon
    #        tip. The string is limited to 63 characters and will be truncated
    #        as necessary.
    #     -balloon_icon  => STRING
    #        Sets the icon that is displayed next to the balloon tip title. If
    #        the balloon tip title is not set (or is set to the empty string),
    #        then no icon is displayed.  Allowed values for STRING are:
    #        error, info, warning, none.  Defaults to 'none'.
    #    -balloon_timeout => NUMBER
    #        The maximum time for which a balloon tooltip is displayed before
    #        being removed, in milliseconds.  The system will limit the range
    #        allowed (typically to between 10 and 30 seconds).  If a balloon
    #        is being displayed and another taskbar icon tries to display a
    #        balloon tip, then the one being displayed will be removed after
    #        it has been displayed for the system minimum time (typically 10
    #        seconds), and only then will the new tooltip be displayed.
    #        Defaults to 10 seconds.
    #
    # Returns a Win32::GUI::NotifyIcon object on success, undef on failure
sub new {
    my $class = shift;
    my $window = shift;

    my %args = @_;

    if(!exists($args{-id})) {
        $args{-id} = $Win32::GUI::NotifyIconIdCounter++; # TODO - deprecate
    }
    else {
        warn qq(The -id option is deprecated, and you should not be setting it.);
    }

    if(!exists($args{-name})) {
        $args{-name} = "_NotifyIcon".$args{-id};
    }

    $args{-balloon} = 0 unless exists $args{-balloon};

    my $self = {};
    bless($self, $class);

    $self->{-id} = $args{-id};
    $self->{-name} = $args{-name};
    $self->{-handle} = $window->{-handle};
    $self->{-balloon_tip} = $args{-balloon_tip};
    $self->{-balloon_title} = $args{-balloon_title};
    $self->{-balloon_timeout} = $args{-balloon_timeout};
    $self->{-balloon_icon} = $args{-balloon_icon};

    # ParseNotifyIconOptions() needs these values to be set in order
    # to correctly sore NEM events, so set them before calling
    # _Add().
    # Store name in parent's notifyicons hash
    $window->{-notifyicons}->{$args{-id}} = $args{-name};
    # Add NotifyIcon into parent's hash
    $window->{$args{-name}} = $self;

    my $result = Win32::GUI::NotifyIcon::_Add($self->{-handle}, %args);

    return $self if $result;

    # Failed to create the Notfiy Icon, so tidy up parent
    delete $window->{-notifyicons}->{$args{-id}};
    delete $window->{$args{-name}};

    return; # return undef or empty list
}

    ###########################################################################
    # (@)METHOD:Change(%OPTIONS)
    # Change all options. See new Win32::GUI::NotifyIcon().
    #
    # Returns 1 on success, 0 on failure
sub Change {
    my $self = shift;
    my %args = @_;

    $args{-balloon} = 0 unless exists $args{-balloon};

    $self->{-balloon_tip} = $args{-balloon_tip} if exists $args{-balloon_tip};
    $self->{-balloon_title} = $args{-balloon_title} if exists $args{-balloon_title};
    $self->{-balloon_timeout} = $args{-balloon_timeout} if exists $args{-balloon_timeout};
    $self->{-balloon_icon} = $args{-balloon_icon} if exists $args{-balloon_icon};

    if($self->{-balloon}) {
        $args{-balloon_tip} = $self->{-balloon_tip};
        $args{-balloon_title} = $self->{-balloon_title};
        $args{-balloon_timeout} = $self->{-balloon_timeout};
        $args{-balloon_icon} = $self->{-balloon_icon};
    }

    return Win32::GUI::NotifyIcon::_Modify($self->{-handle}, -id => $self->{-id}, %args);
}

    ###########################################################################
    # (@)METHOD:ShowBalloon([FLAG=1])
    # Only supported by shell32.dll v5.0 and above
    #
    # Show or hide a balloon tooltip with details supplied from the new() or
    # Change() methods, using the -balloon_tip, -balloon_title, -balloon_timeout
    # and -balloon_icon options.
    #
    # Set B<FLAG> to a true value to display the balloon tooltip, or to a false
    # value to hide the tip (it will automatically be hidden by the system
    # after -balloon_timeout millseconds).  If B<FLAG> is omitted, displays the
    # tooltip.  If the tooltip is already showing, re-showing it queues
    # a new balloon tooltip to be displayed once the existing one times out.
    #
    # Returns 1 on success, 0 on failure or undef if not supported.
sub ShowBalloon {
    return undef if $SHELLDLL_VERSION < 5;
    my $self = shift;
    my $flag = shift;
    $flag = 1 unless defined $flag;

    return Win32::GUI::NotifyIcon::_Modify(
        $self->{-handle},
        -id              => $self->{-id},
        -balloon         => 1,
        -balloon_tip     => $flag ? $self->{-balloon_tip} : '',
        -balloon_title   => $self->{-balloon_title},
        -balloon_timeout => $self->{-balloon_timeout},
        -balloon_icon    => $self->{-balloon_icon},
    );
}

    ###########################################################################
    # (@)METHOD:HideBalloon([FLAG=1])
    # Only supported by shell32.dll v5.0 and above
    #
    # Show or hide a balloon tooltip with details supplied from the new() or
    # Change() methods, using the -balloon_tip, -balloon_title, -balloon_timeout
    # and -balloon_icon options.
    #
    # Set B<FLAG> to a false value to display the balloon tooltip, or to a true
    # value to hide the tip (it will automatically be hidden by the system
    # after -balloon_timeout millseconds).  If B<FLAG> is omitted, hides the
    # tooltip.  If the tooltip is already showing, re-showing it queues
    # a new balloon tooltip to be displayed once the existing one times out.
    #
    # Returns 1 on success, 0 on failure or undef if not supported.
sub HideBalloon {
    return undef if $SHELLDLL_VERSION < 5;
    my $self = shift;
    my $flag = shift;
    $flag = 1 unless defined $flag;

    return $self->ShowBalloon(!$flag);
}

    ###########################################################################
    # (@)METHOD:SetFocus()
    # Only supported by shell32.dll v5.0 and above
    #
    # Return focus to the taskbar notification area.  For example if the
    # taskbar icon displays a shortcut menu and the user cancels the menu
    # with ESC, then use this method to return focus to the taskbar
    # notification area.
    #
    # Returns 1 on success, 0 on failure and undef if not supported.
sub SetFocus {
    return undef if $SHELLDLL_VERSION < 5;
    my $self = shift;
    return Win32::GUI::NotifyIcon::_SetFocus($self->{-handle}, -id => $self->{-id});
}

    ###########################################################################
    # (@)METHOD:SetBehaviour([FLAG])
    # Only supported by shell32.dll v5.0 and above
    #
    # Set FLAG to a true value to get the Windows 2000 taskbar behaviour. set
    # FLAG to a flase value to get Windows 95 taskbar behaviour.  See the MSDN
    # documentation for Shell_NotifyIcon for more details.
    #
    # Returns 1 on success, 0 on failure and undef if not supported.
sub SetBehaviour {
    return undef if $SHELLDLL_VERSION < 5;
    my $self = shift;
    my $flag = shift || 0;
    return Win32::GUI::NotifyIcon::_SetVersion($self->{-handle}, -id => $self->{-id}, -behaviour => $flag);
}

    ###########################################################################
    # (@)METHOD:Remove()
    # Remove the Notify Icon from the system tray, and free its related resources
sub Remove {
    my $self = shift;
    $self->DESTROY();
}

    ###########################################################################
    # (@)METHOD:Delete()
    # Deprecated method for removing notify icon from the system tray.  Will be
    # removed from future Win32::GUI versions without further warning.
sub Delete {
    warn qq(Win32::GUI::NotifyIcon::Delete() is deprecated, please use Win32::GUI::NofityIcon::Remove());
    return Win32::GUI::NotifyIcon::_Delete(@_);
}

    ###########################################################################
    # (@)INTERNAL:DESTROY(OBJECT)

sub DESTROY {
    my $self = shift;

    # Remove the notify icon
    Win32::GUI::NotifyIcon::_Delete($self->{-handle}, -id => $self->{-id});

    # We put this code to tidy up the parent here, rather than
    # in NofifyIcon->Delete(), so that we still tidy up, even in the
    # unlikely event of someone doing PARENT->{NotifyIcon name} = undef;
    my $window = Win32::GUI::GetWindowObject($self->{-handle});
    if(defined $window && tied %$window) {
        # Remove id from -notifyicons hash
        delete $window->{-notifyicons}->{$self->{-id}} if defined $window->{-notifyicons};
        # Remove name from parent
        delete $window->{$self->{-name}};
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::DC
# Work with a Window's DC (Drawing Context)
#
package Win32::GUI::DC;

    ###########################################################################
    # (@)METHOD:new Win32::GUI::DC(WINDOW | DRIVER, DEVICE)
    # Creates a new DC object; the first form (WINDOW is a Win32::GUI object)
    # gets the DC for the specified window (can also be called as
    # WINDOW->GetDC). The second form creates a DC for the specified DEVICE;
    # actually, the only supported DRIVER is the display driver (eg. the
    # screen). To get the DC for the entire screen use:
    #     $Screen = new Win32::GUI::DC("DISPLAY");
    #
sub new {
    my $class = shift;

    my $self = {};
    bless($self, $class);

    my $window = shift;
    if(defined($window)) {
        if(ref($window)) {
            $self->{-handle} = GetDC($window->{-handle});
            $self->{-window} = $window->{-handle};
        } else {
            my $device = shift;
            if(!defined($device) && $window =~ /^[0-9]+$/) {
                $self->{-handle} = $window;
            }
            else {
                $self->{-handle} = CreateDC($window, $device);
            }
        }
    } else {
        $self->{-handle} = CreateDC("DISPLAY", 0);
    }
    return $self;
}

sub DESTROY {
    my $self = shift;
    if($self->{-window}) {
        ReleaseDC($self->{-window}, $self->{-handle});
    } else {
        DeleteDC($self->{-handle});
    }
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Pen
# Create and manipulate drawing Pen resources
#
package Win32::GUI::Pen;

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Pen(COLOR | %OPTIONS)
    # Creates a new Pen object.
    #
    # Allowed B<%OPTIONS> are:
    #   -style =>
    #     0 PS_SOLID
    #     1 PS_DASH
    #     2 PS_DOT
    #     3 PS_DASHDOT
    #     4 PS_DASHDOTDOT
    #     5 PS_NULL
    #     6 PS_INSIDEFRAME
    #   -width => number
    #   -color => COLOR
sub new {
    my $class = shift;

    my $self = {};
    bless($self, $class);
    $self->{-handle} = Create(@_);
    return $self;
}

###############################################################################
# (@)PACKAGE:Win32::GUI::Brush
# Create and manipulate drawing Brush resources
#
package Win32::GUI::Brush;

    ###########################################################################
    # (@)METHOD:new Win32::GUI::Brush(COLOR | %OPTIONS)
    # Creates a new Brush object.
    #
    # Allowed B<%OPTIONS> are:
    #   -style =>
    #     0 BS_SOLID
    #     1 BS_NULL
    #     2 BS_HATCHED
    #     3 BS_PATTERN
    #   -pattern => Win32::GUI::Bitmap object (valid for -style => BS_PATTERN)
    #   -hatch => (valid for -style => BS_HATCHED)
    #     0 HS_ORIZONTAL (-----)
    #     1 HS_VERTICAL  (|||||)
    #     2 HS_FDIAGONAL (\\\\\)
    #     3 HS_BDIAGONAL (/////)
    #     4 HS_CROSS     (+++++)
    #     5 HS_DIAGCROSS (xxxxx)
    #   -color => COLOR
sub new {
    my $class = shift;

    my $handle = Create(@_);

    if($handle) {
			my $self = {};
			$self->{-handle} = $handle;
			return bless($self, $class);
		}
		else {
			return undef;
		}
}


###############################################################################
# (@)PACKAGE:Win32::GUI::AcceleratorTable
# Create accelerator table resources
#
# The AcceleratorTable object can be associated to a window
# with the -accel option; then, when an accelerator is used, a
# corresponding <name>_Click event is fired.

package Win32::GUI::AcceleratorTable;

    ###########################################################################
    # (@)METHOD:new Win32::GUI::AcceleratorTable(%ACCELERATORS)
    # Creates an AcceleratorTable object.
    #
    # B<%ACCELERATORS> is an associative array of key combinations and
    # accelerator names or sub reference, in pair:
    # Example:
    #     $A = new Win32::GUI::AcceleratorTable(
    #         "Ctrl-X"       => "Close",
    #         "Shift-N"      => "New",
    #         "Ctrl-Alt-Del" => "Reboot",
    #         "Shift-A"      => sub { print "Hello\n"; },
    #     );
    # Keyboard combinations currently support the following modifier :
    #     Shift
    #     Ctrl  (or Control)
    #     Alt
    # and the following keys:
    #     A..Z, 0..9
    #     Left, Right, Up, Down
    #     Home, End, PageUp, PageDown (or PgUp/PgDn)
    #     Space, Ins, Del, Esc, Backspace, Tab, Return
    #     F1..F12
sub new {
    my $class = shift;
    my($k, $v);
    my $flag = 0;
    my $key = 0;
    my %accels = @_;
    my @acc;

    while( ($k, $v) = each %accels) {
        $flag = 0x0001;
        if($k =~ s/shift[-\+]//i)                { $flag |= 0x0004; }
        if($k =~ s/(ctrl|control)[-\+]//i)       { $flag |= 0x0008; }
        if($k =~ s/alt[-\+]//i)                  { $flag |= 0x0010; }

                                                 # { $key = 0x01; } # VK_LBUTTON
                                                 # { $key = 0x02; } # VK_RBUTTON
                                                 # { $key = 0x03; } # VK_CANCEL
                                                 # { $key = 0x04; } # VK_MBUTTON
           if($k =~ /^backspace$/i)                { $key = 0x08; } # VK_BACK
        elsif($k =~ /^tab$/i)                      { $key = 0x09; } # VK_TAB
#       elsif($k =~ /^clear$/i)                    { $key = 0x0c; } # VK_CLEAR
        elsif($k =~ /^return$/i)                   { $key = 0x0d; } # VK_RETURN
                                                 # { $key = 0x10; } # VK_SHIFT
                                                 # { $key = 0x11; } # VK_CONTROL
                                                 # { $key = 0x12; } # VK_MENU /ALT
        elsif($k =~ /^pause$/i)                    { $key = 0x13; } # VK_PAUSE
        elsif($k =~ /^capslock$/i)                 { $key = 0x14; } # VK_CAPITAL
        elsif($k =~ /^(esc|escape)$/i)             { $key = 0x1b; } # VK_ESCAPE
        elsif($k =~ /^space$/i)                    { $key = 0x20; } # VK_SPACE
        elsif($k =~ /^(pgup|pageup)$/i)            { $key = 0x21; } # VK_PRIOR
        elsif($k =~ /^(pgdn|pagedn|pagedown)$/i)   { $key = 0x22; } # VK_NEXT
        elsif($k =~ /^end$/i)                      { $key = 0x23; } # VK_END
        elsif($k =~ /^home$/i)                     { $key = 0x24; } # VK_HOME
        elsif($k =~ /^left$/i)                     { $key = 0x25; } # VK_LEFT
        elsif($k =~ /^up$/i)                       { $key = 0x26; } # VK_UP
        elsif($k =~ /^right$/i)                    { $key = 0x27; } # VK_RIGHT
        elsif($k =~ /^down$/i)                     { $key = 0x28; } # VK_DOWN
#       elsif($k =~ /^select$/i)                   { $key = 0x29; } # VK_SELECT
#       elsif($k =~ /^print$/i)                    { $key = 0x2a; } # VK_PRINT
#       elsif($k =~ /^execute$/i)                  { $key = 0x2b; } # VK_EXECUTE
        elsif($k =~ /^(prntscrn|printscreen)$/i)   { $key = 0x2c; } # VK_SNAPSHOT
        elsif($k =~ /^ins$/i)                      { $key = 0x2d; } # VK_INSERT
        elsif($k =~ /^del$/i)                      { $key = 0x2e; } # VK_DELETE
#       elsif($k =~ /^help$/i)                     { $key = 0x2f; } # VK_HELP
        elsif($k =~ /^[0-9a-z]$/i)                 { $key = ord(uc($k)); }
                                                 # 0x30-0x39: ASCII 0-9
                                                 # 0x41-0x5a: ASCII A-Z
        elsif($k =~ /^left(win|windows)$/i)        { $key = 0x5b; } # VK_LWIN
        elsif($k =~ /^right(win|windows)$/i)       { $key = 0x5c; } # VK_RWIN
        elsif($k =~ /^(app|application)$/i)        { $key = 0x5d; } # VK_APPS
#       elsif($k =~ /^sleep$/i)                    { $key = 0x5e; } # VK_SLEEP
        elsif($k =~ /^(num|numeric|keypad)0$/i)    { $key = 0x60; } # VK_NUMPAD0
        elsif($k =~ /^(num|numeric|keypad)1$/i)    { $key = 0x61; } # VK_NUMPAD1
        elsif($k =~ /^(num|numeric|keypad)2$/i)    { $key = 0x62; } # VK_NUMPAD2
        elsif($k =~ /^(num|numeric|keypad)3$/i)    { $key = 0x63; } # VK_NUMPAD3
        elsif($k =~ /^(num|numeric|keypad)4$/i)    { $key = 0x64; } # VK_NUMPAD4
        elsif($k =~ /^(num|numeric|keypad)5$/i)    { $key = 0x65; } # VK_NUMPAD5
        elsif($k =~ /^(num|numeric|keypad)6$/i)    { $key = 0x66; } # VK_NUMPAD6
        elsif($k =~ /^(num|numeric|keypad)7$/i)    { $key = 0x67; } # VK_NUMPAD7
        elsif($k =~ /^(num|numeric|keypad)8$/i)    { $key = 0x68; } # VK_NUMPAD8
        elsif($k =~ /^(num|numeric|keypad)9$/i)    { $key = 0x69; } # VK_NUMPAD9
        elsif($k =~ /^multiply$/i)                 { $key = 0x6a; } # VK_MULTIPLY
        elsif($k =~ /^add$/i)                      { $key = 0x6b; } # VK_ADD
#       elsif($k =~ /^separator$/i)                { $key = 0x6c; } # VK_SEPARATOR
        elsif($k =~ /^subtract$/i)                 { $key = 0x6d; } # VK_SUBTRACT
        elsif($k =~ /^decimal$/i)                  { $key = 0x6e; } # VK_DECIMAL
        elsif($k =~ /^divide$/i)                   { $key = 0x6f; } # VK_DIVIDE
        elsif($k =~ /^f1$/i)                       { $key = 0x70; } # VK_F1
        elsif($k =~ /^f2$/i)                       { $key = 0x71; } # VK_F2
        elsif($k =~ /^f3$/i)                       { $key = 0x72; } # VK_F3
        elsif($k =~ /^f4$/i)                       { $key = 0x73; } # VK_F4
        elsif($k =~ /^f5$/i)                       { $key = 0x74; } # VK_F5
        elsif($k =~ /^f6$/i)                       { $key = 0x75; } # VK_F6
        elsif($k =~ /^f7$/i)                       { $key = 0x76; } # VK_F7
        elsif($k =~ /^f8$/i)                       { $key = 0x77; } # VK_F8
        elsif($k =~ /^f9$/i)                       { $key = 0x78; } # VK_F9
        elsif($k =~ /^f10$/i)                      { $key = 0x79; } # VK_F10
        elsif($k =~ /^f11$/i)                      { $key = 0x7a; } # VK_F11
        elsif($k =~ /^f12$/i)                      { $key = 0x7b; } # VK_F12
#       elsif($k =~ /^f13$/i)                      { $key = 0x7c; } # VK_F13
#       elsif($k =~ /^f14$/i)                      { $key = 0x7d; } # VK_F14
#       elsif($k =~ /^f15$/i)                      { $key = 0x7e; } # VK_F15
#       elsif($k =~ /^f16$/i)                      { $key = 0x7f; } # VK_F16
#       elsif($k =~ /^f17$/i)                      { $key = 0x80; } # VK_F17
#       elsif($k =~ /^f18$/i)                      { $key = 0x81; } # VK_F18
#       elsif($k =~ /^f19$/i)                      { $key = 0x82; } # VK_F19
#       elsif($k =~ /^f20$/i)                      { $key = 0x83; } # VK_F20
#       elsif($k =~ /^f21$/i)                      { $key = 0x84; } # VK_F21
#       elsif($k =~ /^f22$/i)                      { $key = 0x85; } # VK_F22
#       elsif($k =~ /^f23$/i)                      { $key = 0x86; } # VK_F23
#       elsif($k =~ /^f24$/i)                      { $key = 0x87; } # VK_F24
        elsif($k =~ /^numlock$/i)                  { $key = 0x90; } # VK_NUMLOCK
        elsif($k =~ /^scrolllock$/i)               { $key = 0x91; } # VK_SCROLL
                                                 # { $key = 0xa0; } # VK_LSHIFT
                                                 # { $key = 0xa1; } # VK_RSHIFT
                                                 # { $key = 0xa2; } # VK_LCONTROL
                                                 # { $key = 0xa3; } # VK_RCONTROL
                                                 # { $key = 0xa4; } # VK_LMENU
                                                 # { $key = 0xa5; } # VK_RMENU
#       elsif($k =~ /^browserback$/i)              { $key = 0xa6; } # VK_BROWSER_BACK
#       elsif($k =~ /^browserforward$/i)           { $key = 0xa7; } # VK_BROWSER_FORWARD
#       elsif($k =~ /^browserrefresh$/i)           { $key = 0xa8; } # VK_BROWSER_REFRESH
#       elsif($k =~ /^browserstop$/i)              { $key = 0xa9; } # VK_BROWSER_STOP
#       elsif($k =~ /^browsersearch$/i)            { $key = 0xaa; } # VK_BROWSER_SEARCH
#       elsif($k =~ /^browserfavorites$/i)         { $key = 0xab; } # VK_BROWSER_FAVORITES
#       elsif($k =~ /^browserhome$/i)              { $key = 0xac; } # VK_BROWSER_HOME
#       elsif($k =~ /^volumemute$/i)               { $key = 0xad; } # VK_VOLUME_MUTE
#       elsif($k =~ /^volumedown$/i)               { $key = 0xae; } # VK_VOLUME_UP
#       elsif($k =~ /^volumenup$/i)                { $key = 0xaf; } # VK_VOLUME_DOWN
#       elsif($k =~ /^medianexttrack$/i)           { $key = 0xb0; } # VK_MEDIA_NEXT_TRACK
#       elsif($k =~ /^mediaprevtrack$/i)           { $key = 0xb1; } # VK_MEDIA_PREV_TRACK
#       elsif($k =~ /^mediastop$/i)                { $key = 0xb2; } # VK_MEDIA_STOP
#       elsif($k =~ /^mediaplaypause$/i)           { $key = 0xb3; } # VK_MEDIA_PLAY_PAUSE
#       elsif($k =~ /^launchmail$/i)               { $key = 0xb4; } # VK_LAUNCH_MAIL
#       elsif($k =~ /^launchmediaselect$/i)        { $key = 0xb5; } # VK_LAUNCH_MEDIA_SELECT
#       elsif($k =~ /^launchapp1$/i)               { $key = 0xb6; } # VK_LAUNCH_APP1
#       elsif($k =~ /^launchapp2$/i)               { $key = 0xb7; } # VK_LAUNCH_APP2
        elsif($k =~ /^semicolon$/i)                { $key = 0xba; } # VK_OEM_1
        elsif($k =~ /^(plus|equal)$/i)             { $key = 0xbb; } # VK_OEM_PLUS
        elsif($k =~ /^(comma|lessthan)$/i)         { $key = 0xbc; } # VK_OEM_COMMA
        elsif($k =~ /^(minus|underscore)$/i)       { $key = 0xbd; } # VK_OEM_MINUS
        elsif($k =~ /^(period|greaterthan)$/i)     { $key = 0xbe; } # VK_OEM_PERIOD
        elsif($k =~ /^(slash|question)$/i)         { $key = 0xbf; } # VK_OEM_2
        elsif($k =~ /^(acute|tilde)$/i)            { $key = 0xc0; } # VK_OEM_3
        elsif($k =~ /^(left|open)brac(e|ket)$/i)   { $key = 0xdb; } # VK_OEM_4
        elsif($k =~ /^(backslash|verticalbar)$/i)  { $key = 0xdc; } # VK_OEM_5
        elsif($k =~ /^(right|close)brac(e|ket)$/i) { $key = 0xdd; } # VK_OEM_6
        elsif($k =~ /^(single|double|)quote$/i)    { $key = 0xde; } # VK_OEM_7
#       elsif($k =~ /^unknown$/i)                  { $key = 0xdf; } # VK_OEM_8
#       elsif($k =~ /^process$/i)                  { $key = 0xe5; } # VK_PROCESSKEY
        elsif($k =~ /^(attn|attention)$/i)         { $key = 0xf6; } # VK_ATTN
        elsif($k =~ /^crsel$/i)                    { $key = 0xf7; } # VK_CRSEL
        elsif($k =~ /^exsel$/i)                    { $key = 0xf8; } # VK_EXSEL
        elsif($k =~ /^(ereof|eraseeof)$/i)         { $key = 0xf9; } # VK_EREOF
        elsif($k =~ /^play$/i)                     { $key = 0xfa; } # VK_PLAY
        elsif($k =~ /^zoom$/i)                     { $key = 0xfb; } # VK_ZOOM
        elsif($k =~ /^noname$/i)                   { $key = 0xfc; } # VK_NONAME
        elsif($k =~ /^pa1$/i)                      { $key = 0xfd; } # VK_PA1
        elsif($k =~ /^oem_clear$/i)                { $key = 0xfe; } # VK_OEM_CLEAR
        else {$key = 0; print "Key name '$k' unknown\n"; }

        if ($key) {
            my $id = $Win32::GUI::AcceleratorCounter++;
            push @acc, $id, $key, $flag;
            $Win32::GUI::Accelerators{$id} = $v;
        }
    }
    my $handle = Win32::GUI::CreateAcceleratorTable( @acc );
    if($handle) {
        my $self = {};
        $self->{-handle} = $handle;
        bless $self, $class;
        return $self;
    } else {
        return undef;
    }
}

sub DESTROY {
    my($self) = @_;
    # print "DESTROYING AcceleratorTable $self->{-handle}\n";
    if( $self->{-handle} ) {
        Win32::GUI::DestroyAcceleratorTable( $self->{-handle} );
    }
}

###############################################################################
# (@)INTERNAL:Win32::GUI::WindowProps
# The package to tie to a window hash to set/get properties in a more
# fashionable way.
#
package Win32::GUI::WindowProps;

my %TwoWayMethodMap = (
    -text   => "Text",
    -left   => "Left",
    -top    => "Top",
    -width  => "Width",
    -height => "Height",
    -dialogui => "DialogUI",
);

my $Textfield_TwoWayMethodMap = {
    -passwordchar => "PasswordChar",
};

my %PackageSpecific_TwoWayMethodMap = (
    Splitter => {
        -min => "Min",
        -max => "Max",
        -horizontal => "Horizontal",
        -vertical => "Vertical",
    },
    MenuItem => {
        -checked => "Checked",
        -enabled => "Enabled",
    },
    Textfield => $Textfield_TwoWayMethodMap,
    RichEdit  => $Textfield_TwoWayMethodMap,
);


my %OneWayMethodMap = (
    -scalewidth   => "ScaleHeight",
    -scaleheight  => "ScaleWidth",
    -abstop       => "AbsTop",
    -absleft      => "AbsLeft",
);

    ###########################################################################
    # (@)INTERNAL:TIEHASH
sub TIEHASH {
    my($class, $object) = @_;
    # my $tied = { UNDERLYING => $object };
    # print "[TIEHASH] called for '$class' '$object'\n";
    # return bless $tied, $class;
    return bless $object, $class;
}

    ###########################################################################
    # (@)INTERNAL:STORE
sub STORE {
    my($self, $key, $value) = @_;
    # print "[STORE] called for '$self' {$key}='$value'\n";

    my $Package = ref($self);
    $Package =~ s/Win32::GUI:://;

    if(exists $PackageSpecific_TwoWayMethodMap{$Package}{$key}) {
        if(my $method = $self->can($PackageSpecific_TwoWayMethodMap{$Package}{$key})) {
            #print "[STORE] calling method '$PackageSpecific_TwoWayMethodMap{$Package}{$key}' on '$self'\n";
            return &{$method}($self, $value);
        } else {
            #print "[STORE] PROBLEM: method '$PackageSpecific_TwoWayMethodMap{$Package}{$key}' not found on '$self'\n";
        }
    } elsif(exists $TwoWayMethodMap{$key}) {
        if(my $method = $self->can($TwoWayMethodMap{$key})) {
            # print "[STORE] calling method '$TwoWayMethodMap{$key}' on '$self'\n";
            return &{$method}($self, $value);
        } else {
            # print "[STORE] PROBLEM: method '$TwoWayMethodMap{$key}' not found on '$self'\n";
        }
    } elsif($key eq "-style") {
        # print "[STORE] calling GetWindowLong\n";
        return Win32::GUI::GetWindowLong($self, -16, $value);

    } else {
        # print "[STORE] storing key '$key' in '$self'\n";
        # return $self->{UNDERLYING}->{$key} = $value;
        return $self->{$key} = $value;
    }
}

    ###########################################################################
    # (@)INTERNAL:FETCH
sub FETCH {
    my($self, $key) = @_;
    # print "[FETCH] called for '$self' {$key}='$value'\n";
    my $Package = ref($self);
    $Package =~ s/Win32::GUI:://;

    if($key eq "UNDERLYING") {
        # print "[FETCH] returning UNDERLYING for '$self'\n";
        return $self->{UNDERLYING};

    } elsif(exists $PackageSpecific_TwoWayMethodMap{$Package}{$key}) {
        if(my $method = $self->can($PackageSpecific_TwoWayMethodMap{$Package}{$key})) {
            #print "[FETCH] calling method '$PackageSpecific_TwoWayMethodMap{$package}{$key}' on '$self'\n";
            return &{$method}($self);
        } else {
            #print "[FETCH] PROBLEM: method '$PackageSpecific_TwoWayMethodMap{$package}{$key}' not found on '$self'\n";
        }

    } elsif(exists $TwoWayMethodMap{$key}) {
        # if(my $method = $self->{UNDERLYING}->can($TwoWayMethodMap{$key})) {
        if(my $method = $self->can($TwoWayMethodMap{$key})) {
            # print "[FETCH] calling method $TwoWayMethodMap{$key} on $self->{UNDERLYING}\n";
            # print "[FETCH] calling method '$TwoWayMethodMap{$key}' on '$self'\n";
            # return &{$method}($self->{UNDERLYING});
            return &{$method}($self);
        } else {
            # print "[FETCH] method not found '$TwoWayMethodMap{$key}'\n";
            return undef;
        }

    } elsif($key eq "-style") {
        return Win32::GUI::GetWindowLong($self->{UNDERLYING}, -16);

    #} elsif(exists $self->{UNDERLYING}->{$key}) {
    #   print "[FETCH] fetching key $key from $self->{UNDERLYING}\n";
    #   return $self->{UNDERLYING}->{$key};

    } elsif(exists $self->{$key}) {
        # print "[FETCH] fetching key '$key' from '$self'\n";
        return $self->{$key};

    } else {
        # print "Win32::GUI::WindowProps::FETCH returning nothing for '$key' on $self->{UNDERLYING}\n";
        # print "[FETCH] returning nothing for '$key' on '$self'\n";
        return undef;
        # return 0;
    }
}

sub FIRSTKEY {
    my $self = shift;
    my $a = keys %{ $self };
    my ($k, $v) = each %{ $self };
#    print "[FIRSTKEY] k='$k' v='$v'\n";
    return $k;
}

sub NEXTKEY {
    my $self = shift;
    my ($k, $v) = each %{ $self };
#    print "[NEXTKEY] k='$k' v='$v'\n";
    return $k;
}

sub EXISTS {
    my($self, $key) = @_;
    # return exists $self->{UNDERLYING}->{$key};
    return exists $self->{$key};
}

sub DELETE {
    my($self, $key) = @_;
    # print "[DELETE]  self='$self' key='$key'\n";
    return delete $self->{$key};
}

sub UNTIE {
    my($self, $count) = @_;
    # print "[UNTIE] self='$self' count='$count'\n";
}

sub DESTROY {
  my $self = shift;
  # print "[DESTROY Debut] self='$self'\n";

  my $oself = tied(%$self);
  if ( defined $oself ) {
      # print "[OSELF] self='$oself' ".$oself->{-handle}."\n";

      foreach $key (keys %$oself) {
        if ( ref $oself->{$key} ) {
            delete $oself->{$key};
        }
      }

      Win32::GUI::DestroyWindow($oself->{-handle}) if exists $oself->{-handle};
      undef $oself;
      untie %$self;
  }

  # print "[DESTROY Fin  ] self='$self'\n";
}

###############################################################################
# dynamically load in the GUI.dll module.
#

package Win32::GUI;

# Need to bootstrap Win32::GUI early, so that we can call
# Win32::GUI::GetDllVersion during use/compile time
#bootstrap Win32::GUI;

bootstrap_subpackage 'Animation';
bootstrap_subpackage 'Bitmap';
bootstrap_subpackage 'Button';
bootstrap_subpackage 'Combobox';
bootstrap_subpackage 'DateTime';
bootstrap_subpackage 'DC';
bootstrap_subpackage 'Font';
bootstrap_subpackage 'Header';
bootstrap_subpackage 'ImageList';
bootstrap_subpackage 'Label';
bootstrap_subpackage 'Listbox';
bootstrap_subpackage 'ListView';
bootstrap_subpackage 'NotifyIcon';
bootstrap_subpackage 'ProgressBar';
bootstrap_subpackage 'Rebar';
bootstrap_subpackage 'RichEdit';
bootstrap_subpackage 'Splitter';
bootstrap_subpackage 'TabStrip';
bootstrap_subpackage 'Textfield';
bootstrap_subpackage 'Toolbar';
bootstrap_subpackage 'Tooltip';
bootstrap_subpackage 'Trackbar';
bootstrap_subpackage 'TreeView';
bootstrap_subpackage 'StatusBar';
bootstrap_subpackage 'UpDown';
bootstrap_subpackage 'Window';
bootstrap_subpackage 'MDI';
bootstrap_subpackage 'MonthCal';

# Preloaded methods go here.

$Win32::GUI::StandardWinClass = Win32::GUI::Class->new(
    -name    => "PerlWin32GUI_STD",
);

$Win32::GUI::MDIFrameWinClass = Win32::GUI::Class->new(
    -name    => "PerlWin32GUI_MDIFrame",
    -widget  => "MDIFrame"
);

$Win32::GUI::MDIChildWinClass = Win32::GUI::Class->new(
    -name    => "PerlWin32GUI_MDIChild",
    -widget  => "MDIChild"
);

$Win32::GUI::GraphicWinClass = Win32::GUI::Class->new(
    -name    => "Win32::GUI::Graphic",
    -widget  => "Graphic",
);

$Win32::GUI::SplitterHorizontal = Win32::GUI::Class->new(
    -name    => "Win32::GUI::Splitter(horizontal)",
    -widget  => "SplitterH",
);

$Win32::GUI::SplitterVertical = Win32::GUI::Class->new(
    -name    => "Win32::GUI::Splitter(vertical)",
    -widget  => "Splitter",
);

#Currently Autoloading is not implemented in Perl for win32
# Autoload methods go after __END__, and are processed by the autosplit program.

1;
__END__
