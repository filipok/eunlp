# Name:        functions.py
# Purpose:     Various project functions
#
# Author:      Filip
#
# Created:     4.11.2014

import urllib2
import codecs
import re
import os
from bs4 import BeautifulSoup
import datetime
import ladder2text_new
import subprocess
import random


def make_paths(path, text_id, languages):
        source_file = os.path.join(path, text_id + '_' + languages[0] + '.txt')
        target_file = os.path.join(path, text_id + '_' + languages[1] + '.txt')
        align_file = os.path.join(path, 'bi_' + text_id)
        dictionary = os.path.join(path, languages[0].lower() +
                              languages[1].lower() + '.dic')
        return source_file, target_file, align_file, dictionary


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


def make_ep_sub_link(doc_category, doc_year, doc_code):
    return doc_category + doc_year + doc_code


def make_ep_link(category_year_code, lang):
    doc_category = category_year_code[0:2]
    doc_year = category_year_code[2:6]
    doc_code = category_year_code[6:10]
    a = 'http://www.europarl.europa.eu/sides/getDoc.do?type=REPORT&reference=A'
    p = 'http://www.europarl.europa.eu/sides/getDoc.do?type=TA&reference=P'
    b = 'http://www.europarl.europa.eu/sides/getDoc.do?type=MOTION&reference=B'
    if doc_category[0] == 'A':
        part_1 = a
    elif doc_category[0] == 'P':
        part_1 = p
    elif doc_category[0] == 'B':
        part_1 = b
    else:
        print "make_link error"
        part_1 = 'error'  # dubious
    return part_1 + doc_category[1] + '-' + doc_year + '-' + doc_code + \
        '&language=' + lang


def make_celex_link(celex, lang):
    part_1 = "http://eur-lex.europa.eu/legal-content/"
    part_2 = "/TXT/?uri=CELEX:"
    return part_1 + lang + part_2 + celex


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
    # add whitespace after dot if missing (e.g. ' tasks.The ')
    text = re.sub(r'([a-z]\.)([A-Z])', r'\1 \2', text)
    return text

def strip_ep(text):
    # double newlines, otherwise the splitter merges the first lines
    text = re.sub(r'\n', r'\n\n', text)
    # discard language list at the beginning (it ends with Swedish/svenska)
    split = re.split(r'\nsv.{3}svenska.*\n', text)
    text = split[1]
    return text


def paragraph_combiner(input_file, output_file):
    with codecs.open(input_file, 'r', 'utf-8') as fin:
        text = fin.read()
        text = paragraph_combiner_sub(text)
        with codecs.open(output_file, 'w', 'utf-8') as fout:
            fout.write(text)


def paragraph_combiner_sub(text, simplify=True):
    # TODO eventual si la inceputuri de paragrafe deja unite? "1. The..."
    # combine single lines consisting of numbers/letters with next line
    pattern_1 = \
        re.compile(r'\n(\(?[0-9]+[\.|\)]|\(?[a-z]+[\.|\)]|\(?[A-Z]+[\.|\)])\n')
    # combine single lines consisting of single number + single letter
    # with the next line
    pattern_3 = re.compile(r'\n(\(?[0-9]+[a-z]+[\.|\)])\n')
    # combine lines consisting of Roman numerals to 9 with the next line
    pattern_4 = re.compile(r'\n(\(?i{1,3}[\.|\)])\n')  # 1-3
    pattern_5 = re.compile(r'\n(\(?iv[\.|\)])\n')  # 4
    pattern_6 = re.compile(r'\n(\(?vi{0,3}[\.|\)])\n')  # 5-8
    pattern_7 = re.compile(r'\n(\(?ix[\.|\)])\n')  # 9
    # simplification means removal of the dot after numbers
    if simplify:
        # combine single lines consisting of numbers/letters with next line
        pattern_1 = re.compile(r'\n\(?([0-9]+|[a-z]+|[A-Z]+)[\.|\)]\n')
        # combine single lines consisting of single number + single letter
        # with the next line
        pattern_3 = re.compile(r'\n\(?([0-9]+[a-z]+)[\.|\)]\n')
        # combine lines consisting of Roman numerals to 9 with the next line
        pattern_4 = re.compile(r'\n\(?(i{1,3})[\.|\)]\n')  # 1-3
        pattern_5 = re.compile(r'\n\(?(iv)[\.|\)]\n')  # 4
        pattern_6 = re.compile(r'\n\(?(vi{0,3})[\.|\)]\n')  # 5-8
        pattern_7 = re.compile(r'\n\(?(ix)[\.|\)]\n')  # 9
        # the replacements
        text = re.sub(pattern_1, r'\n(\1) ', text)
        text = re.sub(pattern_3, r'\n(\1) ', text)
        text = re.sub(pattern_4, r'\n(\1) ', text)
        text = re.sub(pattern_5, r'\n(\1) ', text)
        text = re.sub(pattern_6, r'\n(\1) ', text)
        text = re.sub(pattern_7, r'\n(\1) ', text)
    # the replacements:
    text = re.sub(pattern_1, r'\n\1 ', text)
    text = re.sub(pattern_3, r'\n\1 ', text)
    text = re.sub(pattern_4, r'\n\1 ', text)
    text = re.sub(pattern_5, r'\n\1 ', text)
    text = re.sub(pattern_6, r'\n\1 ', text)
    text = re.sub(pattern_7, r'\n\1 ', text)
    return text


def scraper(langs, make_link, error_text, url_code, prefix, is_celex=False,
            is_ep=False):
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
                    elif is_ep:
                        clean_text = strip_ep(clean_text)
                    f.write(clean_text)
            else:
                print "Error in link " + url_code + " " + lang_code + "."


def remove_p(input_name, output_name):
    empty_line = '<P>\n'
    with codecs.open(output_name, "w", "utf-8") as fout:
        with codecs.open(input_name, "r", "utf-8") as fin:
            for line in fin:
                if line != empty_line:
                    fout.write(line)


def create_dictionary(input_source, input_target, output_file):
    with codecs.open(input_source, "r", "utf-8") as sin:
        s_list = list(sin)
    with codecs.open(input_target, "r", "utf-8") as tin:
        t_list = list(tin)
    if len(s_list) == len(t_list) and len(s_list) != 0:
        with codecs.open(output_file, "w", "utf-8") as fout:
            for i in range(len(s_list)):
                s_term = s_list[i].rstrip()
                t_term = t_list[i].rstrip()
                if len(s_term) > 0 and len(t_term) > 0:
                    line_to_add = t_term + ' @ ' + s_term + '\r\n'
                    fout.write(line_to_add)
    else:
        print "Dictionary files of different lenght or length = 0. Aborting."



def tab_to_separate(input_name, output_source, output_target):
    with codecs.open(input_name, "r", "utf-8") as fin:
        with codecs.open(output_source, "w", "utf-8") as out_s:
            with codecs.open(output_target, "w", "utf-8") as out_t:
                for line in fin:
                    line = line.strip('\n')
                    text = re.split(r'\t', line)
                    source = text[2]
                    target = text[1]
                    out_s.write(source + '\n')
                    out_t.write(target + '\n')


def tab_to_tmx(input_name, tmx_name, s_lang, t_lang, note):
    # TODO de verificat in Workbench
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
                source = text[2].strip('\n')
                target = text[1]
                # remove triple tildas from hunalign
                source = source.replace('~~~ ', '')
                target = target.replace('~~~ ', '')
                #   create TU line
                tu = '<tu creationdate="' + current_date + \
                     '" creationid="eunlp"><prop type="Txt::Note">' + \
                     note + '</prop>\n'
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


def splitter_wrapper(lang, input_file, output_file, program_folder):
    command = 'perl ' + program_folder + '/' + \
              'sentence_splitter/split-sentences.perl -l ' + lang + ' < ' + \
              input_file + '> ' + output_file
    subprocess.check_output(command, shell=True)


def tokenizer_wrapper(lang, input_file, output_file, program_folder):
    command = 'perl ' + program_folder + '/' + \
              'tokenizer.perl -l ' + lang + ' < ' + input_file + ' > '\
              + output_file
    subprocess.check_output(command, shell=True)

def hunalign_wrapper(source_file, target_file, dictionary, align_file,
                     program_folder, realign=True):
    realign_parameter = ''
    if realign:
        realign_parameter = '-realign '
    command = program_folder + '/' + \
        'hunalign-1.1/src/hunalign/hunalign -utf ' + realign_parameter + \
        dictionary + ' ' + source_file + ' ' + target_file + ' > ' \
        + align_file
    subprocess.check_output(command, shell=True)


def file_to_list(file_name):
    # clean convert file to list of paragraphs
    with codecs.open(file_name, "r", "utf-8") as fin:
        text = fin.read()
    text = re.sub(r'\n\s+', r'\n', text)  # remove whitespace after newline
    text = re.sub(r'\n+', r'\n', text)  # remove empty lines
    text = re.sub(r'^\n+', r'', text)  # remove empty lines at the beginning
    text = re.sub(r'\n$', r'', text)  # remove empty lines at the end
    text = re.sub(r',\s\n', r', ', text)  # merge segments separated by comma
    text = paragraph_combiner_sub(text)  # combine para numbers with text
    paragraph_list = re.split(r'\n', text)  # split file
    return paragraph_list


def ep_aligner(source_file, target_file, s_lang, t_lang, dictionary,
                   align_file, program_folder, note, para_size=1000):
    # Exemplu in Python console:
    # functions.ep_aligner("A720120002_EN.txt", "A720120002_RO.txt", "en", "ro", "enro.dic", "bi_test", "/home/filip/eunlp", "A720120002", 500)
    # TODO split lines at the beginning and at the end; language dependent
    source_list = file_to_list(source_file)
    target_list = file_to_list(target_file)
    # If different number of paragraphs
    if len(source_list) != len(target_list):
        # call classic aligner
        print "Different number of paras, yielding to hunalign in ", \
            source_file
        aligner(source_file, target_file, s_lang, t_lang, dictionary,
                align_file, program_folder, note, delete_temp=True)
        return None
    # If same number of paragraphs:
    with codecs.open(align_file + '.tab', "w", "utf-8") as fout:
        for i in range(len(source_list)):
            if len(source_list[i]) < para_size:
                line = "1\t" + target_list[i] + "\t" + source_list[i] + \
                       "\n"
                fout.write(line)
            else:
                print "Creating temporary file from large paragraph ", i, \
                    "..."
                # create temporary files from paragraphs
                # mkdir /tmp/eunlp
                if not os.path.exists("/tmp/eunlp"):
                    os.makedirs("/tmp/eunlp")
                # create random file names
                r_num = str(random.randint(0, 100000))
                temp_source = "/tmp/eunlp/s_" + r_num + ".txt"
                temp_target = "/tmp/eunlp/t_" + r_num + ".txt"
                temp_align = "/tmp/eunlp/align_" + r_num
                # write the two files
                with codecs.open(temp_source, "w", "utf-8") as sout:
                    sout.write(source_list[i])
                with codecs.open(temp_target, "w", "utf-8") as tout:
                    tout.write(target_list[i])
                # process them with the classic aligner
                aligner(temp_source, temp_target, s_lang, t_lang,
                        dictionary, temp_align, program_folder, "a_" + r_num,
                        delete_temp=False)
                # open tab file created by classic aligner
                with codecs.open(temp_align + '_' + s_lang + '_' + t_lang +
                                 ".tab", "r", "utf-8") as fin:
                    lines = list(fin)
                # and merge resulting alignment into the current tab file
                # TODO de verificat daca returneaza segmente ok
                # TODO o problema e cu 1. vs (1); de unificat in preprocesare?
                # TODO de respins rezultate cu segmente goale
                # TODO de marit para_size? 500 mult mai bun ca 300!
                # TODO de verificat daca a ignorat text?
                # TODO de verificat diferente foarte mari de dimensiune s/t
                # TODO sentence splitter de la zero?
                for i in range(len(lines)):
                    split_line = re.split("\t", lines[i])
                    if len(split_line) == 3: # avoid out of range errors
                        new_line = "1\t" + split_line[1] + "\t" + \
                                   split_line[2]
                        fout.write(new_line)
    # turn alignment into tmx
    tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang, t_lang, note)
    # create parallel source and target text files
    tab_to_separate(align_file + '.tab', source_file[:-4] + '.ali',
                    target_file[:-4] + '.ali')


def aligner(source_file, target_file, s_lang, t_lang, dictionary, align_file,
            program_folder, note, delete_temp=True):
    # sentence splitter; resulting file are with the .sp1 extension
    # TODO use pipe where possible, too many files!
    # http://stackoverflow.com/questions/4514751/pipe-subprocess-standard-output-to-a-variable
    #
    # TODO in germana nu separa "... Absaetze 5 und 6. Diese ..."
    # TODO eventual alt splitter cu supervised learning pt DE?
    splitter_wrapper(s_lang, source_file, source_file[:-4] + '.sp1',
                     program_folder)
    splitter_wrapper(t_lang, target_file, target_file[:-4] + '.sp1',
                     program_folder)
    # remove < P > and create files with extension .sp2
    remove_p(source_file[:-4] + ".sp1", source_file[:-4] + '.sp2')
    remove_p(target_file[:-4] + ".sp1", target_file[:-4] + '.sp2')
    # combine paragraphs and create files without extension
    paragraph_combiner(source_file[:-4] + '.sp2', source_file[:-4])
    paragraph_combiner(target_file[:-4] + '.sp2', target_file[:-4])
    # tokenizer and create files with the .tok extension
    tokenizer_wrapper(s_lang, source_file[:-4], source_file[:-4] + '.tok',
                      program_folder)
    tokenizer_wrapper(t_lang, target_file[:-4], target_file[:-4] + '.tok',
                      program_folder)
    # create empty hunalign dic from program-folder/data_raw files
    if not os.path.exists(dictionary):
        create_dictionary(program_folder + '/data_raw/' + s_lang + '.txt',
                          program_folder + '/data_raw/' + t_lang + '.txt',
                          dictionary)
    # create hunalign ladder alignment
    align_file = align_file + '_' + s_lang + '_' + t_lang
    hunalign_wrapper(source_file[:-4] + '.tok', target_file[:-4] + '.tok',
                     dictionary, align_file + '.lad', program_folder,
                     realign=True)
    # create aligned output
    output_lines = ladder2text_new.create_output_lines(align_file + '.lad',
                                                       source_file[:-4],
                                                       target_file[:-4])
    with codecs.open(align_file + '.tab', "w", "utf-8") as fout:
        for line in output_lines:
            fout.write(unicode(line, "utf-8") + '\n')
    # turn alignment into tmx
    tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang, t_lang, note)
    # create parallel source and target text files
    tab_to_separate(align_file + '.tab', source_file[:-4] + '.ali',
                    target_file[:-4] + '.ali')
    # remove files without extension
    if delete_temp:
        os.remove(source_file[:-4])
        os.remove(target_file[:-4])
        # remove .spl files
        os.remove(source_file[:-4] + ".sp1")
        os.remove(target_file[:-4] + ".sp1")
        # remove.sp2 files
        os.remove(source_file[:-4] + ".sp2")
        os.remove(target_file[:-4] + ".sp2")
        # remove .tok files
        os.remove(source_file[:-4] + ".tok")
        os.remove(target_file[:-4] + ".tok")
        # remove .html files
        os.remove(source_file[:-4] + ".html")
        os.remove(target_file[:-4] + ".html")
        # remove .txt files
        os.remove(source_file[:-4] + ".txt")
        os.remove(target_file[:-4] + ".txt")
