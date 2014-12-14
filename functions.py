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
import os
from bs4 import BeautifulSoup
import datetime
from subprocess import check_output

def delete_and_rename(file_to_change_name, file_to_delete):
    os.remove(file_to_delete) #delete file_2
    os.rename(file_to_change_name, file_to_delete) #rename file_1 to file_2


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

def untokenize(file_name):
    # u'\u2026' ellipsis
    # u'\u2018' single opening quotation mark
    # u'\u2019' single closing quotation mark
    # u'\u201c' double opening quotation mark
    # u'\u201d' double closing quotation mark
    # u'\u201e' low double opening quotation mark
    # u'\u00ab' left-pointing double angle quotation mark
    # u'\u00bb' right-pointing double angle quotation mark

    # Define punctuation marks where spaces should be removed after/before.
    space_after =['(', u'\u201e', '[', u'\u2018', u'\u201c', u'\u00ab', "/"]
    space_before =[')', '.', ',', ":", ";", "?", "!", u'\u201d', u'\u2019', ']', u'\u2026', u'\u00bb', "/"]
    new_name = 'un_' + file_name
    with codecs.open(new_name, "w", "utf-8") as fout:
        with codecs.open(file_name, "r", "utf-8") as fin:
            for line in fin:
                apostrophe = u'\u2019'
                new = apostrophe + "s "
                old = apostrophe + " s "
                line = line.replace(old, new)  # English possessive (Saxon)
                for sign in space_after:
                    new = sign
                    old = sign + " "
                    line = line.replace(old, new)
                for sign in space_before:
                    new = sign
                    old = " " + sign
                    line = line.replace(old, new)
                fout.write(line)


def tab_to_tmx(file_name, lang_source, lang_target):
    # get current date
    current_date = datetime.datetime.now().isoformat()
    current_date = current_date[0:4] + current_date[5:7] + current_date[8:10] \
        + "T" + current_date[11:13] + current_date[14:16] + \
        current_date[17:19] + "Z"
    # create new TMX file
    tmx_file = file_name + ".tmx"
    # open tmx_file
    with codecs.open(tmx_file, "w", "utf-8") as fout:
        # add tmx header (copied from LF Aligner output)
        fout.write('<?xml version="1.0" encoding="utf-8" ?>\n')
        fout.write('<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n')
        fout.write('<tmx version="1.4">\n')
        fout.write('  <header\n')
        fout.write('    creationtool="eunlp"\n')
        fout.write('    creationtoolversion="0.01"\n')
        fout.write('    datatype="unknown"\n')
        fout.write('    segtype="sentence"\n')
        fout.write('    adminlang="' + lang_source + '"\n')
        fout.write('    srclang="' + lang_source + '"\n')
        fout.write('    o-tmf="TW4Win 2.0 Format"\n')
        fout.write('  >\n')
        fout.write('  </header>\n')
        fout.write('  <body>\n')
        with codecs.open(file_name, "r", "utf-8") as fin:
            for line in fin:
                #   get source and target to temp variables
                text = re.split(r'\t', line)
                source = text[0]
                target = text[1]
                # remove triple tildas from hunalign
                source = source.replace('~~~ ', '')
                target = target.replace('~~~ ', '')
                # TODO use hunalign without -text
                # test each line for quasi-empty < P >
                #TODO < P > are created by the sentence splitter, clean there
                if source != '&lt; P &gt;':
                    #   create TU line
                    tu = '<tu creationdate="' + current_date + \
                         '" creationid="eunlp"><prop type="Txt::Note">' + \
                         file_name + '</prop>\n'
                    fout.write(tu)
                    #   create TUV source line
                    tuv = '<tuv xml:lang="' + lang_source + '"><seg>' + source\
                          + '</seg></tuv>\n'
                    fout.write(tuv)
                    #   create TUV target line
                    tuv = '<tuv xml:lang="' + lang_target + '"><seg>' + target\
                          + '</seg></tuv> </tu>\n'
                    fout.write(tuv)
                    fout.write('\n')
        # add tmx footer
        fout.write('\n')
        fout.write('</body>\n')
        fout.write('</tmx>')


def aligner(source_file, target_file, lang_source, lang_target, align_file):
    # check OS
    computer = sys.platform
    if computer == 'win32':
        command = 'LFalign\LF_aligner_4.05.exe --filetype="t" --infiles="' + source_file + '","' + target_file + '" --languages="' + lang_source + '","' + lang_target + '" --segment="y" --review="n" --tmx="y"'
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
        # untokenize alignment
        untokenize(align_file + '.txt')
        # turn alignment into tmx
        tab_to_tmx('un_' + align_file + '.txt', lang_source, lang_target)
