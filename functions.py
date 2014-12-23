# Name:        functions.py
# Purpose:     Various project functions
#
# Author:      Filip
#
# Created:     4.11.2014

import urllib2
import codecs
import re
import sys
import os
from bs4 import BeautifulSoup
import datetime
import ladder2text_new
from subprocess import check_output


def delete_and_rename(file_to_change_name, file_to_delete):
    os.remove(file_to_delete)  # delete file_2
    os.rename(file_to_change_name, file_to_delete)  # rename file_1 to file_2


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


def scraper(langs, make_link, error_text, url_code, prefix, is_celex=False):
    for lang_code in langs:
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


def untokenize(input_file, output_file):
    # u'\u2026' ellipsis
    # u'\u2018' single opening quotation mark
    # u'\u2019' single closing quotation mark
    # u'\u201c' double opening quotation mark
    # u'\u201d' double closing quotation mark
    # u'\u201e' low double opening quotation mark
    # u'\u00ab' left-pointing double angle quotation mark
    # u'\u00bb' right-pointing double angle quotation mark

    # Define punctuation marks where spaces should be removed after/before.
    space_after = ['(', u'\u201e', '[', u'\u2018', u'\u201c', u'\u00ab', "/"]
    space_before = [')', '.', ',', ":", ";", "?", "!", u'\u201d', u'\u2019',
                    ']', u'\u2026', u'\u00bb', "/"]
    with codecs.open(output_file, "w", "utf-8") as fout:
        with codecs.open(input_file, "r", "utf-8") as fin:
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


def remove_p(input_name, output_name):
    empty_line = '<P>\n'
    with codecs.open(output_name, "w", "utf-8") as fout:
        with codecs.open(input_name, "r", "utf-8") as fin:
            for line in fin:
                if line != empty_line:
                    fout.write(line)


def tab_to_separate(input_name, output_source, output_target):
    with codecs.open(input_name, "r", "utf-8") as fin:
        with codecs.open(output_source, "w", "utf-8") as out_s:
            with codecs.open(output_target, "w", "utf-8") as out_t:
                for line in fin:
                    text = re.split(r'\t', line)
                    source = text[2]
                    target = text[1]
                    out_s.write(source + '\n')
                    out_t.write(target + '\n')


def tab_to_tmx(input_name, tmx_name, s_lang, t_lang):
    # get current date
    current_date = datetime.datetime.now().isoformat()
    current_date = current_date[0:4] + current_date[5:7] + current_date[8:10] \
        + "T" + current_date[11:13] + current_date[14:16] + \
        current_date[17:19] + "Z"
    # create new TMX file
    with codecs.open(tmx_name, "w", "utf-8") as fout:
        # add tmx header (copied from LF Aligner output)
        fout.write('<?xml version="1.0" encoding="utf-8" ?>\n')
        fout.write('<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n')
        fout.write('<tmx version="1.4">\n')
        fout.write('  <header\n')
        fout.write('    creationtool="eunlp"\n')
        fout.write('    creationtoolversion="0.01"\n')
        fout.write('    datatype="unknown"\n')
        fout.write('    segtype="sentence"\n')
        fout.write('    adminlang="' + s_lang + '"\n')
        fout.write('    srclang="' + s_lang + '"\n')
        fout.write('    o-tmf="TW4Win 2.0 Format"\n')
        fout.write('  >\n')
        fout.write('  </header>\n')
        fout.write('  <body>\n')
        with codecs.open(input_name, "r", "utf-8") as fin:
            for line in fin:
                #   get source and target to temp variables
                text = re.split(r'\t', line)
                source = text[2]
                target = text[1]
                # remove triple tildas from hunalign
                source = source.replace('~~~ ', '')
                target = target.replace('~~~ ', '')
                #   create TU line
                tu = '<tu creationdate="' + current_date + \
                     '" creationid="eunlp"><prop type="Txt::Note">' + \
                     input_name + '</prop>\n'
                fout.write(tu)
                #   create TUV source line
                tuv = '<tuv xml:lang="' + s_lang + '"><seg>' + source\
                      + '</seg></tuv>\n'
                fout.write(tuv)
                #   create TUV target line
                tuv = '<tuv xml:lang="' + t_lang + '"><seg>' + target\
                      + '</seg></tuv> </tu>\n'
                fout.write(tuv)
                fout.write('\n')
        # add tmx footer
        fout.write('\n')
        fout.write('</body>\n')
        fout.write('</tmx>')


def splitter_wrapper(lang, input_file, output_file):
    command = ' perl sentence_splitter/split-sentences.perl -l ' + \
        lang + ' < ' + input_file + '> ' + output_file
    check_output(command, shell=True)


def tokenizer_wrapper(lang, input_file, output_file):
    command = ' perl tokenizer.perl -l ' + lang + ' < ' + input_file + ' > '\
              + output_file
    check_output(command, shell=True)

def aligner(source_file, target_file, s_lang, t_lang, align_file):
    # check OS
    computer = sys.platform
    if computer == 'win32':
        command = 'LFalign\LF_aligner_4.05.exe --filetype="t" --infiles="' \
                  + source_file + '","' + target_file + '" --languages="' + \
                  s_lang + '","' + t_lang + \
                  '" --segment="y" --review="n" --tmx="y"'
        check_output(command, shell=True)
    else:
        # let's assume everything else is linux
        # sentence splitter; resulting file are with the .spl extension
        splitter_wrapper(s_lang, source_file, source_file[:-4] + '.spl')
        splitter_wrapper(t_lang, target_file, target_file[:-4] + '.spl')
        # remove < P > and create files without extension
        remove_p(source_file[:-4] + ".spl", source_file[:-4])
        remove_p(target_file[:-4] + ".spl", target_file[:-4])
        # tokenizer and create files with the .tok extension
        tokenizer_wrapper(s_lang, source_file[:-4], source_file[:-4] + '.tok')
        tokenizer_wrapper(t_lang, target_file[:-4], target_file[:-4] + '.tok')
        # hunalign
        dictionary = s_lang + t_lang + '.dic'  # TODO if !exist ?
        # create ladder
        command = 'hunalign-1.1/src/hunalign/hunalign ' + dictionary + ' '  \
                  + source_file[:-4] + '.tok ' + target_file[:-4] + \
                  '.tok > ' + align_file + '.lad'
        check_output(command, shell=True)
        # create aligned output
        output_lines = ladder2text_new.create_output_lines(align_file + '.lad',
                                                           source_file[:-4],
                                                           target_file[:-4])
        with codecs.open(align_file + '.tab', "w", "utf-8") as fout:
            for line in output_lines:
               fout.write(line + '\n')
        # turn alignment into tmx
        tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang, t_lang)
        # create parallel source and target text files
        tab_to_separate(align_file + '.tab', source_file[:-4] + '.ali',
                        target_file[:-4] + '.ali')
