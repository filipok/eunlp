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
import xml.etree.ElementTree as ElementTree
import l2t_new as l2t
import util
import convert
import down
from const import PARA_MAX, PARA_MIN


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


def smart_aligner(texts, s_lang, t_lang, dictionary,
                  align_file, note, over=True, para_size=PARA_MAX,
                  para_size_small=PARA_MIN, make_dic=True, compress=False):
    # functions.smart_aligner(texts, "en",
    # "ro", "enro.dic", "bi_test", "/home/filip/eunlp/", "A720120002")
    """

    :type texts: list
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
            os.path.isfile(align_file + '.tmx') or
            os.path.isfile(align_file + '_manual.html') or
            os.path.isfile(align_file + '.tmx.gz')):
        logging.warning("File pair already aligned: %s", align_file)
        return  # exit if already aligned and over=False
    source_list = convert.file_to_list(texts[0], s_lang)
    target_list = convert.file_to_list(texts[1], t_lang)

    # If different No of paragraphs, make 3 more attempts to process the files
    tries = 0
    while len(source_list) != len(target_list) and tries < 3:
        tries += 1
        source_list = convert.file_to_list(texts[0], s_lang, tries=tries)
        target_list = convert.file_to_list(texts[1], t_lang, tries=tries)

    if len(source_list) != len(target_list):
        logging.error('Smart alignment failed in %s: %s-%s', note,
                      s_lang, t_lang)
        jsalign_with_error(texts, s_lang, t_lang, note, align_file)
        return

    if tries > 0:
        logging.warning('Aligned at attempt %s in %s: %s-%s',
                        tries + 1, note, s_lang, t_lang)

    try:
        tab_file = parallel_aligner(source_list, target_list, s_lang, t_lang,
                                    dictionary, para_size=para_size,
                                    para_size_small=para_size_small,
                                    note=note, make_dic=make_dic)
        # turn alignment into tmx and manual html alignment
        tmx_file = convert.tab_to_tmx(tab_file, s_lang, t_lang, note)

        with codecs.open(align_file + '.tmx', "w", "utf-8") as fout:
            fout.write(tmx_file)
        source_list, target_list = convert.tab_to_separate(tab_file)
        jsalign = convert.jsalign_table(source_list, target_list, s_lang,
                                        t_lang, note)
        with codecs.open(align_file + '_manual.html', 'w', 'utf-8') as fout:
            fout.write(jsalign)
        if compress:
            convert.gzipper(align_file + '.tmx')
            convert.gzipper(align_file + '_manual.html')

    except StopIteration:
        logging.error('StopIteration in %s -> %s, %s', note, s_lang, t_lang)
        jsalign_with_error(texts, s_lang, t_lang, note, align_file)


def jsalign_with_error(texts, s_lang, t_lang, note, align_file):
    source_list = convert.file_to_list(texts[0], s_lang)
    s_sentence_splitter = util.sentence_splitter(s_lang)
    source_list = text_sent_splitter(source_list, s_sentence_splitter)
    target_list = convert.file_to_list(texts[1], t_lang)
    t_sentence_splitter = util.sentence_splitter(t_lang)
    target_list = text_sent_splitter(target_list, t_sentence_splitter)

    jsalign = convert.jsalign_table(source_list, target_list, s_lang,
                                    t_lang, note)
    with codecs.open(align_file + '_manual.html', 'w', 'utf-8') as fout:
        fout.write(jsalign)


def parallel_aligner(s_list, t_list, s_lang, t_lang, dictionary,
                     para_size=PARA_MAX, para_size_small=PARA_MIN,
                     note='temp', make_dic=True):
    """

    :type s_list: list
    :type t_list: list
    :type s_lang: str
    :type t_lang: str
    :type dictionary: str
    :type para_size: int
    :type para_size_small: int
    :type note: str
    :type make_dic: bool
    """
    if not os.path.exists("/tmp/eunlp"):
        os.makedirs("/tmp/eunlp")

        # create hunalign dictionary file
    if make_dic:
        if not os.path.exists(dictionary):
            path = os.path.dirname(__file__) + '/data_raw/'
            try:
                util.create_dictionary(path + s_lang + '.txt',
                                       path + t_lang + '.txt', dictionary)
            except IOError:
                open(dictionary, 'a').close()  # create empty dictionary
                logging.warning('Creating empty dictionary %s', dictionary)
    else:
        open(dictionary, 'w').close()  # create empty dict; erase current file

    # send paragraph to hunalign if large or if intermediate and
    # both source and target have a dot followed by whitespace.
    patt = re.compile(r'\. ')
    # create sentence splitters
    s_sentence_splitter = util.sentence_splitter(s_lang)
    t_sentence_splitter = util.sentence_splitter(t_lang)
    try:
        return ''.join([parallel_line(s_line, t_line, para_size,
                                      para_size_small, patt,  dictionary,
                                      note, s_sentence_splitter,
                                      t_sentence_splitter)
                        for s_line, t_line in zip(s_list, t_list)])
    except StopIteration:
        raise


def parallel_line(s_line, t_line, para_size, para_size_small, patt, dictionary,
                  note, s_sentence_splitter, t_sentence_splitter):
    small = len(s_line) < para_size_small
    n_pat = not (re.search(patt, s_line) and re.search(patt, t_line))
    clean_intermediate = ((len(s_line) < para_size) and
                          (len(s_line) >= para_size_small) and n_pat)
    if small or clean_intermediate:
        line = ''.join(["Nai\t", t_line, "\t", s_line, "\n"])
        return line
    else:
        try:
            line = tmp_aligner(s_line, t_line, dictionary, note,
                               s_sentence_splitter, t_sentence_splitter)
        except StopIteration:
            logging.error('StopIteration %s: Source: %s', note, s_line)
            logging.error('StopIteration %s: Target: %s', note, t_line)
            raise

        return line


def tmp_aligner(source, target, dictionary, note, s_sentence_splitter,
                t_sentence_splitter):
    """

    :type source: str
    :type target: str
    :type dictionary: str
    :type note: str
    :type s_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    :type t_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
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
        lines = basic_aligner(tmp_source, tmp_target, dictionary, tmp_align,
                              s_sentence_splitter, t_sentence_splitter)
    except StopIteration:
        raise
    # do some checks with the hunalign aligment and use only if ok
    everything_ok = check_hunalign(lines, source, target)
    if everything_ok[0]:
        line = everything_ok[1]
    else:
        logging.info("Hunalign failed in a segment in file %s.", note)
        line = ''.join(["Err\t", target, "\t", source, "\n"])
    # remove temporary files
    os.remove(tmp_source)
    os.remove(tmp_target)
    os.remove(tmp_align + '.lad')
    return line


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


def text_sent_splitter(text, sent_splitter):
    """

    :type text: list
    :type sent_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    """
    sentence_list = []
    [sentence_list.extend(sent_splitter.tokenize(line)) for line in text]
    return sentence_list


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
    sentence_list = text_sent_splitter(text, sent_splitter)

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


def basic_aligner(s_file, t_file, dic, a_file, s_sentence_splitter,
                  t_sentence_splitter):
    # call splitter & aligner
    """

    :type s_file: str
    :type t_file: str
    :type dic: str
    :type a_file: str
    :type s_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    :type t_sentence_splitter: nltk.tokenize.punkt.PunktSentenceTokenizer
    :rtype: list
    """
    # create tokenized files for hunalign
    split_token_nltk(s_file, s_sentence_splitter)
    split_token_nltk(t_file, t_sentence_splitter)
    # create hunalign ladder alignment
    hunalign_wrapper(s_file[:-4] + '.tok', t_file[:-4] + '.tok', dic,
                     a_file + '.lad', realign=True)
    # create aligned output
    try:
        lines = l2t.make_lines(a_file + '.lad', s_file[:-4], t_file[:-4])
    except StopIteration:
        raise
    lines = [unicode(line, "utf-8") + '\n' for line in lines]
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
    # TODO ce fac cu GA care uneori e EN
    try:
        texts = down.scraper(langs, util.make_celex_link, celex, prefix,
                             style="celex", over_html=False, over_txt=False,
                             save_files=False)
    except urllib2.HTTPError:
        logging.error("Aborting alignment due to link error in %s.", celex)
    except (IndexError, AttributeError):
        logging.error("Aborting alignment due to format error in %s", celex)
    else:
        # prepare paths
        align_file, dic = util.make_paths(path, prefix + celex, langs)
        # call the aligner
        smart_aligner(texts, langs[0].lower(), langs[1].lower(),
                      dic, align_file, celex, over=False, make_dic=make_dic,
                      compress=compress)
        # cleanup
        if os.path.isfile('translate.txt'):
            os.remove('translate.txt')
        if os.path.isfile(dic):
            os.remove(dic)


def bilingual_tmx_realigner(tmx_file):
    """

    :type tmx_file: str
    """
    # open tmx file
    tree = ElementTree.parse(tmx_file)
    root = tree.getroot()
    # convert tmx file to separate files
    s_list = [element[2][0].text for element in root[1].findall('tu')]
    t_list = [element[3][0].text for element in root[1].findall('tu')]
    # get languages and document ID (note)
    s_lang = root[0].get('srclang')
    t_lang = root[1][0][3].get('{http://www.w3.org/XML/1998/namespace}lang')
    note = root[1][0][0].text
    dictionary = s_lang + t_lang + '.dic'
    # 3. call parallel aligner
    tab_file = parallel_aligner(s_list, t_list, s_lang, t_lang, dictionary)
    re_tmx_file = convert.tab_to_tmx(tab_file, s_lang, t_lang, note)
    return re_tmx_file
