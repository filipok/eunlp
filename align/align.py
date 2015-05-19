"""
Name:        align.py
Purpose:     Various project functions

Author:      Filip

Created:     4.11.2014
"""

import urllib2
import codecs
import re
import os
import subprocess
import random
import logging
import nltk
from nltk.tokenize.punkt import PunktSentenceTokenizer, PunktParameters
from . import l2t_new as l2t
from . import util
from . import convert
from . import down


def paragraph_combiner_sub(text):
    """

    :type text: str
    :rtype: str
    """
    # pattern 1 combines 1-3 letters/numbers with dot/brackets with next line
    # pattern_1 = re.compile(
    #     r'\n\(?([0-9]{1,3}|[a-z]{1,3}|[A-Z]{1,3})[\.\)][\n\s]')
    pattern_1_unicode = re.compile(r'\n\(?(\w{1,3})[\.\)][\n\s]', re.UNICODE)
    # pattern 3 combines single number + single letter with the next line
    # pattern_3 = re.compile(r'\n\(?([0-9]+[a-z]+)[\.\)][\n\s]')
    pattern_3_unicode = re.compile(r'\n\(?([0-9]+\w+)[\.\)][\n\s]', re.UNICODE)
    # combine lines consisting of Roman numerals to 9 with the next line
    pattern_4 = re.compile(r'\n\(?(i{1,3})[\.\)][\n\s]')  # 1-3
    pattern_5 = re.compile(r'\n\(?(iv)[\.\)][\n|\s]')  # 4
    pattern_6 = re.compile(r'\n\(?(vi{0,3})[\.\)][\n\s]')  # 5-8
    pattern_7 = re.compile(r'\n\(?(ix)[\.\)][\n\s]')  # 9
    # the replacements
    text = re.sub(pattern_1_unicode, r'\n', text)
    text = re.sub(pattern_3_unicode, r'\n', text)
    text = re.sub(pattern_4, r'\n', text)
    text = re.sub(pattern_5, r'\n', text)
    text = re.sub(pattern_6, r'\n', text)
    text = re.sub(pattern_7, r'\n', text)
    return text


def hunalign_wrapper(source_file, target_file, dictionary, align_file,
                     realign=True):
    """

    :type source_file: str
    :type target_file: str
    :type dictionary: str
    :type align_file: str
    :type realign: bool
    """
    path = os.path.dirname(__file__)
    realign_parameter = '-realign'
    if realign:
        command = [path + '/hunalign-1.1/src/hunalign/hunalign',
                   '-utf', realign_parameter, dictionary, source_file,
                   target_file]
    else:
        command = [path + '/hunalign-1.1/src/hunalign/hunalign',
                   '-utf', dictionary, source_file, target_file]
    proc = subprocess.Popen(command, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    output, err = proc.communicate()
    with codecs.open(align_file, 'w', 'utf-8') as fout:
        fout.write(unicode(output, 'utf-8'))


def file_to_list(file_name, tries=0):
    # clean and convert file to list of paragraphs
    """

    :type file_name: str
    :type tries: int
    :rtype: list
    """
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
    if tries in [1, 2, 3]:
        # remove one-character lines which can make the aligner to fail
        text = re.sub(r'\n.(?=\n)', r'', text)
    if tries in [2, 3]:
        # also try to remove two-character lines which can make it to fail
        text = re.sub(r'\n.{1,2}(?=\n)', r'', text)
    if tries == 3:
        # also try to remove three-character lines which can make it to fail
        text = re.sub(r'\n.{1,3}(?=\n)', r'', text)
    paragraph_list = re.split(r'\n', text)  # split file
    return paragraph_list


def smart_aligner(source_file, target_file, s_lang, t_lang, dictionary,
                  align_file, note, over=True, para_size=300,
                  para_size_small=100, make_dic=True, compress=False):
    # functions.smart_aligner("A720120002_EN.txt", "A720120002_RO.txt", "en",
    # "ro", "enro.dic", "bi_test", "/home/filip/eunlp/", "A720120002")
    """

    :type source_file: str
    :type target_file: str
    :type s_lang: str
    :type t_lang: str
    :type dictionary: str
    :type align_file: str
    :type note: str
    :type over: bool
    :type para_size: int
    :type para_size_small: int
    :type make_dic: bool
    :type compress: bool
    :rtype: None
    """
    if (not over) and (
            os.path.isfile(align_file + '.tab') or
            os.path.isfile(align_file + '.err.html') or
            os.path.isfile(align_file + '.tab.gz')):
        logging.warning("File pair already aligned: %s", align_file)
        return  # exit if already aligned and over=False
    source_list = file_to_list(source_file)
    target_list = file_to_list(target_file)
    # If different No of paragraphs, make 3 more attempts to process the files
    if len(source_list) != len(target_list):
        source_list = file_to_list(source_file, tries=1)
        target_list = file_to_list(target_file, tries=1)
        if len(source_list) != len(target_list):
            source_list = file_to_list(source_file, tries=2)
            target_list = file_to_list(target_file, tries=2)
            if len(source_list) != len(target_list):
                source_list = file_to_list(source_file, tries=3)
                target_list = file_to_list(target_file, tries=3)
                if len(source_list) != len(target_list):
                    logging.error('Smart alignment failed in %s-%s, %s, %s',
                                  s_lang, t_lang, source_file, target_file)
                    source_list = file_to_list(source_file)
                    target_list = file_to_list(target_file)
                    convert.html_table(
                        source_list, target_list, align_file + '.err.html',
                        page_title=align_file)
                    # Using Hunalign on the entire file is mostly useless.
                    # aligner(source_file, target_file, s_lang, t_lang,
                    #         dictionary, align_file, note, delete_temp=True)
                    return
                else:
                    logging.warning('Aligned at 4th attempt in %s-%s, %s, %s',
                                    s_lang, t_lang, source_file, target_file)
            else:
                logging.warning('Aligned at 3rd attempt in %s-%s, %s, %s',
                                s_lang, t_lang, source_file, target_file)
        else:
            logging.warning('Aligned at 2nd attempt in %s-%s, %s, %s',
                            s_lang, t_lang, source_file, target_file)
    # If equal number of paragraphs:
    try:
        parallel_aligner(source_list, target_list, s_lang, t_lang, dictionary,
                         align_file, para_size=para_size,
                         para_size_small=para_size_small, prj=source_file,
                         make_dic=make_dic)
        # turn alignment into tmx
        convert.tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang,
                           t_lang, note)
        # create parallel source and target text files
        s_ali = source_file[:-4] + '_' + s_lang + t_lang + '.ali'
        t_ali = target_file[:-4] + '_' + s_lang + t_lang + '.ali'
        convert.tab_to_separate(align_file + '.tab', s_ali, t_ali)
        if compress:
            convert.gzipper(align_file + '.tab')
            convert.gzipper(align_file + '.tmx')
            convert.gzipper(s_ali)
            convert.gzipper(t_ali)
    except StopIteration:
        logging.error('StopIteration in %s -> %s, %s', note, source_file,
                      target_file)


def parallel_aligner(s_list, t_list, s_lang, t_lang, dictionary,
                     align_file, para_size=300, para_size_small=100,
                     prj='temp', make_dic=True):
    """

    :type s_list: list
    :type t_list: list
    :type s_lang: str
    :type t_lang: str
    :type dictionary: str
    :type align_file: str
    :type para_size: int
    :type para_size_small: int
    :type prj: str
    :type make_dic: bool
    """
    if not os.path.exists("/tmp/eunlp"):
        os.makedirs("/tmp/eunlp")
    fout = codecs.open(align_file + '.tab', "w", "utf-8")
    # send paragraph to hunalign if large or if intermediate and
    # both source and target have a dot followed by whitespace.
    patt = re.compile(r'\. ')
    # create sentence splitters
    s_sentence_splitter = sentence_splitter(s_lang)
    t_sentence_splitter = sentence_splitter(t_lang)
    for i in range(len(s_list)):
        # boolean values (small, pattern not found, intermediate & no pattern)
        small = len(s_list[i]) < para_size_small
        n_pat = not (re.search(patt, s_list[i]) and re.search(patt, t_list[i]))
        clean_intermediate = ((len(s_list[i]) < para_size) and
                              (len(s_list[i]) >= para_size_small) and n_pat)
        if small or clean_intermediate:
            line = ''.join(["Nai\t", t_list[i], "\t", s_list[i], "\n"])
            fout.write(line)
        else:
            try:
                tmp_aligner(s_list[i], t_list[i], s_lang, t_lang, dictionary,
                            fout, prj, i, s_sentence_splitter,
                            t_sentence_splitter, make_dic)
            except StopIteration:
                logging.error('StopIteration %s: Source: %s', prj, s_list[i])
                logging.error('StopIteration %s: Target: %s', prj, t_list[i])
                raise
    fout.close()


def tmp_aligner(source, target, s_lang, t_lang, dictionary, fout, prj_name, i,
                s_sentence_splitter, t_sentence_splitter, make_dic=True):
    """

    :type source: str
    :type target: str
    :type s_lang: str
    :type t_lang: str
    :type dictionary: str
    :type fout: file
    :type prj_name: str
    :type i: int
    :type s_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    :type t_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    :type make_dic: bool
    """
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
    try:
        lines = basic_aligner(tmp_source, tmp_target, s_lang, t_lang,
                              dictionary, tmp_align, "a_" + r_num,
                              s_sentence_splitter, t_sentence_splitter,
                              tab=False, tmx=False, sep=False,
                              make_dic=make_dic)
    except StopIteration:
        raise
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
    """

    :type lines: list
    :type full_source: str
    :type full_target: str
    :rtype: tuple
    """
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
        if not (0.5 < translation_ratio < 2.0):
            everything_ok = False
        # check segment length
        if len(split_line[2]) < 2 or len(split_line[1]) < 2:
            everything_ok = False
    # check total characters (hunalign drops text sometimes)
    if counter_s < len(full_source) or counter_t < len(full_target):
        everything_ok = False
    return everything_ok, text


def split_token_nltk(file_name, sent_splitter):
    """

    :type file_name: str
    :type sent_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    """
    # Source for sentence tokenizer:
    # stackoverflow.com/
    # questions/14095971/how-to-tweak-the-nltk-sentence-tokenizer

    # read file
    with codecs.open(file_name, 'r', 'utf-8') as fin:
        text = list(fin)
    # sentence splitter line by line
    # Source: https://groups.google.com/forum/#!topic/nltk-dev/2eH630nHONI
    # because Punkt ignores line breaks
    sentence_list = []
    for line in text:
        sentences = sent_splitter.tokenize(line)
        sentence_list.extend(sentences)
    # write file without extension
    with codecs.open(file_name[:-4], 'w', 'utf-8') as fout:
        for sent in sentence_list:
            fout.write(sent + '\n')
        # remove last new line
        # stackoverflow.com/
        # questions/18857352/python-remove-very-last-character-in-file
        fout.seek(-1, os.SEEK_END)
        fout.truncate()

    # word tokenizer
    tokenized_sentences = [nltk.word_tokenize(sent) for sent in sentence_list]
    # write .tok file
    with codecs.open(file_name[:-4] + '.tok', 'w', 'utf-8') as fout:
        for sent in tokenized_sentences:
            fout.write(' '.join(sent) + '\n')


def sentence_splitter(lang):
    """

    :type lang: str
    :rtype: nltk.tokenize.punkt.PunktSentenceTokenizer
    """
    punkt_param = PunktParameters()
    path = os.path.dirname(__file__)
    subfolder = '/nonbreaking_prefixes/nonbreaking_prefix.'
    ab_file = ''.join([path, subfolder, lang])
    if os.path.isfile(ab_file):
        punkt_param.abbrev_types = set(util.abbreviation_loader(ab_file))
    else:
        logging.info('Abbreviation file not found for language: %s', lang)
    splitter = PunktSentenceTokenizer(punkt_param)
    return splitter


def basic_aligner(s_file, t_file, s_lang, t_lang, dic, a_file, note,
                  s_sentence_splitter, t_sentence_splitter, tab=True,
                  tmx=True, sep=True, make_dic=True):
    # call splitter & aligner
    """

    :type s_file: str
    :type t_file: str
    :type s_lang: str
    :type t_lang: str
    :type dic: str
    :type a_file: str
    :type note: str
    :type s_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    :type t_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    :type tab: bool
    :type tmx: bool
    :type sep: bool
    :type make_dic: bool
    :rtype: list
    """
    # create tokenized files for hunalign
    split_token_nltk(s_file, s_sentence_splitter)
    split_token_nltk(t_file, t_sentence_splitter)
    # create hunalign dic from /data_raw files
    if make_dic:
        if not os.path.exists(dic):
            path = os.path.dirname(__file__) + '/data_raw/'
            try:
                util.create_dictionary(path + s_lang + '.txt',
                                       path + t_lang + '.txt', dic)
            except IOError:
                open(dic, 'a').close()  # create empty dictionary
                logging.warning('Creating empty dictionary %s', dic)
    else:
        open(dic, 'w').close()  # create empty dict (and erase current file!)
    # create hunalign ladder alignment
    hunalign_wrapper(s_file[:-4] + '.tok', t_file[:-4] + '.tok', dic,
                     a_file + '.lad', realign=True)
    # create aligned output
    try:
        lines = l2t.make_lines(a_file + '.lad', s_file[:-4], t_file[:-4])
    except StopIteration:
        raise
    lines = [unicode(line, "utf-8") + '\n' for line in lines]
    # writing .tab, .tmx and parallel .sep source and target files
    if tab:
        with codecs.open(a_file + '.tab', "w", "utf-8") as fout:
            for line in lines:
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
    return lines


def celex_aligner(langs, path, celex, prefix, make_dic=True, compress=False):
    """

    :type langs: list
    :type path: str
    :type celex: str
    :type prefix: str
    :type make_dic: bool
    :type compress: bool
    """
    # create html and txt files for each language code
    try:
        down.scraper(langs, util.make_celex_link, celex, prefix, style="celex",
                     over_html=False, over_txt=False)
    except urllib2.HTTPError:
        logging.error("Aborting alignment due to link error in %s.", celex)
    except (IndexError, AttributeError):
        logging.error("Aborting alignment due to format error in %s", celex)
    else:
        # prepare paths
        s_file, t_file, align_file, dic = util.make_paths(path, prefix + celex,
                                                          langs)
        # call the aligner
        smart_aligner(s_file, t_file, langs[0].lower(), langs[1].lower(),
                      dic, align_file, celex, over=False, make_dic=make_dic,
                      compress=compress)
