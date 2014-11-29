#!usr/bin/perl
use strict;
use warnings;

use utf8;
use File::Spec; use FindBin qw($Bin);	# needed for ID of script folder

use Tk;
use Tk::TableMatrix;
use Tk::Dialog;
use Tk::BrowseEntry;

sub get_scriptpath;
sub openfile;
sub addcolumns;
sub addcolumns_autoalign;
sub loadfromfile;

sub config_colwidths;	# configures colwidths to fill the window
sub setheight;			# adjusts cell heights to column width + content (TableMatrix doesn't have this built-in)

sub splitcell;
sub mergecell;
sub mergerow;			# merges all cells in the active row
sub shiftdown;			# pushes active column down from the active cell
sub shiftup;
sub deletecell;
sub deleterow;
sub switchcols;
sub deletelastcol;
sub removeempty;
sub savetofile;
sub bumpup;
sub bumpdown;
sub splitup;
sub split_shiftdown;

sub realign;

sub jumptonextempty;
sub search;

sub clone;				# makes a backup of the arrayVar so that the previous state can be restored with File/Undo or Ctrl-Z
sub undo;

sub error;


my $tool = "LF Alignment Editor";
my $version = "1.4";

# TODO

# check memory use

# cursor in wrong place when clicking into cell

# mergerow-t átírni úgy h lefelé tolja a cellákat, ne fel

# Save as...

# Control-Key-C - copy cell to clipboard

# Ctrl-F1 merge first sentence of next cell into current cell

# add segmentation option to Load additional column with autoalignment

# File/Generate HTML

# find and replace

# integrate into aligner as sub ?



# STORE FILE PATH PASSED AS CMDLINE ARGUMENT IN VAR (will be used later when calling loadfromfile)
my $file;
if ($ARGV[0]) {
	$file = $ARGV[0];
	# print "\ninput file: $file\n";
} 


# LOAD SETUP

my $scriptpath;
get_scriptpath;

my $colour1;
my $colour2;
my $activecolour;
my $textfont;
my $multiplier;
my $hidebutts;
open (SETUP, "<:encoding(UTF-8)", "$scriptpath/other_tools/alignedit_setup.txt") or error("\nCan't open setup file at : $!");

while (<SETUP>) {
	# these vars are declared where load_setup is called
	if (/Colour of odd rows:/) {
		/\[(.*)\]/;
		$colour1 = $1;
	}
	
	if (/Colour of even rows:/) {
		/\[(.*)\]/;
		$colour2 = $1;
	}
	
	if (/Colour of active cell:/) {
		/\[(.*)\]/;
		$activecolour = $1;
	}
	
	if (/Font:/) {
		/\[(.*)\]/;
		$textfont = $1;
	}
	
	if (/Row height multiplier:/) {
		/\[(.*)\]/;
		$multiplier = $1;
	}
	
	if (/Hide buttons:/) {
		/\[(.*)\]/;
		$hidebutts = $1;
		$hidebutts = "" if $hidebutts eq "n";
	}
	
}
close SETUP;

# defaults
$colour1 or $colour1 = "white";
$colour2 or $colour2 = "#EBEBFF";
$activecolour or $activecolour = "#A6C1FF";
$textfont or $textfont = "-*-Courier-Medium-R-Normal--*-140-*-*-*-*-*-*";
$multiplier or $multiplier = -8.4;

# my $arrayVar = {};	# a hashref for %$arrayVar
my %arrayVar;
my $arrayVar = \%arrayVar; # Ref to hash

my %arrayVar_prev;
my $rows_prev;
my $cols_prev;
my $arrayVar_prev = \%arrayVar_prev; # Ref to hash
# my $arrayVar_prev = {};	# this is where we store the previous state of %$arrayVar so that we can UNDO

# print "\nodd: $colour1; even: $colour2; active: $activecolour; font: $textfont; multiplier: $multiplier\n";




# CREATE MAINWINDOW
my $mw = MainWindow->new;
$mw->geometry("1200x700"); # default size, can be resized smaller
# $mw->FullScreen;			# seems to be buggy


########
# MENU #
########

my $frm_menu = $mw->Frame()->pack(-fill => 'x'); # -expand => 1, 

###########
# FILE MENU
my $menbutt_file = $frm_menu->Menubutton( -text => 'File' );
$menbutt_file->pack( -side => 'left' );

my $menu_file = $menbutt_file->Menu( -tearoff => 'no' );

# items in File menu
$menu_file->command(
	-label   => 'Open file (Ctrl-O)',
	-command => sub {openfile;},
);

$menu_file->command(
	-label   => 'Load additional columns from file',
	-command => sub {addcolumns;},
);

$menu_file->command(
	-label   => 'Load additional column with autoalignment',
	-command => sub {addcolumns_autoalign;},
);

$menu_file->separator();

$menu_file->command(
  -label   => 'Save (Overwrites original file!)',
  -command => sub {savetofile;},
);

$menu_file->command(
  -label   => 'Save & exit',
  -command => sub {savetofile; exit( 0 ); }, # or $mw->destroy
);

$menbutt_file->configure( -menu => $menu_file );


###########
# EDIT MENU
my $menbutt_edit = $frm_menu->Menubutton( -text => 'Edit' );
$menbutt_edit->pack( -side => 'left' );

my $menu_edit = $menbutt_edit->Menu( -tearoff => 'no' );



my $menu_undo = $menu_edit->command(
  -label   => 'Undo',
  -command => sub {undo;},
);
$menu_undo->configure(-state => 'disabled');

$menu_edit->separator();

$menu_edit->command(
  -label   => 'Adjust columns to fill window',
  -command => sub {config_colwidths; setheight;},
);

$menu_edit->command(
  -label   => 'Readjust row height',
  -command => sub {setheight;},
);

$menu_edit->separator();

$menu_edit->command(
  -label   => 'Search (F11)',
  -command => sub {search;},
);
my $searchterm; # needed for permanency of searches

$menu_edit->command(
  -label   => 'Jump to next empty cell (F12)',
  -command => sub {jumptonextempty;},
);

$menu_edit->separator();

$menu_edit->command(
  -label   => 'Delete content of active row (F5)',
  -command => sub {clone; deleterow;},
);

$menu_edit->command(
  -label   => 'Remove all empty rows',
  -command => sub {clone; removeempty;},
);

$menu_edit->command(
  -label   => 'Switch columns',
  -command => sub {clone; switchcols;},
);

$menu_edit->command(
  -label   => 'Delete entire last column',
  -command => sub {clone; deletelastcol;},
);

$menu_edit->command(
  -label   => 'Realign all below active row',
  -command => sub {clone; realign;},
);



$menbutt_edit->configure( -menu => $menu_edit );


###########
# HELP MENU
my $menbutt_help = $frm_menu->Menubutton( -text => 'Help' );
$menbutt_help->pack( -side => 'left' );

my $menu_help = $menbutt_help->Menu( -tearoff => 'no' );

$menu_help->command(
	-label   => 'Usage',
	-command => sub {
		
		my $about = $mw->Dialog(-title => 'How to use LF Alignment Editor', 
				   -text => "Open a tab separated UTF-8 txt file using File/Open. Adjust the columns to the desired width by dragging the borders, then click Edit/Readjust row height.\nUse the buttons at the bottom to pair up sentences. Start at the top and work your way down. You can delete rows using Edit/Delete active row.\nTip: You can move blocks of cells down or up by repeatedly clicking the Split or Merge button.\n\nOperations cannot be undone.\nYour changes are saved back to the original txt file, so if you need a backup, make one yourself.\nAny changes not saved to the file using Save or Save & exit will be lost.",
				   -default_button => 'Close', -buttons => ['Close'])->Show( );
		
	},
);


$menu_help->command(
	-label   => 'Keyboard shortcuts',
	-command => sub {
		my $shortcuts = $mw->Dialog(-title => 'Keyboard shortcut cheat sheet', 
				   -text => "Ctrl-O:	Open file\nCtrl-S:	Save file\nF1:	Merge\nF2:	Split\nF3:	Shift up\nF4:	Shift down\nF5:	Delete row\nShift-F5:	Delete cell\nF6:	Move nearest non-empty cell up\nShift-F6:	Move nearest non-empty cell down\nF7:	Split upwards\nF8:	Split and shift down\nF11:	Search\nF12:	Jump to next empty segment\nCtrl-Z:	Undo",
				   -default_button => 'Close', -buttons => ['Close'], -wraplength => 800)->Show( ); # 
	},
);


$menu_help->separator();

$menu_help->command(
	-label   => 'About',
	-command => sub {
		
		my $about = $mw->Dialog(-title => 'About LF Alignment Editor', 
				   -text => "LF Alignment Editor version $version\n\nBy András Farkas\nMail: lfaligner\@gmail.com\nwww.sourceforge.net/projects/aligner",
				   -default_button => 'Close', -buttons => ['Close'])->Show( );
		
	},
);

$menbutt_help->configure( -menu => $menu_help );





########################
# CREATE EDITING TABLE #
########################

my $frm_table = $mw->Frame()->pack(-expand => 1, -fill => 'both'); # -expand => 1, 



my $rows;
my $cols = 3; # number of columns


# LOAD TEXT FROM FILE PASSED AS CMDLINE ARGUMENT
loadfromfile($file); # if started without specifying a file as a cmdline parameter, the table will contain a message


my $width = -1100 / ($cols - 1);


sub rowSub{
	my $row = shift;
	return "OddRow" if( $row > 0 && $row % 2) 
}

my $t = $frm_table->Scrolled('TableMatrix', 
					-rows => $rows,
					-cols => $cols,
					-colorigin  => -1,
					-variable => $arrayVar,
					-wrap => 1,
					-justify => 'left',		# this only affects multiline cells
					-anchor => 'nw',			# this aligns text to the top left
					-font => $textfont,
					-scrollbars => 'osoe',
					-selectmode => 0,	# this seems to successfully disable cell selection, which is buggy as hell (single, browse, multiple or extended)
					-colwidth => $width, # default value, they can be resized by dragging
					-resizeborders => 'col', # none, col, row
					-bordercursor => 'sb_h_double_arrow', # add this if only horiz resizing is enabled
					-height => 2,	# minimum displayed table height in rows
					-bg => "$colour1", # background colour of odd-number rows
					# -fg => 'yellow', # text colour - black is default
					-rowtagcommand => \&rowSub, 
					# -maxheight =>300,
					# -colstretchmode => 'all', # using this breaks the height auto-adjustment
)->pack(-expand => 1, -fill => 'both');

$t->colWidth( -1 => -43); # column -1 contains a running serial number, we size the col for four digits
# disable editing the serial number column
$t->tagConfigure('noediting', -state => 'disabled');
$t->tagCol('noediting', '-1' );

$t->tagConfigure('OddRow', -bg => "$colour2"); #  EBEBFF

$t->tagConfigure('active', -bg => "$activecolour");	#  A6C1FF -  background colour of the active cell (the one the cursor is in)

# set column width in accordance with window size (last col narrower than rest)
# config_colwidths; # causes error

# ADJUST CELL HEIGHT - without args, the sub sets the height of all cells
setheight();	# height will be readjusted later when necessary by calling the same sub with args

$t->activate("0,0");
# $t->icursor("3");


# SCROLLING
$t->bind('<MouseWheel>'=>[sub{$_[0]->yview('scroll', -($_[1]/120),'units')} ,Ev('D')]); # mouse wheel scrolling code from https://groups.google.com/forum/?fromgroups=#!topic/comp.lang.perl.tk/TpQqAEeqN1k



##############################
# KEYBOARD SHORTCUT BINDINGS #
##############################

$mw->bind('<Control-Key-o>' => [sub {openfile;}]);
$mw->bind('<Control-Key-s>' => [sub {savetofile;}]);

$mw->bind('<Control-Key-d>' => [sub {clone; mergecell;}]); $mw->bind('<F1>' => [sub {clone; mergecell;}]);
$mw->bind('<Control-Key-g>' => [sub {clone; splitcell;}]); $mw->bind('<F2>' => [sub {clone; splitcell;}]);
$mw->bind('<Control-Key-r>' => [sub {clone; shiftup;}]); $mw->bind('<F3>' => [sub {clone; shiftup;}]);
$mw->bind('<Control-Key-f>' => [sub {clone; shiftdown;}]); $mw->bind('<F4>' => [sub {clone; shiftdown;}]);


$mw->bind('<Shift-F1>' => [sub {clone; mergerow;}]);

$mw->bind('<Control-Key-w>' => [sub {clone; deleterow;}]); $mw->bind('<F5>' => [sub {clone; deleterow;}]);
$mw->bind('<Shift-F5>' => [sub {clone; deletecell;}]);

$mw->bind('<F6>' => [sub {clone; bumpup;}]); # only available through this shortcut
$mw->bind('<Shift-F6>' => [sub {clone; bumpdown;}]); # only available through this shortcut
$mw->bind('<F7>' => [sub {clone; splitup;}]); # combined action that is only available through this shortcut
$mw->bind('<F8>' => [sub {clone; split_shiftdown;}]); # combined action that is only available through this shortcut


$mw->bind('<F11>' => [sub {search;}]);
$mw->bind('<Control-Key-j>' => [sub {jumptonextempty;}]); $mw->bind('<F12>' => [sub {jumptonextempty;}]);

$mw->bind('<Control-Key-z>' => [sub {undo;}]);



##########################################
# KEYBOARD SHORTCUTS FOR MOVING THE CURSOR


$mw->bind('<Shift-Key-Left>' => [sub {		# move cursor by one character
										my $curspos = $t->icursor();
										$curspos-- if $curspos > 0;
										$t->icursor($curspos);
									;}]);


$mw->bind('<Shift-Key-Right>' => [sub {
										my $curspos = $t->icursor();
										$curspos++;		# no problem seems to occur when it bumps into end of cell
										$t->icursor($curspos);
									;}]);



$mw->bind('<Control-Key-Left>' => [sub {		# move cursor by one word
											my $curspos = $t->icursor(); # query cursor position within the active cell
											
											my $actcont = $t->get('active');
											
											# WALK BACKWARDS TO START OF PREVIOUS WORD
											for (my $i = $curspos - 1; $i > 0; $i--) {
												# print "\ntesting character $i: " . substr($actcont,"$i",1) . "\n";
												if (substr($actcont,"$i",1) eq " ") {
													# print "Space found in position $i\n\n";
													$curspos = $i + 1;
													last;
												};
												$curspos = 0; # if cursor is in first word, split at beginning
											}
											$t->icursor($curspos);
											
									}]);




$mw->bind('<Control-Key-Right>' => [sub {
											my $curspos = $t->icursor(); # query cursor position within the active cell
											
											my $actcont = $t->get('active');
											
											my $length = length($actcont);
											
											# WALK FORWARDS TO START OF NEXT WORD
											for (my $i = $curspos + 1; $i < $length; $i++) {
												# print "\ntesting character $i: " . substr($actcont,"$i",1) . "\n";
												if (substr($actcont,"$i",1) eq " ") {
													# print "Space found in position $i\n\n";
													$curspos = $i;
													last;
												};
												$curspos = $length; # if cursor is in first word, split at beginning
											}
											$t->icursor($curspos);
											
									}]);




$mw->bind('<Control-Key-Up>' => [sub {	# by default Ctrl-up moves the selection up a row - we want it to jump to the beginning of the active cell instead
										my $actidx = $t->index('active');
										my ($actrow, $actcol) = split(",", $actidx);
										my $belowactrow = $actrow + 1;
										$t->activate("$belowactrow,$actcol");	# this misbehaves if the cursor is in the first row, but it can't be fixed
										# unless ($actrow == 0) {$t->activate("$belowactrow,$actcol")};	# fails when active cell is in second row
										$t->icursor(0);
									}]);

$mw->bind('<Control-Key-Down>' => [sub {
										my $actidx = $t->index('active');
										my ($actrow, $actcol) = split(",", $actidx);
										my $aboveactrow = $actrow - 1;
										$t->activate("$aboveactrow,$actcol");	# this misbehaves if the cursor is in the last row, but it can't be fixed
										$t->icursor('end')
									;}]);

$mw->bind('<Control-Alt-Key-Left>' => [sub {		# move cursor by one sentence
											my $curspos = $t->icursor(); # query cursor position within the active cell
											
											my $actcont = $t->get('active');
											
											# WALK BACKWARDS TO START OF PREVIOUS sentence
											for (my $i = $curspos - 2; $i > 0; $i--) {
												# print "\ntesting character $i: " . substr($actcont,"$i",1) . "\n";
												if (substr($actcont,"$i",3) =~ /^[\?\!\.\:]["'»«]?\s/) {
													# print "Space found in position $i\n\n";
													$curspos = $i + 1;
													$curspos++ if (substr($actcont,"$i",3) =~ /^.["'»«]\s/);
													last;
												};
												$curspos = 0; # if cursor is in first word, split at beginning
											}
											$t->icursor($curspos);
											

;}]);


$mw->bind('<Control-Alt-Key-Right>' => [sub {
											my $curspos = $t->icursor(); # query cursor position within the active cell
											
											my $actcont = $t->get('active');
											
											my $length = length($actcont);
											
											# WALK FORWARDS TO START OF NEXT SENTENCE
											for (my $i = $curspos + 1; $i < $length; $i++) {
												# print "\ntesting character $i: " . substr($actcont,"$i",1) . "\n";
												if (substr($actcont,"$i",3) =~ /^[\?\!\.\:]["'»«]?\s/) {
													# print "Space found in position $i\n\n";
													$curspos = $i + 1;
													$curspos++ if (substr($actcont,"$i",3) =~ /^.["'»«]\s/);
													last;
												};
												$curspos = $length; # if cursor is in first word, split at beginning
											}
											$t->icursor($curspos);
											
									}]);




#######################
# ADD EDITING BUTTONS #
#######################

my $frm_butts = $mw -> Frame() -> pack(); # to put the buttons above the editing table: pack(-before => $t)

my $buttmerge = $frm_butts->Button( -text => "Merge (F1)", -command => sub{clone; mergecell;},-width => 15,-height => 3,);
my $buttsplit = $frm_butts->Button( -text => "Split (F2)", -command => sub{clone; splitcell;},-width => 15,-height => 3,);
my $buttshiftup = $frm_butts->Button( -text => "Shift up (F3)", -command => sub{clone; shiftup;},-width => 15,-height => 3,);
my $buttshiftdown = $frm_butts->Button( -text => "Shift down (F4)", -command => sub{clone; shiftdown;},-width => 15,-height => 3,);
unless ($hidebutts) {$buttmerge->pack(-side => 'left', -padx => 5, -pady => 5,);$buttsplit->pack(-side => 'left', -padx => 5, -pady => 5,);$buttshiftup->pack(-side => 'left', -padx => 5, -pady => 5,);$buttshiftdown->pack(-side => 'left', -padx => 5, -pady => 5,);}


# THESE ARE DONE THROUGH THE MENU NOW:
# my $buttdelrow = $frm_butts->Button( -text => "Delete row (Ctrl-Space)", -command => sub{deleterow;},-width => 15,-height => 3,)->pack(-side => 'left', -anchor => 'e', -padx => 5, -pady => 5,);
# my $buttremoveempty = $frm_butts->Button( -text => "Remove empty rows", -command => sub{removeempty;},-width => 15,-height => 3,)->pack(-side => 'left', -anchor => 'e', -padx => 5, -pady => 5,); 

# my $buttsave = $mw->Button( -text => "Save", -command => sub{savetofile;})->pack();
# my $buttheight = $mw->Button( -text => "Set height", -command => sub {setheight();})->pack();
# my $buttexit = $mw->Button( -text => "Exit", -command => sub{savetofile;$mw->destroy})->pack();


# $t->focus;	# take focus so that scrolling and arrow navigation works as soon as the table loads, before you click into it
Tk::MainLoop;




########
# SUBS #
########

sub setheight {
	my ($fromrow, $torow);
	$fromrow = $_[0] or $fromrow = 0;			# work from indicated row or last row
	$torow = $_[1] or $torow = $rows - 1;	# work to indicated row or last row
	
	# print "\nsetting height of rows $fromrow to $torow\n";
	
	for my $i ($fromrow .. $torow) {
		# print "\n\nrow $i";
		for my $col (0 .. $cols - 2) { # $cols -2 because col numbering starts at -1 (row no)
			# print "\nactivating row $i col $col\n";
			$t->activate("$i,$col");
			my $activecont = $t->get('active');
			# print "\n$i,$col";
			my $charcount = length($activecont);
			# print " length: $charcount";
			my $width = $t->colWidth($col) / $multiplier; # approx width in characters - behaviour can be tuned by changing -8.4
			my $reqheight = int(length($activecont) / $width) + 1;
			# print ", required height: $reqheight";
			my $currheight = $t->rowHeight($i);
			$t->rowHeight($i, $reqheight) if ( ($col == 0) or ($reqheight > $currheight)); # set row height for the height of the tallest cell in the row
		}
	}
	
	
}




sub splitcell { # split active segment at cursor position and merge second half of content into next segment without shifting col
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	return if $actrow == $rows - 1; # if cursor is last row, do nothing
	
	
	# $t->set("$actidx", '%s') or print "Can't set: $!"; # wrong
	
	# print "\nActive cell index: >$actidx<; row: >$actrow< col: >$actcol<\n";
	my $curspos = $t->icursor(); # query cursor position within the active cell
	#do get length of active cell and return if curspos == length
	
	$t->activate("1,1");				# force the cell values to update in case of editing (such as inserting a space right before splitting the cell)
	$t->activate("$actrow,$actcol");	# reactivate the same cell
	my $actcont = $t->get('active');
	
	
	# IF CURSOR IS MID-WORD, WALK BACKWARDS AND SPLIT AT THE START OF THE WORD (first preceding space)
	my $beforecp = $curspos - 1;
	# print "2 chars around cursor position: >" . substr ($actcont, "$beforecp", 2) . "<";
	if ( ( substr ($actcont, "$beforecp", 2) =~ / / ) or ($curspos == length ($actcont)) ) {
		# print "space found near cursor or cursor is at end of cell"
	} else {
		# print "\ncursor is mid-word, walking back\n";
		for (my $i = $curspos; $i > 0; $i--) {
			# print "\ntesting character $i: " . substr($actcont,"$i",1) . "\n";
			if (substr($actcont,"$i",1) eq " ") {
				# print "Space found in position $i\n\n";
				$curspos = $i;
				last;
			};
			$curspos = 0; # if cursor is in first word, split at beginning
		}
	}
	
	
	
	
	my $beforecurs = substr($actcont, 0, $curspos);
	$beforecurs =~ s/\s$//;
	my $aftercurs = substr($actcont, $curspos); # store cell content after cursor position
	$aftercurs =~ s/^\s//;
	my $aftercurs_length = length($aftercurs);
	# print "\ncontent of active cell after cursor: $aftercurs\n";
	
	$arrayVar->{"$actrow,$actcol"} =  $beforecurs;
	# $t->deleteActive($t->icursor(), 'end'); # other method for deleting second half of active seg
	
	my $belowactrow = $actrow + 1; # working with cell below the row that the cursor is in
	
	$t->activate("$belowactrow,$actcol");
	my $belowactcont = $t->get('active');
	$belowactcont =~ s/^\s//;
	$belowactcont =~ s/\s$//;
	
	$arrayVar->{"$belowactrow,$actcol"} = "$aftercurs $belowactcont";
	$arrayVar->{"$belowactrow,$actcol"} =~ s/\s$//;
	$arrayVar->{"$belowactrow,$actcol"} =~ s/^\s//;
	
	setheight($actrow, $belowactrow);
	$t->activate("$belowactrow,$actcol");
	$t->icursor($aftercurs_length);	# move cursor after the inserted text in the cell below (this is to allow moving text down by repeatedly clicking Split)
}




sub mergecell {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	return if $actrow == $rows - 1; # if cursor is last row, do nothing
	
	# print "\nActive cell index: >$actidx<; row: >$actrow< col: >$actcol<\n";
	my $actcont = $t->get('active');
	
	my $belowactrow = $actrow + 1;
	
	my $belowactcont = $arrayVar->{"$belowactrow,$actcol"};
	$arrayVar->{"$actrow,$actcol"} .= " $belowactcont" if ($belowactcont); # add relevant text with .=
	$arrayVar->{"$actrow,$actcol"} =~  s/^\s//;		# just in case the active cell was empty
	$arrayVar->{"$actrow,$actcol"} =~  s/\s$//;		# just in case the active cell was empty
	
	$arrayVar->{"$belowactrow,$actcol"} = ""; 	# empty the cell below
	
	setheight($actrow, $belowactrow);
	$t->activate("$belowactrow,$actcol");
	# $t->yviewScroll(1, 'units') or print "Can't scroll: $!";
}




sub mergerow {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	return if $actrow == $rows - 1; # if cursor is last row, do nothing
	
	my $belowactrow = $actrow + 1;
	
	
	for my $col (0 .. $cols - 2) {
		# print "\nMerging row $actrow col $col\n";
		my $belowactcont = $arrayVar->{"$belowactrow,$col"};
		$arrayVar->{"$actrow,$col"} .= " $belowactcont" if $belowactcont; # add relevant text with .=
		$arrayVar->{"$actrow,$col"} =~  s/^\s//;		# just in case the active cell was empty
		$arrayVar->{"$actrow,$col"} =~  s/\s$//;		# just in case the active cell was empty
		$arrayVar->{"$belowactrow,$col"} = ""; 	# empty the cell below
	}
	
	setheight($actrow, $belowactrow);
	
}




sub shiftdown {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	
	my $cont = $t->get('active');
	$arrayVar->{"$actrow,$actcol"} = "";
	
	# add a row
	$rows++;
	$t->configure(-rows => $rows,);
	# add serial no to last row
	my $lastrow = $rows - 1;
	$arrayVar->{"$lastrow,-1"} = $rows;
	
	for my $i ($actrow + 1 .. $rows - 1) {
		my $cont_temp = $t->get("$i,$actcol");
		$arrayVar->{"$i,$actcol"} = $cont;
		$cont = $cont_temp;
		
	}
	setheight($actrow); # update the table display and cell heights
	my $belowactrow = $actrow + 1;
	$t->activate("$belowactrow,$actcol");
}




sub shiftup {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	return if $actrow == 0; # if cursor is first row, do nothing
	
	if ($actrow == 0) {$actrow = 1;$t->activate("$actrow,$actcol");} # can't shift up the top cell
	
	my $cont = $t->get('active');
	
	my $aboveactrow = $actrow - 1;
	$arrayVar->{"$aboveactrow,$actcol"} .= " $cont"; # use above as well
	$arrayVar->{"$aboveactrow,$actcol"} =~ s/^\s//;
	$arrayVar->{"$aboveactrow,$actcol"} =~ s/\s$//;
	
	my $ii;
	for my $i ($actrow .. $rows - 2) {
		$ii = $i + 1;
		my $cont = $t->get("$ii,$actcol");
		$arrayVar->{"$i,$actcol"} = $cont;
	}
	
	my $lastrow = $rows - 1;
	$arrayVar->{"$lastrow,$actcol"} = "";
	
	setheight($aboveactrow); # update the table display and cell heights
	$t->activate("$aboveactrow,$actcol");
}




sub bumpup {
	# print "\nbumpup\n";
	
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	my $belowactrow = $actrow + 1;
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	return if $actrow == $rows - 1; # if cursor is last row, do nothing
	
	if ($arrayVar->{"$actrow,$actcol"}) {	# if the active cell is not empty
		if (!$arrayVar->{"$belowactrow,$actcol"}) {	# move on to the one below if it's empty
			# print "\nmoved down a row\n";
			$t->activate("$belowactrow,$actcol");
			$actidx = $t->index('active');
			($actrow, $actcol) = split(",", $actidx);
			$belowactrow = $actrow + 1;
		} else {	# do nothing if the cell below the active cell is not empty, either
			# print "\nreturning\n";
			return;
		}
	}
	
	my $moveme;		# because $i goes out of scope
	#do activate cell below if active cell is not empty
	
	for my $i ($actrow + 1 .. $rows - 1) {
		
		if ($arrayVar->{"$i,$actcol"}) {
			$arrayVar->{"$actrow,$actcol"} = $arrayVar->{"$i,$actcol"};
			$arrayVar->{"$i,$actcol"} = "";
			$moveme = $i;
			last;
		}
	
	}
	setheight($actrow, $actrow);
	setheight($moveme, $moveme);
	$t->activate("$actrow,$actcol");
}




sub bumpdown {
	# print "\nbumpup\n";
	
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	my $aboveactrow = $actrow - 1;
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	return if $actrow == 0; # if cursor is first row, do nothing
	
	if ($arrayVar->{"$actrow,$actcol"}) {	# if the active cell is not empty
		if (!$arrayVar->{"$aboveactrow,$actcol"}) {	# move on to the one above if that one is empty
			# print "\nmoved up a row\n";
			$t->activate("$aboveactrow,$actcol");
			$actidx = $t->index('active');
			($actrow, $actcol) = split(",", $actidx);
			$aboveactrow = $actrow - 1;
		} else {	# do nothing if the cell below the active cell is not empty, either
			# print "\nreturning\n";
			return;
		}
	}
	
	my $moveme;		# because $i goes out of scope
	#do activate cell above if active cell is not empty
	
	for (my $i = $actrow -1; $i >= 0; $i--) {
		if ($arrayVar->{"$i,$actcol"}) {
			$arrayVar->{"$actrow,$actcol"} = $arrayVar->{"$i,$actcol"};
			$arrayVar->{"$i,$actcol"} = "";
			$moveme = $i;
			last;
		}
	
	}
	setheight($actrow, $actrow);
	setheight($moveme, $moveme);
	$t->activate("$actrow,$actcol");
}



sub splitup {	# split active segment, but instead of pushing the second part down, push the first part up
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	return if $actcol == -1; # if cursor is in column -1, do nothing
	return if $actrow == 0; # if cursor is in the top row, do nothing
	
	my $curspos = $t->icursor(); # query cursor position within the active cell
	
	my $aboveactrow = $actrow - 1;
	my $charcount_above = 0;
	$charcount_above = length($arrayVar->{"$aboveactrow,$actcol"}) or $charcount_above = 0;
	# print "\ncharacter count of cell above active cell: $charcount_above\n";
	my $new_curspos = $charcount_above + 1 + $curspos;	# char position where we'll need to split the cell
	
	# MERGE THE ACTIVE CELL WITH THE ONE ABOVE IT
	$t->activate("$aboveactrow,$actcol");
	mergecell;
	
	# SPLIT THE CELL
	$t->activate("$aboveactrow,$actcol");
	$t->icursor($new_curspos);
	splitcell;
	
	$t->activate("$aboveactrow,$actcol");
	
}




sub split_shiftdown {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	my $curspos = $t->icursor(); # query cursor position within the active cell
	
	my $belowactrow = $actrow + 1;
	$t->activate("$belowactrow,$actcol");
	shiftdown;
	
	$t->activate("$actrow,$actcol");
	$t->icursor($curspos); # force cursor position within the active cell
	
	splitcell;
}




sub jumptonextempty {
	
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	for my $i ($actrow + 1 .. $rows - 1) {
		for my $col (0 .. $cols - 2) {
			unless ($arrayVar->{"$i,$col"}) {
				$t->activate("$i,$col");
				$t->see("$i,$col");
				return;
			}
		}
	}
	
}




sub search {
	
	my $searchwindow = $mw->Toplevel(-title => 'Search');
	$searchwindow->raise($mw);
	$searchwindow -> Label (-text => "Find terms in the text", -font => 'bold',)->pack (-pady => 10, );

	$searchwindow -> Label (-text => "Search term:")->pack (-padx => 5, -pady => 5, -anchor=> 'w',);

	my $searchentry = $searchwindow-> Entry (-textvariable => \$searchterm, -width => 40, -takefocus => 1 )->pack(-padx => 5, -pady => 5, -anchor=> 'w',);
	$searchentry->focus( -force );

	my $frm_butts = $searchwindow -> Frame() -> pack(-expand => 1, -fill => 'both'); # to put the buttons above the editing table: pack(-before => $t)

	my $findnext;
	
	
	$findnext = sub {
		# print "Search term entered: $searchterm";
		my $actidx = $t->index('active');
		my ($actrow, $actcol) = split(",", $actidx);
		
		# print "\nsearching for $searchterm below row $actrow\n";
		
			for my $i ($actrow + 1 .. $rows - 1) {
			for my $col (0 .. $cols - 2) {
				# print "\ntesting cell $i $col";
				# if ($arrayVar->{"$i,$col"} =~ /$searchterm/i) {
				if (($arrayVar->{"$i,$col"}) && ($arrayVar->{"$i,$col"} =~ /$searchterm/i)) { # otherwise I get an error msg if the last cell is empty
					# print "\nfound a hit for $searchterm in row $i, column $col\n"; # comment out
					$t->activate("$i,$col");
					$t->see("$i,$col");
					return; # stop at the first hit
				}
			}
		}
		
		# $searchwindow->Dialog(-title => 'No hits', 
			   # -text => "Search term not found below the active row", 
			   # -default_button => 'OK', -buttons => ['OK'])->Show( );
		
	}; # don't delete the ;

	# KEYBOARD BINDINGS
	$searchwindow->bind( '<KeyRelease-Return>' => [\&$findnext]);
	$searchwindow->bind( '<KeyRelease-Escape>' => [sub {$searchwindow -> destroy}]);

	# BUTTONS
	my $buttnexthit = $frm_butts->Button( -text => "Find next", -command => $findnext, -width => 15,)->pack(-side => 'left', -anchor => 'sw', -padx => 5, -pady => 5,);
	my $buttcancel = $frm_butts->Button( -text => "Cancel", -command => sub {$searchwindow -> destroy},-width => 15,)->pack(-side => 'right', -anchor => 'se', -padx => 5, -pady => 5,);

}




sub deletecell {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	$arrayVar->{"$actrow,$actcol"} = "";
	
	setheight($actrow, $actrow); # update the table display and cell heights
	my $belowactrow = $actrow + 1;
	$t->activate("$belowactrow,$actcol");
}




sub deleterow {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	for my $col (0 .. $cols - 2) {
		$arrayVar->{"$actrow,$col"} = "";
	}
	setheight($actrow, $actrow); # update the table display and cell heights
	my $belowactrow = $actrow + 1;
	$t->activate("$belowactrow,$actcol");
}


sub switchcols {
	
	
	
	my $sw = $mw->Toplevel(-title => 'Search');	#create switch pick window
	$sw->minsize(300, 150);		# minimum size of main window in pixels
	$sw->raise($mw);
	
	$sw -> Label (-text => "Switch columns:", -font => 'bold',)->pack (-pady => 10, );
	my $switchme = 1;
	my $withme = 2;

	# $sw -> Label (-text => "Pick columns to switch:")->pack (-padx => 5, -pady => 5,); 	#  -anchor=> 'w',
	
	my $frm_pickers = $sw->Frame()->pack(); # -expand => 1, 
	
					my $picker1 = $frm_pickers -> BrowseEntry(
					-label => 'Switch this column: ',
					-state => 'readonly',		# only choose from picklist, no free text entry
					-variable => \$switchme,
					-width => 4,
					# -browsecmd => sub {}
				)->pack(-pady => 5, -anchor => 'e');# pack(-side => 'left');
				$picker1->insert('end', (1 .. $cols - 1));
	
	
	
					my $picker2 = $frm_pickers -> BrowseEntry(
					-label => 'With this one: ',
					-variable => \$withme,
					-state => 'readonly',
					-width => 4,
					# -browsecmd => sub {}
				)->pack(-pady => 5, -anchor => 'e');# pack(-side => 'left');
				$picker2->insert('end', (1 .. $cols - 1));
	
	
	
	
	my $go;		# this sub runs when the go button is pressed
	$go = sub {
		
		return if $switchme == $withme;
		$switchme--;
		$withme--;
		
		# print "\nswitching col $switchme with col $withme\n";
		
		for my $row (0 .. $rows - 1) {
			my $temp = $arrayVar->{"$row,$switchme"};
			$arrayVar->{"$row,$switchme"} = $arrayVar->{"$row,$withme"};
			$arrayVar->{"$row,$withme"} = $temp;
			
		}
		
		# no need to run setheight, but we need to force the table display to update
		$t->configure(-padx =>( $t->cget(-padx)));
		
		$sw -> destroy; # close the window
		
		my $actidx = $t->index('active');
		my ($actrow, $actcol) = split(",", $actidx);
		$t->activate("1,1");				# force the cell values to update
		$t->activate("$actrow,$actcol");	# reactivate the same cell
		
	};	# don't delete, end of $go sub
	
	
	
		# BUTTONS
	my $buttgo = $sw->Button( -text => "GO", -command => $go, -width => 15,)->pack(-side => 'left', -anchor => 'sw', -padx => 5, -pady => 5,);
	my $buttcancel = $sw->Button( -text => "Cancel", -command => sub {$sw -> destroy},-width => 15,)->pack(-side => 'right', -anchor => 'se', -padx => 5, -pady => 5,);
	
}



sub deletelastcol {
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	my $col = $cols - 2;
	
	for my $row (0 .. $rows - 1) {
		$arrayVar->{"$row,$col"} = undef;
	}
	
	$cols--;
	$t->configure(-cols => $cols,);	#columns?
	
	
	setheight(); # update the table display and cell heights
	
	$t->activate("$actrow,$actcol");
	
	
}



sub removeempty {
	my $actidx = $t->index('active'); # store index of active cell for reactivation at the end
	
	# first, generate a list of empty rows and store in a hash for easy lookup
	my %empty;
	for my $i (0 .. $rows - 1) {
		my $thisisempty = "yes";	# marker, set to signify empty by default
		for my $col (0 .. $cols - 2) {
			if ($arrayVar->{"$i,$col"}) {$thisisempty = ""}; # if any cell in the row contains text, mark the row as not empty
		}
		$empty{$i}++ if $thisisempty;	# enter row number into hash if the row is empty
	}
	
	my $emptyrows = scalar keys %empty; # number of empty rows
	# print "\n$emptyrows empty rows found\n";
	
	# rewrite arrayvar, skipping empty rows
	my $offset = 0;
	my $printrow; # the row we'll be writing text into (can be a lower number row than the one we're reading from as rows are moved up)
	for my $i (0 .. $rows - 1) {
		
		if ($empty{$i}) {	# skip empty rows
			$offset++;
			next;
			# print "\n$i is empty; offset is now $offset\n";
		}
		
		$printrow = $i - $offset;
		# print "\n printing into $printrow from $i\n";
		for my $col (0 .. $cols - 2) {
			$arrayVar->{"$printrow,$col"} = $arrayVar->{"$i,$col"}; # copy text from row $i to row ($i - $offset)
		}
		
	}
	

	
	# REMOVE SURPLUS VALUES from arrayVar
	# text associated with higher row numbers than the current size of the table might be present and would show up when the row count is increased later by shiftdown
	for my $i ($printrow + 1 .. $rows - 1) {
		foreach my $col (0 .. $cols - 2) {
			$arrayVar->{"$i,$col"} = "";
			$arrayVar->{"$i,$col"} = "";
		}
	}
	
	
	# UPDATE ROW COUNT
	# print "\nthere used to be $rows rows\n";
	$rows = $rows - $emptyrows;
	# print "\nrow number reduced to $rows\n";
	$t->configure(-rows => $rows,);
	
	
	setheight();
	
	$t->activate($actidx); # re-activate the cell that was active when the sub was called
}










sub realign {
	
	# return if $cols > 3;	# we only do this with 2-language alignments
	
	my $actidx = $t->index('active');
	my ($actrow, $actcol) = split(",", $actidx);
	
	# my $actrow_print = $actrow + 1;
	# my $confirm = $mw->Dialog(-title => 'Confirm realign', 
				   # -text => "This operation uses hunalign to auto-align everything below row $actrow_print in columns 1 and 2.\nAre you sure you want to proceed?",
				   # -default_button => 'Yes', -buttons => ['Yes', 'Not really'])->Show( );
	
	# return if $confirm ne "Yes";
	
	# print "\nrealigning from row $actrow, output: $scriptpath/other_tools/lang1.txt\n";
	
	# GENERATE FILES TO ALIGN
	open (OUT1, ">:encoding(UTF-8)", "$scriptpath/other_tools/lang1.txt") or error("\nCan't open lang 1 output file: $!");	#do return in addition to raising the error
	open (OUT2, ">:encoding(UTF-8)", "$scriptpath/other_tools/lang2.txt") or error("\nCan't open lang 2 output file: $!");
	
	for my $i ($actrow + 1 .. $rows - 1) {
		if ($arrayVar->{"$i,0"}) { 
			print OUT1 $arrayVar->{"$i,0"} . "\n";
		}
		
		if ($arrayVar->{"$i,1"}) { 
			print OUT2 $arrayVar->{"$i,1"} . "\n";
		}
		
		
	}
	
	close OUT1;
	close OUT2;
	
	# RUN HUNALIGN
	system ("\"$scriptpath\\scripts\\hunalign\\hunalign\" -text \"$scriptpath\\scripts\\hunalign\\data\\null.dic\" \"$scriptpath/other_tools/lang1.txt\" \"$scriptpath/other_tools/lang2.txt\" > \"$scriptpath/other_tools/aligned.txt\""); # or error("\nCan't run hunalign: $!"); # always raises an error
	
	# IMPORT ALIGNED SEGMENTS TO TABLE
	open (ALIGNED, "<:encoding(UTF-8)", "$scriptpath/other_tools/aligned.txt") or error("\nCan't open aligned file for reading: $!");
	my $row;
	my $cell1;
	my $cell2;
	while (<ALIGNED>) {
		next if /^\t\t/;	# skip empty (hunalign generates one empty row at the end)
		$row = $. + $actrow; # row to insert text into
		
		s/ ~~~//g;				# remove ~~~ inserted by Hunalign
		/^([^\t]*)\t([^\t]*)/;
		$cell1 = $1;
		$cell2 = $2;
		
		$arrayVar->{"$row,0"} = $cell1;
		$arrayVar->{"$row,1"} = $cell2;
		
	}
	close ALIGNED;
	
	
	# REMOVE SURPLUS VALUES from arrayVar
	# text associated with higher row numbers than the current size of the table might be present and would show up when the row count is increased later by shiftdown
	for my $i ($row + 1 .. $rows - 1) {
		$arrayVar->{"$i,0"} = "";
		$arrayVar->{"$i,1"} = "";
	}
	
	# UPDATE ROW COUNT
	$rows = $row + 1; # chop the surplus off the end of the table
	$t->configure(-rows => $rows,);
	
	setheight;	#redraw the table
	
	unlink "$scriptpath/other_tools/lang1.txt";
	unlink "$scriptpath/other_tools/lang2.txt";
	unlink "$scriptpath/other_tools/aligned.txt";
	unlink "$scriptpath/other_tools/translate.txt";
	
}




sub openfile {
	my $in_type = [	['Txt', ['.txt']],
							['All Files', '*']	];

			
			$file = $mw ->getOpenFile(
									-title => "Please choose the input file(s)",
									-filetypes => $in_type,
									-multiple => 0,
								);
	
	return unless ($file);	# if ESC was pressed, do nothing
	
	loadfromfile($file); # this is placed in a separate sub because it is also called on startup to open any file passed as a command line argument
	
	$t->configure(-rows => $rows,);
	$t->configure(-cols => $cols,);
	
	
	config_colwidths;
	
	setheight();
	$t->activate("0,0");
	$t->see("0,0");
}




sub loadfromfile { # this sub is passed a file name and loads the file into the table
	$file = $_[0] or $file = 0;

	# print "\nloading from file $file\n";
	# undef %$arrayVar; # empty the table
	
	
	if ($file) {
		unless (open (IN, "<:encoding(UTF-8)", "$file") ) {error ("\nCan't open input file: $!");return};
				while (<IN>){my @colcount = $_ =~ /\t/g; $cols = scalar @colcount + 2;last;}
		close IN;

		unless (open (IN, "<:encoding(UTF-8)", "$file") ) {error ("\nCan't open input file: $!");return};
		while (<IN>){
			s/^\x{FeFF}// if $. == 1;		# remove BOM
			chomp;
			my $i = $. - 1;
			# my @fields = $_ =~ /[^\t]*/g; # if row is empty, row will be empty in the table as well until removeempty is called
			my @fields = split ("\t", $_);
			$arrayVar->{"$i,-1"} = "$."; # add row number
			foreach my $col (0 .. $cols - 2) {
				$arrayVar->{"$i,$col"} = $fields[$col];
			}
			
		}
		$rows = $.;
		close IN;
		
	} else { # if launched without passing a filename, print welcome message
		$arrayVar->{"0,0"} = "Click File/Open to open an input file. (Only tab separated  txt files in UTF-8 encoding are supported.)";
		$rows = 1;
	}
	

	# print "\nrows: $rows\n";
	
	# set window title
	my $file_short = $file;
	$file_short =~ s/.*[\\\/]//;
	$mw->title("$tool $version - $file_short");

}




sub addcolumns {
	my $in_type = [ ['Txt', ['.txt'] ], ['All Files', '*'] ];
	
			my $file = $mw ->getOpenFile(	#do add my here and test
										-title => "Please choose the input file(s)",
										-filetypes => $in_type,
										-multiple => 0,
									);
	
	
	my $newcols;		# we'll add this many columns to the table
	unless (open (IN, "<:encoding(UTF-8)", "$file") ) {error ("\nCan't open input file: $!");return};
			while (<IN>){my @colcount = $_ =~ /\t/g; $newcols = scalar @colcount + 1;last;}
	close IN;
	
	unless (open (IN, "<:encoding(UTF-8)", "$file") ) {error ("\nCan't open input file: $!");return};
	
	my $i = 0;
	while (<IN>){
		next if /^\s*$/;		# skip empty rows
		
		s/^\x{FeFF}// if $. == 1;		# remove BOM
		chomp;
		
		my @fields = split ("\t", $_);
		
		$arrayVar->{"$i,-1"} = "$."; # add row number to table in case there are more rows in the new file than there are in the existing table
		
		foreach my $col (0 .. $newcols) {
			my $colidx = $col + $cols - 1;
			$arrayVar->{"$i,$colidx"} = $fields[$col];
		}
		
		$i++;
	}
	my $newrows = $i;
	close IN;
	
	
	
	# print "\nrows in old file$ rows; in new file: $newrows\n";
	
	if ($newrows > $rows) {$rows = $newrows; $t->configure(-rows => $rows);};
	$cols = $cols + $newcols;
	$t->configure(-cols => $cols);
	
	# print "\nrow number set to: $rows\n";
	
	config_colwidths;
	
	setheight();
	$t->activate("0,0");
}




sub addcolumns_autoalign {
	my $in_type = [ ['Txt', ['.txt'] ], ['All Files', '*'] ];
	
			my $file = $mw ->getOpenFile(	# in this sub, $file is the file that contains the extra column to be added
										-title => "Please choose the input file(s)",
										-filetypes => $in_type,
										-multiple => 0,
									);
	
	unless (open (IN, "<:encoding(UTF-8)", "$file") ) {error ("\nCan't open input file $file: $!");return};
	my $file_mod = $file;
	$file_mod =~ s/\.([^\.]+)$/_mod\.$1/;
	# print "\nmod file name: $file_mod\n";
	
	unless (open (OUT, ">:encoding(UTF-8)", "$file_mod") ) {error ("\nCan't open output file $file_mod: $!");return};
	while (<IN>){
		next if /^\s*$/;		# skip empty rows
		s/^\x{FeFF}// if $. == 1;		# remove BOM
		print OUT;
	}
	close IN;
	close OUT;
	
	
	
	# EXPORT COLUMN 1
	unless (open (OUT1, ">:encoding(UTF-8)", "$scriptpath/other_tools/lang1.txt") ) {error ("\nCan't open output file: $!");return};
	
	
	
	for my $i (0 .. $rows - 1) {
		my $text = $arrayVar->{"$i,0"};
		$text =~ s/ ~~~//;
		if ($text) {print OUT1 $text;} else {print OUT1 "[NULL]";}
		print OUT1 "\n" ;
	}
	
	close OUT1;
	
	# print "\nabout to call hunalign\n";
	# <STDIN>;
	
	# RUN HUNALIGN
	system ("\"$scriptpath\\scripts\\hunalign\\hunalign\" -text \"$scriptpath\\scripts\\hunalign\\data\\null.dic\" \"$scriptpath/other_tools/lang1.txt\" \"$file_mod\" > \"$scriptpath/other_tools/aligned.txt\""); # or error("\nCan't run hunalign: $!"); # always raises an error
	
	# print "\nran hunalign\n";
	# <STDIN>;
	
	
			# UNDO SEGMENT MERGING DONE BY HUNALIGN IN L1

		unless (open (ALIGNED, "<:encoding(UTF-8)", "$scriptpath/other_tools/aligned.txt") ) {error ("\nCan't open input file $file: $!");return};
		unless (open (ALIGNED_MOD, ">:encoding(UTF-8)", "$scriptpath/other_tools/aligned_mod.txt") ) {error ("\nCan't open input file $file: $!");return};
		my $repeat;
		REPEAT: # label for looping, come back here if needed
		$repeat = "0";
		while (<ALIGNED>) { #
			s/^([^\t]*) ~~~ ([^\t]*)\t(.*)$/$1\t$3\n$2\t/; # not /g!
			if (/^[^\t]* ~~~ /) {$repeat = "1"}# if there are still instances of ~~~ left in the text
			print ALIGNED_MOD;
		}

		close ALIGNED;
		close ALIGNED_MOD;
		unless ( rename ("$scriptpath/other_tools/aligned_mod.txt", "$scriptpath/other_tools/aligned.txt") ) {error("\nCan't rename file: $!");return};
		unless ( open (ALIGNED, "<:encoding(UTF-8)", "$scriptpath/other_tools/aligned.txt") ) {error("\nCan't open file for reading: $!");return};
		unless ( open (ALIGNED_MOD, ">:encoding(UTF-8)", "$scriptpath/other_tools/aligned_mod.txt") ) { abort("Can't open file for writing: $!");return};

		goto REPEAT if $repeat eq "1";
	
	# print "\nstretching done\n";
	# <STDIN>;
	
	
	
		# MERGE BACK WHERE HUNALIGN STRETCHED APART
		my $previous = "";
		while (<ALIGNED>) {
			chomp;
			print ALIGNED_MOD $previous; # print previous line
			# if (/^[^\t]/) {print ALIGNED_MOD "\n"} else {s/^\t/ /}# if first field of this line is empty, append to previous (don't print line break after previous)
			unless ($. == 1) {if (/^[^\t]/) {print ALIGNED_MOD "\n"} else {s/^\t/ /} }# if first field of this line is empty, append to previous (don't print line break after previous)
			$previous = $_;
		}
		print ALIGNED_MOD $previous;

		close ALIGNED;
		close ALIGNED_MOD;
		unless ( rename ("$scriptpath/other_tools/aligned_mod.txt", "$scriptpath/other_tools/aligned.txt") ) {error("\nCan't rename file: $!");return};
	
	# print "\nmerging done\n";
	# <STDIN>;
	
	unless (open (IN, "<:encoding(UTF-8)", "$scriptpath/other_tools/aligned.txt") ) {error ("\nCan't open aligned file for reading: $!");return};
	
	my $i = 0;
	my $colidx = $cols - 1;
	while (<IN>){
		next if /^\s*$/;		# skip empty rows
		s/^\x{FeFF}// if $. == 1;		# remove BOM
		chomp;
		s /^ +//;
		s/ ~~~//g;				# remove ~~~ inserted by Hunalign
		
		# $arrayVar->{"$i,-1"} = "$."; # no need to add row number as length won't change
		
		/^[^\t]*\t([^\t]*)/;
		$arrayVar->{"$i,$colidx"} = $1;
		
		$i++;
	}
	my $newrows = $i;
	close IN;
	
	
	unlink $file_mod;
	unlink "$scriptpath/other_tools/lang1.txt";
	unlink "$scriptpath/other_tools/aligned.txt";
	unlink "$scriptpath/other_tools/translate.txt";

	# print "\nrows in new file: $newrows\n";
	
	if ($newrows > $rows) {$rows = $newrows; $t->configure(-rows => $rows);};
	
	$cols++;
	$t->configure(-cols => $cols);
	
	
	config_colwidths;
	setheight();
	$t->activate("0,0");
}




sub savetofile { # doesn't save the last changes to the active cell when called by keyboard shortcut

	# REMOVE EMPTY LINES before saving to file
	#do this could be sped up by simply skipping empty lines when writing instead of calling the removeempty sub (write previous line in every loop iteration) - benchmark to decide
	removeempty;

	open (OUT, ">:encoding(UTF-8)", "$file") or error ("\nCan't open output file: $!"); # Replace the original file with the edited content. No backups, no takesie-backsies.
	
	for my $i (0 .. $rows - 1) {
		print OUT "\x{FeFF}" if $i == 0;		# add BOM
		for my $col (0 .. $cols - 2) { # $cols -2 because col numbering starts at -1 (row no)
			if ($arrayVar->{"$i,$col"}) {$arrayVar->{"$i,$col"} =~ s/\n//g; print OUT $arrayVar->{"$i,$col"}};
			print OUT "\t" unless $col == $cols - 2; # no \t needed after last cell in the row #do replace with join
		}
		print OUT "\n" unless $i == $rows - 1; # no line break needed after last line
	}
	close OUT;
}




sub config_colwidths {
	# CONFIGURE COLWIDTHS so that all cols fit into the current width of the $mw
	my $mw_width = $mw->width; # query $mw width, which may have been changed by going full screen etc.
	# print "\nmain window is $mw_width pixels wide\n";
	
	$width = ($mw_width - 80) / ($cols - 1);
	
	# if ($cols == 4) {$width = $width + 50};	#last column usually contains a short note, make it narrower than the rest
	# if ($cols == 5) {$width = $width + 33};
	
	$width = 150 if $width < 150; # set a minimum
	$width = $width * -1;	# width measured in pixels, therefore negative
	for my $col (0 .. $cols - 2) {
		$t->colWidth( $col => $width);
	}
	# print "\nset columns to $width \n";
	
	# if ($cols == 4) {$t->colWidth( 2 => ($width + 150) )};	#last column usually contains a short note, make it narrower than the rest
	# if ($cols == 5) {$t->colWidth( 3 => ($width + 133) )};
	
	# my $lastcol = $t->colWidth(2);	print "\nlast column set to: $lastcol\n";
}




sub clone {
	# print "\ncloning\n";
	
	# undef %$arrayVar_prev or print "Can't undef: $!";
	%arrayVar_prev = %arrayVar;		# Create a copy of the hash
	$rows_prev = $rows;				# store the no of rows so it can be restored
	$cols_prev = $cols;				# store the no of rows so it can be restored
	$menu_undo->configure(-state => 'normal');	# enable the Undo command in the menu
}




sub undo {
	# print "\nUndoing last operation\n";
	
	%arrayVar = %arrayVar_prev; # restore the main hash using the cloned backup - the row and col count is restored later
	
	# print "\nemptying cloned hash\n";
	# sleep 3;
	# undef %arrayVar_prev or print "Can't undef: $!";
	
	
	# RESTORE ROW COUNT
	# print "\nthere used to be $rows rows; row number changed to $rows_prev\n";
	$rows = $rows_prev;
	$t->configure(-rows => $rows,);
	
	# RESTORE COL COUNT
	$cols = $cols_prev;
	$t->configure(-cols => $cols,);
	
	setheight();
	
	$menu_undo->configure(-state => 'disabled');
	
}




sub error {
	my $errormsg = $_[0];
	# print $errormsg
	
	
	$mw->Dialog(
					-title => "ERROR", 
					-text => "ERROR!\n$errormsg",
					-default_button => 'Close',
					-buttons => ['Close'],
				)->Show( );
	
}




sub get_scriptpath {
	my $script = File::Spec->rel2abs( __FILE__ );

	$script =~ /(.*)[\/|\\](.*)/;
	$scriptpath = $1;

	$scriptpath =~ /(.*)[\/|\\](.*)/;
	my $scriptpath_alt1 = $1;

	$scriptpath_alt1 =~ /(.*)[\/|\\](.*)/;
	my $scriptpath_alt2 = $1;

	$Bin or $Bin = $script;		# avoid error msg
	$Bin =~ /(.*)[\/|\\](.*)/;	# 2nd attempt at finding scripts directory
	my $Bin_alt = $1;

	$0 or $0 = $script;			# avoid error msg
	$0 =~ /(.*)[\/|\\](.*)/;	# 3rd attempt at finding scripts directory
	my $scriptpath_alt3 = $1;

	$scriptpath_alt2 =~ /(.*)[\/|\\](.*)/;
	my $scriptpath_alt4 = $1;


	if (-d "$scriptpath/scripts/hunalign") {
		# print "\nScript folder found.\n";
	} elsif (-d "$scriptpath_alt1/scripts/hunalign") {$scriptpath = $scriptpath_alt1}
	elsif (-d "$scriptpath_alt2/scripts/hunalign") {$scriptpath = $scriptpath_alt2}
	elsif (-d "$Bin/scripts/hunalign") {$scriptpath = $Bin}	# machinegun approach in case (__File__) fails
	elsif (-d "$Bin_alt/scripts/hunalign") {$scriptpath = $Bin_alt}
	elsif (-d "$scriptpath_alt2/scripts/hunalign") {$scriptpath = $scriptpath_alt3}
	elsif (-d "$scriptpath_alt3/scripts/hunalign") {$scriptpath = $scriptpath_alt4}
	else {
		do {
			print "\nThe script path found automatically (${scriptpath}) is not correct.\nPlease drag and drop the aligner script here and press enter. (If your OS doesn't support drag & drop, copy-paste the path here. You can paste by right clicking in the window or right clicking the icon in the top left corner of this window.)\n";
			chomp ($script = <STDIN>);
			$script =~ / *[\"\'](.*)[\/\\](.*)[\"\'] */;
			$scriptpath = $1;
			$scriptpath =~ s/^\s+//;					# strip leading whitespace
			$scriptpath =~ s/\s+$//;					# strip trailing whitespace

			if (-d "$scriptpath/scripts/hunalign") {print "\nScript folder identified correctly.\n"}
		} until (-d "$scriptpath/scripts/hunalign");
	}

}