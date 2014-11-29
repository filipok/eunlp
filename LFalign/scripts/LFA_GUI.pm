package LFA_GUIStdin;
our @ISA = qw[ Thread::Queue ];

sub TIEHANDLE { bless $_[1], $_[0]; }
sub READLINE { $_[0]->dequeue(); }

package LFA_GUIStdout;
our @ISA = qw[ Thread::Queue ];

sub TIEHANDLE { bless $_[1], $_[0]; }
sub PRINT  { $_[0]->enqueue( join ' ', @_[ 1 .. $#_ ] ); }
sub PRINTF { $_[0]->enqueue( sprintf $_[1], @_[ 2 .. $#_ ] ); }

package LFA_GUI;
use strict;
use warnings;
use threads;
use Thread::Queue;

my $Qin  = new Thread::Queue;
my $Qout = new Thread::Queue;

tie *STDIN,  'LFA_GUIStdin',  $Qin;
tie *STDOUT, 'LFA_GUIStdout', $Qout;



#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x

#TODO:

# GUIstrings fájlban : helyett =

# Processing... message at least during segmentation and alignment

# colours

# dropdown list for all celex documents

# errormsg when doing 3-lang pdf:

 # Default button `Close' does not exist.
 # error:Tk::Frame=HASH(0x363cc04) is not a widget at LFA_GUI.pm line 602 thread 1
 # Tk::Error: Tk::Frame=HASH(0x363cc04) is not a widget at LFA_GUI.pm line 602 thread
 # 1
 # Tk::After::repeat at C:/Perl/site/lib/Tk/After.pm line 80
 # [repeat,[{},after#591,50,repeat,[\&LFA_GUI::__ANON__]]]
 # ("after" script)


# disable next button until a value is entered in all fields

# split-sentences.exe konzol nélküli verzió (pp --gui -o foo.exe bar.pl -x)
# segmenter msg

# file browse ablak cím

# , -font => [-slant => 'italic'] # this makes the font larger as well as italic; size weight (bold) slant (roman, italic) underline overstrike
# -font => "courier 12 bold italic" or -font => [-slant => "italic"]

# TMX langcode list supported by trados: http://msdn.microsoft.com/en-us/goglobal/bb896001.aspx

#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x#x




##################
# "GLOBAL" VARS: #
##################

my $tool;
my $version;
my $guilang;
my $no = 2;					# number of languages (usually 2, so 2 is the default)
my @inputfile;			# array that holds the filepath of all input files of lf aligner
my @langs_iso;			# the two-letter ISO code of languages picked by the user; $tmx_langcode[x] is the language code used in the TMX
my $lang_1_iso_def;
my $lang_2_iso_def;
my @url;
my @langs_fullnames;	# the full names of languages picked by the user
my @line_no;			# line number of input files before/after segmentation
my @line_no_seg;			# line number of input files before/after segmentation
my @tmx_langcodes;
my $tmx_langcode_1_def;
my $tmx_langcode_2_def;
my %tmx_settings;



#######################
# LOAD LANGUAGE CODES #
#######################

# Global vars
my @langlist;		# Full list of all supported language names
my %langcodelookup;	# These can't be placed in the BEGIN block for some reason
my %langcodelookup_reverse;	# These can't be placed in the BEGIN block for some reason

my %GUIstrings;

$GUIstrings{yes} ||= "Yes";
$GUIstrings{no} ||= "No";


BEGIN {
	# these will be the picklist entries in the language selection drop-down box
	@langlist = ("English","German","French","Spanish","Italian", #major languages first (repeated later in alphabetic list)
	"Abkhaz","Afar","Afrikaans","Akan","Albanian","Amharic","Arabic","Aragonese","Armenian","Assamese","Avaric","Avestan","Aymara","Azerbaijani","Bambara","Bashkir","Basque","Belarusian","Bengali","Bihari","Bislama","Bosnian","Breton","Bulgarian","Burmese","Catalan; Valencian","Chamorro","Chechen","Chichewa; Chewa; Nyanja","Chinese","Chuvash","Cornish","Corsican","Cree","Croatian","Czech","Danish","Divehi; Maldivian","Dutch","Dzongkha","English","Esperanto","Estonian","Ewe","Faroese","Fijian","Finnish","French","Fulah; Pular","Galician","Georgian","German","Greek","Guarani","Gujarati","Haitian; Haitian Creole","Hausa","Hebrew","Herero","Hindi","Hiri Motu","Hungarian","Interlingua","Indonesian","Interlingue","Irish","Igbo","Inupiaq","Ido","Icelandic","Italian","Inuktitut","Japanese","Javanese","Kalaallisut; Greenlandic","Kannada","Kanuri","Kashmiri","Kazakh","Khmer","Kikuyu","Kinyarwanda","Kirundi","Kyrgyz","Komi","Kongo","Korean","Kurdish","Kwanyama","Latin","Luxembourgish","Luganda","Limburgish","Lingala","Lao","Lithuanian","Luba-Katanga","Latvian","Manx","Macedonian","Malagasy","Malay","Malayalam","Maltese","Maori","Marathi","Marshallese","Mongolian","Nauru","Navajo","Norwegian Bokmal","North Ndebele","Nepali","Ndonga","Norwegian Nynorsk","Norwegian","Nuosu","South Ndebele","Occitan","Ojibwe","Old Church Slavonic; Old Bulgarian","Oromo","Oriya","Ossetian","Punjabi","Pali","Pashto","Persian","Polish","Portuguese","Quechua","Romansh","Romanian; Moldavian; Moldovan","Russian","Sanskrit","Sardinian","Sindhi","Northern Sami","Samoan","Sango","Serbian","Scottish Gaelic","Shona","Sinhalese","Slovak","Slovene","Somali","Southern Sotho","Spanish","Sundanese","Swahili","Swati","Swedish","Tamil","Telugu","Tajik","Thai","Tigrinya","Tibetan","Turkmen","Tagalog","Tswana","Tonga","Turkish","Tsonga","Tatar","Twi","Tahitian","Uyghur","Ukrainian","Urdu","Uzbek","Venda","Vietnamese","Volapuk","Walloon","Welsh","Wolof","Western Frisian","Xhosa","Yiddish","Yoruba","Zhuang","Zulu",);

	
	# this hash is for converting the language names to two-letter ISO codes; $langcodelookup{English} prints 'en' etc.
	%langcodelookup = ("Abkhaz" => "ab","Afar" => "aa","Afrikaans" => "af","Akan" => "ak","Albanian" => "sq","Amharic" => "am","Arabic" => "ar","Aragonese" => "an","Armenian" => "hy","Assamese" => "as","Avaric" => "av","Avestan" => "ae","Aymara" => "ay","Azerbaijani" => "az","Bambara" => "bm","Bashkir" => "ba","Basque" => "eu","Belarusian" => "be","Bengali" => "bn","Bihari" => "bh","Bislama" => "bi","Bosnian" => "bs","Breton" => "br","Bulgarian" => "bg","Burmese" => "my","Catalan; Valencian" => "ca","Chamorro" => "ch","Chechen" => "ce","Chichewa; Chewa; Nyanja" => "ny","Chinese" => "zh","Chuvash" => "cv","Cornish" => "kw","Corsican" => "co","Cree" => "cr","Croatian" => "hr","Czech" => "cs","Danish" => "da","Divehi; Maldivian" => "dv","Dutch" => "nl","Dzongkha" => "dz","English" => "en","Esperanto" => "eo","Estonian" => "et","Ewe" => "ee","Faroese" => "fo","Fijian" => "fj","Finnish" => "fi","French" => "fr","Fulah; Pular" => "ff","Galician" => "gl","Georgian" => "ka","German" => "de","Greek" => "el","Guaraní" => "gn","Gujarati" => "gu","Haitian; Haitian Creole" => "ht","Hausa" => "ha","Hebrew" => "he","Herero" => "hz","Hindi" => "hi","Hiri Motu" => "ho","Hungarian" => "hu","Interlingua" => "ia","Indonesian" => "id","Interlingue" => "ie","Irish" => "ga","Igbo" => "ig","Inupiaq" => "ik","Ido" => "io","Icelandic" => "is","Italian" => "it","Inuktitut" => "iu","Japanese" => "ja","Javanese" => "jv","Kalaallisut; Greenlandic" => "kl","Kannada" => "kn","Kanuri" => "kr","Kashmiri" => "ks","Kazakh" => "kk","Khmer" => "km","Kikuyu" => "ki","Kinyarwanda" => "rw","Kyrgyz" => "ky","Komi" => "kv","Kongo" => "kg","Korean" => "ko","Kurdish" => "ku","Kwanyama" => "kj","Latin" => "la","Luxembourgish" => "lb","Luganda" => "lg","Limburgish" => "li","Lingala" => "ln","Lao" => "lo","Lithuanian" => "lt","Luba-Katanga" => "lu","Latvian" => "lv","Manx" => "gv","Macedonian" => "mk","Malagasy" => "mg","Malay" => "ms","Malayalam" => "ml","Maltese" => "mt","Maori" => "mi","Marathi" => "mr","Marshallese" => "mh","Mongolian" => "mn","Nauru" => "na","Navajo" => "nv","Norwegian Bokmal" => "nb","North Ndebele" => "nd","Nepali" => "ne","Ndonga" => "ng","Norwegian Nynorsk" => "nn","Norwegian" => "no","Nuosu" => "ii","South Ndebele" => "nr","Occitan" => "oc","Ojibwe" => "oj","Old Church Slavonic; Old Bulgarian" => "cu","Oromo" => "om","Oriya" => "or","Ossetian" => "os","Punjabi" => "pa","Pali" => "pi","Persian" => "fa","Polish" => "pl","Pashto" => "ps","Portuguese" => "pt","Quechua" => "qu","Romansh" => "rm","Kirundi" => "rn","Romanian; Moldavian; Moldovan" => "ro","Russian" => "ru","Sanskrit" => "sa","Sardinian" => "sc","Sindhi" => "sd","Northern Sami" => "se","Samoan" => "sm","Sango" => "sg","Serbian" => "sr","Scottish Gaelic" => "gd","Shona" => "sn","Sinhalese" => "si","Slovak" => "sk","Slovene" => "sl","Somali" => "so","Southern Sotho" => "st","Spanish" => "es","Sundanese" => "su","Swahili" => "sw","Swati" => "ss","Swedish" => "sv","Tamil" => "ta","Telugu" => "te","Tajik" => "tg","Thai" => "th","Tigrinya" => "ti","Tibetan" => "bo","Turkmen" => "tk","Tagalog" => "tl","Tswana" => "tn","Tonga" => "to","Turkish" => "tr","Tsonga" => "ts","Tatar" => "tt","Twi" => "tw","Tahitian" => "ty","Uyghur" => "ug","Ukrainian" => "uk","Urdu" => "ur","Uzbek" => "uz","Venda" => "ve","Vietnamese" => "vi","Volapuk" => "vo","Walloon" => "wa","Welsh" => "cy","Wolof" => "wo","Western Frisian" => "fy","Xhosa" => "xh","Yiddish" => "yi","Yoruba" => "yo","Zhuang" => "za","Zulu" => "zu");

	%langcodelookup_reverse = reverse %langcodelookup; # for reverse lookup, i.e. to get full language name from the two-letter language code
	
}
#################################





##############
# CREATE GUI #
##############


sub gui {
	require Tk;
	require Tk::Dialog;
	# require Tk::DialogBox;	# fancier dialog, I haven't used it so far
	require Tk::BrowseEntry;
	require Tk::Pane;			# for scrolled frames, see ...-> Scrolled('Frame' ...

	use utf8; # in case űíőó are used on labels (eg translations)

	my $mw = Tk::MainWindow->new;
	# $mw->minsize(450, 200);		# minimum size of main window in pixels
	$mw->minsize(500, 320);		# minimum size of main window in pixels


# debug window, disable for release
	# my $window2 = $mw -> Toplevel();
	# my $lb = $window2->Listbox( -width => 80, -height => 10 )->pack; #toggle to switch console on/off


	
	# my $ef = $mw->Entry( -width => 75, -takefocus => 1 )->pack( -side => 'left' );
	# my $enter = sub {$Qin->enqueue( $ef->get );$ef->delete(0, 'end' );1;};
	# my $do = $mw->Button( -text => 'go', -command => $enter)->pack( -after => $ef );
	# $ef->focus( -force );
	# $mw->bind( '<Return>', $enter );




	my $doStdout = sub {
		if( $Qout->pending ) {
			my $output = $Qout->dequeue;
			# $lb->insert( 'end', $output ) ;
			# $lb->see( 'end' );		# reloads the listbox and shows the last entries in case they hang off the end
			




#####################################################################################################################
# each elsif ( $output =~ /foo/) {} block contains a UI screen that is triggered by a STDOUT string in the main .pl #
#####################################################################################################################


################################################
			if ( $output =~ /Defaults: /) {	# $output always contains what the .pl printed to STDOUT (see my $output = $Qout->dequeue;)
			
			# if the gui is on, the main .pl prints the defaults that can't otherwise be grabbed, and we store them  global vars
			chomp $output;		# can't hurt, right?
			# $output =~ /lang_1_iso_def: ([^;]*); lang_2_iso_def: ([^;]*); tmx_langcode_1_def: ([^;]*); tmx_langcode_2_def: ([^;]*); creationid_def: ([^;]*)/;
			
			($lang_1_iso_def) = $output =~ /lang_1_iso_def: ([^;]*)/i;
			$lang_1_iso_def = $langcodelookup_reverse{$lang_1_iso_def};	# get a full language name from the two-letter code that's in the setup file
			
			($lang_2_iso_def) = $output =~ /lang_2_iso_def: ([^;]*)/i;
			$lang_2_iso_def = $langcodelookup_reverse{$lang_2_iso_def};
			
			($tmx_langcode_1_def) = $output =~ /tmx_langcode_1_def: ([^;]*)/i;
			
			($tmx_langcode_2_def) = $output =~ /tmx_langcode_2_def: ([^;]*)/i;
			
			($tmx_settings{creationid}) = $output =~ /creationid_def: ([^;]*)/i;

			
			($tool) = $output =~ /tool: ([^;]*)/i;
			
			($version) = $output =~ /version: ([^;]*)/i;
			
			($guilang) = $output =~ /guilang: ([^;]*)/i;
			
			# do inkább a fáj elérési újtát küldje az aligner; open (GUIstrings, "<:encoding(UTF-8)", "$guistrings_file") or print "\nCan't open input file $guistrings_file: $!\n";
			
			$guilang or $guilang = "en";	#do from setup with fallback to en
			open (GUIstrings, "<:encoding(UTF-8)", "GUIstrings_$guilang.txt") or print "\nCan't open input file GUIstrings_$guilang.txt: $!\n";
			while (<GUIstrings>) {
				s/^\x{FeFF}// if $. == 1;		# remove BOM if present
				chomp;
				next unless /^([^= ]+)=\s*(.*)$/;	# skip comment lines
				my $id = $1;
				my $string = $2;
				$string =~ s/\\n/\n/g;		# convert literal "\n" in the string to real line breaks
				# print "inserting $2 with id $id\n";
				$GUIstrings{$id} = $string;
				# print "\nID: $id; value: $GUIstrings{$id}\n";
}

			
			
			
			

#########################################################################
# GUI ELEMENTS OF LF ALIGNER (SOME OF THEM ARE SHARED BY THE TMX MAKER) #
#########################################################################

			} elsif ( $output =~ /FATAL ERROR!/ ) { # FATAL ERROR (printed by abort sub in main script), inform user of error before quitting
				$output =~ s/FATAL ERROR!//;
				$output =~ s/^\s+//;		# strip leading whitespace
				
				$GUIstrings{bigerror} ||= "ERROR";
				$GUIstrings{bigerror_text} ||= "The aligner has run into an error and needs to close.\nReason: ";
				$GUIstrings{close} ||= "Close";
				$GUIstrings{view_log} ||= "View log";
				
				my $quit = $mw->Dialog(-title => $GUIstrings{bigerror}, 
				   -text => "$GUIstrings{bigerror_text}\n$output\n", 
				   -default_button => $GUIstrings{close}, -buttons => [$GUIstrings{view_log}, $GUIstrings{close}])->Show( );
				if ($quit eq $GUIstrings{close}) {
					$Qin->enqueue("");
				} elsif ($quit eq $GUIstrings{view_log}) {
									$Qin->enqueue("log");
			}



################################################
			} elsif ( $output =~ /try again!/i ){ # in case of wrong user input that can be fixed
			# } elsif ( $output =~ /(?:try again)|(?:SETUP FILE NOT FOUND)/i ){ #do doesn't work cuz setup is launched before the gui
				
				$GUIstrings{ok} ||= "OK";
				$GUIstrings{error} ||= "Error";
				
				$mw->Dialog(	-title => $GUIstrings{error}, 
								-text => "$output", 
								-default_button => $GUIstrings{ok},
								-buttons => [$GUIstrings{ok}]
							)->Show( );


################################################
			} elsif ( $output =~ /t\/p\/h\/w\/c\/com\/epr\? \(Default:/ ) {
				$output =~ /Default: (.*)\)/;
				my $filetype = $1;


		# -borderwidth => 4, -relief => 'groove'
				my $frm_filetype = $mw -> Frame() -> pack(-expand => 1, -fill => 'both',);		# , -padx => 5,

				$GUIstrings{next} ||= "Next";
				
				$GUIstrings{filetype_prompt} ||= "Please choose the type of your input files!";
				
				$GUIstrings{filetype_txt} ||= "txt (UTF-8!), rtf, doc or docx file (see the readme!)";
				$GUIstrings{filetype_pdf} ||= "pdf, or pdf exported to txt (exporting works better, see readme!)";
				$GUIstrings{filetype_html} ||= "HTML file saved to your computer";
				$GUIstrings{filetype_web} ||= "webpage (you provide two URLs, the script does the rest)";
				$GUIstrings{filetype_celex} ||= "EU legislation by CELEX number (will be downloaded automatically)";
				$GUIstrings{filetype_com} ||= "European Commission proposals (downloaded by year and number)";
				$GUIstrings{filetype_eprep} ||= "European Parliament reports (downloaded by year and number)";
				
				
				$frm_filetype -> Label(-text => $GUIstrings{filetype_prompt}, -font=>'bold')->pack (-pady => 10);
				# $frm_filetype -> Label(-text => "just some text", -font=>'bold')->pack (-pady => 10);

				my $rdb_e = $frm_filetype -> Radiobutton(-text=>$GUIstrings{filetype_txt}, -value=>"t",  -variable=>\$filetype) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_p = $frm_filetype -> Radiobutton(-text=>$GUIstrings{filetype_pdf}, -value=>"p",  -variable=>\$filetype) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_h = $frm_filetype -> Radiobutton(-text=>$GUIstrings{filetype_html}, -value=>"h",  -variable=>\$filetype) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_w = $frm_filetype -> Radiobutton(-text=>$GUIstrings{filetype_web}, -value=>"w",  -variable=>\$filetype) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_c = $frm_filetype -> Radiobutton(-text=>$GUIstrings{filetype_celex}, -value=>"c",  -variable=>\$filetype) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_com = $frm_filetype -> Radiobutton(-text=>$GUIstrings{filetype_com}, -value=>"com",  -variable=>\$filetype) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_epr = $frm_filetype -> Radiobutton(-text=>$GUIstrings{filetype_eprep}, -value=>"epr",  -variable=>\$filetype) -> pack(-anchor=> 'w', -padx => 10);


				my $buttnext = $frm_filetype -> Button(-text=>$GUIstrings{next}, -command =>sub {$Qin->enqueue( $filetype );$frm_filetype->destroy;}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );

				# my $butt_exit = $mw -> Button(-text=>"Abort", -command =>sub {$mw->destroy}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);




				# my $frm_beta = $frm_filetype -> Frame(
													# ) -> pack(-expand => 1, -fill => 'both');

				# my $betawarn = $frm_beta -> Label(-text => "Note: The graphical interface of LF Aligner is in beta. Some features may be missing or buggy.\nPlease send your comments, bug reports and feature requests to lfaligner\@gmail.com\nTo return to the command line interface, edit LF_aligner_setup.txt.\nCheck the sourceforge page regularly for updates.")->pack (-pady => 10);

# $frm_beta->configure(-bg=> 'Red');
# $betawarn->configure(-bg=> 'Red');




################################################
			}	elsif ( $output =~ /Provide a name for the output folder/ ) {
				my $folder;
				
				$GUIstrings{pickerwindow} ||= "Choose a folder";
				$GUIstrings{choose_folder} ||= "Please choose the folder where your files will be saved!\n";
				$GUIstrings{browse} ||= "Browse";
				$GUIstrings{newfolder} ||= "\nNote: To create a new folder, overwrite the folder name in the entry field.\nThe path and the folder name can only contain non-accented latin letters, numbers and a few symbols like _.";
				
				my $getfolder = sub {
					$folder = $mw->chooseDirectory(	-initialdir => '~',
												-title => $GUIstrings{pickerwindow},);
				};
				
				my $frm_folder = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				
				$frm_folder -> Label(-text => $GUIstrings{choose_folder}, -font=>'bold')->pack (-pady => 10);

				my $browse = $frm_folder -> Button( -text => $GUIstrings{browse}, -command => $getfolder)->pack();
				
				
				$frm_folder -> Label(-text => $GUIstrings{newfolder},)->pack();
				
				my $buttnext = $frm_folder -> Button(
														-text=>$GUIstrings{next},
														-command =>sub {
																			$folder or $folder = "\n";
																			# if the user tacks on the folder name instead of overwriting the name in the editing field, you get existingfolder/existingfolder/newfolder; we fix that
																			if ( ($folder =~ /^(.*([\/\\][^\/\\]+)\2)+([\/\\][^\/\\]+)$/) && (!-d "$1") ) {
																				$folder =~ s@([/\\][^/\\]+)\1+([/\\][^/\\]+)$@$1$2@;
																			}
																			$Qin->enqueue( $folder );
																			$frm_folder->destroy;
																		}
														) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );
				
				
				
				# my $ef = $frm_folder->Entry( -width => 50, -takefocus => 1 )->pack( -side => 'left' );

				# my $enter = sub {
					# $Qin->enqueue( $ef->get );
					# $ef->delete(0, 'end' );
					# $frm_folder->destroy;
					# 1;
				# };
				# $mw->bind( '<Return>', $enter );	# can force focus here because it's on the entry field; bind the sub to enter instead
				# $ef->focus( -force );				# so the user can type right away




##########################################
			}	elsif ( $output =~ /Number of languages\?/ ) { #do only ask for number in case of TMX
				
				$langs_fullnames[0] = $lang_1_iso_def;	# defaults loaded by the .pl from the setup file and passed via STDOUT
				$langs_fullnames[1] = $lang_2_iso_def;
				$langs_fullnames[2] = "Spanish";	# hard-coded defaults
				$langs_fullnames[3] = "Italian";


				my $frm_langs_all;		# moved the declaration of these two in front of the sub
				my @frm_langs;


				# REDRAW THE WINDOW (to show language name entry boxes according to the current value of $no)
				my $apply_changeno = sub {	# we're using this workaround in the nested subs to avoid the "will not stay shared" error
					for (my $i = 0; $i < $no; $i++) {
						my $ii = $i;
						$ii++; # $ii is always $i + 1

						$GUIstrings{english} ||= "English";

						$langs_fullnames[$i] or $langs_fullnames[$i] = $GUIstrings{english};	# English is the default
						$frm_langs[$i] = $frm_langs_all -> Frame() -> pack();		# a new frame for each browseentry box, no -expand => 1, -fill => 'both'
						# $frm_langs[$i] -> pack() if $tool =~ /align/i;
						
						# if $tool =~ /align/i
						
						$GUIstrings{langpicker_language} ||= "Language";
						
						my $langpicker = $frm_langs[$i] -> BrowseEntry(
							-label => "$GUIstrings{langpicker_language} $ii: ",
							-state => 'readonly',				# this way the user can't type freely into the box
							-choices => \@langlist,
							-variable => \$langs_fullnames[$i],
						)->pack(-side => 'left');
					}
				}; # don't delete the ; - it is needed here (end of apply_changeno sub)




				my $frm_getinfo = $mw -> Frame() -> pack(-expand => 1,-fill => 'both'); # 
				# my $frm_getinfo = $mw -> Scrolled('Frame', -scrollbars => 'osoe') -> pack(-expand => 1, -fill => 'both'); #scrolled in case of small screen or many languages
				
				$GUIstrings{specify_langs} ||= "Specify the languages of your texts:\n";
				$GUIstrings{langno_tmxmaker} ||= "Number of languages?\n";
				$GUIstrings{langno} ||= "Number of languages (usually, 2): ";
				
				my $headertext;
				if ($tool =~ /align/i) {$headertext = $GUIstrings{specify_langs};} else {$headertext = $GUIstrings{langno_tmxmaker};}
				$frm_getinfo-> Label(-text => $headertext, -font=>'bold')->pack (-pady => 10);

				my $frm_langs = $frm_getinfo -> Scrolled('Frame', -scrollbars => 'osoe') -> pack(-expand => 1, -fill => 'both');

				my $frm_langs_no = $frm_langs -> Frame() -> pack(-expand => 1, -fill => 'both');

				my $changeno = $frm_langs_no -> BrowseEntry(
					-label => $GUIstrings{langno},
					-variable => \$no,
					-width => 4,
					-browsecmd => sub {
						$frm_langs_all -> destroy; 							# remove old entry boxes
						$frm_langs_all = $frm_langs -> Frame();	# create the frame again
						$frm_langs_all -> pack(-expand => 1, -fill => 'both') if $tool =~ /align/i;		# do not display in TMX maker
						&$apply_changeno;
						}
				)->pack();# pack(-side => 'left');
				$changeno->insert('end', (2 .. 99));

				$frm_langs_all = $frm_langs -> Frame(); # frame so that we can destroy all the $frm_langs[$i] frames together
				$frm_langs_all -> pack(-expand => 1, -fill => 'both') if $tool =~ /align/i;		# do not display in TMX maker
				
				
				&$apply_changeno; # build entry boxes once when the window loads (rebuilt when $no is changed)
				
				
				$GUIstrings{langpicker_note} ||= "\nNote: you can change the default languages by editing LF_aligner_setup.txt";
				$frm_getinfo -> Label(-text => $GUIstrings{langpicker_note},)-> pack if $tool =~ /align/i;		# do not display in TMX maker
				
				
				my $buttnext = $frm_getinfo->Button(-text=>$GUIstrings{next}, -command => sub {
																		$frm_getinfo->destroy;
																		for (my $i = 0; $i < $no; $i++) {
																			$langs_iso[$i] = $langcodelookup{$langs_fullnames[$i]} 
																		}
																		$Qin->enqueue($no);
																		# $Qin->enqueue(join (",", $no, @langs_iso)); # send $no and the lang list together in one string separated by ',' - the aligner will parse it
																		})-> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);	#doesn't work, button not at bottom
				$buttnext -> focus (-force)
				
				# -side => 'bottom', 



#############################################
							} elsif ( $output =~ /Language (\d+)\?/ ) { # feed the language codes to the main script
				my $ii = $1;
				my $i = $ii - 1;
				$Qin->enqueue($langs_iso[$i]);	 # the language was picked previously, we just feed it to the .pl from the array here



#############################################
			} elsif ( $output =~ /CELEX number\?/ ) {

				my $frm_celex = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{enter_celex} ||= "Enter the CELEX number!\n";
				$frm_celex -> Label(-text => $GUIstrings{enter_celex}, -font => 'bold')->pack;
				
				my $frm_celex_entry = $frm_celex -> Frame() -> pack(-expand => 1, -fill => 'both');
				$GUIstrings{celexno} ||= "CELEX number: ";
				$frm_celex_entry -> Label(-text => $GUIstrings{celexno}, -justify => 'left')->pack(-side => 'left');
				my $celexentry = $frm_celex_entry->Entry( -width => 20, -takefocus => 1 )->pack(-side => 'left');
				$celexentry->focus( -force );
				
				$GUIstrings{celexnote} ||= "\nNote: For regulations, directives and framework directives, you can simply\nenter R, D or FD, the year and number (the year always comes first!).\nE.g. 62003C0371, D 1996 34 or FD 2001 220";
				$frm_celex -> Label(-text => $GUIstrings{celexnote},)->pack;
				
				
				my $next = sub {
							$Qin->enqueue($celexentry->get);
							$frm_celex->destroy;
				};
				
				
				$frm_celex->Button(-text => $GUIstrings{next}, -command => $next)-> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$mw->bind( '<Return>', $next );



#############################################
			} elsif ( $output =~ /Enter the year and number of the Commission proposal./ ) {
				my $year;
				my $number;
				
				my $frm_com = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{com_yr_no} ||= "Enter the year and number of the Commission document!\n";
				$frm_com -> Label(-text => $GUIstrings{com_yr_no}, -font => 'bold')->pack;
				
				$GUIstrings{com_yr} ||= "Year: ";
				$frm_com -> Label(-text => $GUIstrings{com_yr}, -justify => 'left')->pack (-side => 'left');
				
				my $comentry_yr = $frm_com->Entry( -width => 10, -textvariable => \$year, -takefocus => 1 )->pack (-side => 'left');
				$comentry_yr->focus( -force );
				$GUIstrings{com_no} ||= "Number: ";
				$frm_com -> Label(-text => $GUIstrings{com_no}, -justify => 'left')->pack (-side => 'left');
				my $comentry_nr = $frm_com->Entry( -width => 10, -textvariable => \$number, -takefocus => 1 )->pack (-side => 'left');


				# $frm_com -> Label(-text => "Note: ", -justify => 'left')->pack; # no note for COM
				
				
				my $next = sub {
							$Qin->enqueue($year . " " . $number);
							$frm_com->destroy;
				};
				
				
				$frm_com->Button(-text => $GUIstrings{next}, -command => $next)-> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$mw->bind( '<Return>', $next );
				




#############################################
			} elsif ( $output =~ /Enter the cycle, year and number of the EP report./ ) { #Enter the cycle, year and number of the EP report.
				my $cycle_year;
				my $number;
				
				my $frm_epr = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				my $frm_epr_entry = $frm_epr -> Frame(-borderwidth => 4,) -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{eprep_cycle_yr_no} ||= "Enter the cycle, year and number of the EP report.";
				$frm_epr_entry -> Label(-text => $GUIstrings{eprep_cycle_yr_no}, -font => 'bold', -justify => 'left')->pack;
				
				$GUIstrings{eprep_cycle_yr} ||= "Cycle and year (e.g. A7-2010): ";
				$frm_epr_entry -> Label(-text => $GUIstrings{eprep_cycle_yr}, -justify => 'left')->pack (-side => 'left');
				my $comentry_yr = $frm_epr_entry -> Entry( -width => 10, -textvariable => \$cycle_year, -takefocus => 1 )->pack (-side => 'left');
				$comentry_yr->focus( -force );

				$GUIstrings{eprep_cycle_no} ||= "Number: ";
				$frm_epr_entry -> Label(-text => $GUIstrings{eprep_cycle_no}, -justify => 'left')->pack (-side => 'left');
				my $comentry_nr = $frm_epr_entry -> Entry( -width => 10, -textvariable => \$number, -takefocus => 1 )->pack (-side => 'left');
				
				
				$GUIstrings{eprepnote} ||= "Note: The database only contains reports from 2003 on.";
				$frm_epr -> Label(-text => $GUIstrings{eprepnote},)->pack;
				
				
				my $next = sub {
							$Qin->enqueue($cycle_year . " " . $number);
							$frm_epr->destroy;
				};
				
				
				$frm_epr->Button(-text => $GUIstrings{next}, -command => $next)-> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$mw->bind( '<Return>', $next );
				


#############################################
			} elsif ( $output =~ /URL 1 \(..\)\?/ ) {
				my @frm_url;

				my $frm_web = $mw -> Scrolled('Frame', -scrollbars => 'osoe') -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{enter_url_title} ||= "Enter the URLs for webpage alignment";
				$frm_web -> Label(-text => $GUIstrings{enter_url_title}, -font => 'bold', -justify => 'left')->pack;

				for (my $i = 0; $i < $no; $i++) {
					my $ii = $i +1; $ii++; # $ii is always $i + 1
					$frm_url[$i] = $frm_web -> Frame() -> pack(-expand => 1, -fill => 'both');
					
					$GUIstrings{enter_url1} ||= "URL of";
					$GUIstrings{enter_url2} ||= "page: ";
					$frm_url[$i] -> Label(-text=> "$GUIstrings{enter_url1} $langs_fullnames[$i] $GUIstrings{enter_url2}", -width => 25, -anchor => 'w')->pack(-side => 'left');
					my $entry_url = $frm_url[$i] -> Entry( -width => 55, -textvariable => \$url[$i],)->pack( -side => 'left' );
				}
				

				
				my $buttnext = $frm_web -> Button(-text=>$GUIstrings{next}, -command =>sub {$Qin->enqueue( $url[0] );$frm_web->destroy;}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );



#############################################
				} elsif ( $output =~ /URL (\d+) \(..\)\?/ ){ # languages 2 - $no
				my $ii = $1;
				my $i = $ii - 1;
				$Qin->enqueue( $url[$i] );
				

#do progress screen for print "\nDownloading file: $file[$i]; url: $url[$i]\n\n";


#############################################
			} elsif ( $output =~ /Drag and drop file 1/ ) { # this only triggers once, on the first file - we get all file paths at once and enqueue them later
																	# /Drag and drop file (\d+) \((..)\)/
				
				my $frm_inputfile_global = $mw -> Frame () -> pack(-expand => 1, -fill => 'both');	# all the browse frames are inside this frame
				# my $frm_inputfile_global = $mw -> Scrolled('Frame', -scrollbars => 'osoe') -> pack(-expand => 1, -fill => 'both');
				my @frm_inputfile;
				$GUIstrings{pickfiles} ||= "Pick the input files!\n";
				$frm_inputfile_global -> Label(-text => $GUIstrings{pickfiles}, -font=>'bold')->pack (-pady => 10);
				
				my $frm_inputfile_filepickers = $frm_inputfile_global -> Scrolled('Frame', -scrollbars => 'osoe') -> pack(-expand => 1, -fill => 'both');	# all the browse frames are inside this frame
				

				my @labeltext;
				my @buttbrowse;
				$GUIstrings{please_choose1} ||= "Please choose the";
				$GUIstrings{please_choose2} ||= "file";
				$GUIstrings{filechosen1} ||= "";
				$GUIstrings{filechosen2} ||= "file: ";
				
				my $filepicker = sub {	# this sub is launched when the Browse button is pressed, see further down
					my $i = $_[0]; # $i is passed to the sub as an argument
					
					$inputfile[$i] = $mw ->getOpenFile(
								-title => "$GUIstrings{please_choose1} $langs_fullnames[$i] $GUIstrings{please_choose1}"
							);
					$labeltext[$i] = $inputfile[$i];		# autoupdated label
					$labeltext[$i] =~ s/^.*(.{40})$/...$1/ if $labeltext[$i] =~ /.{41}/;	# the full path may not fit
					$labeltext[$i] = "$GUIstrings{filechosen1} $langs_fullnames[$i] $GUIstrings{filechosen2}" . $labeltext[$i];
				}; # don't delete this ;
				

				
				for (my $i = 0; $i < $no; $i++) {
					my $ii = $i +1; $ii++; # $ii is always $i + 1
					$frm_inputfile[$i] = $frm_inputfile_filepickers -> Frame() -> pack();	# -expand => 1, -fill => 'both'

					
					$labeltext[$i] = "$GUIstrings{filechosen1} $langs_fullnames[$i] $GUIstrings{filechosen2}\t– ";		# this will be displayed by the autoupdated label
					$buttbrowse[$i] = $frm_inputfile[$i] -> Button(-text=>$GUIstrings{browse}, -command =>[\&$filepicker, $i]) -> pack(-side=> 'left');
					# this needs to be done in this roundabout way; command in sub outside of here, with $i passed as an argument (otherwise the other sub can't see $i), and the sub ref as a variable due to the nested subs problem
					$frm_inputfile[$i] -> Label(
													-textvariable => \$labeltext[$i],
													-width => 65,
													-anchor => 'w',
													# -justify => 'left', # this only seems to work with multiline text
												)->pack(-side => 'left'); 
				}
				#new the "same folder" limitation was removed as of ver 3.1
				# $frm_inputfile_global -> Label(-text => "
# Note: The files need to be in the same folder.", )->pack (-anchor => 'w');

				
				
				$GUIstrings{pleasepickfiles} ||= "Please pick a file in each language using the Browse button.";
				
				
				# enqueue the first file (we'll do the rest automatically)
				my $buttnext = $frm_inputfile_global -> Button(-text => $GUIstrings{next}, -command => sub {
					my $filledin = 0;
					for (my $i = 0; $i < $no; $i++) {
						$filledin++ if ($inputfile[$i]);
					}
					if ($filledin eq $no ) {	# if all fields filled in, we go on
						$Qin->enqueue($inputfile[0]);$frm_inputfile_global->destroy;
					} else {					# warn if the user didn't pick all the files
							$mw->Dialog(-title => $GUIstrings{error}, 
				   -text => $GUIstrings{pleasepickfiles}, 
				   -default_button => $GUIstrings{ok}, -buttons => [$GUIstrings{ok}])->Show( );
					}
				})-> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );



#############################################
							} elsif ( $output =~ /Drag and drop file (\d+)/ ) { # for files 2 to $no
				my $ii = $1;
				my $i = $ii - 1;
				$Qin->enqueue($inputfile[$i]);	 # the file was picked previously, we just feed it to the .pl here



#############################################
			} elsif ( $output =~ /Pdf to txt conversion done./i ){
				
				 my $frm_pdf = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');

				$GUIstrings{pdfreview} ||= "Pdf review";
				$GUIstrings{pdfreview_msg} ||= "Press next when you're done with reviewing the converted pdf files, and you have closed them.";
				 
				$frm_pdf -> Label(-text => $GUIstrings{pdfreview}, -font=>'bold')->pack (-pady => 10);
				$frm_pdf -> Label(-text => $GUIstrings{pdfreview_msg},)->pack;

				
				$GUIstrings{pdfreview_popuptext} ||= "Pdf to txt conversion done. To get the best alignment results, review the txt files and remove any page headers/footers now, then save and close the files.";
				$GUIstrings{view_files} ||= "View txt files";
				
				
				my $reviewpdf = $mw->Dialog(-title => $GUIstrings{pdfreview}, 
				   -text => $GUIstrings{pdfreview_popuptext}, 
				   -default_button => $GUIstrings{next}, -buttons => [$GUIstrings{view_files}, $GUIstrings{next}])->Show( );
				if ($reviewpdf eq $GUIstrings{next}) {
					$Qin->enqueue("Move on.");
					$frm_pdf->destroy;
				} else {
					$Qin->enqueue("open");
				}


				my $buttnext = $frm_pdf -> Button(	-text=>$GUIstrings{next},
													-command =>sub {
																		$Qin->enqueue( "Move on." );
																		$frm_pdf->destroy;
																	}
												);
				$buttnext -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );



##############################################
			} elsif ( $output =~ /File (\d+).* (\d+) -> (\d+)/ ) { # capture the segment number stats for use later
my $ii= $1;
my $i = $ii - 1;
$line_no[$i] = $2;
$line_no_seg[$i] = $3;



##############################################
			} elsif ( $output =~ /Revert to unsegmented.*\? \(Default: (.)\)/ ) {
			# } elsif ( $output =~ /Defaults:/ ) {
				# Revert to unsegmented [y/n]? (Default: n) 
				
				my $revert = $1; # set the default

				# my $frm_revert = $mw -> Scrolled('Frame', -scrollbars => 'osoe') -> pack(-expand => 1, -fill => 'both');
				my $frm_revert = $mw -> Frame() -> pack(-expand => 1, -fill => 'both'); #dontcare no scrolling in this screen, if there are too many files, the stats hang off the screen
				
				
				$GUIstrings{revert_q} ||= "Do you wish to revert to paragraph segmented files,\nor use the sentence segmented versions?";
				$frm_revert -> Label(-text => $GUIstrings{revert_q}, -font=>'bold')->pack (-pady => 10);

				$GUIstrings{segnums} ||= "Segment numbers before and after segmentation:";
				$frm_revert -> Label(-text => $GUIstrings{segnums},)->pack (-pady => 5);
				for (my $i = 0; $i < $no; $i++) { 
					$frm_revert -> Label(-text => "$langs_fullnames[$i]: $line_no[$i] -> $line_no_seg[$i]",)->pack (-anchor => 'w', -padx => 10);
				}
				
				$GUIstrings{use_segmented} ||= "The segmenting seems to have gone well, so I'll use the sentence segmented texts";
				$GUIstrings{revert} ||= "Revert to the paragraph segmented versions";
				my $rdb_n = $frm_revert -> Radiobutton(-text=> $GUIstrings{use_segmented}, -value=>"n",  -variable=>\$revert) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_y = $frm_revert -> Radiobutton(-text=> $GUIstrings{revert} , -value=>"y",  -variable=>\$revert) -> pack(-anchor=> 'w', -padx => 10);

				$GUIstrings{revert_note} ||= "\nNote: you should revert to the paragraph segmented files if the segmentation\npushed the files badly out of balance (they had a similar number of segments before\nbut not after), especially if (one of) the files hardly gained any new segments.";
				my $note = $frm_revert -> Label(-text => $GUIstrings{revert_note}, ); #  -side=> 'bottom', -anchor=> 's',


				my $buttnext = $frm_revert -> Button(-text=>$GUIstrings{next}, -command =>sub {$Qin->enqueue( $revert );$frm_revert->destroy;}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3,);	# -after => $note # -side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3,
				$buttnext->focus( -force );
				
				$note->pack(-side=> 'bottom', -anchor=> 's',);		# packed after the next button to make sure the next button ends up at the bottom of the window




#############################################
				} elsif ( $output =~ /Clean up text\?/ ){ # review
				$output =~ /\(Default: (.)\)/;	# can't put this in the elsif line above, because the // can't span the \n in the output string
				my $cleanup = $1;				# set the default
				
				
				$GUIstrings{cleanup_q} ||= "Do you want to clean up the aligned file?";
				my $frm_cleanup = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				$frm_cleanup -> Label(-text => $GUIstrings{cleanup_q}, -font=>'bold')->pack (-pady => 10);
				

				my $rdb_y = $frm_cleanup -> Radiobutton(-text=>$GUIstrings{yes}, -value=>"y",  -variable=>\$cleanup) -> pack(-anchor=> 'w');
				my $rdb_n = $frm_cleanup -> Radiobutton(-text=>$GUIstrings{no}, -value=>"n",  -variable=>\$cleanup) -> pack(-anchor=> 'w');
					
					
					$GUIstrings{cleanup_note} ||= "Note: cleanup means removing the ~~~ placed by Hunalign\nat the boundaries of merged segments, and removing segment-starting hyphens.\nIn most cases, you should pick Yes.";
					$frm_cleanup -> Label(-text => $GUIstrings{cleanup_note}, )->pack (-anchor => 'w');

				
				my $buttnext = $frm_cleanup -> Button(-text=>$GUIstrings{next}, -command =>sub {$Qin->enqueue( $cleanup );$frm_cleanup->destroy;}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );
			



#############################################
				} elsif ( $output =~ /\/x\] \(Default: / ){ # review
				# régi: [n/t/x] (Default: új: [n/x] (Default:
				my $review = "e";	# in GUI, the default is always the graphical editor
				

				my $frm_review = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{review_title} ||= "Review the aligned file to correct any incorrectly paired segments";
				$frm_review -> Label(-text => $GUIstrings{review_title}, -font=>'bold')->pack (-pady => 10);
				
				$GUIstrings{gui_editor} ||= "Use the graphical editor";
				$GUIstrings{edit_xls} ||= "Generate an xls and open it for reviewing";
				$GUIstrings{noreview} ||= "No review";
				
				my $rdb_e = $frm_review -> Radiobutton(-text=>$GUIstrings{gui_editor}, -value=>"e",  -variable=>\$review) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_x = $frm_review -> Radiobutton(-text=>$GUIstrings{edit_xls}, -value=>"x",  -variable=>\$review) -> pack(-anchor=> 'w', -padx => 10);
				# my $rdb_xn = $frm_review -> Radiobutton(-text=>"Generate an xls but do not open it", -value=>"xn",  -variable=>\$review) -> pack(-anchor=> 'w');
				my $rdb_n = $frm_review -> Radiobutton(-text=>$GUIstrings{noreview}, -value=>"n",  -variable=>\$review) -> pack(-anchor=> 'w', -padx => 10);


				
				$GUIstrings{xls_background} ||= "Generate xls in background after review";
				
				my $frm_addxls = $frm_review -> Frame() -> pack(-anchor => 'w', -pady => 15);
				my $addxls = "off";
				$frm_addxls -> Checkbutton(
									# -text     => "Note to be added to each TU: ",
									-variable => \$addxls,
									-onvalue  => 'on',
									-offvalue => 'off',
									-text => $GUIstrings{xls_background}
									# -command  => sub {},
									)->pack(-anchor => 'w', -side => 'left', -padx => 10);
				
				# $frm_addxls -> Label(-text=>"Generate xls in background after review")->pack(-anchor => 'w', -side => 'left',	);






				my $buttnext = $frm_review -> Button(-text=>$GUIstrings{next}, -command =>sub { if ( ($review ne "x") && ($addxls eq "on") ) {$review = $review . "x"}; $Qin->enqueue( $review );$frm_review->destroy;}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );
				



################################################
			} elsif ( $output =~ /Append.write to / ) {
				my $tomastertm = "a";		# set default to "append"
				
				my $frm_mastertm = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{master_tm_title} ||= "Append to existing master TM file or overwrite it?";
				$frm_mastertm -> Label(-text => $GUIstrings{master_tm_title}, -font=>'bold')->pack (-pady => 10);

				$GUIstrings{master_tm_append} ||= "Append";
				$GUIstrings{master_tm_overwrite} ||= "Overwrite";
				$GUIstrings{master_tm_none} ||= "Don't write to master TM";
				
				
				my $rdb_e = $frm_mastertm -> Radiobutton(-text=>$GUIstrings{master_tm_append}, -value=>"a",  -variable=>\$tomastertm) -> pack(-anchor=> 'w');
				my $rdb_p = $frm_mastertm -> Radiobutton(-text=>$GUIstrings{master_tm_overwrite}, -value=>"o",  -variable=>\$tomastertm) -> pack(-anchor=> 'w');
				my $rdb_h = $frm_mastertm -> Radiobutton(-text=>$GUIstrings{master_tm_none}, -value=>"n",  -variable=>\$tomastertm) -> pack(-anchor=> 'w');

				my $buttnext = $frm_mastertm -> Button(-text=>$GUIstrings{next}, -command =>sub {$Qin->enqueue( $tomastertm );$frm_mastertm->destroy;}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );


############################################# #c
				} elsif ( $output =~ /Create TMX\?/ ){ # create TMX or not
				$output =~ /\(Default: (.)\)/;	# can't put this in the elsif line above, because the // can't span the \n in the output string
				my $create_tmx = $1;				# set the default
				
				my $frm_create_tmx = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{tmx_title} ||= "Do you want to generate a TMX file?";
				$frm_create_tmx -> Label(-text => $GUIstrings{tmx_title}, -font=>'bold')->pack (-pady => 10);
				
				
				my $rdb_y = $frm_create_tmx -> Radiobutton(-text=>$GUIstrings{yes}, -value=>"y",  -variable=>\$create_tmx) -> pack(-anchor=> 'w', -padx => 10);
				my $rdb_n = $frm_create_tmx -> Radiobutton(-text=>$GUIstrings{no}, -value=>"n",  -variable=>\$create_tmx) -> pack(-anchor=> 'w', -padx => 10);

				
				$GUIstrings{tmx_note} ||= "\nNote: you'll need a TMX file if you wish to import your aligned texts into a CAT tool such as Trados";
				$frm_create_tmx -> Label(-text => $GUIstrings{tmx_note}, )->pack (-anchor => 's');

				my $buttnext = $frm_create_tmx -> Button(-text=>$GUIstrings{next}, -command =>sub {$Qin->enqueue( $create_tmx );$frm_create_tmx->destroy;}) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );
				


#############################################
				# } elsif ( $output =~ /Default tmx note: (.*)/ ){ # default note not available at startup with all other defaults because it' set by main script based on filenames etc.
				
				
				# $tmx_settings{note} = $1;
				# chomp $tmx_settings{note}; # can't hurt




#############################################
				} elsif ( $output =~ /Default creationdate: (.*Z)/ ){
				
				$tmx_settings{creationdate} = $1;
				chomp $tmx_settings{creationdate}; # can't hurt


#############################################
				} elsif ( $output =~ /Type the language code of language 1/ ){ # we'll ask for all the TMX settings in a single page here
				
				my $frm_tmx_settings = $mw -> Scrolled('Frame', -scrollbars => 'osoe') -> pack(-expand => 1, -fill => 'both');
				
				$GUIstrings{tmxsetup_title} ||= "Please provide the settings for the TMX file\n";
				$frm_tmx_settings -> Label(-text => $GUIstrings{tmxsetup_title}, -font=>'bold')->pack (-pady => 10);
				
				
				my $frm_tmx_settings_leftright = $frm_tmx_settings -> Frame() -> pack();
				
				my $frm_tmx_settings_left = $frm_tmx_settings_leftright -> Frame() -> pack(-side=>"left");
				my $frm_tmx_settings_right = $frm_tmx_settings_leftright -> Frame() -> pack(-side=>"left");
				
				
				for (my $i = 0; $i < $no; $i++) {
					$tmx_langcodes[$i] = uc($langs_iso[$i]);
				}
				
				# overwrite lang 1 and 2 with the defaults set in the setup.txt (if available)
				$tmx_langcodes[0] = $tmx_langcode_1_def if $tmx_langcode_1_def;
				$tmx_langcodes[1] = $tmx_langcode_2_def if $tmx_langcode_2_def;
				
				
				$GUIstrings{langcode1} ||= "Language code for";
				$GUIstrings{langcode2} ||= ": ";
				for (my $i = 0; $i < $no; $i++) {
					my $ii = $i +1; $ii++; # $ii is always $i + 1
					$frm_tmx_settings_left -> Label(-text=>"$GUIstrings{langcode1} $langs_fullnames[$i] $GUIstrings{langcode2}", -width => 36, -anchor => 'w')->pack(-anchor => 'w');
					$frm_tmx_settings_right -> Entry(-width => 10, -textvariable => \$tmx_langcodes[$i],)->pack(-anchor => 'w');
					
				}
				


				# get TMX note (the string to be passed to the other thread is set when the Next button is pressed)
				
				my $frm_tmx_note = $frm_tmx_settings_left -> Frame() -> pack(-expand => 1, -fill => 'both');
				
				
				$GUIstrings{tmxnote_label} ||= "Note:  ";
				my $tmxnote_label = $frm_tmx_note -> Label(-text=>$GUIstrings{tmxnote_label})->pack(-anchor => 'w', -side => 'left');
				
				
				# entry field for custom note
				my $tmxnote_entered;
				my $tmxnote_entry = $frm_tmx_settings_right -> Entry(-width => 25, -textvariable => \$tmxnote_entered, -state => 'disabled')->pack(-anchor => 'w',); # , -state => 'disabled'         -side => 'left',
				
				
				my $tmxnote_choice = "thirdcol";	# default radio button
				
				$GUIstrings{tmxnote_off} ||= "Off";
				my $rdb_off = $frm_tmx_note -> Radiobutton(-text=>$GUIstrings{tmxnote_off}, -value=>"off",  -variable=>\$tmxnote_choice, -command  => sub { $tmxnote_entry->configure( -state => 'disabled'); }) -> pack(-anchor => 'w', -side => 'left', );
				
				$GUIstrings{tmxnote_thirdcol} ||= "Third column";
				my $rdb_thirdcol = $frm_tmx_note -> Radiobutton(-text=>$GUIstrings{tmxnote_thirdcol}, -value=>"thirdcol",  -variable=>\$tmxnote_choice, -command  => sub { $tmxnote_entry->configure( -state => 'disabled'); },) -> pack(-anchor => 'w', -side => 'left', );
				
				$GUIstrings{tmxnote_custom} ||= "Custom:";
				my $rdb_custom = $frm_tmx_note -> Radiobutton(-text=>$GUIstrings{tmxnote_custom}, -value=>"custom",  -variable=>\$tmxnote_choice, -command  => sub { $tmxnote_entry->configure( -state => 'normal'); },) -> pack(-anchor => 'w', -side => 'left', );
				
				
				
				$GUIstrings{creationid} ||= "Creation ID: ";
				$frm_tmx_settings_left -> Label(-text=>$GUIstrings{creationid})->pack(-anchor => 'w');
				$frm_tmx_settings_right -> Entry( -width => 25, -textvariable => \$tmx_settings{creationid},)->pack(-anchor => 'w');
				
				

				# my $frm_tmx_creationdate = $frm_tmx_settings -> Frame() -> pack(-expand => 1, -fill => 'both');
				$GUIstrings{creationdate} ||= "Creation date: ";
				$frm_tmx_settings_left -> Label(-text=>$GUIstrings{creationdate})->pack(-anchor => 'w');
				$frm_tmx_settings_right -> Entry( -width => 25, -textvariable => \$tmx_settings{creationdate},)->pack(-anchor => 'w');
				# malformed dates are ignored by the main script


				$GUIstrings{tmxsetup_note_1} ||= "\nNote 1: The \"Note\" field above refers to a text field added to each TU in your TMX.\n\"Third column\" means that the text in the third column of a bilingual file will be added as a note.\n To add a custom note text, check 'Custom' and type in the box.";
				$frm_tmx_settings -> Label(-text => $GUIstrings{tmxsetup_note_1},)->pack (-anchor => 'w');

				
				$GUIstrings{tmxsetup_note_2} ||= "\nNote 2: CAT tools tend to be picky about what language codes they accept in TMX files.\nMany of them don't accept two-letter codes, i.e. you need to use EN-GB or EN-US instead of EN etc.\nIf in doubt, export a TM into TMX with the CAT tool you will be using and check the codes it uses.\nAlternatively, you can take a stab in the dark and hope for the best.";
				$frm_tmx_settings -> Label(-text => $GUIstrings{tmxsetup_note_2},)->pack (-anchor => 'w');


				
				my $buttnext = $frm_tmx_settings -> Button(	-text=>$GUIstrings{next},
															-command =>sub {
																$Qin->enqueue( $tmx_langcodes[0] );
																# set $tmx_settings{note}
																if ($tmxnote_choice eq "off") {$tmx_settings{note} = "none"} elsif ($tmxnote_choice eq "thirdcol") {$tmx_settings{note} = ""} else {$tmx_settings{note} = $tmxnote_entered}
																
																$frm_tmx_settings->destroy;
																}
															) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );



#############################################
				} elsif ( $output =~ /Type the language code of language (\d+)/ ){ # languages 2 - $no
				my $ii = $1;
				my $i = $ii - 1;
				$Qin->enqueue( $tmx_langcodes[$i] );
				


#############################################
				} elsif ( $output =~ /date and time to be recorded in the TMX/ ){

				$Qin->enqueue("$tmx_settings{creationdate}"); #do add option to specify a date/time via $tmx_settings{creationdate}


#############################################
				} elsif ( $output =~ /the creator name you wish to be recorded in the TMX/ ){ 

				$Qin->enqueue("$tmx_settings{creationid}");


#############################################
				} elsif ( $output =~ /You can add a note to your TMX./ ){ 

# $tmx_settings{note} = "none" if $tmx_settings{note} eq ""; # this is now done in-place
				$Qin->enqueue("$tmx_settings{note}");


#############################################
				} elsif ( $output =~ /Press Enter to quit./i ){
				# when aborting, lf aligner prints "press enter to close this window", therefore we can use this string for recognizing normal termination

				$output =~ s/^\n+//s;

				# $written TUs have been written to the TMX. $skipped segments were skipped ($halfempty of them due to being half-empty).\n\nPress Enter to quit.\n";
				my $stats = "";
				if ($output =~ /have been written to the TMX/) {$output =~ /^(.*)\s*\n*Press Enter to quit.$/s;$stats = "$1";} #do
				
				
				$GUIstrings{done_title} ||= "The end";
				$GUIstrings{done_text1} ||= "The programme has terminated successfully.";
				$GUIstrings{done_text2} ||= "Click OK to exit.";
				my $quit = $mw->Dialog(	-title => $GUIstrings{done_title},
										-text => "$GUIstrings{done_text1}\n${stats}$GUIstrings{done_text2}", 
										-default_button => $GUIstrings{ok}, -buttons => [$GUIstrings{ok}])->Show( );
				if ($quit eq $GUIstrings{ok}) {
					$Qin->enqueue("Done");
				}


#############################################
#      GUI ELEMENTS OF THE TMX MAKER        #
#############################################
				} elsif ( $output =~ /Drag and drop the input file \(tab delimited txt/ ){ 




				my $frm_infiles = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');	# all the browse frames are inside this frame
				
				$GUIstrings{tmx_pickfiles} ||= "Pick the input files!\n";
				$frm_infiles -> Label(-text => $GUIstrings{tmx_pickfiles}, -font=>'bold')->pack (-pady => 10);
				
				
				my $frm_infiles_picker = $frm_infiles -> Frame() -> pack();
				
				my $labeltext;
				my @inputfiles;
				
				my $filepicker = sub {	# this sub is launched when the Browse button is pressed, see further down
				
				my $in_type = [	['Txt / xls', ['.txt', '.xls']],
								['All Files', '*']	];

				
				
				$GUIstrings{tmx_pickafile} ||= "Please choose the input file(s)";
				@inputfiles = $mw ->getOpenFile(
										-title => $GUIstrings{tmx_pickafile},
										-filetypes => $in_type,
										-multiple => 1,
									);
				$labeltext = $inputfiles[0];										# this will be displayed by the autoupdated label
				$labeltext =~ s/^.*(.{40})$/...$1/ if $labeltext =~ /.{41}/;	# the full path may not fit
				my $fileno = @inputfiles;
				
				
				$GUIstrings{tmx_fileschosen} ||= "files chosen: ";
				$GUIstrings{tmx_filechosen} ||= "File chosen: ";
				if ($fileno > 1) {
					$labeltext = "$no $GUIstrings{tmx_fileschosen}" . $inputfiles[0];
				} else {
					$labeltext = $GUIstrings{tmx_filechosen} . $inputfiles[0];}
				}; # don't delete this ;
				
				
				
				$GUIstrings{tmx_nofilechosen} ||= "No file chosen";
					$labeltext = $GUIstrings{tmx_nofilechosen};		# default of the autoupdated label
					my $buttbrowse = $frm_infiles_picker -> Button(-text=>$GUIstrings{browse}, -command =>[\&$filepicker]) -> pack(-side=> 'left');
					# this needs to be done in this roundabout way; command in sub outside of here, with $i passed as an argument (otherwise the other sub can't see $i), and the sub ref as a variable due to the nested subs problem
					$frm_infiles_picker -> Label(
													-textvariable => \$labeltext,
													-width => 65,
													-anchor => 'w',
													# -justify => 'left', # this only seems to work with multiline text
												)->pack(-side => 'left'); 
				
				
				$GUIstrings{tmx_filepicker_note} ||= "Note: input files can be UTF-8 txt or xls.\nYou may pick more than one file, they will be merged into the same TMX.";
				$frm_infiles -> Label(-text => $GUIstrings{tmx_filepicker_note})->pack (-pady => 30); # -pady => 10
				
				
				# enqueue the file path(s) when the Next button is clicked
				$GUIstrings{tmx_error} ||= "Please pick at least one input file.";
				
				my $buttnext = $frm_infiles -> Button(-text => $GUIstrings{next}, -command => sub {
					my $infilelist = join (";,;", @inputfiles); # ;,; is unlikely to occur in a file name
					if ($infilelist) {	# if at least one file has been picked, we go on
						$Qin->enqueue($infilelist);$frm_infiles->destroy;
					} else {					# warn if the user didn't pick all the files
							$mw->Dialog(-title => 'Error', 
						-text => $GUIstrings{tmx_error}, 
						-default_button => $GUIstrings{ok}, -buttons => [$GUIstrings{ok}])->Show( );
					}
				})-> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				
				$buttnext->focus( -force );




#############################################
			} elsif ( $output =~ /Specify the path and name of the output file/i ){ 
				chomp $output;	# can't hurt
				
				my $frm_outfile = $mw -> Frame() -> pack(-expand => 1, -fill => 'both');
				my $frm_outfile_picker = $frm_outfile -> Frame() -> pack(-expand => 1, -fill => 'both');

				$GUIstrings{tmx_out_title} ||= "Please specify the output file";
				$frm_outfile_picker -> Label(-text => $GUIstrings{tmx_out_title}, -font=>'bold')->pack (-pady => 10);


				my $labeltext;
				my $outfile;
				
				($outfile) = $output =~ /Default: (.*)$/;
				
				
				$GUIstrings{tmx_out_pleasechoose} ||= "Please choose the output file";
				$GUIstrings{tmx_out_outfile} ||= "Output file:";
				
				my $filepicker = sub {	# this sub is launched when the Browse button is pressed, see further down
				my $out_type = [	['TMX', ['.tmx']],
								['All Files', '*']	];
				$outfile = $mw ->getSaveFile(
										-title => $GUIstrings{tmx_out_pleasechoose},
										-filetypes => $out_type,
										-defaultextension => "tmx",
									);
				
									$labeltext = $outfile;										# this will be displayed by the autoupdated label
									$labeltext =~ s/^.*(.{40})$/...$1/ if $labeltext =~ /.{41}/;	# the full path may not fit
									
										$labeltext = "$GUIstrings{tmx_out_outfile} $outfile";
									}; # don't delete the ;
				
				
				

					$labeltext = "$GUIstrings{tmx_out_outfile} $outfile";		# default of the autoupdated label
					my $buttbrowse = $frm_outfile_picker -> Button(-text=>$GUIstrings{browse}, -command =>[\&$filepicker]) -> pack(-side=> 'left',-padx => 10);
					# this needs to be done in this roundabout way; command in sub outside of here, with $i passed as an argument (otherwise the other sub can't see $i), and the sub ref as a variable due to the nested subs problem
					$frm_outfile_picker -> Label(
													-textvariable => \$labeltext,
													-width => 65,
													-anchor => 'w',
													# -justify => 'left', # this only seems to work with multiline text
												)->pack(-side => 'left'); 
				


				$GUIstrings{tmx_out_note} ||= "Note: just press Next to create the output file\nin the same folder as the (last) output file, with the same name.";
				$frm_outfile -> Label(-text => $GUIstrings{tmx_out_note})->pack (-pady => 30);


				my $buttnext = $frm_outfile -> Button(	-text=>$GUIstrings{next},
															-command =>sub {
																$Qin->enqueue( $outfile );
																# set $tmx_settings{note}
																$frm_outfile -> destroy;
																}
															) -> pack(-side => 'bottom', -anchor=> 'se', -padx => 3, -pady => 3);
				$buttnext->focus( -force );



#############################################
			} elsif ( $output =~ /already exists! Rename it or it will be overwritten/ ){ 
				
				#do translation for error text
				
				my $exists = $mw->Dialog(	-title => 'Error', 
								-text => "$output", 
								-default_button => $GUIstrings{ok},
								-buttons => [$GUIstrings{ok}]
							)->Show( );
				
				if ($exists eq $GUIstrings{ok}) {
					$Qin->enqueue("");
				}


			}
####################################
# ^^^ END OF LAST ELSIF BLOCK ^^^^ #
####################################


		}			# end of if( $Qout->pending ) {
	};				# end of dostdout sub

	$mw->repeat( 50, $doStdout );

	Tk::MainLoop();
	exit(0);		# this terminates the other process when the GUI window is closed
}


1;


__DATA__
test: Some text
filetype_prompt: Please choose the type of your input files!
another test: some more text