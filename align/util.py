"""
Name:        util.py
Purpose:     Various utilities

Author:      Filip

Created:     1.4.2015
"""

import codecs
import logging
import re
import os
from nltk.tokenize.punkt import PunktSentenceTokenizer, PunktParameters
from const import SUBFOLDER

def sentence_splitter(lang):
    """

    :type lang: str
    :rtype: nltk.tokenize.punkt.PunktSentenceTokenizer
    """
    punkt_param = PunktParameters()
    path = os.path.dirname(__file__)
    ab_file = ''.join([path, SUBFOLDER, lang])
    if os.path.isfile(ab_file):
        punkt_param.abbrev_types = set(abbreviation_loader(ab_file))
    else:
        logging.info('Abbreviation file not found for language: %s', lang)
    splitter = PunktSentenceTokenizer(punkt_param)
    return splitter


def make_ep_sub_link(doc_category, doc_year, doc_code):
    """

    :type doc_category: str
    :type doc_year: str
    :type doc_code: str
    :rtype: str
    """
    return doc_category + doc_year + doc_code


def make_ep_link(cat_year_code, lang):
    """

    :type cat_year_code: str
    :type lang: str
    :rtype: str
    """
    doc_category = cat_year_code[0:2]
    doc_year = cat_year_code[2:6]
    doc_code = cat_year_code[6:10]
    common_str = 'http://www.europarl.europa.eu/sides/getDoc.do?'
    a_str = common_str + 'type=REPORT&reference=A'
    p_str = common_str + 'type=TA&reference=P'
    b_str = common_str + 'type=MOTION&reference=B'
    p_specific = ''  # this is specific to P links
    if doc_category[0] == 'A':
        part_1 = a_str
    elif doc_category[0] == 'P':
        part_1 = p_str
        p_specific = 'TA-'
    elif doc_category[0] == 'B':
        part_1 = b_str
    else:
        logging.error("EP doc_category error in %s %s", cat_year_code, lang)
        raise IOError("EP link error in doc_category")
    return "".join([part_1, doc_category[1], '-', p_specific, doc_year, '-',
                    doc_code, '&language=', lang])


def make_celex_link(celex, lang):
    """

    :type celex: str
    :type lang: str
    :rtype: str
    """
    part_1 = "http://eur-lex.europa.eu/legal-content/"
    part_2 = "/TXT/?uri=CELEX:"
    return part_1 + lang + part_2 + celex


def make_paths(path, text_id, languages):
    """

    :type path: str
    :type text_id: str
    :type languages: list
    :rtype: tuple
    """
    align_file = os.path.join(path, 'bi_' + text_id + '_' +
                              languages[0].lower() + '_' +
                              languages[1].lower())
    dictionary = os.path.join(path, languages[0].lower() +
                              languages[1].lower() + '.dic')
    return align_file, dictionary


def make_paths_multi(path, text_id, s_lang, t_langs):
    """

    :type path: str
    :type text_id: str
    :type s_lang: str
    :type t_langs: list
    :rtype: tuple
    """
    list_of_targets = []
    list_of_dictionaries = []
    source_file = os.path.join(path, text_id + '_' + s_lang + '.txt')
    for t_lang in t_langs:
        target_file = os.path.join(path, text_id + '_' + t_lang + '.txt')
        list_of_targets.append(target_file)
        dictionary = os.path.join(path, s_lang + t_lang + '.dic')
        list_of_dictionaries.append(dictionary)
    prefix = 'multi_'
    postfix = ''
    if len(t_langs) == 1:
        prefix = 'bi_'
        postfix = '_' + t_langs[0]
    align_file = os.path.join(
        path, prefix + text_id + '_' + s_lang + postfix)

    return source_file, list_of_targets, align_file, list_of_dictionaries


def create_dictionary(s_file, t_file, output_file):
    """

    :type s_file: str
    :type t_file: str
    :type output_file: str
    """
    try:
        with codecs.open(s_file, "r", "utf-8") as sin:
            s_list = list(sin)
        with codecs.open(t_file, "r", "utf-8") as tin:
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
            logging.error(
                "Dictionary files of different length or length = 0.")
    except IOError:
        logging.error('Unavailable dictionary files %s or %s.', s_file, t_file)
        raise


def abbreviation_loader(file_name):
    """

    :type file_name: str
    :rtype: list
    """
    abbreviations = []
    with codecs.open(file_name, 'r', 'utf-8') as fin:
        lines = list(fin)
    for line in lines:
        if len(line) > 1 and line[0] != '#':
            abb = line.strip('\n')
            abb = re.split(' #', abb)[0]
            abbreviations.append(abb)
    return abbreviations
