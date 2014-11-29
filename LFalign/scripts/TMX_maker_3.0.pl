#!/usr/bin/perl
# for xls input  support on *nix, fatpack to get Spreadsheet::ParseExcel::Simple

my $tool = "LF TMX maker";
my $version = "3.0";
use strict;
use warnings;
use threads;					# this is for the module-based GUI solution
use File::Copy;
use File::Spec; use FindBin qw($Bin);# needed for ID of script folder
use Getopt::Long;				# for command line argument mode that allows unsupervised batch mode (filenames & settings passed on the command line)
use IO::Handle;

# from CPAN
use Spreadsheet::ParseExcel::Simple;


# TODO

# if note set to 3rd column and there is no 3rd column, use the filename

# abort sub similar to lf aligner with "close this window" string that will be recognized by GUI (?)

# do we need use IO::Handle; ? - maybe it's necessary for autoflush

# optional second (third) note

# improve logging




# declaring subs; the subs themselves are at the end
sub load_setup;
sub get_scriptpath;
sub convert_xls;
sub ren_tmx;
sub getlocaltime;

# OS ID
my $OS;

if ($^O =~ /mswin/i) {$OS = "Windows";print "OS detected: Windows\n"}
elsif ($^O =~ /linux/i) {$OS = "Linux";print "OS detected: Linux\n"}
elsif ($^O =~ /darwin/i) {$OS = "Mac";print "OS detected: Mac OS X\n"} 
else {print "\nUnable to detect OS type, choose your OS:\n\nWindows	Any version of Microsoft Windows\nMac	Any flavour of Mac OS X\nLinux	Linux of some sort\n\n";
do {
chomp ($OS = <STDIN>);
print "\nIncorrect OS type. Try again.\n\n" unless $OS eq "Windows" or $OS eq "Mac" or $OS eq "Linux";} until ($OS eq "Windows" or $OS eq "Mac" or $OS eq "Linux");
}



# SCRIPT FOLDER ID
my $scriptpath;

get_scriptpath;



my ($filetype_def, $filetype_prompt, $l1_def, $l2_def, $l1_prompt, $l2_prompt, $segmenttext_def, $segmenttext_prompt, $merge_numbers_headings, $cleanup_def, $cleanup_prompt, $cleanup_remove_conf_value, $delete_dupes, $delete_untranslated, $review_def, $review_prompt, $create_tmx_def, $create_tmx_prompt, @tmx_langcode, $tmx_langcode_1_def, $tmx_langcode_2_def, $tmx_langcode_1_prompt, $tmx_langcode_2_prompt, $no, $creationdate_prompt, $creationid_def, $creationid_prompt, $tmxnote_prompt, $skiphalfempty, $ask_master_TM, $master_TM_path_1, $master_TM_path_2, $chopmode, $confirm_segmenting, $pdfmode, %charconv_source, %charconv_target, $localtime, $gui, $mw, @inputfiles, $outfile);




# LOAD SETUP

load_setup;


# CUSTOMIZE

# OS-dependent GUI defaults are set in the setup sub
if ($gui ne "y") {$gui = ""}; # so that I can use the simple if ($gui) {}test





# LOAD SETTINGS FROM COMMAND LINE ARGUMENTS
# this is done after loading the setup so that command-line settings can overwrite the setup file
# if a value is set by command line args, we set the actual variable, not the *_def default & so that the script doesn't prompt the user later


 # file_full helyett @inputfiles ?
 # my @file_full;
GetOptions (
				"infiles=s"		=> \@inputfiles,		# full file path of input files (2 or more)
				"codes=s"		=> \@tmx_langcode,
				"outfile=s"		=> \$outfile,
				);
@inputfiles = split(",",join(",",@inputfiles)); # 
@tmx_langcode = split(",",uc(join(",",@tmx_langcode)));	# TMX langcodes should be upper-case

$no = @tmx_langcode;	# number of languages inferred from number of language codes passed

my $cmdline; # set to "on" if cmd line input is switched on
if (@inputfiles) {$cmdline = "on"; $tmxnote_prompt = "n"; $creationid_prompt = "n"; $creationdate_prompt = "n"}



if ($cmdline) {
	print "\nCommand line entry mode is on\n";
	$gui = "";
}





# LAUNCH THE GUI (if it's enabled by default for the OS we're on, or it was forced on in the setup)

# $gui = "";

if ($gui) {
	require 'LFA_GUI.pm';
	async( \&LFA_GUI::gui )->detach;
	
	# print all the defaults so the GUI can capture and store them, see the log print 20 lines down from here
	print "Defaults: lang_1_iso_def: NA; lang_2_iso_def: NA; tmx_langcode_1_def: $tmx_langcode_1_def; tmx_langcode_2_def: $tmx_langcode_2_def; creationid_def: $creationid_def; tool: $tool; $version: $version";
} else {
	binmode STDIN, ':encoding(UTF-8)';		# Helps with non-ASCII filenames on Ubuntu
}

# The gui is in LFA_GUI.pm, and it communicates with the main script by tieing STDIN and STDOUT to queues. The main script works without a gui, you just need to set "force gui" to n in the setup file to force the gui not to load. By default, it's on on Win and off on *nix


# CREATE LOGFILE

open (LOG, ">:encoding(UTF-8)", "$scriptpath/scripts/log.txt") or print "\nCan't create log file: $!\nContinuing anyway.\n";
LOG->autoflush; # so that everything is committed to disk immediately (and is not lost in case of a crash etc.)

getlocaltime; # so that the local time can be printed in the log

print LOG "$tool version $version, OS: $OS, started: $localtime\n\n";
print LOG "Setup: filetype_def: $filetype_def; filetype_prompt: $filetype_prompt; l1_def: $l1_def; l2_def: $l2_def; l1_prompt: $l1_prompt; l2_prompt: $l2_prompt; segmenttext_def: $segmenttext_def; segmenttext_prompt: $segmenttext_prompt=; cleanup_def: $cleanup_def; cleanup_prompt: $cleanup_prompt; review_def: $review_def; review_prompt: $review_prompt; create_tmx_def: $create_tmx_def; create_tmx_prompt: $create_tmx_prompt; tmx_langcode_1_def: $tmx_langcode_1_def; tmx_langcode_2_def: $tmx_langcode_2_def; tmx_langcode_1_prompt: $tmx_langcode_1_prompt; tmx_langcode_2_prompt: $tmx_langcode_2_prompt; creationdate_prompt: $creationdate_prompt; creationid_def: $creationid_def; creationid_prompt: $creationid_prompt; ask_master_TM: $ask_master_TM; chopmode: $chopmode; tmxnote_prompt: $tmxnote_prompt; skiphalfempty: $skiphalfempty; pdfmode: $pdfmode\n";

print LOG "\nCommand line entry mode is on" if ($cmdline);

# $creationdate_prompt = "n"; $creationid_prompt ="n"; # $tmxnote_prompt  ="n"; # comment out

# GET INPUT FILE

my $inputfile_full;
my $folder;
my $full_filename;
my $filenotfound;
my $filename_noext;
# my $ext;

do {

	unless (@inputfiles) {	# do not ask for input file name if it has already been passed on the cmdline
		print "\n\nDrag and drop the input file (tab delimited txt in UTF-8 encoding, or xls) here and press enter.\n";
		if ($OS eq "Windows") {print "(Vista users: sorry, Microsoft left you out in the cold. See readme; type [scr]/foldername/filename to run the script on files in the aligner folder.)\n"};
		chomp ($inputfile_full = <STDIN>);
		$inputfile_full =~ s/^\s+//;					# strip leading whitespace
		$inputfile_full =~ s/\s+$//;					# strip trailing whitespace

		if ($inputfile_full =~ /^\[scr\]\/(.*)/) {$inputfile_full = "$scriptpath/$1"};

		# strip any leading and trailing spaces and quotes
		# windows adds double quotes if there is a space in the path, linux always adds single quotes
		$inputfile_full =~ s/^ *[\"\']?([^\"\']+)[\"\']? *$/$1/; # strip leading/trailing spaces and quotes
		
		if ($inputfile_full =~ /;,;/) {	# the GUI passes all file names in one string separated by ;,;
			@inputfiles = split(";,;", $inputfile_full);
			# maybe strip quotes and whitespace
		} else {
			push (@inputfiles, $inputfile_full);	# add the single dragged file to the array (using array for compatibility with gui open)
		}

	}



	$filenotfound = "";
	print LOG "\nInput file(s):";
	foreach $inputfile_full (@inputfiles) {
		print LOG "\n\t$inputfile_full";
		# windows doesn't add quotes if there is no space in the path, linux adds single quotes
		# strip any leading and trailing spaces and quotes; $1=everything up to last / or \, $2= everything from there up to the end except spaces and "'.
		$inputfile_full =~ /^ *[\"\']?(.*)[\/\\]([^\"\']*)[\"\']? *$/;
		$folder = $1;
		$full_filename = $2;

		$full_filename =~ /(.*)\.(.*)/;
		$filename_noext = $1;#del
		# $ext = lc($2);
		unless (-e "$folder/$full_filename") {$filenotfound = $full_filename}
	}

	if ($filenotfound) {print "\n$full_filename doesn't exist (or its path or filename contains accented letters). Try again!\n\n";sleep 3;}
} while ($filenotfound); # if one or more file is not found, ask for input file again



# CONVERT XLS TO TABBED TXT - they are all put in $temptxt
# my $temptxt;
# if ($ext eq "xls") {
#c
# print LOG "\nInput file(s) identified as .xls, converting\n";
# my $timestamp = $localtime;			# we'e using the current date/time to get a unique temp filename
# $timestamp =~ s/[^0-9]//g;		# remove .:, etc from the date
# $temptxt = $folder .  "/" . ${filename_noext} . "_" . $timestamp . ".txt";	# name of last file in @inputfiles array plus _timestamp.txt

my $i = 0;
	foreach $inputfile_full (@inputfiles) {
	my $out = $inputfile_full;
	$out =~ /\.([^.]+)$/;
	my $extension = lc($1);
	next if $extension eq "txt";
	if ($extension eq "xls") {
		print LOG "\nInput file ($inputfile_full) detected as xls, converting to txt";
		$out =~ s/\.([^.])+$/\.txt/;	# change extenstion to txt
		if ( (-e "$out") && (! $cmdline) ){print "\nA file named $out already exists! Rename it or it will be overwritten.\nPress enter when done.";<STDIN>;}		#just in case the txt file already exists
		convert_xls ($inputfile_full, $out);	# all input files will be merged into the same txt
	}
	# work with txt file from now on (all input files merged into one txt)
	# @inputfiles = ();										# flush out the inputfiles array
	$inputfiles[$i]= $out;	# work with the txt file from here on
$i++;
}



#do maybe browse for output file in GUI

my $outfile_def = "$folder/$full_filename"; # we're naming the output file after the last input file
$outfile_def =~ s/\.[^.]+$/\.tmx/;

unless ($outfile) {
	print "\n\n-------------------------------------------------";
	print "\n\nSpecify the path and name of the output file, or just press enter to use the same path and name as your input file.\nDefault: $outfile_def";
	chomp ($outfile = <STDIN>);
}
# print "\noutfile passed: >$outfile<\n";

$outfile =~ s/^[\s"']+//;					# strip leading whitespace and quotes
$outfile =~ s/[\s"']+$//;					# strip trailing whitespace and quotes

$outfile or $outfile = $outfile_def; # if user entered nothing, outfile will be the same as the last infile




if ( (-e "$outfile") && (! $cmdline) ) {print "\nA tmx file named $outfile already exists! Rename it or it will be overwritten.\nPress enter when done.";<STDIN>;}



# NUMBER OF LANGUAGES
unless (@tmx_langcode) {	# @tmx_langcode is defined if the langs were supplied as cmdline arguments
	print "\n\n-------------------------------------------------";
	print "\n\nNumber of languages? This will usually be 2.\n(Default: 2) ";

	do {
		chomp ($no = <STDIN>);
		$no or $no = "2"; # default

		$no =~ s/^\s+//;					# strip leading whitespace
		$no =~ s/\s+$//;					# strip trailing whitespace
		unless ($no =~ /^\d+$/) {print "\nPlease enter a number! Number of languages? "};
	} until ($no =~ /^\d+$/);
}


my ($sec, $min, $hr, $mday, $mon, $year);
($sec,$min,$hr,$mday,$mon,$year,,,) = gmtime(time);
$year += 1900;
$mon++;
my $month = sprintf("%02d", $mon);
my $day = sprintf("%02d", $mday);
my $hour = sprintf("%02d", $hr);
my $minute = sprintf("%02d", $min);
my $second = sprintf("%02d", $sec);
my $date = "$year$month${day}T$hour$minute${second}Z";

if ($date =~ /^[0-2][0-9]{3}[0-1][0-9][0-3][0-9]T[0-2][0-9][0-5][0-9][0-5][0-9]Z$/) {
	#print "\n\nCurrent GMT date and time (yyyymmddThhmmssZ): $date\n"
} else {
	print "\nAutomatic date/time identification unsuccessful, falling back to fixed date.\n";
	$date = "20100101T120000Z";
	print "\nDate and time (yyyymmddThhmmssZ): $date\n";
}

# pass default date to GUI
if ($gui) {print "Default creationdate: $date";} # we're printing these so that LFA_GUI.pm can capture them


	# GET LANGUAGE CODES

	unless (@tmx_langcode) { # skip the prompts if this was set from the command line
		# get $tmx_langcode[0]
		unless ($tmx_langcode_1_prompt eq "n") {

			if ($gui) {print "Default creationdate: $date";} # we're printing these so that LFA_GUI.pm can capture them
			
			# $tmx_langcode_1_def or $tmx_langcode_1_def = uc($l[0]); # by default no default TMX code set in the setup file, so we set it here
			# $tmx_langcode_2_def or $tmx_langcode_2_def = uc($l[1]);	# the gui does the same for all langs
		
		
			print "\n\nType the language code of language 1 as used in TMX files by your CAT tool, (usually EN-GB, EN-US etc.) If in doubt, export a TM into TMX with the CAT tool you will be using and check the codes it uses. Alternatively, you can take a stab in the dark and hope for the best.\n(Default: $tmx_langcode_1_def) ";
			do {
				chomp ($tmx_langcode[0] = uc(<STDIN>));					# upper-case and chomp the tmx_langcode provided by the user
				$tmx_langcode[0] or $tmx_langcode[0] = uc($tmx_langcode_1_def);	# default for L1
				unless ($tmx_langcode[0] =~ /\w+/) {print "\n\nLanguage codes must contain at least two letters, try again!\n"}
			} until ($tmx_langcode[0] =~ /\w+/)
		}
		$tmx_langcode[0] or $tmx_langcode[0] = uc($tmx_langcode_1_def);	# default for L1
		$tmx_langcode[1] or $tmx_langcode[1] = uc($tmx_langcode_2_def);	# default for L2

		# LANGS 2-.. ($tmx_langcode[1-..])
		for (my $i = 1; $i < $no; $i++) {
			my $ii = $i;$ii ++;
			next if ( ($i == 1) && ($tmx_langcode_2_prompt eq "n") ); # don't ask for the tmx_langcode

			do {
				print "\n\nType the language code of language $ii.\n";
				print "(Default: $tmx_langcode_2_def) " if ($i eq 1);
				chomp ($tmx_langcode[$i] = uc(<STDIN>));
				$tmx_langcode[1] or $tmx_langcode[1] = uc($tmx_langcode_2_def);	# default for L2 
				unless ($tmx_langcode[$i] =~ /\w+/) {print "\n\nLanguage codes must contain at least two letters, try again!\n"} # L3 and up have no default
			} until ($tmx_langcode[$i] =~ /\w+/);
		}
	}

	print LOG ", language codes: $tmx_langcode[0]";
	for (my $i = 1; $i < $no; $i++) {
		print LOG ", $tmx_langcode[$i]"
	}


my $creationdate;
unless ($creationdate_prompt eq "n") {
	do {
		print "\n\n-------------------------------------------------";
		print "\n\nPress enter to use the autodetected date and time, or specify your own date and time to be recorded in the TMX. Use the format yyyymmddThhmmssZ, capital T and Z included. See details in readme.\nAutodetected default: $date ";
		chomp ($creationdate = <STDIN>);
		$creationdate or $creationdate = $date;

		print "\nIncorrect date format, try again\n" unless ($creationdate =~ /^[0-2][0-9]{3}[0-1][0-9][0-3][0-9]T[0-2][0-9][0-5][0-9][0-5][0-9]Z$/);
	} until ($creationdate =~ /^[0-2][0-9]{3}[0-1][0-9][0-3][0-9]T[0-2][0-9][0-5][0-9][0-5][0-9]Z$/);
}

$creationdate or $creationdate = $date;
print LOG "\nTMX date/time: $creationdate";

# ASK FOR CREATOR ID
my $creationid;
unless ($creationid_prompt eq "n") {
	print "\n\n-------------------------------------------------";
	print "\n\nType the creator name you wish to be recorded in the TMX. Do not use accented letters or other special characters.\n(Default: $creationid_def) ";
	chomp ($creationid = <STDIN>);
}
$creationid or $creationid = $creationid_def;
print LOG ", creator ID: $creationid";



# NOTE
my $tmxnote = "";

unless ($tmxnote_prompt eq "n") {
	print "\n\n-------------------------------------------------";
	print "\n\nYou can add a note to your TMX. Your options are:
	\n1) Add the contents of the last column of the txt as a note. This is the default, just press enter to apply. This allows you to use accented characters or assign different notes to the various lines/segments in your TM - very useful e.g. if the content comes from several different documents.
	\n2) Type the text you wish to add as note. (Accented letters and other special characters may get corrupted.)
	\n3) Create the TMX without a note. Type \"none\" to apply.";

	print "\n\nleave empty/add your text/type \"none\": ";
	chomp ($tmxnote = <STDIN>);
}

print LOG ", note: $tmxnote";

my $tabs_req = $no;		# number of tab characers required (to make sure the file has all the expected columns)
$tabs_req-- unless $tmxnote eq "";		# less tabs required if there is no note in the last column



# START WRITING TMX

open (TMX, ">:encoding(UTF-8)", "$outfile") or die "Can't open file: $!\nFile name: >$outfile<";

foreach $inputfile_full (@inputfiles) {
# print "\ninput file: $inputfile_full\n";
	$inputfile_full =~ /^ *[\"\']?(.*)[\/\\]([^\"\']*)[\"\']? *$/;
	$folder = $1;
	$full_filename = $2;

	$full_filename =~ /(.*)\.(.*)/;
	# print "\ntrying to open: >$folder/$full_filename<\n";
	open (ALIGNED, "<:encoding(UTF-8)", "$folder/$full_filename") or die "Can't open file for reading (file: $folder/$full_filename)\nError message: $!";

	# strip BOM and replace characters that don't work in TMX
	while (<ALIGNED>) {
		s/^\x{FeFF}//;		#strip BOM


		s/&quot;/"/g;		# you never know where a quot shows up
		s/&nbsp;/ /g;		# you never know where a nbsp shows up
		s/&amp;/&/g;		# for rogue &amp;amp;
		s/&amp;/&/g;		# for rogue &amp;amp;

		# add the 5 TMX-approved char entities
		s/&/&amp;/g;		# Studio needs this, and it needs to be done before lt and gt
		s/</&lt;/g;
		s/>/&gt;/g;
		s/"/&quot;/g;		#	apparently not needed, I left it in anyway
		s/'/&apos;/g;		#	apparently not needed

		print TMX $_;
	}

}

close TMX;

open (TMX, "<:encoding(UTF-8)", "$outfile") or die "Can't open file: $!";
open (TMX_MOD, ">:encoding(UTF-8)", "${outfile}.mod") or die "Can't open file: $!";
print TMX_MOD "\x{FeFF}<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<!DOCTYPE tmx SYSTEM \"tmx14.dtd\">\n<tmx version=\"1.4\">\n  <header\n    creationtool=\"${tool}\"\n    creationtoolversion=\"${version}\"\n    datatype=\"unknown\"\n    segtype=\"sentence\"\n    adminlang=\"$tmx_langcode[0]\"\n    srclang=\"$tmx_langcode[0]\"\n    o-tmf=\"TW4Win 2.0 Format\"\n  >\n  </header>\n  <body>\n";

# NEW
my $skipped = "0";
my $halfempty = "0";	# lines in which there is no L1 text or no L2 text (only in bilingual files)
my $written = "0";
my $tmxnote_print;
while (<TMX>) {
	chomp($_);

	unless (/(.*\t){$tabs_req}/) {print "\n\nLINE $. OF THE FILE DOESN'T HAVE ENOUGH COLUMNS, SO IT HAS BEEN SKIPPED.\nCHECK THE SOURCE FILE AND RUN THE TMX MAKER AGAIN IF NEEDED\n";$skipped++;next;}
	if (  ($skiphalfempty ne "n")  &&  ($no == 2)  &&  ( (/^\t/) or (/^[^\t]*\t(?:\t|$)/) )  ) {$halfempty++;$skipped++;next;} # skip if L1 or L2 is empty

	print TMX_MOD "<tu creationdate=\"$creationdate\" creationid=\"$creationid\">";
	unless ($tmxnote eq "none") { #do
		if ($tmxnote eq "") {/^([^\t]*\t){$no}([^\t]*)/; $tmxnote_print = $2} else {$tmxnote_print = $tmxnote}
		print TMX_MOD "<prop type=\"Txt::Note\">$tmxnote_print<\/prop>";
	}
	for (my $i = 0; $i < $no; $i++) { # loop through $no languages (2, usually)
		/^(?:[^\t]*\t){$i}([^\t]*)/; # capture the text that follows $i columns of previous stuff
		print TMX_MOD "\n<tuv xml:lang=\"$tmx_langcode[$i]\"><seg>$1<\/seg><\/tuv>";
	}
	$written++;
	print "\n$written segments done\n" if $written % 10000 == 0;
	print TMX_MOD " <\/tu>\n\n";
}


print TMX_MOD "\n<\/body>\n<\/tmx>";
close TMX_MOD; #added in 2.23
ren_tmx;


print "\n\n\n${outfile} created\n";



close ALIGNED;
close TMX;
close TMX_MOD;

unlink "${outfile}.mod";
# unlink $temptxt;
print "\n\n-------------------------------------------------";

my $halfemptyreport;
if ($skiphalfempty eq "y") {
	$halfemptyreport = " ($halfempty of them due to being half-empty)";
} else {
	$halfemptyreport = "";
}

print "\n\n$written TUs have been written to the TMX. $skipped segments were skipped$halfemptyreport.\n\nPress Enter to quit.\n";
print LOG "\n$written TUs written to the TMX; $skipped skipped.\nTerminated normally.";
unless ($cmdline) {<STDIN>}; # in cmdline mode, we move on to the next file right away





# SUBS


sub getlocaltime {
	my ($lsec,$lmin,$lhr,$lmday,$lmon,$lyear,,,) = localtime(time);

	$lyear += 1900;
	$lmon++;
	my $lmonth = sprintf("%02d", $lmon);
	my $lday = sprintf("%02d", $lmday);
	my $lhour = sprintf("%02d", $lhr);
	my $lminute = sprintf("%02d", $lmin);
	my $lsecond = sprintf("%02d", $lsec);
	$localtime = "$lyear/$lmonth/${lday}, $lhour:$lminute:${lsecond}";
}



sub ren_tmx {

	close TMX;
	close TMX_MOD;
	rename ("${outfile}.mod", "$outfile") or die "Can't rename file: $!";

	open (TMX, "<:encoding(UTF-8)", "$outfile") or die "Can't open tmx file for reading: $!";
	open (TMX_MOD, ">:encoding(UTF-8)", "${outfile}.mod") or die "Can't open tmx file for writing: $!";
}



sub convert_xls($) { # do some error checking?

	# print "file: >$_[0]<"; # comment out
	open (TXTFROMXLS, ">>:encoding(UTF-8)", $_[1]) or print "\nCan't create output file: $!";	# we're appending all xls contents to one txt

	my $xls = Spreadsheet::ParseExcel::Simple->read ($_[0]);

	foreach my $sheet ($xls->sheets) {		# iterates through all available worksheets in the file named $xls (unless last; is used)
		while ($sheet->has_data) {
			my @data = $sheet->next_row;
			print TXTFROMXLS join ("\t", @data) . "\n";
		}
		# last;			# uncomment to get only the first worksheet
	}
	close TXTFROMXLS;
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



sub load_setup {
	# REGENERATE SETUP FILE IF NOT FOUND
	unless (-e "$scriptpath/LF_aligner_setup.txt") {
		print "\nSETUP FILE NOT FOUND, creating $scriptpath/LF_aligner_setup.txt with default settings\n";
		print LOG "Setup file not found, creating $scriptpath/LF_aligner_setup.txt with default settings\n";
		open (SETUP, ">:encoding(UTF-8)", "$scriptpath/LF_aligner_setup.txt") or print "Can't create setup file: $!";
		print SETUP "\x{FeFF}Here, you can specify settings for LF aligner. Put your choice (usually y or n) between the square brackets, and don't change anything else in this file. If you want to restore the default settings or you think you may have corrupted the file, just delete it. It will be recreated with default settings the next time the aligner runs.\n\n\n*** INPUT ***\n\nFiletype default (t/c/com/epr/w/h/p): [t]\nPrompt user for filetype: [y]\n\nLanguage 1 default: [en]\nPrompt user for language 1: [y]\nLanguage 2 default: [hu]\nPrompt user for language 2: [y]\n\n\n*** OUTPUT ***\n\nSegment to sentences default: [y]\nPrompt user whether to segment: [y]\n\nMerge numbers and chapter/point headings with the next segment: [y]\n\nCleanup default: [y]\nPrompt user whether to do cleanup: [y]\n\nRemove match confidence value: [y]\n\nDelete duplicate entries: [n]\n\nDelete entries where the text is the same in both languages (filters out untranslated text and segments than only contain numbers etc.): [n]\n\nReview default (n/t/x): [x]\nPrompt user whether/how to review pairings: [y]\n\nOffer to write to txt (allows you to add all aligned files to the same master TM): [n]\nMaster TM path: []\n\n\n*** TMX ***\n\nMake TMX by default: [y]\nPrompt user whether to make TMX: [y]\n\nLanguage code 1 default: []\nPrompt user for language code 1: [y]\nLanguage code 2 default: []\nPrompt user for language code 2: [y]\n\nPrompt user for creation date and time: [y]\n\nCreator ID default: []\nPrompt user for creator ID: [y]\n\nPrompt user for TMX note: [y]\n\nSkip half-empty segments: [y]\n\n\n*** MISC ***\n\nChop up files larger than this size (0 deactivates the feature; only activate for files larger than about 20,000 segments if the normal mode failed). [0]\n\nAsk for confirmation after segmenting (switch off only if you want the aligner to run unattended): [y]\n\nPdf conversion mode; formatted or not (-layout option in pdftotext) [y]\n\nForce GUI on (y) or off (n) []\n\n\nCharacter conversion: provide character pairs separated by a tab, one pair per line. The aligner will replace the first character with the second in your aligned file. The replacement is case-sensitive and can be used to decode character entities or fix corrupted characters.\n\nCharacter conversion table for language 1:\n\n\nCharacter conversion table for language 2:\n\n";

		close SETUP;
	}


	open (SETUP, "<:encoding(UTF-8)", "$scriptpath/LF_aligner_setup.txt") or print "Can't open setup file: $!\nDefaulting to basic settings.";

	while (<SETUP>) {
		# these vars are declared where load_setup is called
		if (/Filetype default/) {
			/\[(.*)\]/;
			$filetype_def = $1;
		}
		if (/Prompt user for filetype:/) {
			/\[(.*)\]/;
			$filetype_prompt = $1;
		}

		if (/Language 1 default:/) {
			/\[(.*)\]/;
			$l1_def = $1;
		}
		if (/Language 2 default:/) {
			/\[(.*)\]/;
			$l2_def = $1;
		}
		if (/Prompt user for language 1:/) {
			/\[(.*)\]/;
			$l1_prompt = $1;
		}
		if (/Prompt user for language 2:/) {
			/\[(.*)\]/;
			$l2_prompt = $1;
		}

		if (/Segment to sentences default:/) {
			/\[(.*)\]/;
			$segmenttext_def = $1;
		}

		if (/Prompt user whether to segment:/) {
			/\[(.*)\]/;
			$segmenttext_prompt = $1;
		}

		if (/Merge numbers and chapter\/point headings with the next segment:/) {
			/\[(.*)\]/;
			$merge_numbers_headings = $1;
		}

		if (/Cleanup default:/) {
			/\[(.*)\]/;
			$cleanup_def = $1;
		}
		if (/Prompt user whether to do cleanup:/) {
			/\[(.*)\]/;
			$cleanup_prompt = $1;
		}

		if (/Remove match confidence value:/) {
			/\[(.*)\]/;
			$cleanup_remove_conf_value = $1;
		}

		if (/Delete duplicate entries:/) {
			/\[(.*)\]/;
			$delete_dupes = $1;
		}

		if (/Delete entries where the text is the same in both languages/) {
			/\[(.*)\]/;
			$delete_untranslated = $1;
		}

		if (/Review default \(n\/t\/x\):/) {
			/\[(.*)\]/;
			$review_def = $1;
		}

		if (/Prompt user whether\/how to review pairings:/) {
			/\[(.*)\]/;
			$review_prompt = $1;
		}

		if (/Make TMX by default:/) {
			/\[(.*)\]/;
			$create_tmx_def = $1;
		}

		if (/Prompt user whether to make TMX:/) {
			/\[(.*)\]/;
			$create_tmx_prompt = $1;
		}

		if (/Language code 1 default:/) {
			/\[(.*)\]/;
			$tmx_langcode_1_def = $1;
		}
		if (/Language code 2 default:/) {
			/\[(.*)\]/;
			$tmx_langcode_2_def = $1;
		}

		if (/Prompt user for language code 1:/) {
			/\[(.*)\]/;
			$tmx_langcode_1_prompt = $1;
		}
		if (/Prompt user for language code 2:/) {
			/\[(.*)\]/;
			$tmx_langcode_2_prompt = $1;
		}

		if (/Prompt user for creation date and time:/) {
			/\[(.*)\]/;
			$creationdate_prompt = $1;
		}

		if (/Creator ID default:/) {
			/\[(.*)\]/;
			$creationid_def = $1;
		}

		if (/Prompt user for creator ID:/) {
			/\[(.*)\]/;
			$creationid_prompt = $1;
		}

		# if (/Default TMX note:/) {
			# /\[(.*)\]/;
			# $tmxnote_def = $1;
		# }

		if (/Prompt user for TMX note:/) {
			/\[(.*)\]/;
			$tmxnote_prompt = $1;
		}
#c
		if (/Skip half-empty segments:/) {
			/\[(.*)\]/;
			$skiphalfempty = $1;
		}

		if (/Offer to write to txt/) {
			/\[(.*)\]/;
			$ask_master_TM = $1;
		}

		if (/Master TM path:/) {
			/\[([^;]*);? ?(.*)\]/;
			$master_TM_path_1 = $1;
			$master_TM_path_2 = $2;
		}

		if (/Chop up files larger than this size/) {
			/\[(.*)\]/;
			$chopmode = $1;
		}

		if (/Ask for confirmation after segmenting/) {
			/\[(.*)\]/;
			$confirm_segmenting = $1;
		}

		if (/Pdf conversion mode/) {
			/\[(.*)\]/;
			$pdfmode = $1;
		}

		if (/GUI/) {
			/\[(.*)\]/;
			$gui = lc($1);
		}

	}
	close SETUP;

	# default values in case the setup file is bad
	$filetype_def or $filetype_def = "t";
	$filetype_prompt or $filetype_prompt = "y";
	$l1_def or $l1_def = "hu";
	$l2_def or $l2_def = "en";
	$l1_prompt or $l1_prompt = "y";
	$l2_prompt or $l2_prompt = "y";
	$segmenttext_def or $segmenttext_def = "y";
	$segmenttext_prompt or $segmenttext_prompt= "y";
	$cleanup_def or $cleanup_def = "y";
	$cleanup_prompt or $cleanup_prompt = "y";
	$review_def or $review_def = "x";
	$review_prompt or $review_prompt = "y";
	$create_tmx_def or $create_tmx_def = "y";
	$create_tmx_prompt or $create_tmx_prompt = "y";
	$tmx_langcode_1_def or $tmx_langcode_1_def = "EN-GB";
	$tmx_langcode_2_def or $tmx_langcode_2_def = "HU";
	$tmx_langcode_1_prompt or $tmx_langcode_1_prompt = "y";
	$tmx_langcode_2_prompt or $tmx_langcode_2_prompt = "y";
	$creationdate_prompt or $creationdate_prompt = "y";
	$creationid_def or $creationid_def = "$tool $version";
	$creationid_prompt or $creationid_prompt = "y";
	$ask_master_TM or $ask_master_TM = "n";
	$chopmode or $chopmode = 0;
	# $tmxnote_def or $tmxnote_def = "";
	$tmxnote_prompt or $tmxnote_prompt = "y";
	$skiphalfempty or $skiphalfempty = "y";
	$pdfmode or $pdfmode = "y";
	if ($OS eq "Windows") {$gui or $gui = "y"} else {$gui or $gui = "n"};

}


