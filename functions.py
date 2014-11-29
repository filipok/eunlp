#-----------------------------------------------------------------------------
# Name:        functins.py
# Purpose:     Various project functions
#
# Author:      Filip
#
# Created:     4.11.2014
# Licence:     Public domain
#-----------------------------------------------------------------------------

import urllib2
import codecs
import re
import sys
from bs4 import BeautifulSoup
from subprocess import check_output


def download(link):
    response = urllib2.urlopen(link)
    return response.read()


def check_error(text, error_string):
    if error_string in text:
        print "Link error!"
        return False
    return True


def strip_celex(text):
    # discard some leftover Javascript and newlines at the beginning
    split = re.split(r'\n\t{5}Text\n', text)
    text = split[1]
    # discard some leftover Javascript and newlines at the end
    split = re.split(r'\n\s{,6}Top\s{,6}\n', text)
    text = split[0]
    # remove empty newlines
    text = re.sub(r'\n+', r'\n', text)
    # double newlines, otherwise the splitter merges the first lines
    text = re.sub(r'\n', r'\n\n', text)
    return text



def scraper(languages, make_link, error_text, url_code, prefix, is_celex = False):
    for lang_code in languages:
            link = make_link(url_code, lang_code)
            text = download(link)
            if check_error(text, error_text):
                new_name = prefix + url_code + '_' + lang_code + '.html'
                with open(new_name, 'w') as f:
                    f.write(text)
                new_name = prefix + url_code + '_' + lang_code + '.txt'
                with codecs.open(new_name, "w", "utf-8") as f:
                    soup = BeautifulSoup(text)
                    clean_text = soup.get_text()
                    # do some cleanup if is_celex
                    if is_celex:
                        clean_text = strip_celex(clean_text)
                    f.write(clean_text)
            else:
                print "Error in link " + url_code + " " + lang_code + "."

def aligner(source_file, target_file, lang_source, lang_target, align_file):
    # check OS
    computer = sys.platform
    if computer == 'win32':
        command = 'C:\Users\Filip\Dropbox\Tranzit\LFalign\LF_aligner_4.05.exe --filetype="t" --infiles="' + source_file + '","' + target_file + '" --languages="' + lang_source + '","' + lang_target + '" --segment="y" --review="n" --tmx="y"'
        check_output(command, shell = True)
    else:
        # let's assume everything else is linux
        # sentence splitter
        command = ' perl sentence_splitter/split-sentences.perl ' + lang_source + ' < ' + source_file + '> ' + source_file + '_s'
        check_output(command, shell = True)
        command = ' perl sentence_splitter/split-sentences.perl ' + lang_target + ' < ' + target_file + '> ' + target_file + '_s'
        check_output(command, shell = True)
        # tokenizer
        command = ' perl tokenizer.perl ' + lang_source + ' < ' + source_file + '_s ' + '> ' + source_file + '_st'
        check_output(command, shell = True)
        command = ' perl tokenizer.perl ' + lang_target  + ' < ' + target_file + '_s ' + '> ' + target_file + '_st'
        check_output(command, shell = True)
        # hunalign
        dictionary = lang_source + lang_target + '.dic' #this assumes the file exists
        command = 'hunalign-1.1/src/hunalign/hunalign ' + dictionary + ' '  + source_file + '_st ' + target_file + '_st -text > '+ align_file+ '.txt'
        check_output(command, shell = True)
        # make it human readable
        # turn it into tmx
        # pass
