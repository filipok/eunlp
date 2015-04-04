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
import subprocess
import random
import logging

import nltk
from nltk.tokenize.punkt import PunktSentenceTokenizer, PunktParameters

from . import ladder2text_new as l2t
from . import util
from . import convert
from . import down
# TODO remove useless folders
# TODO test test1.xml, test2.xml
# TODO test simultaneous alignment with all languages


def paragraph_combiner_sub(text):
    pattern_1 = re.compile(
        r'\n\(?([0-9]{1,3}|[a-z]{1,3}|[A-Z]{1,3})[\.\)][\n\s]')
    # combine single lines consisting of single number + single letter
    # with the next line
    pattern_3 = re.compile(r'\n\(?([0-9]+[a-z]+)[\.\)][\n\s]')
    # combine lines consisting of Roman numerals to 9 with the next line
    pattern_4 = re.compile(r'\n\(?(i{1,3})[\.\)][\n\s]')  # 1-3
    pattern_5 = re.compile(r'\n\(?(iv)[\.\)][\n|\s]')  # 4
    pattern_6 = re.compile(r'\n\(?(vi{0,3})[\.\)][\n\s]')  # 5-8
    pattern_7 = re.compile(r'\n\(?(ix)[\.\)][\n\s]')  # 9
    # the replacements
    text = re.sub(pattern_1, '\n', text)
    text = re.sub(pattern_3, r'\n', text)
    text = re.sub(pattern_4, r'\n', text)
    text = re.sub(pattern_5, r'\n', text)
    text = re.sub(pattern_6, r'\n', text)
    text = re.sub(pattern_7, r'\n', text)
    return text


def hunalign_wrapper(source_file, target_file, dictionary, align_file,
                     program_folder, realign=True):
    realign_parameter = '-realign'
    if realign:
        command = [program_folder + 'hunalign-1.1/src/hunalign/hunalign',
                   '-utf', realign_parameter, dictionary, source_file,
                   target_file]
    else:
        command = [program_folder + 'hunalign-1.1/src/hunalign/hunalign',
                   '-utf', dictionary, source_file, target_file]
    proc = subprocess.Popen(command, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    output, err = proc.communicate()
    with codecs.open(align_file, 'w', 'utf-8') as f:
        f.write(unicode(output, 'utf-8'))


def file_to_list(file_name, one=False, two=False):
    # clean and convert file to list of paragraphs
    with codecs.open(file_name, "r", "utf-8") as fin:
        text = fin.read()
    text = re.sub(r'\xa0+', ' ', text)  # replace non-breaking space
    text = re.sub(r'\n\s+', r'\n', text)  # remove whitespace after newline
    text = re.sub(r'^\n+', r'', text)  # remove empty lines at the beginning
    text = re.sub(r'\n$', r'', text)  # remove empty lines at the end
    # merge segments separated by comma and whitespace, with some exceptions
    # which are language-dependent unfortunately
    # re.sub(r',\s\n(?!Whereas|Having regard|In cooperation)', r', ', text)
    text = re.sub(r'\s+\n', r'\n', text)  # remove whitespace before newline
    text = re.sub(r' +', r' ', text)  # remove double whitespaces
    text = paragraph_combiner_sub(text)  # combine para numbers with text
    if one:
        # remove one-character lines which can make the aligner to fail
        text = re.sub(r'\n.(?=\n)', r'', text)
        # also try to remove two-character lines which can make it to fail
        if two:
            text = re.sub(r'\n.{1,2}(?=\n)', r'', text)
    paragraph_list = re.split(r'\n', text)  # split file
    return paragraph_list


def smart_aligner(source_file, target_file, s_lang, t_lang, dictionary,
                  align_file, program_folder, note, over=True, para_size=300,
                  para_size_small=100):
    # functions.smart_aligner("A720120002_EN.txt", "A720120002_RO.txt", "en",
    # "ro", "enro.dic", "bi_test", "/home/filip/eunlp/", "A720120002")
    if (not over) and os.path.isfile(align_file + '.tab'):
        logging.warning("File pair already aligned: %s", align_file)
        return  # exit if already aligned and over=False
    source_list = file_to_list(source_file)
    target_list = file_to_list(target_file)
    # If different No of paragraphs, make 2 more attempts to process the files
    if len(source_list) != len(target_list):
        source_list = file_to_list(source_file, one=True)
        target_list = file_to_list(target_file, one=True)
        if len(source_list) != len(target_list):
            source_list = file_to_list(source_file, one=True, two=True)
            target_list = file_to_list(target_file, one=True, two=True)
            if len(source_list) != len(target_list):
                logging.error('Smart alignment failed in %s-%s, %s, %s',
                              s_lang, t_lang, source_file, target_file)
                # Using Hunalign on the entire file is mostly useless.
                # aligner(source_file, target_file, s_lang, t_lang, dictionary,
                #         align_file, program_folder, note, delete_temp=True)
                return
            else:
                logging.warning('Alignment at 3rd attempt in %s-%s, %s, %s',
                                s_lang, t_lang, source_file, target_file)
        else:
            logging.warning('Alignment at 2nd attempt in %s-%s, %s', s_lang,
                            t_lang, source_file, target_file)
    # If equal number of paragraphs:
    parallel_aligner(source_list, target_list, s_lang, t_lang, dictionary,
                     align_file, program_folder, para_size=para_size,
                     para_size_small=para_size_small, prj_name=source_file)
    # turn alignment into tmx
    convert.tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang,
                       t_lang, note)
    # create parallel source and target text files
    s_ali = source_file[:-4] + '_' + s_lang + t_lang + '.ali'
    t_ali = target_file[:-4] + '_' + s_lang + t_lang + '.ali'
    convert.tab_to_separate(align_file + '.tab', s_ali, t_ali)


def parallel_aligner(s_list, t_list, s_lang, t_lang, dictionary,
                     align_file, program_folder, para_size=300,
                     para_size_small=100, prj_name='temp'):
    if not os.path.exists("/tmp/eunlp"):
        os.makedirs("/tmp/eunlp")
    fout = codecs.open(align_file + '.tab', "w", "utf-8")
    # send paragraph to hunalign if large or if intermediate and
    # both source and target have a dot followed by whitespace.
    patt = re.compile(r'\. ')
    # create sentence splitters
    s_sentence_splitter = sentence_splitter(program_folder, s_lang)
    t_sentence_splitter = sentence_splitter(program_folder, t_lang)
    for i in range(len(s_list)):
        small = len(s_list[i]) < para_size_small
        n_pat = not (re.search(patt, s_list[i]) and re.search(patt, t_list[i]))
        clean_intermediate = ((len(s_list[i]) < para_size) and
                              (len(s_list[i]) >= para_size_small) and n_pat)
        if small or clean_intermediate:
            line = ''.join(["Nai\t", t_list[i], "\t", s_list[i], "\n"])
            fout.write(line)
        else:
            tmp_aligner(s_list[i], t_list[i], s_lang, t_lang, dictionary,
                        program_folder, fout, prj_name, i, s_sentence_splitter,
                        t_sentence_splitter)
    fout.close()


def tmp_aligner(source, target, s_lang, t_lang, dictionary, program_folder,
                fout, prj_name, i, s_sentence_splitter, t_sentence_splitter):
    r_num = str(random.randint(0, 100000))
    tmp_source = "/tmp/eunlp/s_" + r_num + ".txt"
    tmp_target = "/tmp/eunlp/t_" + r_num + ".txt"
    tmp_align = "/tmp/eunlp/align_" + r_num
    # write the two files
    with codecs.open(tmp_source, "w", "utf-8") as sout:
        sout.write(source + '\n')
    with codecs.open(tmp_target, "w", "utf-8") as tout:
        tout.write(target + '\n')
    # process them with the classic aligner
    lines = basic_aligner(tmp_source, tmp_target, s_lang, t_lang, dictionary,
                          tmp_align, program_folder, "a_" + r_num,
                          s_sentence_splitter, t_sentence_splitter, tab=False,
                          tmx=False, sep=False)
    # do some checks with the hunalign aligment and use only if ok
    everything_ok = check_hunalign(lines, source, target)
    if everything_ok[0]:
        fout.write(everything_ok[1])
    else:
        logging.info("Hunalign failed in segment %s in file %s.", str(i),
                     prj_name)
        line = ''.join(["Err\t", target, "\t", source, "\n"])
        fout.write(line)
    # remove temporary files
    os.remove(tmp_source)
    os.remove(tmp_target)
    os.remove(tmp_align + '.lad')


def check_hunalign(lines, full_source, full_target):
    counter_s = 0
    counter_t = 0
    text = ''
    everything_ok = True
    for i in range(len(lines)):
        split_line = re.split("\t", lines[i])
        new_line = ''.join(["Hun\t", split_line[1], "\t", split_line[2]])
        text += new_line
        counter_s += len(split_line[2]) + 1
        counter_t += len(split_line[1]) + 1
        if len(split_line[1]) > 0:
            translation_ratio = float(
                len(split_line[2]))/len(split_line[1])
        else:
            translation_ratio = 0
        # check source and target size
        if not(0.5 < translation_ratio < 2.0):
            everything_ok = False
        # check segment length
        if len(split_line[2]) < 2 or len(split_line[1]) < 2:
            everything_ok = False
    # check total characters (hunalign drops text sometimes)
    if counter_s < len(full_source) or counter_t < len(full_target):
        everything_ok = False
    return everything_ok, text


def split_token_nltk(file_name, sent_splitter):
    # Source for sentence tokenizer:
    # stackoverflow.com/
    # questions/14095971/how-to-tweak-the-nltk-sentence-tokenizer

    # read file
    with codecs.open(file_name, 'r', 'utf-8') as f:
        text = list(f)
    # sentence splitter line by line
    # Source: https://groups.google.com/forum/#!topic/nltk-dev/2eH630nHONI
    # because Punkt ignores line breaks
    sentence_list = []
    for line in text:
        sentences = sent_splitter.tokenize(line)
        sentence_list.extend(sentences)
    # write file without extension
    with codecs.open(file_name[:-4], 'w', 'utf-8') as f:
        for sent in sentence_list:
            f.write(sent + '\n')
        # remove last new line
        # stackoverflow.com/
        # questions/18857352/python-remove-very-last-character-in-file
        f.seek(-1, os.SEEK_END)
        f.truncate()

    # word tokenizer
    tokenized_sentences = [nltk.word_tokenize(sent) for sent in sentence_list]
    # write .tok file
    with codecs.open(file_name[:-4] + '.tok', 'w', 'utf-8') as f:
        for sent in tokenized_sentences:
            f.write(' '.join(sent) + '\n')


def sentence_splitter(program_folder, lang):
    punkt_param = PunktParameters()
    subfolder = 'sentence_splitter/nonbreaking_prefixes/nonbreaking_prefix.'
    ab_file = ''.join([program_folder, subfolder, lang])
    if os.path.isfile(ab_file):
        punkt_param.abbrev_types = set(util.abbreviation_loader(ab_file))
    else:
        logging.info('Abbreviation file not found for language: %s', lang)
    splitter = PunktSentenceTokenizer(punkt_param)
    return splitter


def basic_aligner(s_file, t_file, s_lang, t_lang, dic, a_file, program_folder,
                  note, s_sentence_splitter, t_sentence_splitter, tab=True,
                  tmx=True, sep=True):
    # TODO eliminate program_folder
    # call splitter & aligner
    split_token_nltk(s_file, s_sentence_splitter)
    split_token_nltk(t_file, t_sentence_splitter)
    # create empty hunalign dic from program-folder/data_raw files
    if not os.path.exists(dic):
        path = program_folder + 'data_raw/'
        try:
            util.create_dictionary(path + s_lang + '.txt',
                                   path + t_lang + '.txt', dic)
        except IOError:
            open(dic, 'a').close()  # create empty dictionary
            logging.warning('Creating empty dictionary %s', dic)
    # create hunalign ladder alignment
    hunalign_wrapper(s_file[:-4] + '.tok', t_file[:-4] + '.tok', dic,
                     a_file + '.lad', program_folder, realign=True)
    # create aligned output
    output_lines = l2t.make_lines(a_file + '.lad', s_file[:-4], t_file[:-4])
    output_lines = [unicode(line, "utf-8") + '\n' for line in output_lines]
    # writing .tab, .tmx and parallel .sep source and target files
    if tab:
        with codecs.open(a_file + '.tab', "w", "utf-8") as fout:
            for line in output_lines:
                fout.write(line)
        if tmx:
            convert.tab_to_tmx(a_file + '.tab', a_file + '.tmx', s_lang,
                               t_lang, note)
        if sep:
            s_ali = s_file[:-4] + '_' + s_lang + t_lang + '.ali'
            t_ali = t_file[:-4] + '_' + s_lang + t_lang + '.ali'
            convert.tab_to_separate(a_file + '.tab', s_ali, t_ali)
    # remove temporary files
    os.remove(s_file[:-4])
    os.remove(t_file[:-4])
    os.remove(s_file[:-4] + ".tok")
    os.remove(t_file[:-4] + ".tok")
    return output_lines


def celex_aligner(langs, path, celex, prefix, program_folder):
    # create html and txt files for each language code
    try:
        down.scraper(langs, util.make_celex_link, celex, prefix, style="celex",
                     over_html=False, over_txt=False)
    except urllib2.HTTPError:
        logging.error("Aborting alignment due to link error in %s.", celex)
    else:
        # prepare paths
        s_file, t_file, align_file, dic = util.make_paths(path, prefix + celex,
                                                          langs)
        # call the aligner
        smart_aligner(s_file, t_file, langs[0].lower(), langs[1].lower(),
                      dic, align_file, program_folder, celex, over=False)