"""
Name:        multi.py
Purpose:     Various project functions for multi-alignment

Author:      Filip

Created:     21.05.2015
"""

import urllib2
import codecs
import re
import os
import logging
from itertools import izip
from . import util
from . import convert
from . import down
from .const import PARA_MAX, PARA_MIN


def parallel_aligner(s_list, t_lists, s_lang, t_langs, dics,
                     align_file, para_size=PARA_MAX, para_size_small=PARA_MIN,
                     prj='temp', make_dic=True):
    """

    :type s_list: list
    :type t_lists: list
    :type s_lang: str
    :type t_langs: list
    :type dics: list
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
    s_sentence_splitter = util.sentence_splitter(s_lang)
    t_sentence_splitters = [util.sentence_splitter(lang) for lang in t_langs]

    for i in range(len(s_list)):
        # boolean values (small, pattern not found, intermediate & no pattern)
        small = len(s_list[i]) < para_size_small
        t_patt = all(re.search(patt, t_list[i]) for t_list in t_lists)
        n_pat = not (re.search(patt, s_list[i]) and t_patt)
        clean_intermediate = ((len(s_list[i]) < para_size) and
                              (len(s_list[i]) >= para_size_small) and n_pat)
        if small or clean_intermediate:
            t_segm = '\t'.join([t_list[i] for t_list in t_lists])
            line = ''.join(["Nai\t", t_segm, "\t", s_list[i], "\n"])
            fout.write(line)
        else:
            try:
                # tmp_aligner(s_list[i], t_list[i], s_lang, t_lang, dictionary,
                #            fout, prj, i, s_sentence_splitter,
                #            t_sentence_splitter, make_dic)
                # TODO add the real stuff here instead of this filler
                t_segm = '\t'.join([t_list[i] for t_list in t_lists])
                line = ''.join(["Nai\t", t_segm, "\t", s_list[i], "\n"])
                fout.write(line)
            except StopIteration:
                logging.error('StopIteration %s: Source: %s', prj, s_list[i])
                raise
    fout.close()


def smart_aligner(s_file, t_files, s_lang, t_langs, dics,
                  align_file, note, over=True, para_size=PARA_MAX,
                  para_size_small=PARA_MIN, make_dic=True, compress=False):
    """

    :type s_file: str
    :type t_files: list
    :type s_lang: str
    :type t_langs: list
    :type dics: list
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
    s_list = convert.file_to_list(s_file)
    t_lists = [convert.file_to_list(target) for target in t_files]
    # If different No of paragraphs, make 3 more attempts to process the files
    if not all(len(s_list) == len(target) for target in t_lists):
        s_list = convert.file_to_list(s_file, tries=1)
        t_lists = [convert.file_to_list(target, tries=1)
                   for target in t_files]
        if not all(len(s_list) == len(target) for target in t_lists):
            s_list = convert.file_to_list(s_file, tries=2)
            t_lists = [convert.file_to_list(target, tries=2)
                       for target in t_files]
            if not all(len(s_list) == len(target) for target in t_lists):
                s_list = convert.file_to_list(s_file, tries=3)
                t_lists = [convert.file_to_list(target, tries=3)
                           for target in t_files]
                if not all(len(s_list) == len(target) for target in t_lists):
                    logging.error('Multi-alignment failed in %s-%s', s_lang,
                                  s_file)

                    s_list = convert.file_to_list(s_file)
                    t_lists = [
                        convert.file_to_list(target) for target in t_files]
                    # TODO perhaps only write down problem languages
                    convert.m_html_table(
                        s_list, t_lists, align_file + '.err.html',
                        page_title=align_file)
                    # Using Hunalign on the entire file is mostly useless.
                    # aligner(source_file, target_file, s_lang, t_lang,
                    #         dictionary, align_file, note, delete_temp=True)
                    return
                else:
                    logging.warning('Aligned at 4th attempt in %s-%s',
                                    s_lang, s_file)
            else:
                logging.warning('Aligned at 3rd attempt in %s-%s',
                                s_lang, s_file)
        else:
            logging.warning('Aligned at 2nd attempt in %s-%s',
                            s_lang, s_file)
    # If equal number of paragraphs:
    try:
        parallel_aligner(s_list, t_lists, s_lang, t_langs, dics,
                         align_file, para_size=para_size,
                         para_size_small=para_size_small, prj=s_file,
                         make_dic=make_dic)
        # turn alignment into tmx
        convert.m_tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang,
                             t_langs, note)
        # create parallel source and target text files
        s_ali = s_file[:-4] + '_' + s_lang + '.ali'
        t_alis = []
        for pair in izip(t_files, t_langs):
            t_alis.append(pair[0][:-4] + '_' + pair[1] + '.ali')
        convert.m_tab_to_separate(align_file + '.tab', s_ali, t_alis)
        if compress:
            convert.gzipper(align_file + '.tab')
            convert.gzipper(align_file + '.tmx')
            convert.gzipper(s_ali)
            convert.m_gzipper(t_alis)
    except StopIteration:
        logging.error('StopIteration in %s -> %s', note, s_file)


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
        langs = [x.lower() for x in langs]
        s_file, t_files, align_file, dics = util.make_paths_multi(
            path, prefix + celex, langs[0], langs[1:])
        smart_aligner(s_file, t_files, langs[0], langs[1:], dics, align_file,
                      celex, over=False, make_dic=make_dic, compress=compress)
