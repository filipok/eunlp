#!/usr/bin/perl
# windows version uses convert_html with HTML::Strip and HTML::Entities
# to generate "with modules" *nix version: leave off use utf8 and drop underneath the WriteExcel and ParseExcel modules (in ANSI file)
# to release: update docs, make sure $version is updated, change *nix file permissions to executable

use utf8;

my $tool = "LF Aligner";
my $version = "4.04";		# sajat
use strict;
use warnings;
use threads;							# this is for the module-based GUI solution
use File::Copy;
use File::Spec; use FindBin qw($Bin);	# needed for ID of script folder
use Getopt::Long;						# for command line argument mode that allows unsupervised batch mode (filenames & settings passed on the command line)
use IO::Handle;


# these modules need to be installed from CPAN:
use Spreadsheet::WriteExcel;				# packed into exe on Windows, fatpacked on *nix
use Spreadsheet::ParseExcel::Simple;		# packed into exe on Windows, HASN'T BEEN FATPACKED!!!
use if $^O eq "MSWin32", "HTML::Strip";		# packed into exe on Windows, workaround on *nix
use if $^O eq "MSWin32", "HTML::Entities";	# packed into exe on Windows, workaround on *nix
# Tk is loaded conditionally later with 'require'


# TODO:

# support mixed input files (doc/pdf/txt)

# support for specifying just the languages on the cmdline

# GUI for batch mode

# In HTML conversion, s/<\/td>/\n/g;

# report word and character numbers in GUI

# do we need use IO::Handle; ? - maybe it's necessary for autoflush

# Greek sentence segmenter (; [capitalgreekletter])

# Wf memory format

# troubleshoot pdf on linux; pdftotext: consider -nopgbrk

# document converters (consider http://poi.apache.org/ as well, tho it's java based)

# add icon: if (-e "icon.bmp") {my $icon = $mw->Photo(-file => "icon.bmp", -format => 'bmp');$mw->Icon(-image => $icon);}

# integrate Spreadhseet::XLSX for reading xlsx files in tmx maker - see if app::fatpacker supports it

# error checking on celex numbers (p'raps obviated by GUI picker)

# log name: log_2012.10.06.txt (as in output folder), move log to $folder

# set output folder via cmdline param (so that output files are in the same folder even if input files are scattered) - but what to do with name conflicts?

# retry opening files w/ wait:

# my $attempts;
# while (not rename $file1, $file2)
# {
  # $attempts++;
  # die "Could not rename file: $!" if $attempts > 3;
  # sleep $attempts;
# }

# handle empty files in multi mode; if $no > 2 & empty file found at any stage, skip loop and update aligned file with empty cells with sub pad_aligned

# fix auto seg eval divide by 0 error

# TMX maker default langcodes w/ new empty setup

# readme: troubleshooting, excel macro etc.

# merge sentence splitter into main script as sub

# sdlxliff as preseg input instead of TMX (less fussy, more reliable) - just update readme with xls export procedure instead

# HTML encoding detection; charset=UNICODE-1-1-UTF-8, charset=utf-8, charset="utf-8", encoding="ISO-8859-1" see "detect HMTL encoding"

# update TM after review is done on cleaned file: get the 'bad' TMX, convert to tabbed, extract the target language segments, autoalign those with the new target language translations while conserving the segmentation of the 'bad' target language version as in 3-language mode, then swap the new target segments into the original TMX.

# remove page headers and footers; page break char is FF:  \x{000C} chr(12)

# segmenter msg

# w/ new hunalign: -utf




# declaring subs; they are at the end
sub load_setup;
sub get_scriptpath;
sub align;
sub ren;
sub renseg;
sub ren_aligned;
sub tmx_extract;
sub convert_html;
sub convert_html_compatibility;
sub convert_xls;
sub abort;
sub getlocaltime;

# INTRO
print "\n$tool $version\n";

# OS ID
my $OS;
if ($^O =~ /mswin/i) {$OS = "Windows";print "OS detected: Windows\n"}
elsif ($^O =~ /linux/i) {$OS = "Linux";print "OS detected: Linux\n"}
elsif ($^O =~ /darwin/i) {$OS = "Mac";print "OS detected: Mac OS X\n"} 
else {print "\nUnable to detect OS type, choose your OS:\n\nWindows	Any version of Microsoft Windows\nMac	Any flavour of Mac OS X\nLinux	Linux of some sort\n\n";
do {
chomp ($OS = <STDIN>);
print "\nIncorrect OS type. Try again!\n\n" unless $OS eq "Windows" or $OS eq "Mac" or $OS eq "Linux";} until ($OS eq "Windows" or $OS eq "Mac" or $OS eq "Linux");
}



# SCRIPT FOLDER ID
my $scriptpath;

get_scriptpath;



# LOAD SETUP

my ($filetype, $filetype_def, $filetype_prompt, $lang_1_iso_def, $lang_2_iso_def, $l1_prompt, $l2_prompt, $segmenttext, $confirm_segmenting, $merge_numbers_headings, $cleanup, $cleanup_def, $cleanup_prompt, $cleanup_remove_conf_value, $delete_dupes, $delete_untranslated, $review, $review_def, $review_prompt, $create_tmx, $create_tmx_def, $create_tmx_prompt, $date, @tmx_langcode, $tmx_langcode_1_def, $tmx_langcode_2_def, $tmx_langcode_1_prompt, $tmx_langcode_2_prompt, $creationdate_prompt, $creationid_def, $creationid_prompt, $tmxnote_prompt, $skiphalfempty, $ask_master_TM, $master_TM, $master_TM_file_1, $master_TM_file_2, $master_TM_path_1, $master_TM_path_2, $chopmode, $pdfmode, $gui, $guilang, $mw, %charconv_source, %charconv_target, $current_year, @url, @file_full, @file, @f, @l, $no);



load_setup; # loads setup variables from LF_aligner_setup.txt


# CUSTOMIZE

# settings for my personal use
if ($version =~ /sajat/) {$ask_master_TM = "y";$master_TM_path_1 = "c:\\Users\\A\\Documents\\Translation Resources\\xbench_aktualiscucc.txt"};
if ($version =~ /sajat/) {$cleanup_prompt = "n";$cleanup_def = "y";}


# LOAD SETTINGS FROM COMMAND LINE ARGUMENTS
	# this is done after loading the setup so that command-line settings can overwrite the setup file
	# if a value is set by command line args, we set the actual variable, not the *_def default & so that the script doesn't prompt the user later

my $seg;
GetOptions (
				"filetype=s"		=> \$filetype,
				"infiles=s"		=> \@file_full,		# full file path of input files (2 or more)
				"languages=s"	=> \@l,				# two-letter language codes in same order as files
				"segment=s"		=> \$seg,
				"review=s"		=> \$review,		# post-alignment review & correction in Excel
				"tmx=s"			=> \$create_tmx,
				"codes=s"		=> \@tmx_langcode,
				"outfile=s"		=> \$master_TM_path_1,
				);
@file_full = split(",",join(",",@file_full));
@l = split(",",join(",",@l));
@tmx_langcode = split(",",uc(join(",",@tmx_langcode)));	# TMX langcodes should be upper-case

$no = @file_full;
my $no_langs = @l;
unless ($no) {$no = $no_langs}	# in case the langs are passed as command line params but the file names are not

if ( ($no ne $no_langs) && (@l) && (@file_full) ){abort("The number of files ($no) does not match the number of languages you listed ($no_langs). Please review the rules on command line input.\nThe error occurred at line " . __LINE__ . ".");}

if ($filetype) { if ($filetype eq "t" or $filetype eq "h" or $filetype eq "p") {$filetype_prompt = "n"} else {abort("Wrong filetype specified in command line argument; only t, h and p are supported at line " . __LINE__)} };

if ($review) { if ($review eq "xn") {$review = "nx"}; $review_prompt = "n" if ($review eq "n" or $review eq "t" or $review eq "x" or $review eq "nx") };

if ($seg) {
	if ($seg eq "y") {$segmenttext = "y";$confirm_segmenting = "n"}
	elsif ($seg eq "n") {$segmenttext = "n";$confirm_segmenting = "n"}
	elsif ($seg eq "auto") {$segmenttext = "y";$confirm_segmenting = "auto"}
	else {abort ("Wrong segmenting switch at line " . __LINE__)}
}

if ($create_tmx) { if ($create_tmx eq "y" or $create_tmx eq "n") {$create_tmx_prompt = "n"} };

if (@tmx_langcode) {$tmxnote_prompt = "n"; $creationid_prompt = "n"; $creationdate_prompt = "n"}

if ($master_TM_path_1) {$ask_master_TM = "y"; $master_TM = "a"}

my $cmdline;
$cmdline = "on" if (@file_full);
if ($cmdline) {
	print "\nCommand line entry mode is on\n";
	$gui = "";
}




# LAUNCH THE GUI (if it's enabled by default for the OS we're on, or it was forced on in the setup)

if ($gui) {
	require 'LFA_GUI.pm';
	async( \&LFA_GUI::gui )->detach;
	# print all the defaults so the GUI can capture and store them, see the log print 20 lines down
	print "Defaults: lang_1_iso_def: $lang_1_iso_def; lang_2_iso_def: $lang_2_iso_def; tmx_langcode_1_def: $tmx_langcode_1_def; tmx_langcode_2_def: $tmx_langcode_2_def; creationid_def: $creationid_def; tool: $tool; version: $version; GUIlang: $guilang"; #do inkább a fájl elérési útját küldje át
} else {
	binmode STDIN, ':encoding(UTF-8)';		# Helps with non-ASCII filenames on Ubuntu
}

# The gui is in LFA_GUI.pm, and it communicates with the main script by tieing STDIN and STDOUT to queues. The main script works without a gui, you just need to set "force gui" to n in the setup file to force the gui not to load. By default, it's on on Win and off on *nix

# CREATE LOGFILE


open (LOG, ">:encoding(UTF-8)", "$scriptpath/scripts/log.txt") or print "\nCan't open log file: $!\nContinuing anyway.\n";
LOG->autoflush;  # so that everything is committed to disk immediately (and is not lost in case of a crash etc.)

my $localtime;
getlocaltime;	# so that the local time can be printed in the log
print LOG "Program: $tool, version: $version, OS: $OS, launched: $localtime\n\n";


print LOG "Setup: filetype_def: $filetype_def; filetype_prompt: $filetype_prompt; lang_1_iso_def: $lang_1_iso_def; lang_2_iso_def: $lang_2_iso_def; l1_prompt: $l1_prompt; l2_prompt: $l2_prompt; segmenttext: $segmenttext; confirm_segmenting: $confirm_segmenting; cleanup_def: $cleanup_def; cleanup_prompt: $cleanup_prompt; review_def: $review_def; review_prompt: $review_prompt; create_tmx_def: $create_tmx_def; create_tmx_prompt: $create_tmx_prompt; tmx_langcode_1_def: $tmx_langcode_1_def; tmx_langcode_2_def: $tmx_langcode_2_def; tmx_langcode_1_prompt: $tmx_langcode_1_prompt; tmx_langcode_2_prompt: $tmx_langcode_2_prompt; creationdate_prompt: $creationdate_prompt; creationid_def: $creationid_def; creationid_prompt: $creationid_prompt; ask_master_TM: $ask_master_TM; chopmode: $chopmode; tmxnote_prompt: $tmxnote_prompt; skiphalfempty: $skiphalfempty; pdfmode: $pdfmode\n";

if ($cmdline) {print LOG "\nCommand line arguments on";}

if ($gui) {print LOG "\nGUI on";} else {print LOG "\nGUI off";}


# my $script = File::Spec->rel2abs( __FILE__ );
# print "script: $script";
# sleep 5;


# FILETYPE SELECTOR

unless ($filetype_prompt eq "n") {
	print "\n\n-------------------------------------------------";
	print "\n\nFiletype?\n\n";
	print "t   -  txt (UTF-8!), rtf, doc, docx or odt file (see the readme!)\n";
	print "p   -  pdf, or pdf exported to txt (exporting works better, see readme!)\n";
	print "h   -  HTML file saved to your computer\n";
	print "w   -  webpage (you provide two URLs, the script does the rest)\n";
	print "c   -  EU legislation by CELEX number (will be downloaded automatically)\n";
	print "com -  European Commission proposals (downloaded by year and number)\n";
	print "epr -  European Parliament reports (downloaded by year and number)\n";

	do {
		print "\nt/p/h/w/c/com/epr? (Default: $filetype_def) ";
		chomp ($filetype = lc(<STDIN>));
		$filetype =~ s/^\s+//;					# strip leading whitespace
		$filetype =~ s/\s+$//;					# strip trailing whitespace

		$filetype or $filetype = $filetype_def;
		print "\nIncorrect filetype. Try again!\n\n" unless ($filetype eq "t" or $filetype eq "c" or $filetype eq "w" or $filetype eq "h" or $filetype eq "p" or $filetype eq "com" or $filetype eq "epr");
	} until ($filetype eq "t" or $filetype eq "c" or $filetype eq "w" or $filetype eq "h" or $filetype eq "p" or $filetype eq "com" or $filetype eq "epr");
}
$filetype or $filetype = $filetype_def;
print LOG "\nfiletype: $filetype";

# abort("We're testing!"); #del

# FOLDERNAME c, com, w
my $foldername;
my $folder;
if ($filetype eq "c" or $filetype eq "com" or $filetype eq "epr" or $filetype eq "w") {
	do {
		print "\n\n-------------------------------------------------";
		print "\n\nProvide a name for the output folder - don't use accented or other special characters. The folder will be created automatically inside the aligner folder.\n";
		chomp ($foldername = <STDIN>);
		$foldername =~ s/^\s+//;				# strip leading whitespace
		$foldername =~ s/\s+$//;				# strip trailing whitespace
		
		if ($gui) {
			if ($foldername) {$folder = "$foldername";} else {$folder = "$scriptpath/new"};
		} else {
			$foldername or $foldername = "new";
			$folder = "$scriptpath/$foldername";
		}


		chomp $folder;
		if ($OS eq "Windows") {	# perl can can usually handle non-ASCII filenames on *nix, so we only limit the charset on Windows
			unless ($folder =~ /^[a-z?\:?[a-z0-9_\\\/\!\$\%\&\'\+\,\-\.\; \=\@\{\}\(\)\[\]\^\`]+$/i) {			# ([a-zA-Z]:)? to allow colon in C:\
				print "Folder names/paths can only contain ASCII letters and some symbols\n(a-zA-Z0-9!$%&'+,-.; =@^`{}()[]_).\nTry again!";
				print LOG "\nfolder name rejected due to illegal character: $folder";
			}
		}
	
	} until ( ($OS ne "Windows") or ($folder =~ /^[A-Z]?\:?[a-zA-Z0-9_\\\/\!\$\%\&\'\+\,\-\.\; \=\@\{\}\(\)\[\]\^\`]+$/) );

	if (!-d "$folder") {
		print "\nCreating $folder";
		mkdir "$folder" or abort("Can't create folder $folder: $! at line " . __LINE__);
	};

	print LOG "\nfolder: $folder";
}

# NUMBER OF LANGUAGES

unless (@l) {
	print "\n\n-------------------------------------------------";
	print "\n\nNumber of languages? This will usually be 2.\n(Default: 2) ";

	do {
		chomp ($no = <STDIN>);
		$no or $no = "2"; # default

		$no =~ s/^\s+//;					# strip leading whitespace
		$no =~ s/\s+$//;					# strip trailing whitespace

		unless ( ($no =~ /^\d+$/) && ($no < 100) && ($no > 1) ) {print "\nPlease enter a number between 2 and 100! Try again!\n"};
	} until ( ($no =~ /^\d+$/) && ($no < 100) && ($no > 1) );

	# LANGUAGES (needed for the segmenter's prefix lists and EU doc downloads)


	for (my $i = 0; $i < $no; $i++) {
		my $ii = $i;$ii++; # a counter that's always set at i+1

		next if ( ($i == 0) && ($l1_prompt eq "n") );
		next if ( ($i == 1) && ($l2_prompt eq "n") );
		print "\n\n-------------------------------------------------";
		print "\n\nLanguage $ii? ";
		if ($i == 0) {print "Use standard two-letter language codes, such as en, es, de, fr, hu etc. To see a full list of language codes, type list.\n(Default: $lang_1_iso_def) "}
		if ($i == 1) {print "(Default: $lang_2_iso_def) "}

		do {
			chomp ($l[$i] = lc(<STDIN>));
			if ($i == 0) {$l[$i] or $l[$i] = lc($lang_1_iso_def);}	# defaults loaded from setup file
			if ($i == 1) {$l[$i] or $l[$i] = lc($lang_2_iso_def);}
			if ($i == 2) {$l[$i] or $l[$i] = "es";}			# hidden defaults
			if ($i == 3) {$l[$i] or $l[$i] = "it";}
			$l[$i] =~ s/^\s+//;								# strip leading whitespace
			$l[$i] =~ s/\s+$//;								# strip trailing whitespace
			if ($l[$i] =~ /list/i) { # give the user a list of codes if requested (taken from Wikipedia and stripped of non-ASCII chars)
				print "\n\nList of language codes:\n\nAbkhaz -> ab\nAfar -> aa\nAfrikaans -> af\nAkan -> ak\nAlbanian -> sq\nAmharic -> am\nArabic -> ar\nAragonese -> an\nArmenian -> hy\nAssamese -> as\nAvaric -> av\nAvestan -> ae\nAymara -> ay\nAzerbaijani -> az\nBambara -> bm\nBashkir -> ba\nBasque -> eu\nBelarusian -> be\nBengali -> bn\nBihari -> bh\nBislama -> bi\nBosnian -> bs\nBreton -> br\nBulgarian -> bg\nBurmese -> my\nCatalan; Valencian -> ca\nChamorro -> ch\nChechen -> ce\nChichewa; Chewa; Nyanja -> ny\nChinese -> zh\nChuvash -> cv\nCornish -> kw\nCorsican -> co\nCree -> cr\nCroatian -> hr\nCzech -> cs\nDanish -> da\nDivehi; Dhivehi; Maldivian; -> dv\nDutch -> nl\nDzongkha -> dz\nEnglish -> en\nEsperanto -> eo\nEstonian -> et\nEwe -> ee\nFaroese -> fo\nFijian -> fj\nFinnish -> fi\nFrench -> fr\nFula; Fulah; Pulaar; Pular -> ff\nGalician -> gl\nGeorgian -> ka\nGerman -> de\nGreek, Modern -> el\nGuaraní -> gn\nGujarati -> gu\nHaitian; Haitian Creole -> ht\nHausa -> ha\nHebrew (modern) -> he\nHerero -> hz\nHindi -> hi\nHiri Motu -> ho\nHungarian -> hu\nInterlingua -> ia\nIndonesian -> id\nInterlingue -> ie\nIrish -> ga\nIgbo -> ig\nInupiaq -> ik\nIdo -> io\nIcelandic -> is\nItalian -> it\nInuktitut -> iu\nJapanese -> ja\nJavanese -> jv\nKalaallisut, Greenlandic -> kl\nKannada -> kn\nKanuri -> kr\nKashmiri -> ks\nKazakh -> kk\nKhmer -> km\nKikuyu, Gikuyu -> ki\nKinyarwanda -> rw\nKirghiz, Kyrgyz -> ky\nKomi -> kv\nKongo -> kg\nKorean -> ko\nKurdish -> ku\nKwanyama, Kuanyama -> kj\nLatin -> la\nLuxembourgish, Letzeburgesch -> lb\nLuganda -> lg\nLimburgish, Limburgan, Limburger -> li\nLingala -> ln\nLao -> lo\nLithuanian -> lt\nLuba-Katanga -> lu\nLatvian -> lv\nManx -> gv\nMacedonian -> mk\nMalagasy -> mg\nMalay -> ms\nMalayalam -> ml\nMaltese -> mt\nMaori -> mi\nMarathi -> mr\nMarshallese -> mh\nMongolian -> mn\nNauru -> na\nNavajo, Navaho -> nv\nNorwegian Bokmal -> nb\nNorth Ndebele -> nd\nNepali -> ne\nNdonga -> ng\nNorwegian Nynorsk -> nn\nNorwegian -> no\nNuosu -> ii\nSouth Ndebele -> nr\nOccitan -> oc\nOjibwe, Ojibwa -> oj\nOld Church Slavonic, Old Bulgarian -> cu\nOromo -> om\nOriya -> or\nOssetian, Ossetic -> os\nPanjabi, Punjabi -> pa\nPali -> pi\nPersian -> fa\nPolish -> pl\nPashto, Pushto -> ps\nPortuguese -> pt\nQuechua -> qu\nRomansh -> rm\nKirundi -> rn\nRomanian, Moldavian, Moldovan -> ro\nRussian -> ru\nSanskrit -> sa\nSardinian -> sc\nSindhi -> sd\nNorthern Sami -> se\nSamoan -> sm\nSango -> sg\nSerbian -> sr\nScottish Gaelic; Gaelic -> gd\nShona -> sn\nSinhala, Sinhalese -> si\nSlovak -> sk\nSlovene -> sl\nSomali -> so\nSouthern Sotho -> st\nSpanish; Castilian -> es\nSundanese -> su\nSwahili -> sw\nSwati -> ss\nSwedish -> sv\nTamil -> ta\nTelugu -> te\nTajik -> tg\nThai -> th\nTigrinya -> ti\nTibetan -> bo\nTurkmen -> tk\nTagalog -> tl\nTswana -> tn\nTonga (Tonga Islands) -> to\nTurkish -> tr\nTsonga -> ts\nTatar -> tt\nTwi -> tw\nTahitian -> ty\nUighur, Uyghur -> ug\nUkrainian -> uk\nUrdu -> ur\nUzbek -> uz\nVenda -> ve\nVietnamese -> vi\nVolapuk -> vo\nWalloon -> wa\nWelsh -> cy\nWolof -> wo\nWestern Frisian -> fy\nXhosa -> xh\nYiddish -> yi\nYoruba -> yo\nZhuang, Chuang -> za\nZulu -> zu\n";
				print "\n\nLanguage $ii? ";
			} else {
				unless ($l[$i] =~ /^[a-z]{2}$/) {print "\nThe code must be made up of two ASCII letters, try again!\n"}; 
			}
		} until ($l[$i] =~ /^[a-z]{2}$/);

	}

	$l[0] or $l[0] = $lang_1_iso_def;	# use defaults if prompt was set to n
	$l[1] or $l[1] = $lang_2_iso_def;

}



# SET URL - CELEX

my ($celex, $celextype, $celexyear, $celexserial, $url1, $url2, $ext, $alignfilename);
if ($filetype eq "c") {
	print "\n\n-------------------------------------------------";
	print "\n\nCELEX number? Right click in the window or right click the icon in the top left corner to paste from clipboard.\nFor regulations, directives and framework directives, you can just type R, D or FD, the year and number (the year always comes first!).\nE.g. 62003C0371, D 1996 34 or FD 2001 220\n";
	chomp ($celex = uc(<STDIN>));

	$celex =~ s/^\s+//;						# remove leading spaces
	$celex =~ s/\s+$//;						# remove trailing spaces

	if ($version =~ /sajat/) {$celex or $celex = "D 1996 34"}

	print LOG "\nCELEX input: $celex";
	# generate CELEX from natural number
		if ($celex =~ /^(F?[RD]) ?([0-9]{2,4})[\/ ]([0-9]{1,4})$/) {#fd
		$celextype = $1;
		$celexyear = $2;
		$celexserial = $3;

		if ($celextype eq "D") {$celextype = "L"};
		if ($celextype eq "FD") {$celextype = "F"};#fd
		if ($celexyear =~ /^\d{2}$/) {$celexyear = "19$celexyear"};
		$celexserial = sprintf("%04d", $celexserial);
		$celex = "3${celexyear}${celextype}${celexserial}";
		print LOG ", parsed as: type: $celextype, year:  $celexyear, number: $celexserial, generated CELEX no.: $celex";
		print "\nGenerated CELEX number: $celex\n";
		sleep 1;
	};

	print "\n\n";
	# we grab the eur-lex landing page and search it for a url (many docs are on the OJ pages, not on a CELEX page)

	# get and save eur-lex landing page
	if ($OS eq "Mac") {system ("curl -o \"/$folder/eurlex.html\" \"http://eur-lex.europa.eu/LexUriServ/LexUriServ.do?uri=CELEX:${celex}:EN:NOT\"")}
	elsif ($OS eq "Windows") {system ("\"$scriptpath\\scripts\\wget\\wget\" -O \"$folder/eurlex.html\" \"http://eur-lex.europa.eu/LexUriServ/LexUriServ.do?uri=CELEX:${celex}:EN:NOT\"")}
	else {system ("wget -O \"$folder/eurlex.html\" \"http://eur-lex.europa.eu/LexUriServ/LexUriServ.do?uri=CELEX:${celex}:EN:NOT\"")};


	# this gets the last matching url from the page, perhaps it should grab the first (set a variable if hit is found, skip // if variable is set)
	for (my $i = 0; $i < $no; $i++) {
		my $ii = $i; $ii++; # counter, $ii is always $+i
		open (EURLEX, "<:encoding(UTF-8)", "$folder/eurlex.html") or abort("Can't open file: $! at line " . __LINE__); #test # reopen needed before every while loop

		while (<EURLEX>) {
			if (/a href=\"(http:\/\/eur-lex.europa.eu\/LexUriServ\/LexUriServ.do\?uri=\S*:$l[$i]:HTML)/i) {$url[$i] = $1; print LOG "\n$l[$i] URL found on eur-lex landing page: $url[$i]"}
		}
		close EURLEX;
		$url[$i] or abort("The document wasn't found on eur-lex.europa.eu in language $l[$i] at line " . __LINE__); #abort
	}

	unlink "$folder/eurlex.html";


	for (my $i = 0; $i < $no; $i++) {
		$file[$i] = "${celex}_${l[$i]}.html";
		$file[$i] =~ /(.*)\.(.*)/;
		$f[$i] = $1;
		$ext = $2;
	}


	$alignfilename = "${celex}_${l[0]}-${l[1]}";

}


# SET URL - COM
# See note at # DOWNLOAD!
my $comyear;
my $comnumber;
if ($filetype eq "com"){
	# get COMyear
	do {
		print "\n\n-------------------------------------------------";
		print "\n\nEnter the year and number of the Commission proposal. (E.g. 2009 34)\n";
		chomp (my $cominput = <STDIN>);
		$cominput =~ s/^\s+//;					# strip leading whitespace
		$cominput =~ s/\s+$//;					# strip trailing whitespace

		$cominput =~ /^(.+)\s+(.+)$/;
		$comyear = $1;
		$comnumber = $2;

		$comnumber = sprintf("%04d", $comnumber) if $comnumber =~ /^\d+$/;		# pad with zeroes to 4 digits

		unless ( ($comyear =~ /^\d\d\d\d$/) && ($comyear > 1946) && ($comyear <= $current_year) ) {print "\nIncorrect year number, try again!\n"};
		unless ($comnumber =~ /^\d\d\d\d$/) {print "\nIncorrect document number, try again!\n"};
	} until ( ($comyear =~ /^\d\d\d\d$/) && ($comyear > 1946) && ($comyear <= $current_year) && ($comnumber =~ /^\d\d\d\d$/));


	# set URLs for downloading
	for (my $i = 0; $i < $no; $i++) {
		$url[$i] = "http://eur-lex.europa.eu/LexUriServ/LexUriServ.do?uri=COM:${comyear}:${comnumber}:FIN:${l[$i]}:HTML";

		$file[$i] = "COM_${comyear}_${comnumber}_$l[$i].html";
		$file[$i] =~ /(.*)\.(.*)/;
		$f[$i] = $1;
		$ext = $2;
	}

	$alignfilename = "COM_${comyear}_${comnumber}_${l[0]}-${l[1]}";
	print LOG "\nCOM $comyear $comnumber";
}



# SET URL - EP REPORT
# See note at # DOWNLOAD!
my $eprepyear;
my $eprepno;
if ($filetype eq "epr"){
	# get eprepyear
	do {
		print "\n\n-------------------------------------------------";
		print "\n\nEnter the cycle, year and number of the EP report.\nE.g. A6-2008 62 or A7-2010 123\nThe database only contains reports from 2003 on.\n";
		chomp (my $eprepinput = uc(<STDIN>));
		
		$eprepinput =~ s/^\s+//;			# strip leading whitespace
		$eprepinput =~ s/\s+$//;			# strip trailing whitespace (chomps as well)

		$eprepinput =~ /^(.*) (.*)$/;	# split on last space
		$eprepyear = $1;
		$eprepno = $2;
		
		if (($eprepyear =~ /^\d\d\d\d$/) && ($eprepyear > 2003) && ($eprepyear < 2009)) {$eprepyear = "A6-$eprepyear"};
		if (($eprepyear =~ /^\d\d\d\d$/) && ($eprepyear > 2008) && ($eprepyear < 2015)) {$eprepyear = "A7-$eprepyear"};
		if (($eprepyear =~ /^\d\d\d\d$/) && ($eprepyear > 2014) && ($eprepyear < 2019)) {$eprepyear = "A8-$eprepyear"};
		
		$eprepno = sprintf("%04d", $eprepno);   				# pad with zeroes until it's 4 digits long
		unless ($eprepyear =~ /^A\d{1,2}-20\d\d$/) {print "\nIncorrect cycle and year, try again!\n"};
		unless ($eprepno =~ /^\d\d\d\d$/) {print "\nIncorrect report number, try again!\n"};
	} until ( ($eprepyear =~ /^A\d{1,2}-20\d\d$/) && ($eprepno =~ /^\d\d\d\d$/) );




	for (my $i = 0; $i < $no; $i++) {
		$url[$i] = "http://www.europarl.europa.eu/sides/getDoc.do?pubRef=-//EP//TEXT+REPORT+${eprepyear}-${eprepno}+0+DOC+XML+V0//$l[$i]"
		# print LOG "\nURL $i: $url[$i]";
	}

	for (my $i = 0; $i < $no; $i++) {
		$file[$i] = "EP_Rep_${eprepyear}_${eprepno}_$l[$i].html";
		$file[$i] =~ /(.*)\.(.*)/;
		$f[$i] = $1;
		$ext = $2;
	}



	$alignfilename = "EP_${eprepyear}_${eprepno}_${l[0]}-${l[1]}";
	print LOG "\nEP report $eprepyear $eprepno";
}


# SET URL - Webpage

if ($filetype eq "w"){

	for (my $i = 0; $i < $no; $i++) {
		my $ii = $i;$ii++; # a counter that's always set at i+1
		print "\n\n-------------------------------------------------";
		print "\n\nURL $ii (${l[$i]})?";
		if ($i == 0) {print " (You can paste from the clipboard - try right clicking in this window or right clicking the icon in the top left corner.)"};
		print "\n";
		chomp ($url[$i] = <STDIN>);

		$url[$i] =~ s/^\s+//;						# remove leading whitespace
		$url[$i] =~ s/\s+$//;						# remove trailing whitespace

#do get first part of URL and generate filename based on that my $urlbase; # loop elé if ($. == 0) { /(http:\/\/)?www\.(.+)[\.\/]/; $urlbase = $2}

		$file[$i] = "$l[$i].html";
		$file[$i] =~ /(.*)\.(.*)/;
		$f[$i] = $1;
		$ext = $2;

		print LOG "\nURL $ii: $url[$i]";
	}

	$alignfilename = "${l[0]}-${l[1]}";
}



# DOWNLOAD
# Please do not try to abuse the system by modifying the script to download large amounts of material in one go. None of us wants the admins to randomize the URLs or take steps to limit access by robots in response to somebody overloading their servers/hogging too much bandwidth. You don't want your own IP address or range banned, either... As the readme says, most of the EU material is already available at http://langtech.jrc.it/DGT-TM.html and http://www.statmt.org/europarl/ already.


if ($filetype eq "c" or $filetype eq "com" or $filetype eq "epr" or $filetype eq "w") {
	print "\n\n-------------------------------------------------";
	print "\n\nDownloading...\n";
	print "\n";

	for (my $i = 0; $i < $no; $i++) {
		my $ii = $i;$ii++; # a counter that's always set at i+1

		print "\nDownloading file: $file[$i]; url: $url[$i]\n\n";
		if ($OS eq "Mac") {system ("curl -o \"/$folder/$file[$i]\" \"$url[$i]\"")} elsif ($OS eq "Windows") {system ("\"$scriptpath\\scripts\\wget\\wget\" -O \"$folder/$file[$i]\" \"$url[$i]\"")} else {system ("wget -O \"$folder/$file[$i]\" \"$url[$i]\"")};
		# Check if download was successful
		my $dlsize = -s "$folder/$file[$i]";
		if ((! -e "$folder/$file[$i]") or ($dlsize == 0)) {
			abort("The download of file $ii ($l[$i]) seems to have failed at line " . __LINE__); #abort
		}
	}
}



# GET INPUT FILES (t, h, p)
my @inputfolder;
my $repeat; # if this toggle var is set, we start over from do {
if ($filetype eq "t" or $filetype eq "h" or $filetype eq "p") {
	do {
	$repeat = "";
	
# if (@file_full) {print "\nfile_full defined\n";} else {print "\nfile_full undef\n";}
# <STDIN>;
		unless ($cmdline) {
			for (my $i = 0; $i < $no; $i++) { #do think about consolidating this loop and the next one
				my $ii = $i;$ii++; # a counter that's always set at i+1
				print "\n\n-------------------------------------------------";
				print "\n\nDrag and drop file $ii ($l[$i]) here and press enter. (If it's a txt, save it first in UTF-8 encoding using File/Save As in your text editor.)\n";
				if ($OS eq "Windows") {print "(Vista users: sorry, Microsoft left you out in the cold. See readme; type [scr]/foldername/filename to run the script on files in the aligner folder.)\n"};
				chomp ($file_full[$i] = <STDIN>);
				
				
			}
		}

		if ($version =~ /sajat/) {$file_full[0] or $file_full[0] = "E:\\aligner_perl\\test\\1.txt";$file_full[1] or $file_full[1] = "E:\\aligner_perl\\test\\2.txt";}


		for (my $i = 0; $i < $no; $i++) {
			my $ii = $i;$ii++; # $ii is a counter that's always set at i+1

			$file_full[$i] =~ s/^\s+//;					# strip leading whitespace
			$file_full[$i] =~ s/\s+$//;					# strip trailing whitespace

			if ($file_full[$i] =~ /^\[scr\]\/(.*)/) {$file_full[$i] = "$scriptpath/$1"};

			# strip any leading and trailing spaces and quotes; $1=everything up to last / or \, $2= everything from there up to the end except spaces and "'.
			# windows adds double quotes if there is a space in the path, linux always adds single quotes
			$file_full[$i] =~ s/^[\"\']//;	# strip quotes
			$file_full[$i] =~ s/[\"\']$//;
			$file_full[$i] =~ /^(.*)[\/\\](.*)$/;
			$inputfolder[$i] = $1; # for input checking
			$file[$i] = $2;
			$file[$i] =~ /(.*)\.(.*)/;
			$f[$i] = $1;
			$ext = lc($2);

			# $folder = $inputfolder[0]; # for later use
			
			
			$folder = $inputfolder[0] . "/align_$localtime"; # for later use
			# if running in cmdline mode and an outfile is specified, create outfolder (date only, not timestamp folder) in the same folder as the outfile (in case input files are scattered all over the place)
			if ( ($cmdline) && ($master_TM_path_1) ) {$folder = $master_TM_path_1; $folder =~ s/(.*)[\/\\].*/$1/; $folder = $folder . "/align_$localtime"; $folder =~ s/(.*)_.*$/$1/;}
			if ($folder eq "") {$folder = "."}; # proposed via email for files in cwd; can't hurt, I guess
			if ($OS eq "Windows") {$folder =~ s/\//\\/;} # otherwise rtf and docx(?) conversion fails
			
			mkdir $folder;


# restrict charset on win (unless cmdline input is on; for some reason, cmdline input does support non-ASCII characters)
			if ( ($OS eq "Windows") && (!$cmdline) ) {		# perl can can usually handle non-ASCII filenames on *nix, so we only limit the charset on Windows
				unless ($file_full[$i] =~ /^[a-z]?\:?[a-z0-9_\\\/\!\$\%\&\+\,\-\.\; \=\@\{\}\(\)\[\]\^\`]+$/i) { #do check ()
					print "\n\nERROR: File names/paths can only contain ASCII letters and some symbols\n(a-zA-Z0-9!$%&+,-.; =@^`{}()_).\n$file_full[$i] contains illegal characters.\nRename the file and try again!";
					print LOG "\nFile rejected due to illegal character: $file_full[$i]";
					$repeat = "on";	# setting the $repeat flag forces the user to submit a new file name
					sleep 2;
				}	# else {print "\nfile $ii passed charfilter\n";}
			}


			unless ($repeat) { # if the char filter already caught the problem, there's no need to throw this error as well
			unless (-e "$file_full[$i]") {
			print "\n\n\nERROR: Input file not found ($!) at line " . __LINE__ . "\n(file: $file_full[$i])\n Try again!\n\n";
			print LOG "\nERROR: File $ii not found; folder: $inputfolder[0], file: $file[0]";
			$repeat = "on";
			sleep 2;
			}
		}

		for (my $j = 0; $j < $i; $j++) { # make sure the dumbass didn't specify the same file twice by mistake
		# print "\n$i vs $j\n";
			if ("$file_full[$j]" eq "$file_full[$i]") {
				print "\n\n\nERROR! You specified the same file twice. Try again!\n";
				print LOG "\nERROR! Same file dropped in twice";
				$repeat = "on";
				sleep 2;
			}
		}

			print LOG "\nInput file $ii: $file[$i] (${file_full[$i]})";
		}	# end of $i loop



#? do the checks for other files as well?
#do set a variable if any of the checks fails on any of the files

		# unless ("$ext" eq "$ext2") {
		# print "\n\n\nERROR! The file extensions don't match. Try again!\n($ext vs. $ext2)\n";
		# print LOG "\nERROR! Extensions don't match: $ext vs. $ext2";
		# }
		



		
		# generate $alignfilename for output file naming and metadata (added to last column and to TMX)
		if ($no < 3) {
			$alignfilename = "${f[0]}-${f[1]}"; #do
		} else {
			$alignfilename = "${f[0]}-${l[0]}-${l[1]}"; # in multilingual projects, the filename could end up being too long for Windows
		}

		if ($cmdline) {$repeat = "";}	# don't ask for corrected input in cmdline mode (the next step will abort if incorrect)
	} until (! $repeat); # end of 'do' block


	for (my $i = 0; $i < $no; $i++) {
		# copy raw input files to output folder
		if (-e "$folder/$file[$i]") { # if two input files are named the same (from different folders), rename
			#this if/else relies on the folder being new & empty when we start (due to  timestamp, it is)
			copy ("$file_full[$i]", "$folder/$l[$i]_$file[$i]") or abort("Cannot copy source file ($file_full[$i]) to output directory: $! at line " . __LINE__);
			$file[$i] = "$l[$i]_" . $file[$i];
			$f[$i] = "$l[$i]_" . $f[$i];
		} else {
			copy ("$file_full[$i]", "$folder/$file[$i]") or abort("cannot copy source file ($file_full[$i]) to output directory: $! at line " . __LINE__);
		}
	}

} # end of "if ($filetype..." block that processes the names/paths of local (txt, html, doc etc) input files

# print "\nsee if files have been copied to align_datetime folder\n";<STDIN>; #they are


# BACKUP # not needed anymore as input files are copied to an output dir and originals are left in place
# unless ( ($filetype eq "t" && $ext eq "docx") or ($filetype eq "t" && $ext eq "doc") or ($filetype eq "p" && $ext eq "pdf") ) { # docx, doc & pdf are left in place

	# unless(-d "$folder/source_files_backup") {mkdir "$folder/source_files_backup" or abort("Cannot create backup folder: $! at line " . __LINE__)};
	# for (my $i = 0; $i < $no; $i++) {
		# copy ("$folder/$file[$i]", "$folder/source_files_backup/$file[$i]") or abort("cannot create backup of $file[$i]: $! at line " . __LINE__);
	# }
# }



# CHECK FILE SIZES
my @filesize;
print LOG "\nInput file sizes:";
for (my $i = 0; $i < $no; $i++) {
	my $ii = $i;$ii++; # a counter that's always set at i+1

	$filesize[$i] = -s "$folder/$file[$i]";
	print LOG " $filesize[$i] bytes";

	if ($filesize[$i] == 0) { abort("Input file $ii is empty at line " . __LINE__); }	#abort
}


# HERE, WE CONVERT ALL INPUT FILE FORMATS TO UTF-8 TXT
my $i; # the global variable is needed so that the ren sub can see $i
for ($i = 0; $i < $no; $i++) { # giant loop for all input->txt converters
	my $ii = $i;$ii++; # a counter that's always set at i+1

	# PROCESS HTML
	if (($filetype eq "c") or ($filetype eq "com") or ($filetype eq "epr") or ($filetype eq "w") or ($filetype eq "h")) {

		# detect HMTL encoding and resave in UTF-8 if needed. Take code from TMX converter @ line 2875

		if ($OS eq "Windows") {		# windows version uses HTML modules, *nix version uses inline stripper
			convert_html("$folder/$file[$i]");
		} else {
			convert_html_compatibility("$folder/$file[$i]");

		}
		unlink "$folder/$file[$i]" if $filetype eq "h";		# delete html files in local projects, originals are in original folder

		$file[$i] = "${f[$i]}.txt";		# work with the txt files from now on
		$ext = "txt";

	}


	# PROCESS TMX
	if (($filetype eq "t") && ($ext eq "tmx")) {
		tmx_extract("$folder/$file[$i]");
		unlink "$folder/$file[$i]";		# delete tmx files from outfolder, originals are in different folder #new
		$file[$i] = "${f[$i]}.txt";		# work with the txt files from now on
	}


	# PROCESS DOCX
	if (($filetype eq "t") && ($ext eq "docx")) {
		print LOG "\nConverting docx file to txt";
		if ($OS eq "Windows") {
			# create config file, run docx2txt.exe modded to use win config file
			open (DOCX2TXTCONFIG, "<", "$scriptpath/scripts/docx2txt/docx2txt.config") or abort("Can't open file: $! at line " . __LINE__);
			unlink "$scriptpath/scripts/docx2txt/docx2txt_win.config";
			open (DOCX2TXTCONFIG_WIN, ">>", "$scriptpath/scripts/docx2txt/docx2txt_win.config") or abort("Can't open file: $! at line " . __LINE__);
			while (<DOCX2TXTCONFIG>) {
				s/^unzip *=>.*$/unzip         => \'$scriptpath\\scripts\\docx2txt\\unzip\\unzip\.exe\',/;
				print DOCX2TXTCONFIG_WIN $_;
			}
			close DOCX2TXTCONFIG;
			close DOCX2TXTCONFIG_WIN;
			system ("\"$scriptpath\\scripts\\docx2txt\\docx2txt_win.exe\" \"$folder/$file[$i]\" \"$folder/${f[$i]}.txt\"");
		} else { # linux and mac both use the original docx2txt.pl and both have unzip at usr/bin/unzip

			system ("perl \"$scriptpath/scripts/docx2txt/docx2txt.pl\" \"$folder/$file[$i]\" \"$folder/${f[$i]}.txt\"");
		}

		unlink "$folder/$file[$i]";		# delete docx files from outfolder, originals are in different folder #new
		
		$file[$i] = "${f[$i]}.txt";	#work with the txt files from now on

	}



	# PROCESS DOC
	if (($filetype eq "t") && ($ext eq "doc")) {
		print LOG "\nConverting doc files to txt";
		my $antiword_bin;

		if ($OS eq "Windows") {$antiword_bin = "$scriptpath\\scripts\\antiword\\antiword.exe"; unless (-e "C:/antiword/UTF-8.txt") {mkdir "C:/antiword"; copy("$scriptpath/scripts/antiword/mappingfiles/UTF-8.txt", "C:/antiword/UTF-8.txt")}}
		elsif (-e "/usr/bin/antiword") {$antiword_bin = "/usr/bin/antiword"; print LOG "\nantiword found installed on system"}
		else {abort("Antiword not found on your system; please install it. See readme.");}

		#print "\nantiword binary: $antiword_bin";

		# ALL OSes
		system ("\"$antiword_bin\" -w 0 -m UTF-8 \"$folder/$file[$i]\" > \"$folder/${f[$i]}.txt\"");

		unlink "$folder/$file[$i]";		# delete doc files from outfolder, originals are in different folder #new

		#work with the txt files from now on
		$file[$i] = "${f[$i]}.txt";

		# remove [pic]
		open (IN, "<:encoding(UTF-8)", "$folder/$file[$i]") or abort("Can't open input file: $! at line " . __LINE__);
		open (OUT, ">:encoding(UTF-8)", "$folder/${f[$i]}_mod.txt") or abort("Can't open output file: $! at line " . __LINE__);


		while (<IN>) {
			next if /^\s*\[pic\]\s*$/;
			print OUT $_;
		}

		ren; # rename sub; renames XXX_mod to XXX and reopens the input and output files for the next round of changes
		close IN;
		close OUT;

	}


	# PROCESS RTF, ODT etc. (everything with "t" filetype that's not txt, docx or doc)
	if ( ($filetype eq "t") && ($ext ne "txt") && ($ext ne "tmx") && ($ext ne "docx") && ($ext ne "doc") ) {


		my $abiword_bin;

		if ($OS eq "Windows") {
			if (-e "c:\\Program Files\\AbiWord\\bin\\AbiWord.exe") {$abiword_bin = "c:\\Program Files\\AbiWord\\bin\\AbiWord.exe"}
			elsif (-e "c:\\Program Files (x86)\\AbiWord\\bin\\AbiWord.exe") {$abiword_bin = "c:\\Program Files (x86)\\AbiWord\\bin\\AbiWord.exe"}
			else {$abiword_bin ="$scriptpath\\scripts\\abiword\\bin\\AbiWord.exe"}

		} else { # lin, mac: see if abiword is preinstalled

			if (-e "/usr/bin/abiword") {$abiword_bin = "/usr/bin/abiword"}
			elsif (-e "/usr/bin/Abiword") {$abiword_bin = "/usr/bin/Abiword"} # capitalization
			elsif (-e "/usr/bin/AbiWord") {$abiword_bin = "/usr/bin/AbiWord"} # capitalization
			else {print "\nAbiWord not found in /usr/bin; attempting to use it anyway. Please install AbiWord if you haven't.\n";$abiword_bin = "abiword"; print LOG "\nAbiWord not found in /usr/bin, proceeding anyway";}
		}


		print LOG "\nConverting $ext files to txt; AbiWord binary: $abiword_bin";
		
		system ("\"$abiword_bin\" \"$folder/$file[$i]\" --to=\"$folder/${f[$i]}.txt\""); #do or abort

		unlink "$folder/$file[$i]";		# delete input files from outfolder, originals are in different folder #new
		
		$file[$i] = "${f[$i]}.txt";		# work with the txt files from now on

	}



	# PROCESS PDF
	if (($filetype eq "p") && ($ext eq "pdf")) { # only with "p" filetype as line break postprocessing is needed

		if (lc($pdfmode) eq "y") {$pdfmode = "-layout"} else {$pdfmode = ""};

		my $pdftotext_bin; # put path+name of pdftotext binary in variable so I can use a unified command
		if 		($OS eq "Windows") {$pdftotext_bin = "$scriptpath\\scripts\\pdftotext\\pdftotext_win"}
		elsif 	(-e "/usr/bin/pdftotext") {$pdftotext_bin = "/usr/bin/pdftotext"; print LOG "\npdftotext found installed on system"}
		elsif 	($OS eq "Linux") {$pdftotext_bin = "$scriptpath/scripts/pdftotext/pdftotext_linux"}
		else 	{$pdftotext_bin = "$scriptpath/scripts/pdftotext/pdftotext_mac"}

		# ALL OSes
		system ("\"$pdftotext_bin\" $pdfmode -enc UTF-8 \"$folder/$file[$i]\" \"$folder/${f[$i]}.txt\"");

		unlink "$folder/$file[$i]";		# delete input files from outfolder, originals are in different folder #new

		#work with the txt files from now on
		$file[$i] = "${f[$i]}.txt";
	}

}		# end of giant loop for all input->txt converters




# allow user to review converted pdf files

if (($filetype eq "p") && ($ext eq "pdf")) {
	# header/footer detection/removal goes here

	print "\n\n-------------------------------------------------";
	print "\n\nPdf to txt conversion done. To get the best alignment results, review the txt files and remove any page headers/footers now, then save and close the files.\nType open to open all txt files, press enter to skip reviewing. ";
	chomp ( my $reviewpdf = lc(<STDIN>) );

	if ($reviewpdf eq "open") {
	for ($i = 0; $i < $no; $i++) { 
			if ($OS eq "Windows") {
			# files: $folder/${f[$i]}.txt
					system ("\"$folder/${f[$i]}.txt\"");
				} elsif ($OS eq "Linux") {
					system ("xdg-open \"$folder/${f[$i]}.txt\"");
				} else {
					system ("open \"$folder/${f[$i]}.txt\"");
				}
			}	# end of file opener for loop
print "\nPress enter when you have saved and closed the txt files.\n";
<STDIN>;
		}

}





# CHECK FILE SIZES, ABORT IF 0
print LOG "\nFile sizes after conversion to txt:";
for (my $i = 0; $i < $no; $i++) {
	my $ii = $i;$ii++; # a counter that's always set at $i+1

	$filesize[$i] = -s "$folder/$file[$i]";
	print LOG " $filesize[$i] bytes";

	if ($filesize[$i] == 0) {
		abort("Conversion of file $ii ($l[$i]) failed. Try converting your files to txt before running the aligner. Error at line " . __LINE__);	#abort
	}
}




# TXT FILES OBTAINED, START PROCESSING

my (@word_no, @char_no, @line_no);
for ($i = 0; $i < $no; $i++) {
	my $ii = $i;$ii++;			# a counter that's always set at i+1

	open (IN, "<:encoding(UTF-8)", "$folder/$file[$i]") or abort("Can't open input file: $! at line " . __LINE__);
	open (OUT, ">:encoding(UTF-8)", "$folder/${f[$i]}_mod.txt") or abort("Can't open output file: $! at line " . __LINE__);



	# CONVERT NEWLINES - test with all 3 line endings on all 3 platforms

	while (<IN>) {
		s/\r/\n/g;
		print OUT $_;
	}

	ren;		# rename sub; renames XXX_mod to XXX and reopens the input and output files for the next round of changes

	if ($filetype eq "p") {

		my $pdfchar = "n";
				while (<IN>) {
				s/^ +//;
				if ( ($l[$i] eq "hu") && (/ı/) ) {$pdfchar = "y"} # Council documents have corrupted characters
				s/^(\(?[0-9]?[0-9]?[a-z0-9]\)|\.)/\n$1/;
				s/^- /\n- /;

				print OUT $_;
			}
		ren;

		if ($pdfchar eq "y") {print LOG "\nHungarian character conversion for pdf activated for language $ii";}

		while (<IN>) {
			s/^\n/<P>\n/;							# dbl line breaks -> <P>
			if ($pdfchar eq "y") {s/ő/ű/g; s/Ő/Ű/g; s/ı/ő/ig;}
			print OUT $_;
		}
		ren;

		while (<IN>) {
			s/\n/ /;								# remove all line breaks
			s/<P>/\n/g;								# <P> -> line break
			s/^  *//g;
			print OUT $_;
		}
		while (<IN>) {
			s/\n/ /;				# remove all line breaks
			s/<P>/\n/g;				# <P> -> line break
			s/^  *//g;
			print OUT $_;
		}
		ren;

	}


	while (<IN>) {
		s/^\x{FeFF}//;		# remove BOM
		s/\f/\n/g;			# replace FF with line break
		s/\x{A0}/ /g;		# replace \xA0 (non-breaking space) with space
		# s/\t/ /g;			# replace tab with space - commented out as hunalign gets rid of tabs anyway
		print OUT $_;
	}
	ren;

	# Remove lines that contain whitespace only, remove multiple spaces and leading and trailing whitespace and |
	while (<IN>) {
		chomp;	#removing the trailing whitespace chomps anyway
		s/   */ /g;
		s/^[\s\|]+//g;
		s/[\s\|]+$//g;
		s/^\s*\n//g;
		print OUT "$_\n";
	}
	ren;

	# MERGE/REMOVE SEGMENTS WITH NUMBERS OR a) ONLY
	if ($merge_numbers_headings eq "y") {
		while (<IN>) {
			s/^([\d\s\.]*)\n/$1 /;			# test
			s/^(\(?[0-9]?[a-zA-Z0-9][0-9]{0,2}[.)]?)\n/$1 /;
			print OUT $_;
		}
		ren;
	}

	# COUNT SEGMENTS, WORDS AND CHARS
	my @wordcounter;
	while (<IN>) {
		chomp($_);
		$char_no[$i] += length($_);
		#$words += scalar(split(/\W+/, $_)); # throws error, replaced by next 2 lines
		@wordcounter = split(/\W+/, $_);
		$word_no[$i] += @wordcounter;
	}
	$line_no[$i] = $.;
	close IN;
	close OUT;

}


# my ($line_no_1, $line_no_2);
# PRINT SEGMENT, WORD AND CHAR NUMBERS
print LOG "\nInitial stats: ";
print "\n\nInput file stats:\n";
for ($i = 0; $i < $no; $i++) {
	# my $ii = $i;$ii++; # a counter that's always set at i+1
	# my $ii = $i;$ii++; # a counter that's always set at i+1
	print LOG "\n- $l[$i]: $line_no[$i] segments,\t$word_no[$i] words,\t$char_no[$i] chars";
	print "- $l[$i]: $line_no[$i] segments,\t$word_no[$i] words,\t$char_no[$i] chars\n";
	
	
	if ($line_no[$i] == 0) {
		abort("File empty (zero segments in file to be aligned) at line " . __LINE__);
		next;
	}

}




#####################################################
# SEGMENTATION
#

# my $segmenttext;
# unless ($segmenttext_prompt eq "n") {
	# do {
		# print "\n\n-------------------------------------------------";
		# print "\n\nSegment text to sentences? (If segmentation is skipped, line breaks will be the segment delimiters - see readme for tips on segmenting with Trados.)\n[y/n] (Default: $segmenttext_def) ";
		# chomp ($segmenttext = lc(<STDIN>));
		# $segmenttext or $segmenttext = $segmenttext_def;

		# print "\nAnswer with y or n.\n\n" unless $segmenttext eq "y" or $segmenttext eq "n";
	# } until ($segmenttext eq "y" or $segmenttext eq "n");
# }
# $segmenttext or $segmenttext = lc($segmenttext_def);
print LOG "\nSegmentation: $segmenttext";



my @line_no_seg;
if ($segmenttext eq "y") {

	for ($i = 0; $i < $no; $i++) {
		my $ii = $i;$ii++; # a counter that's always set at i+1

		open (IN, "<:encoding(UTF-8)", "$folder/$file[$i]") or abort("Can't open file: $! at line " . __LINE__);
		open (OUT, ">:encoding(UTF-8)", "$folder/${f[$i]}_mod.txt") or abort("Can't open output file: $! at line " . __LINE__);

		# double-space the files to make the segmenter respect all line breaks
		while (<IN>) {
			s/$/\n/g;		# double space AND tack on a \n to the last line to fix the segmenter's chop/chomp bug
			print OUT $_;
		}

		ren;

		# RUN THE SENTENCE SPLITTER (Win: exe made w/ PAR::Packer, else: original perl script), Ch: manual segmenter
		my $segmenter_bin;
		if ($OS eq "Windows") {$segmenter_bin = "$scriptpath\\scripts\\sentence_splitter\\split-sentences.exe"} else {$segmenter_bin = "$scriptpath/scripts/sentence_splitter/split-sentences.perl"}


		if ( ($l[$i] ne "zh") && ($l[$i] ne "jp") && ($l[$i] ne "ja") ) { # non-Chinese, non-Japanese texts: run the europarl segmenter

			system ("\"$segmenter_bin\" -l $l[$i] < \"$folder/$file[$i]\" > \"$folder/${f[$i]}_seg.txt\"")

		} else { # Chinese/Japanese manual segmenter, l1
			print "\nRunning the Chinese segmenter on the $l[$i] text\n";
			print LOG "\nRunning Chinese segmenter on the $l[$i] text";

			open (SEG, ">:encoding(UTF-8)", "$folder/${f[$i]}_seg.txt") or abort("Can't open file: $! at line " . __LINE__);

			# to get the chr code of a character: $char = "~";print "code: " . ord ($char) . "\n";
			my $cjk_period = chr(12290);	# Chinese (japanese etc.) period (=circle)
			my $cjk_question = chr(65311);	# odd question mark
			my $cjk_excl = chr(65281);		# odd exclamation mark

			while (<IN>) {
				s/^\n//g; # remove double line breaks
				s/([${cjk_period}${cjk_question}${cjk_excl}?!])([»\'\"\)\]\p{IsPf}]{1,2})/$1$2\n/g;	# punctuation + quotes or brackets
				s/([${cjk_period}${cjk_question}${cjk_excl}?!])([^»\'\"\)\]\p{IsPf}])/$1\n$2/g;		# punctuation, no qoutes, no brackets
				s/(\Q……\E)([»\'\"\)\]\p{IsPf}]{1,2})/$1$2\n/g;
				s/(\Q……\E)([^»\'\"\)\]\p{IsPf}])/$1\n$2/g;

				print SEG $_;
			}
			close SEG;

		}

		open (SEG_IN, "<:encoding(UTF-8)", "$folder/${f[$i]}_seg.txt") or abort("Can't open file: $! at line " . __LINE__);
		open (SEG_MOD, ">:encoding(UTF-8)", "$folder/${f[$i]}_seg_mod.txt") or abort("Can't open file: $! at line " . __LINE__);

		while (<SEG_IN>) {
			s/<[pP]>\n//g;
			print SEG_MOD $_;
		}
		renseg;

		# MERGE/REMOVE SEGMENTS WITH NUMBERS OR a) ONLY - REPEAT AFTER SEGMENTING
		if ($merge_numbers_headings eq "y") {

			while (<SEG_IN>) {
				s/^([\d\s\.]*)\n/$1 /;			# test
				s/^(\(?[0-9]?[a-zA-Z0-9][0-9]{0,2}[.)]?)\n/$1 /;
				print SEG_MOD $_;
			}
			renseg;
		}
		while (<SEG_IN>) {}
		$line_no_seg[$i] = $.;


		close IN;
		close OUT;
		close SEG_IN or abort("Can't close file: $! at line " . __LINE__);
		close SEG_MOD or abort("Can't close file: $! at line " . __LINE__);

		unlink "$folder/${f[$i]}_seg_mod.txt";
		unlink "$folder/${f[$i]}_mod.txt";
	}

	print "\n\n-------------------------------------------------";
	print "\n\nSegment numbers before and after segmentation:\n";

	print LOG ", segment numbers: ";
	for ($i = 0; $i < $no; $i++) {
		my $ii = $i;$ii++; # a counter that's always set at i+1
		print LOG "\n- $l[$i]: $line_no[$i] -> $line_no_seg[$i]";
		print "File $ii (${l[$i]}): $line_no[$i] -> $line_no_seg[$i]\n";
	}
}


# REVERT TO UNSEGMENTED OR NOT
my $revert;
if ($confirm_segmenting eq "auto") {	# evaluate seg. numbers programmatically and decide whether to keep the segmented file versions programmatically based on % calculations

	my $ratio_unseg;
	my $ratio_seg;
	my $growth;

	print LOG "\nAuto evaluation of segmentation results is on";

	# calculate the difference in segment numbers between unsegmented input texts
	if ($line_no[0] >= $line_no[1]) {
		$ratio_unseg = $line_no[0] / $line_no[1];
	} else {
		$ratio_unseg = $line_no[1] / $line_no[0];
	}
	$ratio_unseg = ($ratio_unseg - 1) * 100; # convert to percentage
	$ratio_unseg++;		# some tolerance in case original segment numbers are equal or near equal
	# print "\nunsegmented % diff: $ratio_unseg %\n";

	# calculate growth
	 $growth = ($line_no_seg[0] + $line_no_seg[1]) / ($line_no[0] + $line_no[1]);


	if ($line_no_seg[0] >= $line_no_seg[1]) {
		$ratio_seg = $line_no_seg[0] / $line_no_seg[1];
	} else {
		$ratio_seg = $line_no_seg[1] / $line_no_seg[0];
	}
	$ratio_seg = ($ratio_seg - 1) * 100;
	# print "\nsegmented % diff: $ratio_seg %\n";

	# print "\ngrowth: $growth x\n"; #del
	# we're using simple math to determine when to revert to unsegmented text versions (when files got pushed out of balance by the segmenting)
	if ( ($ratio_seg / $growth ) < $ratio_unseg) {$revert = "n"} else {$revert = "y"}
	# if ( ($ratio_seg / $growth ) < (1.5 * $ratio_unseg) ) {$revert = "n"} else {$revert = "y"}	# to stick with segmented files more of the time

} elsif ($confirm_segmenting ne "n") {	# prompt the user

	print "\nIf the segmentation pushed the files badly out of balance (they had a similar number of segments before but not after), you may want to revert to the unsegmented versions, especially if (one of) the files hardly gained any new segments.\nIf the segmenting seems to have gone well, choose \"n\" or just hit Enter.\nRevert to unsegmented [y/n]? (Default: n) ";

	do {
		chomp ($revert = lc(<STDIN>));
		$revert or $revert = "n";
		print "\n\nType \"y\" to revert to unsegmented, leave empty or type \"n\" to use segmented versions.\n" unless (($revert eq "y") or ($revert eq "n"));
	} until ($revert eq "y" or $revert eq "n");
}
# elsif ($confirm_segmenting eq "a") { #set $revert to y or n based on percentages of $line_no[$i] -> $line_no_seg[$i] }

$revert or $revert = "n";



if ($segmenttext eq "y" && $revert eq "y") {
	print "\nReverting to unsegmented file versions";
	if ($confirm_segmenting eq "auto") {print " based on automatic evaluation";}
	print ".\n";

	print LOG "\nReverted to unsegmented";
	# delete empty lines from unsegmented

	for ($i = 0; $i < $no; $i++) {
		# my $ii = $i;$ii++; # a counter that's always set at i+1
		open (IN, "<:encoding(UTF-8)", "$folder/$file[$i]") or abort("Can't open file: $! at line " . __LINE__);
		open (OUT, ">:encoding(UTF-8)", "$folder/${f[$i]}_mod.txt") or abort("Can't open output file: $! at line " . __LINE__);

		while (<IN>) {
			s/^\n//g;
			print OUT $_;
		}
		ren;

		# delete segmented files
		close IN;
		close OUT;
		unlink "$folder/${f[$i]}_seg.txt";
		unlink "$folder/${f[$i]}_mod.txt";
	}


} elsif ($segmenttext eq "y") {

	print "\nUsing segmented file versions";
	print LOG "\nUsing segmented file versions";
	if ($confirm_segmenting eq "auto") {print " based on automatic evaluation";}
	print ".\n";

	# overwrite original with _seg
	for ($i = 0; $i < $no; $i++) {
		rename ("$folder/${f[$i]}_seg.txt", "$folder/${f[$i]}.txt") or abort("Can't rename file: $! at line " . __LINE__);
	}

	$line_no[0] = $line_no_seg[0]; # get an updated segment no. to toggle chopping mode with

} else {
	print "\nUsing unsegmented files";
	print LOG "\nUsing unsegmented files";
}

#
# SEGMENTATION DONE
#####################################################




#####################################################
# ALIGN
#


for ($i = 1; $i < $no; $i++) { # we're starting this loop at $i = 1; align 0-1, 0-2, 0-3 etc.

	align ("$f[0].txt", "$l[0]", "$f[$i].txt", "$l[$i]", "$l[0]-$l[$i]"); # file name, lang, file name 2, lang2, output file
		# this sub generates dictionaries if needed, aligns the two txt's with hunalign, cleans up the output and extracts segments in l1 and l2 etc. into separate files

	if ($i == 1) {
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_$l[0]-$l[1].txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);

	} else {

	# ADD 3rd, 4th etc. LANGUAGE TO ALIGNED FILE 
	open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
	open (ADDME, "<:encoding(UTF-8)", "$folder/${f[$i]}.txt") or abort("Can't open file: $! at line " . __LINE__);
	open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);

	# merge new language into multilingual aligned file
	until( eof(ALIGNED) and eof (ADDME) ) 
	{
		my $col_1 = <ALIGNED>;
		my $col_2 = <ADDME>;
		$col_1 ||= "";
		$col_2 ||= "";
		chomp($col_1);
		chomp($col_2);
		print ALIGNED_MOD "$col_1\t$col_2\n";
	}
	close ALIGNED;
	close ADDME;
	close ALIGNED_MOD;

	my $oldfilename = "aligned_${alignfilename}.txt";			# so we can delete the old aligned file
	my $oldfilename_mod = "aligned_${alignfilename}_mod.txt";
	# UPDATE ALIGNFILENAME

	# if ( ($filetype eq "t") or ($filetype eq "p") or ($filetype eq "h") ) { #do
			# $alignfilename = $alignfilename . "-$f[$i]"; # update alignfilename with full filename
		# }
		# else {
			$alignfilename = $alignfilename . "-$l[$i]"; # update alignfilename by tacking on the language code
		# }

		rename ("$folder/$oldfilename_mod", "$folder/aligned_${alignfilename}.txt") or print "\nCan't rename aligned file: $!\n";;
		unlink "$folder/$oldfilename" or print "\nCan't delete $oldfilename: $!\n";
	}

}



open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);

# ADD NOTE IN LAST COLUMN
while (<ALIGNED>) {
	chomp $_;
	s/$/\t$alignfilename\n/;
	print ALIGNED_MOD $_;
}
ren_aligned;

# Add BOM to aligned txt (only at the end for the sake of the duplicate & untranslated filter)
while (<ALIGNED>) {
	if ($. == 1) {s/^\x{FeFF}//};			# strip UTF-8 BOM if there is one
	if ($. == 1) {s/^/\x{FeFF}/};			# add UTF-8 BOM
	print ALIGNED_MOD $_;
}
ren_aligned;





#####################################################
# CHARACTER CONVERSION BASED ON SETUP
#

# load character pairs into hash - move this to setup sub?
open (SETUP, "<:encoding(UTF-8)", "$scriptpath/LF_aligner_setup.txt") or abort("Can't open file: $! at line " . __LINE__);
my $marker = "off";
while (<SETUP>) {
	chomp;
	if (($marker eq "source") && (/\t/)) {
		/^(.*)\t(.*)$/;
		$charconv_source{$1} = $2;
	}

	if (($marker eq "target") && (/\t/)) {
		/^(.*)\t(.*)$/;
		$charconv_target{$1} = $2;
	}
	$marker = "source" if /Character conversion table for language 1/i;
	$marker = "target" if /Character conversion table for language 2/i;
}
close SETUP;

my $charconv_entries;
# SOURCE CHARACTER CONVERSION
$charconv_entries = keys %charconv_source;

# if character conversion pairs were provided, do the replacements
if (%charconv_source) {# only run if user defined character pairs
	print "\n\n-------------------------------------------------";
	print "\n\nRunning the source language character converter with $charconv_entries entries.\n";
	print LOG "\nRunning the source language character converter with $charconv_entries entries.";

	while (my $line = <ALIGNED>) {
		chomp $line;	# gets chomped anyway
		foreach my $key (keys %charconv_source) {
			$line =~ /^([^\t]*)(.*)$/;					# pick out source language
			my $source = $1;							# pick out source language
			my $after = $2;								# save rest of line 
			$source =~ s/$key/$charconv_source{$key}/g;	# do replacement in source text
			$line = $source.$after."\n"; 				# rebuild entire line
		}
		print ALIGNED_MOD $line;						# line processed in various passes (key by key), print it
	}
	ren_aligned;
}


# TARGET CHARACTER CONVERSION
$charconv_entries = keys %charconv_target;

if (%charconv_target) {
	print "\n\n-------------------------------------------------";
	print "\n\nRunning the target language character converter with $charconv_entries entries.\n";
	print LOG "\nRunning the target language character converter with $charconv_entries entries.";

	while (my $line = <ALIGNED>) {
	chomp $line;
		foreach my $key (keys %charconv_target) {
			$line =~ /^([^\t]*\t)([^\t]*)(.*)$/;
			my $before = $1;
			my $target = $2;
			my $after = $3;
			$target =~ s/$key/$charconv_target{$key}/g;
			$line = $before.$target.$after."\n";
		}
		print ALIGNED_MOD $line;
	}
	ren_aligned;
}

# 
# CHARCONV DONE
#####################################################


#####################################################
# ALIGNMENT DONE, review
#

unless ($review_prompt eq "n") {
	print "\n\n-------------------------------------------------";
	print "\n\nYou'll probably want to review the autoalignment now. You can put your notes (to be shown by your CAT as a text field when you get a concordance hit etc.) in the last column, replacing the note added by the aligner.\n";

	do {
		print "\nDo you wish to:\nn  -  skip the review\nx  -  create and open an xls\n      (only for files under 65500 segments; see instructions in xls)\n\n[n/x] (Default: $review_def) ";

		chomp ($review = lc(<STDIN>));
		$review or $review = lc($review_def);
		if ($review eq "xn") {$review = "nx"};	# for tpyos; nx makes the xls w/o instructions and doesn't open it.
		print "\nAnswer with n, t or x\n" unless ($review eq "n" or $review eq "t" or $review eq "x" or $review eq "nx");
	} until ($review eq "n" or $review eq "e" or $review eq "ex" or $review eq "x" or $review eq "nx");

}
$review or $review = lc($review_def);
if ($review eq "xn") {$review = "nx"};

if (($tool =~ /compatibility/i) && ($review =~ /x/)) {$review = "n"; print "\nIn the compatibility version, xls review is not available.\n"; print LOG "Review changed to n as the compatibility version can't generate xls\n";} # deprecated, remove (?)

print LOG "\nReview: $review";


# LAUNCH GRAPHICAL EDITOR
if ($review =~ /e/) { # e, ex
	print LOG "\nLaunching alignedit with ";
	system ("\"$scriptpath\\other_tools\\alignedit.exe\" \"$folder\\aligned_${alignfilename}.txt\"");
}



if ($review eq "x") {
	print "\n\n-------------------------------------------------";
	print "\n\nWARNING! Do NOT press enter here now! Close the xls and the txt and wait for the next prompt.\n";
}




# GENERATE XLS

if (($review =~ /x/) ) { # x, nx, ex

	{ #unnamed block to keep the open xls command at the end in separate block from xls generation

		# Create a new Excel document
		my $workbook = Spreadsheet::WriteExcel->new("$folder/${alignfilename}.xls");

		# Add a worksheet
		my $worksheet1 = $workbook->add_worksheet;

		# set column widths
		my $width;
		$width = "80" if $no == 2;
		$width = "57" if $no == 3;
		$width = "43" if $no == 4;
		$width = "35" if $no > 4;

		for (my $i = 0; $i < $no; $i++) {
			$worksheet1->set_column($i, $i, $width);
		}

		if ($review eq "x") {
			# Create a format for the header
			my $format2 = $workbook->add_format();
			$format2->set_bold();
			$format2->set_align('vcenter');


			# cell heights for the header
			$worksheet1->set_row(0, 16);
			$worksheet1->set_row(1, 16);
			$worksheet1->set_row(2, 16);
			$worksheet1->set_row(3, 16);
			$worksheet1->set_row(4, 16);
			$worksheet1->set_row(5, 16);
			$worksheet1->set_row(6, 16);

			# Header
			$worksheet1->write("A1", "Instructions:", $format2);
			$worksheet1->write("A2", "1) Review and correct the pairings. See instructions on worksheet 2.", $format2);
			$worksheet1->write("A3", "2) Write your notes (to be added to each translation unit in the TMX) in column C if you wish.", $format2);
			$worksheet1->write("A4", "3) Save and close this file, and close any other open spreadsheets.", $format2);
			$worksheet1->write("A5", "4) Return to the aligner window.", $format2);
		}

		# Create a format with text wrap and top alignment
		my $format1 = $workbook->add_format();
		$format1->set_align('top');
		$format1->set_text_wrap();


		# starting line no. for printing aligned text
		my $count = 8;		# skip a few lines after the header; if this is modified, also modify next if ($. > 6); in CONVERT REVIEWED XLS FILE TO TXT
		if ($review ne "x") {$count = 0};

		while (<ALIGNED>) {

			if ($count == 65510) {
				print "\nYour file contains more than 65500 lines, the xls has been truncated (the txt contains the entire file).\nPress enter to view the xls.\n";
				print LOG "\nxls truncated";
				<STDIN>;
				last;
			}

			$count ++;
			chomp ($_);

			if ($. == 1) {s/^\x{FeFF}//};			#strip BOM from aligned file

			# the xls maker fails if it comes across sg that looks like a formula
			s/^=/ =/;
			s/\t=/\t =/g;
			s/^"/ "/;
			s/\t"/\t "/g;

# get $no columns + 1 or 2 without formatting

			my $line = $_; # to use in loop
			my @col = ("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "AA", "AB", "AC", "AD", "AE", "AF", "AG", "AH", "AI", "AJ", "AK", "AL", "AM", "AN", "AO", "AP", "AQ", "AR", "AS", "AT", "AU", "AV", "AW", "AX", "AY", "AZ", "BA", "BB", "BC", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BK", "BL", "BM", "BN", "BO", "BP", "BQ", "BR", "BS", "BT", "BU", "BV", "BW", "BX", "BY", "BZ", "CA", "CB", "CC", "CD", "CE", "CF", "CG", "CH", "CI", "CJ", "CK", "CL", "CM", "CN", "CO", "CP", "CQ", "CR", "CS", "CT", "CU", "CV");
				# 100 column codes for Excel

			for (my $i = 0; $i < $no; $i++) {
				# Pick out columns, \t? to make it work with files w/ no note column
				$line =~ /^(?:[^\t]*\t){$i}([^\t]*)/; # (?:) is a non-capturing grouping
				my $text_col = $1;
				$worksheet1->write("$col[$i]$count", "$text_col", $format1);
			}


			$line =~ /^(?:[^\t]*\t){$no}([^\t]*)\t?([^\t]*)/;
			$worksheet1->write("$col[$no]$count", "$1"); # last but one cell of $line
			$worksheet1->write("$col[$no + 1]$count", "$2"); #last cell of $line
		}
		print LOG "\nGenerated xls with $. lines";

		# WORKSHEET 2 - REVIEWING INSTRUCTIONS
		if ($review eq "x") {
			my $worksheet2 = $workbook->add_worksheet;

			# set column width
			$worksheet2->set_column(0, 0, 120);

			# Format
			my $format3 = $workbook->add_format();
			$format3->set_bold();

			# Text
			$worksheet2->write("A1", "Intro", $format3);
			$worksheet2->write("A3", "You will probably want to check the sentence alignment before using your newly created TM. If the source files were reasonably similarly formatted and there weren't several pages missing from either of the two, a minute or two is usually enough to make sure everything is ok. Reading and comparing each segment one by one is only necessary if you want absolute 100% perfection for some reason - I find that it's hardly ever worth the effort. With larger alignment projects, it's usually a lot faster and a lot more convenient to use a 95% or 98% perfect alignment in the TM. Remember, you can always come back to this xls in case you bump into a misaligned segment during translation.", $format1);
			$worksheet2->write("A5", "Step by step:", $format3);
			$worksheet2->write("A7", "Scroll down the table; you can see at a glance if one segment is missing or is a lot shorter than the one it's paired with. You can scroll or pgdn your way down pretty fast and any major errors will stand out. Correct them by merging/splitting/moving segments. You can insert and delete rows by right clicking on the row heading. You can leave empty rows in the table; they will be deleted before your TMX is generated.", $format1);
			$worksheet2->write("A8", "Of course, you'll always want to move segments around without pushing columns A and B out of sync. If the autoaligner messed up the alignment at any point, you can be sure it got back to the straight and narrow later on unless the input files were absolutely hopeless. So, if you were to delete or add a cell in column A without doing the same in column B, you would mess up the rest of the file.", $format1);
			$worksheet2->write("A9", "You can go to A1 and press ctrl-down to jump to the first empty cell to check if there are any segments in colum A that are not paired with anything, then do the same in B.", $format1);
			$worksheet2->write("A10", "You can insert a running serial number to column D (start with 00001, not 1 - you need the number format to be set to \"text\" for this) to mark the original line order, and then sort the whole table alphabetically by column C to check cells with a low confidence rating. Sorting by A and B can also be useful. Then sort by D to get back to the original order. The confidence value can also be used for automatically discarding records under a certain threshold.", $format1);

			$worksheet2->write("A12", "Use of the Excel macro:", $format3);
			$worksheet2->write("A14", "A macro is provided in aligner/scripts to speed up reviewing/editing. Installation: In the Tools Menu, click Add-Ins / Browse. Browse to aligner/scripts/MergeCells.xla, select it and click ok. Make sure the add-in is in the Add-ins available box and it is checked. Click OK; the add-in is now installed and the macro will be available in all workbooks you open.", $format1);
			$worksheet2->write("A15", "After installing the add-in, you can use the macro by pressing ctrl-j. If no cell is selected, the macro merges the active cell with the next cell below it. If no cell is selected and the active cell is empty, the cell below the active cell is moved up. If you select two or more cells in a column, they are all merged into the top cell, with spaces between the contents of each cell. (Note: always select downwards: click the top cell, press and hold Shift and use the down arrow).", $format1);
		}


	}
	close ALIGNED; # maybe remove this as we won't need to open the file when we use xls->txt autoconversion


# OPEN XLS FILE
	if ($review eq "x") {
		if ($OS eq "Windows") {system ("\"$folder/${alignfilename}.xls\"");} elsif ($OS eq "Linux") {system ("xdg-open \"$folder/${alignfilename}.xls\"");} else {system ("open \"$folder/${alignfilename}.xls\"");}
	}
}



# CONVERT REVIEWED XLS FILE TO TXT so we can apply the user's changes when generating a tmx
my $xls2txtlinecount = 0;
if ($review eq "x") { # in "nx" or "ex", no need to convert to txt as the txt is already up to date
	convert_xls ("$folder/${alignfilename}.xls", "$folder/aligned_${alignfilename}.txt");
	# remove header up to Return to the aligner window.
	open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
	# my $header;
	while (<ALIGNED>) {
		# if (/Return to the aligner window/i) {$header = "over";next;}	# find the end of the header
		# if ( ($header) && (!/^\s*$/) ) {print ALIGNED_MOD};				# skip the couple of empty lines after the end of the header, and any empty/whitespace-only lines introduced by user
		next if ($. < 6);
		if (!/^\s*$/) {print ALIGNED_MOD; $xls2txtlinecount ++};				# skip the couple of empty lines after the end of the header, and any empty/whitespace-only lines introduced by user
	}
	print LOG "\nConverted xls to txt after review; $xls2txtlinecount lines";
	ren_aligned;
	close ALIGNED;
}




# GENERATE XBENCH VERSION
if ( ($version =~ /sajat/) && ($no == "3") ) {
	copy ("$folder/aligned_${alignfilename}.txt", "$folder/aligned_${alignfilename}_xb.txt");
	open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
	open (XB, ">>:encoding(UTF-8)", "$folder/aligned_${alignfilename}_xb.txt") or abort("Can't open file for writing: $! at line " . __LINE__);
	while (<ALIGNED>) {
		chomp;
		/^([^\t]*)\t([^\t]*)\t([^\t]*)(.*)$/;
		if ($. == 1) {s/^\x{FeFF}//};			# strip UTF-8 BOM if there is one
		if ($. == 1) {s/^/\x{FeFF}/};			# add UTF-8 BOM
		print XB "$3\t$2\t$1$4\n";
	}
	close XB;
}



# PRINT ALIGNED FILE TO MASTER TM

unless ($ask_master_TM eq "n") {
	if ( ($version =~ /sajat/) && ($no eq "3") ) {$alignfilename = "${alignfilename}_xb"}; # in sajat, use xb for this - BUT corrupts TMX

	# master tm names

	$master_TM_path_1 =~ /^ *(.*)[\/\\]([^\"\']*) *$/;
	$master_TM_file_1 = $2;

	$master_TM_path_2 =~ /^ *(.*)[\/\\]([^\"\']*) *$/;
	$master_TM_file_2 = $2;


	if ($master_TM ne "a") {	# $master_TM is set to "a" if the master TM is set from a command line argument (batch mode)
		do {
			# ask to append or overwrite
			print "\n\n-------------------------------------------------";
			print "\n\nAppend/write to $master_TM_file_1?\n\nn  -  No\na  -  Append to existing file\no  -  Create new file or overwrite existing one\n\n";
			chomp ($master_TM = lc(<STDIN>));
			$master_TM or $master_TM = "n";
			print "\nAnswer with n, a or o. Try again!\n\n" unless $master_TM eq "n" or $master_TM eq "a" or $master_TM eq "o";
		} until ($master_TM eq "n" or $master_TM eq "a" or $master_TM eq "o");
	}

	# APPEND
	if ($master_TM eq "a") {
		# open files
		open (MASTER_APP, ">>:encoding(UTF-8)", "$master_TM_path_1") or abort("Can't open master TM file $master_TM_path_1. Error: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open aligned file for reading: $! at line " . __LINE__);
		# print
		while (<ALIGNED>) {
			if ($. == 1) {s/^\x{FeFF}//};			#strip BOM from aligned file
			print MASTER_APP $_;
		}
		print MASTER_APP "\n"; # add an empty line at the end so different files are separated 
		# close files
		close ALIGNED;
		close MASTER_APP;
		print "\nFile appended to master TM ($master_TM_path_1).\n";
	}

	# OVERWRITE
	if ($master_TM eq "o") {
		copy ("$master_TM_path_1", "${master_TM_path_1}.bak") or print "Cannot make backup of master TM: $!";
		copy ("$folder/aligned_${alignfilename}.txt", "$master_TM_path_1") or abort("Cannot copy file to master TM: $! at line " . __LINE__);
		print "\nMaster TM created ($master_TM_path_1).\n";
	}


	# REPEAT WITH PATH 2

	unless ($master_TM_path_2 eq "") {

		# ask to append or overwrite 2
		do {
			print "\n\n-------------------------------------------------";
			print "\n\nAppend to $master_TM_file_2?\n\nn  -  No\na  -  Append to file\n\n";
			chomp ($master_TM = lc(<STDIN>));
			$master_TM or $master_TM = "n";
			print "\nAnswer with n or a.\n\n" unless $master_TM eq "n" or $master_TM eq "a";
		} until ($master_TM eq "n" or $master_TM eq "a");

		# APPEND
		if ($master_TM) {
			# open files
			open (MASTER_APP_2, ">>:encoding(UTF-8)", "$master_TM_path_2") or abort("Can't open master TM file: $! at line " . __LINE__);
			open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open aligned file for reading: $! at line " . __LINE__);
			# print
			while (<ALIGNED>) {
				if ($. == 1) {s/^\x{FeFF}//};			#strip BOM from aligned file
				print MASTER_APP_2 $_;
			}
			# close files
			close ALIGNED;
			close MASTER_APP_2;
		}

	}
}


# CREATE TMX

unless ($create_tmx_prompt eq "n") {
	do {
		print "\n\n-------------------------------------------------";
		print "\n\nCreate TMX?\n[y/n] (Default: $create_tmx_def) ";
		chomp ($create_tmx = lc(<STDIN>));
		$create_tmx or $create_tmx = lc($create_tmx_def);

		print "\nAnswer with y or n.\n\n" unless $create_tmx eq "y" or $create_tmx eq "n";

	} until ($create_tmx eq "y" or $create_tmx eq "n");
}
$create_tmx or $create_tmx = lc($create_tmx_def);
print LOG "\nCreate TMX: $create_tmx";


my $tmxreport = ""; # to be printed at the end
if ($create_tmx eq "y") {

	# GET LANGUAGE CODES

	unless (@tmx_langcode) { # skip the prompts if this was set from the command line
		# get $tmx_langcode[0]
		unless ($tmx_langcode_1_prompt eq "n") {

			if ($gui) {print "Default creationdate: $date";} # we're printing these so that LFA_GUI.pm can capture them
			
			$tmx_langcode_1_def or $tmx_langcode_1_def = uc($l[0]); # by default no default TMX code set in the setup file, so we set it here
			$tmx_langcode_2_def or $tmx_langcode_2_def = uc($l[1]);	# the gui does the same for all langs
		
		
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

	# DATE/TIME
#do remove, merge into getlocaltime
	my $creationdate;
unless ($creationdate_prompt eq "n") {
		print "\n\n-------------------------------------------------";
		print "\n\nPress enter to use the autodetected date and time, or specify your own date and time to be recorded in the TMX. Use the format yyyymmddThhmmssZ, capital T and Z included. See details in readme.\nAutodetected default: $date ";
		chomp ($creationdate = <STDIN>);
		$creationdate or $creationdate = $date;

		unless ($creationdate =~ /^[0-2][0-9]{3}[0-1][0-9][0-3][0-9]T[0-2][0-9][0-5][0-9][0-5][0-9]Z$/) {
			print "\nIncorrect date format, falling back to default.\n";	# no "Try again!" because implementing it in the GUI would be messy
			$creationdate = $date;
		}

	}

	$creationdate or $creationdate = $date;
	print LOG ", date/time: $creationdate";

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
	my $tmxnote;

	unless ($tmxnote_prompt eq "n") {
		print "\n\n-------------------------------------------------";
		print "\n\nYou can add a note to your TMX. Your options are:
		\n1) Add the contents of the last column of the txt as a note. This is the default, just press enter to apply. This allows you to use accented characters or assign different notes to the various lines/segments in your TM - very useful e.g. if the content comes from several different documents.
		\n2) Type the text you wish to add as note. (Accented letters and other special characters may get corrupted.)
		\n3) Create the TMX without a note. Type \"none\" to apply.\n\n";

		print "\n\nleave empty/add your text/type \"none\": ";
		chomp ($tmxnote = <STDIN>);
		$tmxnote = "none" if ($tmxnote =~ /^\s*\"? ?none ?\"?\s*$/);
	}


	if ($tmxnote eq "") {print LOG ", note: last column"} else {print LOG ", note: $tmxnote";};

	my $tabs_req = $no;						# tab characters required in each line of the input file (=> columns in file)
	$tabs_req-- unless $tmxnote eq "";		# less tabs required if there is no note in the last column


	# START WRITING TMX
	
	open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
	open (TMX, ">:encoding(UTF-8)", "$folder/${alignfilename}.tmx") or abort("Can't open file: $! at line " . __LINE__);

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
	close TMX;
	open (TMX, "<:encoding(UTF-8)", "$folder/${alignfilename}.tmx") or abort("Can't open file: $! at line " . __LINE__);
	
	
	
	# o-tmf used to be "aligned"; now spoofing Trados' string for Studio compatibility
	my $segtype;
	if ($segmenttext eq "y") {$segtype = "sentence"} else {$segtype = "paragraph"}; #

	open (TMX_MOD, ">>:encoding(UTF-8)", "$folder/${alignfilename}_mod.tmx") or abort("Can't open file: $! at line " . __LINE__);
	print TMX_MOD "\x{FeFF}<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<!DOCTYPE tmx SYSTEM \"tmx14.dtd\">\n<tmx version=\"1.4\">\n  <header\n    creationtool=\"${tool}\"\n    creationtoolversion=\"${version}\"\n    datatype=\"unknown\"\n    segtype=\"$segtype\"\n    adminlang=\"$tmx_langcode[0]\"\n    srclang=\"$tmx_langcode[0]\"\n    o-tmf=\"TW4Win 2.0 Format\"\n  >\n  </header>\n  <body>\n";



	my $skipped = "0";
	my $halfempty = "0";	# lines in which there is no L1 text or no L2 text (only in bilingual files)
	my $written = "0";
	my $tmxnote_print;
	while (<TMX>) {
		chomp($_);

		unless (/(.*\t){$tabs_req}/) {print "\n\nLINE $. OF THE FILE DOESN'T HAVE ENOUGH COLUMNS, SO IT HAS BEEN SKIPPED.\nCHECK THE SOURCE FILE AND RUN THE TMX MAKER AGAIN IF NEEDED\n";$skipped++;next;}
		if (  ($skiphalfempty ne "n")  &&  ($no == 2)  &&  ( (/^\t/) or (/^[^\t]*\t(?:\t|$)/) )  ) {$halfempty++;$skipped++;next;} # skip if L1 or L2 is empty

		print TMX_MOD "<tu creationdate=\"$creationdate\" creationid=\"$creationid\">";
		unless ($tmxnote eq "none") {
			if ($tmxnote eq "") {/^([^\t]*\t){$no}([^\t]*)/; $tmxnote_print = $2} else {$tmxnote_print = $tmxnote}
			print TMX_MOD "<prop type=\"Txt::Note\">$tmxnote_print<\/prop>";
		}
		for (my $i = 0; $i < $no; $i++) { # loop through $no languages (2, usually)
			/^(?:[^\t]*\t){$i}([^\t]*)/; # capture the text that follows $i columns of previous stuff
			print TMX_MOD "\n<tuv xml:lang=\"$tmx_langcode[$i]\"><seg>$1<\/seg><\/tuv>";
		}
		$written++;
		print TMX_MOD " <\/tu>\n\n";
	}

	print TMX_MOD "\n<\/body>\n<\/tmx>";

	close TMX;
	close TMX_MOD;
	rename ("$folder/${alignfilename}_mod.tmx", "$folder/${alignfilename}.tmx") or abort("Can't rename file: $! at line " . __LINE__);

	# print "\n\n$written TUs have been written to ${alignfilename}.tmx; $skipped TUs have been skipped.\n";
	
	my $halfemptyreport;
	if ($skiphalfempty eq "y") {
		$halfemptyreport = " ($halfempty of them due to being half-empty)";
	} else {
		$halfemptyreport = "";
	}

	$tmxreport = "$written TUs have been written to the TMX. $skipped segments were skipped$halfemptyreport.\n\n";
}



# END

close OUT;
close ALIGNED;
close ALIGNED_MOD;
close TMX;
close TMX_MOD;

unlink "$folder/aligned_${alignfilename}_mod.txt";

print "\n\n-------------------------------------------------";
print "\n\nThe aligner has terminated successfully.";
# or n to run again
# print $scriptpath;
# my $script = File::Spec->rel2abs( __FILE__ );
# print "script: $script";


print LOG "\nTerminated normally.";
close LOG;
unless ($cmdline) {print " ${tmxreport}Press Enter to quit.\n";<STDIN>};


#########################################################################################

# SUBS

sub abort ($){ # FATAL ERROR! means the program can't continue and quits; ERROR: is used for "try again" errors
	my $errormsg = $_[0];			# errormsg

	# close filehandles, delete temp files
	close OUT;
	close SEG_MOD;
	close ALIGNED;
	close ALIGNED_MOD;
	close TMX;
	close TMX_MOD;

	unlink "$folder/${alignfilename}_mod.tmx";
	unlink "$folder/aligned_${alignfilename}_mod.txt";
	# unlink "$folder/${f1}_mod.txt";#? maybe add a loop to delete $folder/$f[$i].mod.txt and $f[$i]_seg.mod.txt
	# unlink "$folder/${f2}_mod.txt";
	# unlink "$folder/${f1}_seg_mod.txt";
	# unlink "$folder/${f2}_seg_mod.txt";

	print "\n\nFATAL ERROR! $errormsg\n";
	print LOG "\n\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nERROR! $errormsg\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nIf you can't resolve the error and you think you ran into a bug, send this log, a description of what you did and your input and output files to lfaligner\@gmail.com";
	close LOG;
	sleep 2;
	print "\nLF Aligner has aborted due to the above error.\nType log to view the log (saved at aligner/scripts/log.txt) or press enter to close this window\n";
	chomp ( my $exit = lc(<STDIN>) );
	
	if ($exit eq "log") {
		if ($OS eq "Windows") {
			system ("\"$scriptpath/scripts/log.txt\"")
		} elsif ($OS eq "Linux") {
			system ("xdg-open \"$scriptpath/scripts/log.txt\"")
		} else {
			system ("open \"$scriptpath/scripts/log.txt\"")
		} # test
	}

	die;
}

sub ren {
	close IN or abort("Can't close file: $! at line " . __LINE__);
	close OUT or abort("Can't close file: $! at line " . __LINE__);

	my $attempts; # extra attemtps at renaming the file may be needed e.g. if a backup program has locked the file
	while (not rename "$folder/${f[$i]}_mod.txt", "$folder/${f[$i]}.txt") {
		$attempts++;
		abort("Could not rename file: $! at line " . __LINE__) if $attempts > 5;
		print LOG "\n$attempts extra rename attempt(s) needed";
		sleep $attempts;
	}


	# rename ("$folder/${f[$i]}_mod.txt", "$folder/${f[$i]}.txt") or abort("Can't rename file: $! at line " . __LINE__);

	open (IN, "<:encoding(UTF-8)", "$folder/$file[$i]") or abort("Can't open input file: $! at line " . __LINE__);
	open (OUT, ">:encoding(UTF-8)", "$folder/${f[$i]}_mod.txt") or abort("Can't open output file: $! at line " . __LINE__);
}


sub renseg {
	close SEG_IN or abort("Can't close file: $! at line " . __LINE__);
	close SEG_MOD or abort("Can't close file: $! at line " . __LINE__);

	my $attempts;
	while (not rename "$folder/${f[$i]}_seg_mod.txt", "$folder/${f[$i]}_seg.txt") {
		$attempts++;
		abort("Could not rename file: $! at line " . __LINE__) if $attempts > 5;
		print LOG "\n$attempts extra rename attempt(s) needed";
		sleep $attempts;
	}

	# rename ("$folder/${f[$i]}_seg_mod.txt", "$folder/${f[$i]}_seg.txt") or abort("Can't rename file: $! at line " . __LINE__);

	open (SEG_IN, "<:encoding(UTF-8)", "$folder/${f[$i]}_seg.txt") or abort("Can't open file: $! at line " . __LINE__);
	open (SEG_MOD, ">:encoding(UTF-8)", "$folder/${f[$i]}_seg_mod.txt") or abort("Can't open file: $! at line " . __LINE__);
}



sub ren_aligned { # $alignfilename scoped to the align sub in the multi version, deactivate

	close ALIGNED;
	close ALIGNED_MOD;

	my $attempts;
	while (not rename "$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") {
		$attempts++;
		abort("Could not rename file: $! at line " . __LINE__) if $attempts > 5;
		print LOG "\n$attempts extra rename attempt(s) needed";
		sleep $attempts;
	}

	# rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);

	open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
	open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);
}



sub align($) { # $_[0,1,2 etc.]

	my $file1 = $_[0];			# file 1 and 2
	my $file2 = $_[2];
	my $l1 = $_[1];				# always $l[0]
	my $l2 = $_[3];				# $l2 is whatever the second languge is in the current loop
	my $alignfilename = $_[4];	# we're scoping this $alignfilename variable to this sub only


	my $hunalign_dic = "null.dic";		# empty dictionary in case there's no dictionary for the language pair

	if (-e "$scriptpath/scripts/hunalign/data/${l1}-${l2}.dic") {
		$hunalign_dic = "${l1}-${l2}.dic";		# use dic if available
	} elsif ( (-e "$scriptpath/scripts/hunalign/data/raw/${l1}.txt") && (-e "$scriptpath/scripts/hunalign/data/raw/${l2}.txt") ) {
		# if we have raw single-language files for the language pair, generate dictionary from them
		# dict data is stored in single-langue files as storing ~1000 language combinations would take up too much space

		print "\n\n-------------------------------------------------";
		print "\n\nGenerating ${l1}-${l2} dictionary...\n";

		open (DIC1, "<:encoding(UTF-8)", "$scriptpath/scripts/hunalign/data/raw/${l1}.txt") or print "Can't open dictionary file: $!" or goto DICFAILED; # if the open fails, skip dicmaking
		open (DIC2, "<:encoding(UTF-8)", "$scriptpath/scripts/hunalign/data/raw/${l2}.txt") or print "Can't open dictionary file: $!" or goto DICFAILED;
		open (DIC, ">:encoding(UTF-8)", "$scriptpath/scripts/hunalign/data/${l1}-${l2}.dic") or print "Can't open dictionary file: $!" or goto DICFAILED;

		my %seen; # for filtering out dupes
		until( eof(DIC1) and eof (DIC2)) { # generate a .dic file from two word lists
			my $col_1 = <DIC1>;
			my $col_2 = <DIC2>;
			chomp($col_1);
			chomp($col_2);
			next if $col_1 eq ""; # skip incomplete records
			next if $col_2 eq "";
			my $record = "$col_2 @ $col_1"; # hunalign takes dictionaries in reverse order!
			print DIC "$record\n" if (! $seen{ $record }++); # add record to hash as key, occurrence no. as value. If not yet in hash, print to DIC
		}
		my $dicsize = keys %seen;
		print "\nDictionary generated containing $dicsize entries\n";
		print LOG "\nGenerated ${l1}-${l2} dictionary with $dicsize entries";

		close DIC1;
		close DIC2;
		close DIC;

		$hunalign_dic = "${l1}-${l2}.dic";	# use newly made dictionary if the creation was successful
	}

	DICFAILED: # goto label for aborting dic generation

	print "\n\n-------------------------------------------------";
	print "\n\nAligning...\n";
	print "\n\nDictionary used by Hunalign: $hunalign_dic\n\n";
	print LOG "\nHunalign dictionary: $hunalign_dic";

	my $hunalign_binpath;
	if ($OS eq "Windows") {$hunalign_binpath = "$scriptpath\\scripts\\hunalign\\hunalign"}
	elsif ($OS eq "Mac") {$hunalign_binpath = "$scriptpath/scripts/hunalign/hunalign_mac"}
	else {$hunalign_binpath = "$scriptpath/scripts/hunalign/hunalign_linux"};


	# NON-CHOPPING MODE
	if ( ($chopmode == 0) or ($line_no[0] < $chopmode) ) {

		if ($chopmode == 0) {print LOG "\nUsing Hunalign in normal mode";} else {print LOG "\nUsing Hunalign in normal mode ($line_no[0] is less than $chopmode)";}

		my $hunalign_dicpath = "$scriptpath/scripts/hunalign/data/$hunalign_dic";
		$hunalign_dicpath =~ s/\//\\/g; # hunalign 1.2 complains about \ in path, so we replace with /
		

		system ("\"$hunalign_binpath\" -text \"$hunalign_dicpath\" \"$folder/$file1\" \"$folder/$file2\" > \"$folder/aligned_${alignfilename}.txt\"");

		unlink "$scriptpath/translate.txt"; # hunalign generates this useless empty file every time it runs

	} else {	# CHOPPING MODE (for large input files, above 15000 segs by default)

	print LOG "\nUsing Hunalign in chopping mode, $line_no[0] is more than than $chopmode";
		print "\nUsing Hunalign in chopping mode\n";
		unlink (<aligned_part_?.align>);
		unlink (<aligned_part_??.align>);
		unlink (<aligned_part_?.$l1>);
		unlink (<aligned_part_?.$l2>);
		unlink (<aligned_part_??.$l1>);
		unlink (<aligned_part_??.$l2>);
		if (-e "$folder/hunaligncommand.txt") {unlink ("$folder/hunaligncommand.txt")};


		if ($OS eq "Windows") {
		system ("\"$scriptpath\\scripts\\hunalign\\largefile_chopper\\partialAlign\" \"$folder/$file1\" \"$folder/$file2\" aligned_part $l1 $l2 $chopmode > \"$folder/hunaligncommand.txt\"");
		} else {system ("python \"$scriptpath/scripts/hunalign/largefile_chopper/partialAlign.py\" \"$folder/$file1\" \"$folder/$file2\" aligned_part $l1 $l2 $chopmode > \"$folder/hunaligncommand.txt\"")}


		# REMOVE EMPTY LINE FROM END OF COMMAND
		open (COMMAND, "<", "$folder/hunaligncommand.txt") or abort("Can't open Hunalign command file: $! at line " . __LINE__);
		open (COMMAND_MOD, ">", "$folder/hunaligncommand_mod.txt") or abort("Can't open Hunalign command output file: $! at line " . __LINE__);

		while (<COMMAND>) {}
		my $command_line_no = $.;
		print LOG "\nChopped file into $command_line_no pieces";
		# close and reopen needed after line count
		close COMMAND;
		close COMMAND_MOD;
		open (COMMAND, "<", "$folder/hunaligncommand.txt") or abort("Can't open Hunalign command file: $! at line " . __LINE__);
		open (COMMAND_MOD, ">", "$folder/hunaligncommand_mod.txt") or abort("Can't open Hunalign command output file: $! at line " . __LINE__);


binmode COMMAND;		# required for converting the file to unix line breaks (see below)
binmode COMMAND_MOD;

while (<COMMAND>) {
	s/\x0D(?=\x0A)//;						# convert to unix line breaks (hunalign 1.2 requires unix line breaks in the command file, even on windows)
	if ($. == $command_line_no) {chomp};	# remove line break from end of last line, otherwise hunalign throws error
	print COMMAND_MOD $_;
}




		# while (<COMMAND>) {
			# if ($. == $command_line_no) {s/\n//g};
			# print COMMAND_MOD $_;
		# }
		
		
		
		close COMMAND;
		close COMMAND_MOD;
		rename ("$folder/hunaligncommand_mod.txt", "$folder/hunaligncommand.txt") or abort("Can't rename Hunalign command file: $! at line " . __LINE__);

		# do with variable for hunalign binary
		# RUN HUNALIGN WITH COMMAND MADE BY THE CHOPPER
		if ($OS eq "Windows") {system ("\"$scriptpath\\scripts\\hunalign\\hunalign\" -text -batch \"$scriptpath/scripts/hunalign/data/$hunalign_dic\" \"$folder/hunaligncommand.txt\"")}
		elsif ($OS eq "Mac") {system ("\"$scriptpath/scripts/hunalign/hunalign_mac\" -text -batch \"$scriptpath/scripts/hunalign/data/$hunalign_dic\" \"$folder/hunaligncommand.txt\"")}
		else {system ("\"$scriptpath/scripts/hunalign/hunalign_linux\" -text -batch \"$scriptpath/scripts/hunalign/data/$hunalign_dic\" \"$folder/hunaligncommand.txt\"")};


		# append coming up, so delete any previous alignments
		if (-e "$folder/aligned_${alignfilename}.txt") {unlink "$folder/aligned_${alignfilename}.txt"};

		# MERGE ALIGNED FILES INTO ONE FILE IN $FOLDER
		open (ALIGNED, ">>:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file: $! at line " . __LINE__);
		my $c;
		for ($c = 1; $c <= $command_line_no; $c++) {
			open (FILE, "<:encoding(UTF-8)", "aligned_part_$c.align") or abort("\nCan't open aligned_part_$c.align. Chopping limit probably set too low or the files are too different. Error message: $! at line " . __LINE__);

			while (<FILE>) {
				print ALIGNED $_;
			}
			close FILE;
		}
		close ALIGNED;
		
		unlink (<aligned_part_?.align>);
		unlink (<aligned_part_?.$l1>);
		unlink (<aligned_part_?.$l2>);
		
		unlink (<aligned_part_??.align>);
		unlink (<aligned_part_??.$l1>);
		unlink (<aligned_part_??.$l2>);
		if (-e "$folder/hunaligncommand.txt") {unlink ("$folder/hunaligncommand.txt")};

	}

	# SEE IF ALIGNED FILE IS OK, ABORT IF NOT

	my $alignedfilesize = -s "$folder/aligned_${alignfilename}.txt";
	if ($alignedfilesize == 0) {
		print "\n\n-------------------------------------------------";
		print "\n\nAlignment failed (probably due to one file being empty or much shorter than the other). ABORTING...\n\n";
		unlink "$folder/aligned_${alignfilename}.txt";
		abort("The aligned file is empty.");
	} else {
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or print "Can't open aligned file for line count: $!";
		while (<ALIGNED>) {};
		$. --;					# correct the line count for the log
		print LOG "\nAligned file: $. segments, $alignedfilesize bytes ($folder/aligned_${alignfilename}.txt)";
		close ALIGNED;
	}



	open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open aligned file for reading: $! at line " . __LINE__);
	open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);

	# delete empty records (hunalign creates 1 or 2 at the end
	while (<ALIGNED>) {
		s/^\t\t.*\n//;
		print ALIGNED_MOD $_;
	}

	#ren_aligned; #
	close ALIGNED;
	close ALIGNED_MOD;
	rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
	open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
	open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);


	# CLEANUP
	if ($no > 2) {$cleanup_prompt = "n"; $cleanup = "n"; if ($i eq "1") {$cleanup = "y"}}
		# if there are 3 or more langs, always do cleanup in 1st loop, never in 2nd 3rd etc. loop


	unless ($cleanup_prompt eq "n") { 
		do {
			print "\n\n-------------------------------------------------";
			print "\n\nClean up text? (Remove ~~~ placed by Hunalign at the boundaries of merged segments, remove segment-starting \"- \".)\n[y/n] (Default: $cleanup_def) ";
			chomp ($cleanup = lc(<STDIN>));
			$cleanup or $cleanup = lc($cleanup_def);

			print "\nAnswer with y or n.\n\n" unless $cleanup eq "y" or $cleanup eq "n";

		}until ($cleanup eq "y" or $cleanup eq "n");
	}
	$cleanup or $cleanup = $cleanup_def;
	print LOG "\nCleanup: $cleanup";

	if ($cleanup eq "y") {
		while (<ALIGNED>) {
			s/ ~~~//g;				# remove ~~~ inserted by Hunalign
			s/^- //;				# remove segment starting "- "#?
			s/\t- /\t/;				# remove segment starting "- "#?
			print ALIGNED_MOD $_;
		}
		#ren_aligned; #
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);
	}

	# remove confidence value
	if ( ($no > 2) or ($cleanup_remove_conf_value eq "y") ) { # if $no > 2, always remove conf value
		while (<ALIGNED>) {
			s/([^\t]*\t[^\t]*).*$/$1/;
			print ALIGNED_MOD $_;
		}
		#ren_aligned; #
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);

	}

	# filter out dupes
	if ( ($delete_dupes eq "y") && ($no == 2) ) { # disable if $no > 2

		my %seen;		# hash that contains uique records (hash lookups are faster than array lookups)
		my $key;		# key to be put in hash
		while (<ALIGNED>) {
			/^([^\t]*\t[^\t]*)/;	# only watch first two fields
			chomp ($key = $1);		# only watch first two fields
			print ALIGNED_MOD $_ if (! $seen{ $key }++); # add to hash, and if new, print to file
		}

		my $unfiltered_number = $.;
		my $filtered_number = keys %seen;
		print "\n\n-------------------------------------------------";
		print "\n\nSegment numbers before and after filtering out dupes: $unfiltered_number -> $filtered_number\n";
		print LOG "\nFiltered out dupes: $unfiltered_number -> $filtered_number";

		undef %seen; # free up memory

		#ren_aligned; #
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);

	}


	# filter out L1 = L2
	if ( ($no == 2) && ($delete_untranslated eq "y") ) { # disable if $no > 2
		my $filtered_number = "0";
		while (<ALIGNED>) {
			chomp;
			/^([^\t]*)\t([^\t]*)/;
			next if $1 eq $2;
			print ALIGNED_MOD $_ . "\n";
			$filtered_number++;
		}
		my $unfiltered_number = $.;
		print "\n\n-------------------------------------------------";
		print "\n\nSegment numbers before and after filtering out untranslated segments: $unfiltered_number -> $filtered_number\n";
		print LOG "\nFiltered out untranslated segments: $unfiltered_number -> $filtered_number";

		#ren_aligned; #
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);
	}


	# EXTRACT LANGUAGE 1 TO USE AS INPUT FOR FURTHER ALIGNMENTS
	if ( ($i eq "1") && ($no > 2) ){
		open (L1, ">:encoding(UTF-8)", "$folder/${f[0]}.txt") or abort("Can't open file: $! at line " . __LINE__);

		while (<ALIGNED>) {
		s/^([^\t]*).*$/$1/g; # remove everything from the first tab on
		s/^\n/\[null\]\n/; # do we need this? #?
		print L1 $_;
		}
		close L1;


	} elsif ($no > 2) { # EXTRACT OTHER LANGUAGE FOR MERGING INTO ALIGNED FILE


		# UNDO SEGMENT MERGING DONE BY HUNALIGN IN L1
		my $repeat;
		REPEAT: # label for looping, come back here if needed
		$repeat = "0";
		while (<ALIGNED>) { #
			s/^([^\t]*) ~~~ ([^\t]*)\t(.*)$/$1\t$3\n$2\t/; # not /g!
			if (/^[^\t]* ~~~ /) {$repeat = "1"}# if there are still instances of ~~~ left in the text
			print ALIGNED_MOD;
		}
		#ren_aligned; #
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);

		goto REPEAT if $repeat eq "1";


		# MERGE BACK WHERE HUNALIGN STRETCHED APART
		
		# this is a proper mess, but it's the best I can do
			# the #fixfirst lines shift l2 to the second row if the first row's l1 cell is empty (it fixes files like 31978L0686 en-hu)
			# the rest of the loop appends orphan cells to the previous line
		
		my $previous = "";
		my $firstempty;
		while (<ALIGNED>) {	#change
			chomp;
			if ( ($. == 1) && (/^[\t]/) ) {$firstempty = $_;}; #fixfirst
			print ALIGNED_MOD $previous unless ($firstempty && $. == 2);# print previous line
			# if (/^[^\t]/) {print ALIGNED_MOD "\n"} else {s/^\t/ /}	# needed to be replaced due to #fixfirst
			unless ($. == 1) {if (/^[^\t]/) {print ALIGNED_MOD "\n"} else {s/^\t/ /} }# if first field of this line is empty, append to previous (don't print line break after previous)
			$previous = $_;
			if ( ($. == 2) && ($firstempty) ) {$previous =~ s/\t/$firstempty /;}; #fixfirst
		}
		print ALIGNED_MOD $previous;	#print last row
		#ren_aligned; #
		
		
		
		
		
		
		
		
		
		
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);


		# delete empty lines
		while (<ALIGNED>) {
			s/^\s*\n//;
			print ALIGNED_MOD $_;
		}
		#ren_aligned; #
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);

		# CLEANUP
		while (<ALIGNED>) {
			s/ ~~~//g;				# remove ~~~ inserted by Hunalign
			s/^- //;				# remove segment starting "- "
			s/\t- /\t/;				# remove segment starting "- "
			print ALIGNED_MOD $_;
		}
		#ren_aligned; #
		close ALIGNED;
		close ALIGNED_MOD;
		rename ("$folder/aligned_${alignfilename}_mod.txt", "$folder/aligned_${alignfilename}.txt") or abort("Can't rename file: $! at line " . __LINE__);
		open (ALIGNED, "<:encoding(UTF-8)", "$folder/aligned_${alignfilename}.txt") or abort("Can't open file for reading: $! at line " . __LINE__);
		open (ALIGNED_MOD, ">:encoding(UTF-8)", "$folder/aligned_${alignfilename}_mod.txt") or abort("Can't open file for writing: $! at line " . __LINE__);


		# EXTRACT LANGUAGE 3, 4 etc.

		open (LX, ">:encoding(UTF-8)", "$folder/${f[$i]}.txt") or abort("Can't open file: $! at line " . __LINE__);
			#in loop 2, this overwrites the third text; $f[i] = $f[2]

		while (<ALIGNED>) {
			s/^[^\t]*\t(.*)$/$1/g; # remove everything from the first tab on
			print LX $_;
		}
		close ALIGNED;
		close ALIGNED_MOD;
		close LX;


	unlink "$folder/aligned_${alignfilename}.txt"; # we're leaving the first aligned file

	}
	close ALIGNED_MOD;
	unlink "$folder/aligned_${alignfilename}_mod.txt";


}





sub convert_html($){
	# NOTE: $pf contains the path as well as the filename excluding the extension.

	$_[0] =~ /(.*)\.(.*)/;
	my $pf = $1;
	my $ext = $2;

	open (IN, "<:encoding(UTF-8)", "${pf}.${ext}");
	open (OUT, ">:encoding(UTF-8)", "${pf}_htmlmod.${ext}");

# PREPARE FILES BEFORE RUNNING THE STRIPPER
	while (<IN>) {
		s/\x{A0}/ /g;
		s/\n/ /g;
		s/<\/?p>/\n/ig;					# conserve line breaks ("\/?" because "<p style =...> blabla</p>" is not caught by the normal regex)
		s/<br( \/)?>/\n/ig;
		s/&gt\;/&amp\;gt\;/g;			# to make &gt; and &lt; stay as character references after decode_entities (to conserve quoted tags in text)
		s/&lt\;/&amp\;lt\;/g;
		# perhaps s/&otilde;/ő/g;		# In Hu texts &otilde; should be ő, altho the correct code for ő is &#337;
		# also s/&Otilde;/Ő/g;
		s/&\#8209;/-/g;
		print OUT decode_entities($_);
		# print OUT $_;					# failed alternative solution (fails if HTML has literal éáűúőóüöí)
	}
	close IN;
	close OUT;



# STRIP TAGS


	open (IN, "<", "${pf}_htmlmod.${ext}");
	open (OUT, ">", "${pf}.txt");

	# open (IN, "<:encoding(UTF-8)", "${pf}_htmlmod.${ext}");	# failed alternative solution
	# open (OUT, ">:encoding(UTF-8)", "${pf}.txt");				# failed alternative solution
	{
		my $hs = HTML::Strip->new();
		# my $hs = HTML::Strip->new( decode_entities => 1 );	# failed alternative solution

		while (<IN>) {
		my $clean_text = $hs->parse($_);
		print OUT $clean_text;
	}

	close IN;
	close OUT;
	unlink "${pf}_htmlmod.${ext}";
	}
}



sub convert_html_compatibility($){
	# NOTE: $pf contains the path as well as the filename excluding the extension.

	$_[0] =~ /(.*)\.(.*)/;
	my $pf = $1;
	my $ext = $2;

	open (IN, "<:encoding(UTF-8)", "${pf}.${ext}");
	open (OUT, ">:encoding(UTF-8)", "${pf}_htmlmod.${ext}");


	while (<IN>) {

		# line breaks

		s/\n/ /g;						# literal line breaks are all over the place in HTML, better remove
		s/<\/?p>/\n/ig;					# <p> and </p> -> \n
		s/<br( \/)?>/\n/ig;

		# character conversions added by myself:
		s/\x{A0}/ /g;					# nbsp
		s/&nbsp;/ /g;					# nbsp
		s/&\#368;/Ű/g;
		s/&\#369;/ű/g;
		s/&\#336;/Ő/g;
		s/&\#337;/ő/g;
		s/&\#8209;/-/g;

		# numericals over 255 from list found online:
	# list filtered for ANSI

		s/&(OElig|\#338);/O/g;
		s/&(oelig|\#339);/o/g;
		s/&(Scaron|\#352);/Š/g;
		s/&(scaron|\#353);/š/g;
		s/&(Yuml|\#376);/Y/g;
		s/&(fnof|\#402);/f/g;
		s/&(circ|\#710);/^/g;
		s/&(tilde|\#732);/~/g;
		s/&(beta|\#946);/ß/g;
		s/&(mu|\#956);/µ/g;
		s/&(ensp|\#8194);/ /g;
		s/&(emsp|\#8195);/ /g;
		s/&(thinsp|\#8201);/ /g;
		s/&(ndash|\#8211);/–/g;
		s/&(mdash|\#8212);/—/g;
		s/&(lsquo|\#8216);/‘/g;
		s/&(rsquo|\#8217);/’/g;
		s/&(sbquo|\#8218);/‚/g;
		s/&(ldquo|\#8220);/“/g;
		s/&(rdquo|\#8221);/”/g;
		s/&(bdquo|\#8222);/„/g;
		s/&(dagger|\#8224);/†/g;
		s/&(Dagger|\#8225);/‡/g;
		s/&(bull|\#8226);/•/g;
		s/&(hellip|\#8230);/…/g;
		s/&(permil|\#8240);/‰/g;
		s/&(prime|\#8242);/'/g;
		s/&(Prime|\#8243);/”/g;
		s/&(lsaquo|\#8249);/‹/g;
		s/&(rsaquo|\#8250);/›/g;
		s/&(euro|\#8364);/€/g;
		s/&(trade|\#8482);/™/g;
		s/&(larr|\#8592);/‹/g;
		s/&(uarr|\#8593);/^/g;
		s/&(rarr|\#8594);/›/g;
		s/&(darr|\#8595);/ˇ/g;
		s/&(harr|\#8596);/-/g;
		s/&(minus|\#8722);/-/g;


	# UTF-8 list
		# s/&(OElig|\#338);/Œ/g;
		# s/&(oelig|\#339);/œ/g;
		# s/&(Scaron|\#352);/Š/g;
		# s/&(scaron|\#353);/š/g;
		# s/&(Yuml|\#376);/Ÿ/g;
		# s/&(fnof|\#402);/ƒ/g;
		# s/&(circ|\#710);/ˆ/g;
		# s/&(tilde|\#732);/˜/g;
		# s/&(Alpha|\#913);/Α/g;
		# s/&(Beta|\#914);/Β/g;
		# s/&(Gamma|\#915);/Γ/g;
		# s/&(Delta|\#916);/Δ/g;
		# s/&(Epsilon|\#917);/Ε/g;
		# s/&(Zeta|\#918);/Ζ/g;
		# s/&(Eta|\#919);/Η/g;
		# s/&(Theta|\#920);/Θ/g;
		# s/&(Iota|\#921);/Ι/g;
		# s/&(Kappa|\#922);/Κ/g;
		# s/&(Lambda|\#923);/Λ/g;
		# s/&(Mu|\#924);/Μ/g;
		# s/&(Nu|\#925);/Ν/g;
		# s/&(Xi|\#926);/Ξ/g;
		# s/&(Omicron|\#927);/Ο/g;
		# s/&(Pi|\#928);/Π/g;
		# s/&(Rho|\#929);/Ρ/g;
		# s/&(Sigma|\#931);/Σ/g;
		# s/&(Tau|\#932);/Τ/g;
		# s/&(Upsilon|\#933);/Υ/g;
		# s/&(Phi|\#934);/Φ/g;
		# s/&(Chi|\#935);/Χ/g;
		# s/&(Psi|\#936);/Ψ/g;
		# s/&(Omega|\#937);/Ω/g;
		# s/&(alpha|\#945);/α/g;
		# s/&(beta|\#946);/β/g;
		# s/&(gamma|\#947);/γ/g;
		# s/&(delta|\#948);/δ/g;
		# s/&(epsilon|\#949);/ε/g;
		# s/&(zeta|\#950);/ζ/g;
		# s/&(eta|\#951);/η/g;
		# s/&(theta|\#952);/θ/g;
		# s/&(iota|\#953);/ι/g;
		# s/&(kappa|\#954);/κ/g;
		# s/&(lambda|\#955);/λ/g;
		# s/&(mu|\#956);/μ/g;
		# s/&(nu|\#957);/ν/g;
		# s/&(xi|\#958);/ξ/g;
		# s/&(omicron|\#959);/ο/g;
		# s/&(pi|\#960);/π/g;
		# s/&(rho|\#961);/ρ/g;
		# s/&(sigmaf|\#962);/ς/g;
		# s/&(sigma|\#963);/σ/g;
		# s/&(tau|\#964);/τ/g;
		# s/&(upsilon|\#965);/υ/g;
		# s/&(phi|\#966);/φ/g;
		# s/&(chi|\#967);/χ/g;
		# s/&(psi|\#968);/ψ/g;
		# s/&(omega|\#969);/ω/g;
		# s/&(ensp|\#8194);/ /g;
		# s/&(emsp|\#8195);/ /g;
		# s/&(thinsp|\#8201);/ /g;
		# s/&(ndash|\#8211);/–/g;
		# s/&(mdash|\#8212);/—/g;
		# s/&(lsquo|\#8216);/‘/g;
		# s/&(rsquo|\#8217);/’/g;
		# s/&(sbquo|\#8218);/‚/g;
		# s/&(ldquo|\#8220);/“/g;
		# s/&(rdquo|\#8221);/”/g;
		# s/&(bdquo|\#8222);/„/g;
		# s/&(dagger|\#8224);/†/g;
		# s/&(Dagger|\#8225);/‡/g;
		# s/&(bull|\#8226);/•/g;
		# s/&(hellip|\#8230);/…/g;
		# s/&(permil|\#8240);/‰/g;
		# s/&(prime|\#8242);/′/g;
		# s/&(Prime|\#8243);/″/g;
		# s/&(lsaquo|\#8249);/‹/g;
		# s/&(rsaquo|\#8250);/›/g;
		# s/&(oline|\#8254);/‾/g;
		# s/&(frasl|\#8260);/⁄/g;
		# s/&(euro|\#8364);/€/g;
		# s/&(trade|\#8482);/™/g;
		# s/&(larr|\#8592);/←/g;
		# s/&(uarr|\#8593);/↑/g;
		# s/&(rarr|\#8594);/→/g;
		# s/&(darr|\#8595);/↓/g;
		# s/&(harr|\#8596);/↔/g;
		# s/&(part|\#8706);/∂/g;
		# s/&(prod|\#8719);/∏/g;
		# s/&(sum|\#8721);/∑/g;
		# s/&(minus|\#8722);/−/g;
		# s/&(radic|\#8730);/√/g;
		# s/&(infin|\#8734);/∞/g;
		# s/&(cap|\#8745);/∩/g;
		# s/&(int|\#8747);/∫/g;
		# s/&(asymp|\#8776);/≈/g;
		# s/&(ne|\#8800);/≠/g;
		# s/&(equiv|\#8801);/≡/g;
		# s/&(le|\#8804);/≤/g;
		# s/&(ge|\#8805);/≥/g;
		# s/&(loz|\#9674);/◊/g;
		# s/&(spades|\#9824);/♠/g;
		# s/&(clubs|\#9827);/♣/g;
		# s/&(hearts|\#9829);/♥/g;
		# s/&(diams|\#9830);/♦/g;


		print OUT $_;
	}
	close IN;
	close OUT;

	#########################################################
	# striphtml ("striff tummel")
	# tchrist@perl.com 
	# version 1.0: Thu 01 Feb 1996 1:53:31pm MST 
	# version 1.1: Sat Feb  3 06:23:50 MST 1996
	# 		(fix up comments in annoying places)
	#########################################################
	open (IN, "<:encoding(UTF-8)", "${pf}_htmlmod.${ext}");
	open (OUT, ">:encoding(UTF-8)", "${pf}.txt");
	our %entity;
	our $chr;

	while (<IN>) {


		#########################################################
		# first we'll shoot all the <!-- comments -->
		#########################################################

		s{ <!                   # comments begin with a `<!'
								# followed by 0 or more comments;

			(.*?)		# this is actually to eat up comments in non 
					# random places

			 (                  # not suppose to have any white space here

								# just a quick start; 
			  --                # each comment starts with a `--'
				.*?             # and includes all text up to and including
			  --                # the *next* occurrence of `--'
				\s*             # and may have trailing while space
								#   (albeit not leading white space XXX)
			 )+                 # repetire ad libitum  XXX should be * not +
			(.*?)		# trailing non comment text
		   >                    # up to a `>'
		}{
			if ($1 || $3) {	# this silliness for embedded comments in tags
			"<!$1 $3>";
			} 
		}gesx;                 # mutate into nada, nothing, and niente

		#########################################################
		# next we'll remove all the <tags>
		#########################################################

		s{ <                    # opening angle bracket

			(?:                 # Non-backreffing grouping paren
				 [^>'"] *       # 0 or more things that are neither > nor ' nor "
					|           #    or else
				 ".*?"          # a section between double quotes (stingy match)
					|           #    or else
				 '.*?'          # a section between single quotes (stingy match)
			) +                 # repetire ad libitum
								#  hm.... are null tags <> legal? XXX
		   >                    # closing angle bracket
		}{}gsx;                 # mutate into nada, nothing, and niente

		#########################################################
		# finally we'll translate all &valid; HTML 2.0 entities
		#########################################################

		s{ (
				&              # an entity starts with an ampersand
				( 
				\x23\d+        # and is either a pound (#) and numbers
				 |	           #   or else
				\w+            # has alphanumunders up to a semi
			)         
				;?             # a semi terminates AS DOES ANYTHING ELSE (XXX)
			)
		} {

			$entity{$2}        # if it's a known entity use that
				||             #   but otherwise
				$1             # leave what we'd found; NO WARNINGS (XXX) - perhaps replace this with ? to get TMX-safe text? TEST

		}gex;                  # execute replacement -- that's code not a string

		#########################################################
		# but wait! load up the %entity mappings enwrapped in 
		# a BEGIN that the last might be first, and only execute
		# once, since we're in a -p "loop"; awk is kinda nice after all.
		#########################################################

		BEGIN {

			%entity = (

				lt     => '<',     #a less-than
				gt     => '>',     #a greater-than
				amp    => '&',     #an ampersand
				quot   => '"',     #a (verticle) double-quote

				nbsp   => chr 160, #no-break space
				iexcl  => chr 161, #inverted exclamation mark
				cent   => chr 162, #cent sign
				pound  => chr 163, #pound sterling sign CURRENCY NOT WEIGHT
				curren => chr 164, #general currency sign
				yen    => chr 165, #yen sign
				brvbar => chr 166, #broken (vertical) bar
				sect   => chr 167, #section sign
				uml    => chr 168, #umlaut (dieresis)
				copy   => chr 169, #copyright sign
				ordf   => chr 170, #ordinal indicator, feminine
				laquo  => chr 171, #angle quotation mark, left
				not    => chr 172, #not sign
				shy    => chr 173, #soft hyphen
				reg    => chr 174, #registered sign
				macr   => chr 175, #macron
				deg    => chr 176, #degree sign
				plusmn => chr 177, #plus-or-minus sign
				sup2   => chr 178, #superscript two
				sup3   => chr 179, #superscript three
				acute  => chr 180, #acute accent
				micro  => chr 181, #micro sign
				para   => chr 182, #pilcrow (paragraph sign)
				middot => chr 183, #middle dot
				cedil  => chr 184, #cedilla
				sup1   => chr 185, #superscript one
				ordm   => chr 186, #ordinal indicator, masculine
				raquo  => chr 187, #angle quotation mark, right
				frac14 => chr 188, #fraction one-quarter
				frac12 => chr 189, #fraction one-half
				frac34 => chr 190, #fraction three-quarters
				iquest => chr 191, #inverted question mark
				Agrave => chr 192, #capital A, grave accent
				Aacute => chr 193, #capital A, acute accent
				Acirc  => chr 194, #capital A, circumflex accent
				Atilde => chr 195, #capital A, tilde
				Auml   => chr 196, #capital A, dieresis or umlaut mark
				Aring  => chr 197, #capital A, ring
				AElig  => chr 198, #capital AE diphthong (ligature)
				Ccedil => chr 199, #capital C, cedilla
				Egrave => chr 200, #capital E, grave accent
				Eacute => chr 201, #capital E, acute accent
				Ecirc  => chr 202, #capital E, circumflex accent
				Euml   => chr 203, #capital E, dieresis or umlaut mark
				Igrave => chr 204, #capital I, grave accent
				Iacute => chr 205, #capital I, acute accent
				Icirc  => chr 206, #capital I, circumflex accent
				Iuml   => chr 207, #capital I, dieresis or umlaut mark
				ETH    => chr 208, #capital Eth, Icelandic
				Ntilde => chr 209, #capital N, tilde
				Ograve => chr 210, #capital O, grave accent
				Oacute => chr 211, #capital O, acute accent
				Ocirc  => chr 212, #capital O, circumflex accent
				Otilde => chr 213, #capital O, tilde
				Ouml   => chr 214, #capital O, dieresis or umlaut mark
				times  => chr 215, #multiply sign
				Oslash => chr 216, #capital O, slash
				Ugrave => chr 217, #capital U, grave accent
				Uacute => chr 218, #capital U, acute accent
				Ucirc  => chr 219, #capital U, circumflex accent
				Uuml   => chr 220, #capital U, dieresis or umlaut mark
				Yacute => chr 221, #capital Y, acute accent
				THORN  => chr 222, #capital THORN, Icelandic
				szlig  => chr 223, #small sharp s, German (sz ligature)
				agrave => chr 224, #small a, grave accent
				aacute => chr 225, #small a, acute accent
				acirc  => chr 226, #small a, circumflex accent
				atilde => chr 227, #small a, tilde
				auml   => chr 228, #small a, dieresis or umlaut mark
				aring  => chr 229, #small a, ring
				aelig  => chr 230, #small ae diphthong (ligature)
				ccedil => chr 231, #small c, cedilla
				egrave => chr 232, #small e, grave accent
				eacute => chr 233, #small e, acute accent
				ecirc  => chr 234, #small e, circumflex accent
				euml   => chr 235, #small e, dieresis or umlaut mark
				igrave => chr 236, #small i, grave accent
				iacute => chr 237, #small i, acute accent
				icirc  => chr 238, #small i, circumflex accent
				iuml   => chr 239, #small i, dieresis or umlaut mark
				eth    => chr 240, #small eth, Icelandic
				ntilde => chr 241, #small n, tilde
				ograve => chr 242, #small o, grave accent
				oacute => chr 243, #small o, acute accent
				ocirc  => chr 244, #small o, circumflex accent
				otilde => chr 245, #small o, tilde
				ouml   => chr 246, #small o, dieresis or umlaut mark
				divide => chr 247, #divide sign
				oslash => chr 248, #small o, slash
				ugrave => chr 249, #small u, grave accent
				uacute => chr 250, #small u, acute accent
				ucirc  => chr 251, #small u, circumflex accent
				uuml   => chr 252, #small u, dieresis or umlaut mark
				yacute => chr 253, #small y, acute accent
				thorn  => chr 254, #small thorn, Icelandic
				yuml   => chr 255, #small y, dieresis or umlaut mark
			);

			####################################################
			# now fill in all the numbers to match themselves
			####################################################
			for $chr ( 0 .. 255 ) { 
				$entity{ '#' . $chr } = chr $chr;
			}
		} # end of begin block
		print OUT $_;
	}
	close IN;
	close OUT;

	unlink "${pf}_htmlmod.${ext}";

	##########################################################################################################


	# CLEANUP

	# open files 
	open (IN, "<:encoding(UTF-8)", "${pf}.txt");
	open (OUT, ">:encoding(UTF-8)", "${pf}_htmlmod.txt");


	while (<IN>) {
	s/^\s*\n//g;			# remove lines w/ whitespace only
	s/   */ /g;			# remove multiple spaces
	s/^ +//g;			# strip leading spaces
	s/ +$//g;			# strip trailing spaces

	print OUT $_;
	}

	close IN;
	close OUT;

	#unlink "${pf}.txt";

	rename ("${pf}_htmlmod.txt", "${pf}.txt") or abort("Can't rename file: $! at line " . __LINE__);

}
# end of sub convert_html_compatibility



sub getlocaltime {	# this uses the local time, as opposed to the TMX timestamp, which uses GMT (?)
	
	# LOCAL TIME for log
	my ($lsec,$lmin,$lhr,$lmday,$lmon,$lyear,,,) = localtime(time);
	$lyear += 1900;$current_year = $lyear; #for com year validation
	$lmon++;
	my $lmonth = sprintf("%02d", $lmon);
	my $lday = sprintf("%02d", $lmday);
	my $lhour = sprintf("%02d", $lhr);
	my $lminute = sprintf("%02d", $lmin);
	my $lsecond = sprintf("%02d", $lsec);
	$localtime = "$lyear.$lmonth.${lday}_$lhour.$lminute.${lsecond}";
	
	
	# GMT TIME for TMX timestamp (creationdate)
		my ($sec, $min, $hr, $mday, $mon, $year);
	($sec,$min,$hr,$mday,$mon,$year,,,) = gmtime(time);
	$year += 1900;
	$mon++;
	my $month = sprintf("%02d", $mon);
	my $day = sprintf("%02d", $mday);
	my $hour = sprintf("%02d", $hr);
	my $minute = sprintf("%02d", $min);
	my $second = sprintf("%02d", $sec);
	$date = "$year$month${day}T$hour$minute${second}Z";
	if ($date =~ /^[0-2][0-9]{3}[0-1][0-9][0-3][0-9]T[0-2][0-9][0-5][0-9][0-5][0-9]Z$/) {
		#print "\n\nCurrent GMT date and time (yyyymmddThhmmssZ): $date\n"
	} else {
		print "\nAutomatic date/time identification unsuccessful, falling back to fixed date.\n";
		$date = "20100101T120000Z";
		print "\nDate and time (yyyymmddThhmmssZ): $date\n";
	}

	
	
	
}


sub load_setup {
	# REGENERATE SETUP FILE IF NOT FOUND
	unless (-e "$scriptpath/LF_aligner_setup.txt") {
		print "\nSETUP FILE NOT FOUND, creating $scriptpath/LF_aligner_setup.txt with default settings.\n";
		# print LOG "Setup file not found, creating $scriptpath/LF_aligner_setup.txt with default settings\n"; # log file is only created at a later point
		open (SETUP, ">:encoding(UTF-8)", "$scriptpath/LF_aligner_setup.txt") or print "Can't create setup file: $!";
		print SETUP "\x{FeFF}Here, you can specify settings for LF aligner. Put your choice (usually y or n) between the square brackets, and don't change anything else in this file. If you want to restore the default settings or you think you may have corrupted the file, just delete it. It will be recreated with default settings the next time the aligner runs.\n\n\n*** INPUT ***\n\nFiletype default (t/c/com/epr/w/h/p): [t]\nPrompt user for filetype: [y]\n\nLanguage 1 default: [en]\nPrompt user for language 1: [y]\nLanguage 2 default: [hu]\nPrompt user for language 2: [y]\n\n\n*** OUTPUT ***\n\nSegment to sentences: [y]\nAsk for confirmation after segmenting (y/n/auto) - n and auto allow the aligner to run unattended (see readme): [y]\n\nMerge numbers and chapter/point headings with the next segment: [y]\n\nCleanup default: [y]\nPrompt user whether to do cleanup: [n]\n\nRemove match confidence value: [y]\n\nDelete duplicate entries: [n]\n\nDelete entries where the text is the same in both languages (filters out untranslated text and segments than only contain numbers etc.): [n]\n\nReview default (n/t/x): [x]\nPrompt user whether/how to review pairings: [y]\n\nOffer to write to txt (allows you to add all aligned files to the same master TM): [n]\nMaster TM path: []\n\n\n*** TMX ***\n\nMake TMX by default: [y]\nPrompt user whether to make TMX: [y]\n\nLanguage code 1 default: []\nPrompt user for language code 1: [y]\nLanguage code 2 default: []\nPrompt user for language code 2: [y]\n\nPrompt user for creation date and time: [y]\n\nCreator ID default: []\nPrompt user for creator ID: [y]\n\nPrompt user for TMX note: [y]\n\nSkip half-empty segments: [y]\n\n\n*** MISC ***\n\nChop up files larger than this size (0 deactivates the feature): [15000]\n\nPdf conversion mode; formatted or not (-layout option in pdftotext): [y]\n\nForce GUI on (y) or off (n) []\n\nGUI language: [en]\n\n\nCharacter conversion: provide character pairs separated by a tab, one pair per line. The aligner will replace the first character with the second in your aligned file. The replacement is case-sensitive and can be used to decode character entities or fix corrupted characters.\n\nCharacter conversion table for language 1:\n\n\nCharacter conversion table for language 2:\n\n";

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
			$lang_1_iso_def = $1;
		}
		if (/Language 2 default:/) {
			/\[(.*)\]/;
			$lang_2_iso_def = $1;
		}
		if (/Prompt user for language 1:/) {
			/\[(.*)\]/;
			$l1_prompt = $1;
		}
		if (/Prompt user for language 2:/) {
			/\[(.*)\]/;
			$l2_prompt = $1;
		}

		if (/Segment to sentences:/) {
			/\[(.*)\]/;
			$segmenttext = $1;
		}

		if (/Ask for confirmation after segmenting/) {
			/\[(.*)\]/;
			$confirm_segmenting = $1;
		}

		# if (/Prompt user whether to segment:/) {
			# /\[(.*)\]/;
			# $segmenttext_prompt = $1;
		# }

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

		if (/Pdf conversion mode/) {
			/\[(.*)\]/;
			$pdfmode = $1;
		}

		if (/Force GUI/) {
			/\[(.*)\]/;
			$gui = lc($1);
		}

		if (/GUI language/) {
			/\[(.*)\]/;
			$guilang = lc($1);
		}

	}
	close SETUP;

	# default values in case the setup file is bad
	$filetype_def or $filetype_def = "t";
	$filetype_prompt or $filetype_prompt = "y";
	$lang_1_iso_def or $lang_1_iso_def = "hu";
	$lang_2_iso_def or $lang_2_iso_def = "en";
	$l1_prompt or $l1_prompt = "y";
	$l2_prompt or $l2_prompt = "y";
	$segmenttext or $segmenttext = "y";
	$confirm_segmenting or $confirm_segmenting = "y";
	# $segmenttext_prompt or $segmenttext_prompt = "y";
	$cleanup_def or $cleanup_def = "y";
	$cleanup_prompt or $cleanup_prompt = "y";
	$review_def or $review_def = "x";
	$review_prompt or $review_prompt = "y";
	$create_tmx_def or $create_tmx_def = "y";
	$create_tmx_prompt or $create_tmx_prompt = "y";
	# $tmx_langcode_1_def or $tmx_langcode_1_def = "EN-GB";
	# $tmx_langcode_2_def or $tmx_langcode_2_def = "HU";
	$tmx_langcode_1_prompt or $tmx_langcode_1_prompt = "y";
	$tmx_langcode_2_prompt or $tmx_langcode_2_prompt = "y";
	$creationdate_prompt or $creationdate_prompt = "y";
	$creationid_def or $creationid_def = "$tool $version";
	$creationid_prompt or $creationid_prompt = "y";
	$ask_master_TM or $ask_master_TM = "n";
	$chopmode or $chopmode = 15000;
	# $tmxnote_def or $tmxnote_def = "";
	$tmxnote_prompt or $tmxnote_prompt = "y";
	$skiphalfempty or $skiphalfempty = "y";
	$pdfmode or $pdfmode = "y";


	if ($OS eq "Windows") {$gui or $gui = "y"} else {$gui or $gui = "n"}; # defaults for each OS type
	if ($gui ne "y") {$gui = ""}; # so that I can use the simple if ($gui) {}test

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




sub tmx_extract {# adapted from tmx->tab delimited converter, produces utf-8 txt with only L1 segments

	my $sourcefile_full = $_[0];

	$sourcefile_full =~ /(.*)\.(.*)/;
	my ${sourcefile_noext} = $1;


	# determine if encoding is UTF-16LE or UTF-8
	my $encoding = ":encoding(UTF-8)"; # default
	my $encodingfound;

	{ local $/ = \2; # process in chunks of 2 bytes
		open (IN, "<", $sourcefile_full) or abort("Can't open file: $! at line " . __LINE__);
		while (<IN>) {
			if (/\x{FF}\x{FE}/) {$encoding = ":raw:perlio:encoding(UTF-16LE):crlf"; $encodingfound = "y";last};
			if (/\x{FE}\x{FF}/) {$encoding = ":raw:perlio:encoding(UTF-16BE):crlf"; $encodingfound = "y";last};
			if (/\x{EF}\x{BB}/) {$encoding = ":encoding(UTF-8)"; $encodingfound = "y";last};
			# print "\nNo BOM found.\n";
			last;
		}
	}
	close IN;

	# pick out UTF-8 encoding
	unless ($encodingfound) {

		open (IN, "<:encoding(UTF-8)", "$sourcefile_full") or abort("Can't open file: $! at line " . __LINE__);
		while (<IN>) {
			if (/utf.*8/i) {$encoding = ":encoding(UTF-8)"; $encodingfound = "y";last}
			last; # only read the first line
		}
	}
	close IN;

	# pick out UTF-16 encoding
	unless ($encodingfound) {
		open (IN, "<:raw:perlio:encoding(UTF-16LE):crlf", "$sourcefile_full") or abort("Can't open file: $! at line " . __LINE__); # opens as UTF-16 to be able to read first line
		while (<IN>) {
			if (/utf.*16/i) {$encoding = ":raw:perlio:encoding(UTF-16LE):crlf"; $encodingfound = "y";last}

			if (/creationtool.*TRADOS.*Workbench/i) {$encoding = ":raw:perlio:encoding(UTF-16LE):crlf";$encodingfound = "y";last}
			last if /<\/header>/; # only read up to the end of the header
		}
	}
	close IN;


	unless ($encodingfound) {print "\nEncoding of the tmx snot detected, sticking to the default (UTF-8)\n";}


	if (-e "${sourcefile_noext}.txt") {
		print "\nPlease move or rename ${sourcefile_noext}.txt, or it will be overwritten.\nPress enter when done.";
		<STDIN>;
	}

	open (IN, "<$encoding", "$sourcefile_full") or abort("Can't open file: $! at line " . __LINE__); # open the TMX in whatever encoding was detected
	open (TAB, ">:encoding(UTF-8)", "${sourcefile_noext}.txt") or abort("Can't open file: $! at line " . __LINE__); # output in UTF-8

	while (<IN>) {	# newlines before/after <body> tags so I can go line by line
		s/<body>/<body>\n/;
		s/<\/body>/\n<\/body>/;
		print TAB $_
	}
	close TAB;


	if (-e "${sourcefile_noext}_mod.txt") {
		print "\nPlease move or rename ${sourcefile_noext}_mod.txt, or it will be overwritten.\nPress enter when done.";
		<STDIN>;
	}


	open (TAB, "<:encoding(UTF-8)", "${sourcefile_noext}.txt") or abort("Can't open file: $! at line " . __LINE__);
	open (TAB_MOD, ">:encoding(UTF-8)", "${sourcefile_noext}_mod.txt") or abort("Can't open file: $! at line " . __LINE__);

	my $flag = "";
	while (<TAB>) {
		if ($flag) {				# start after the <body> tag
			s/<\/tu>/<\/tu>\n/g;	# line break after every TU
			last if /<\/body>/;		# end at </body> tag
			print TAB_MOD $_;
		}
		$flag = "on" if /<body>/;
	}
	close TAB or abort("Can't close file: $! at line " . __LINE__);			# can't move these to a sub due to nested sub problem
	close TAB_MOD or abort("Can't close file: $! at line " . __LINE__);
	rename ("${sourcefile_noext}_mod.txt", "${sourcefile_noext}.txt") or abort("Can't rename file: $! at line " . __LINE__);
	open (TAB, "<:encoding(UTF-8)", "${sourcefile_noext}.txt") or abort("Can't open file: $! at line " . __LINE__);
	open (TAB_MOD, ">:encoding(UTF-8)", "${sourcefile_noext}_mod.txt") or abort("Can't open file: $! at line " . __LINE__);

	while (<TAB>) {
		s/\n// unless /<\/tu>/; # remove all line breaks except after each tu
		print TAB_MOD $_;
	}
	close TAB or abort("Can't close file: $! at line " . __LINE__);
	close TAB_MOD or abort("Can't close file: $! at line " . __LINE__);
	rename ("${sourcefile_noext}_mod.txt", "${sourcefile_noext}.txt") or abort("Can't rename file: $! at line " . __LINE__);
	open (TAB, "<:encoding(UTF-8)", "${sourcefile_noext}.txt") or abort("Can't open file: $! at line " . __LINE__);
	open (TAB_MOD, ">:encoding(UTF-8)", "${sourcefile_noext}_mod.txt") or abort("Can't open file: $! at line " . __LINE__);



	# create tab delimited
	while (<TAB>) {
		chomp;

		s/<bpt[> ].*?<\/bpt>//g;	# for <bpt>foo</bpt>
		s/<bpt[^>]*\/>//g;			# for <bpt i="1" type="775" x="1" />
		s/<ept[> ].*?<\/ept>//g;
		s/<ept[^>]*\/>//g;
		s/<it[> ].*?<\/it>//g;
		s/<it[^>]*\/>//g;
		s/<ph[> ].*?<\/ph>//g;
		s/<ph[^>]*\/>//g;
		s/<hi[> ].*?<\/hi>//g;
		s/<hi[^>]*\/>//g;
		s/<ut[> ].*?<\/ut>//g;
		s/<ut[^>]*\/>//g;
		s/<sub[> ].*?<\/sub>//g;
		s/<sub[^>]*\/>//g;

		s/\t/ /g; # extra tab characters would be troublesome in a tab delimited file
		# /<seg>(.*?)<\/seg>.*?<seg>(.*?)<\/seg>/; # capture the bits between the <seg> tags
		/<seg>(.*?)<\/seg>.*?<seg>.*?<\/seg>/; # capture the bits between the <seg> tags
		# print TAB_MOD "$1\t$2\n";
		print TAB_MOD "$1\n";
	}
	close TAB or abort("Can't close file: $! at line " . __LINE__);
	close TAB_MOD or abort("Can't close file: $! at line " . __LINE__);
	rename ("${sourcefile_noext}_mod.txt", "${sourcefile_noext}.txt") or abort("Can't rename file: $! at line " . __LINE__);
	open (TAB, "<:encoding(UTF-8)", "${sourcefile_noext}.txt") or abort("Can't open file: $! at line " . __LINE__);
	open (TAB_MOD, ">:encoding(UTF-8)", "${sourcefile_noext}_mod.txt") or abort("Can't open file: $! at line " . __LINE__);


	# only 5 character entities allowed in TMX, substitute them
	while (<TAB>) {
		s/&amp;/&/g;
		s/&#38;/&/g;
		s/&lt;/</g;
		s/&#60;/</g;
		s/&gt;/>/g;
		s/&#62;/</g;
		s/&apos;/'/g;
		s/&#39;/</g;
		s/&quot;/"/g;
		s/&#34;/</g;

		print TAB_MOD $_
	}
	close TAB or abort("Can't close file: $! at line " . __LINE__);
	close TAB_MOD or abort("Can't close file: $! at line " . __LINE__);
	rename ("${sourcefile_noext}_mod.txt", "${sourcefile_noext}.txt") or abort("Can't rename file: $! at line " . __LINE__);
	open (TAB, "<:encoding(UTF-8)", "${sourcefile_noext}.txt") or abort("Can't open file: $! at line " . __LINE__);
	open (TAB_MOD, ">:encoding(UTF-8)", "${sourcefile_noext}_mod.txt") or abort("Can't open file: $! at line " . __LINE__);


	close TAB;
	close TAB_MOD;

	unlink "${sourcefile_noext}_mod.txt";
	# print "\nDone, ${sourcefile_noext}_mod.txt created.\nPress enter to quit.\n";

}


sub convert_xls($) { 

	# print "file: >$_[0]<"; # comment out
	open (TXTFROMXLS, ">:encoding(UTF-8)", $_[1]) or print "\nCan't create output file: $!";	# overwrites the previous autoaligned file 

	my $xls = Spreadsheet::ParseExcel::Simple->read ($_[0]);

	foreach my $sheet ($xls->sheets) {		# iterates through all available worksheets in the file named $xls (unless last; is used)
		while ($sheet->has_data) {
			my @data = $sheet->next_row;
			print TXTFROMXLS join ("\t", @data) . "\n";
		}
		last;			# we only need the first worksheet
	}
	close TXTFROMXLS;
}