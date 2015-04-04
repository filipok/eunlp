# Name:        util.py
# Purpose:     Various utilities
#
# Author:      Filip
#
# Created:     1.4.2015

import codecs
import logging
import re
import os


def make_ep_sub_link(doc_category, doc_year, doc_code):
    return doc_category + doc_year + doc_code


def make_ep_link(cat_year_code, lang):
    doc_category = cat_year_code[0:2]
    doc_year = cat_year_code[2:6]
    doc_code = cat_year_code[6:10]
    a = 'http://www.europarl.europa.eu/sides/getDoc.do?type=REPORT&reference=A'
    p = 'http://www.europarl.europa.eu/sides/getDoc.do?type=TA&reference=P'
    b = 'http://www.europarl.europa.eu/sides/getDoc.do?type=MOTION&reference=B'
    p_specific = ''  # this is specific to P links
    if doc_category[0] == 'A':
        part_1 = a
    elif doc_category[0] == 'P':
        part_1 = p
        p_specific = 'TA-'
    elif doc_category[0] == 'B':
        part_1 = b
    else:
        logging.error("EP doc_category error in %s %s", cat_year_code, lang)
        raise IOError("EP link error in doc_category")
    return "".join([part_1, doc_category[1], '-', p_specific, doc_year, '-',
                    doc_code, '&language=', lang])


def make_celex_link(celex, lang):
    part_1 = "http://eur-lex.europa.eu/legal-content/"
    part_2 = "/TXT/?uri=CELEX:"
    return part_1 + lang + part_2 + celex


def make_paths(path, text_id, languages):
        source_file = os.path.join(path, text_id + '_' + languages[0] + '.txt')
        target_file = os.path.join(path, text_id + '_' + languages[1] + '.txt')
        align_file = os.path.join(path, 'bi_' + text_id + '_' +
                                  languages[0].lower() + '_' +
                                  languages[1].lower())
        dictionary = os.path.join(path, languages[0].lower() +
                                  languages[1].lower() + '.dic')
        return source_file, target_file, align_file, dictionary


def create_dictionary(s_file, t_file, output_file):
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
    abbreviations = []
    with codecs.open(file_name, 'r', 'utf-8') as f:
        lines = list(f)
    for line in lines:
        if len(line) > 0 and line[0] != '#':
            abb = line.strip('\n')
            abb = re.split(' #', abb)[0]
            abbreviations.append(abb)
    return abbreviations
