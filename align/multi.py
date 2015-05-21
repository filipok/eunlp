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
import subprocess
import random
import logging
import nltk
from nltk.tokenize.punkt import PunktSentenceTokenizer, PunktParameters
from . import l2t_new as l2t
from . import util
from . import convert
from . import down


def smart_aligner(source_file, targets, s_lang, t_langs, dics,
                  align_file, note, over=True, para_size=300,
                  para_size_small=100, make_dic=True, compress=False):
    """

    :type source_file: str
    :type targets: list
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
    s_list = convert.file_to_list(source_file)
    t_lists = [convert.file_to_list(target) for target in targets]
    # If different No of paragraphs, make 3 more attempts to process the files
    if not all(len(s_list) == len(target) for target in targets):
        s_list = convert.file_to_list(source_file, tries=1)
        t_lists = [convert.file_to_list(target, tries=1)
                        for target in targets]
        if not all(len(s_list) == len(target) for target in targets):
            s_list = convert.file_to_list(source_file, tries=2)
            t_lists = [convert.file_to_list(target, tries=2)
                            for target in targets]
            if not all(len(s_list) == len(target) for target in targets):
                s_list = convert.file_to_list(source_file, tries=3)
                t_lists = [convert.file_to_list(target, tries=3)
                                for target in targets]
                if not all(len(s_list) == len(target) for target in targets):
                    logging.error('Multi-alignment failed in %s-%s', s_lang,
                                  source_file)
                    s_list = convert.file_to_list(source_file)
                    t_lists = [convert.file_to_list(target) for target in targets]
                    # TODO perhaps only write down problem languages
                    convert.html_table(
                        s_list, targets, align_file + '.err.html',
                        page_title=align_file)
                    # Using Hunalign on the entire file is mostly useless.
                    # aligner(source_file, target_file, s_lang, t_lang,
                    #         dictionary, align_file, note, delete_temp=True)
                    return
                else:
                    logging.warning('Aligned at 4th attempt in %s-%s',
                                    s_lang, source_file)
            else:
                logging.warning('Aligned at 3rd attempt in %s-%s',
                                s_lang, source_file)
        else:
            logging.warning('Aligned at 2nd attempt in %s-%s',
                            s_lang, source_file)
    # If equal number of paragraphs:
    try:
        parallel_aligner(s_list, target_list, s_lang, t_lang, dictionary,
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

