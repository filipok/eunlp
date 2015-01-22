# Name:        get_EP_text
# Purpose:     Download EP reports, texts adopted and motions for resolutions
# How to use:   python get_EP_text.py [A|P|B][7|8] AAAA NUMBER EN RO
#
# Example:
# python ~/eunlp/get_EP_text.py A7 2012 0002 EN RO
# Author:      Filip
#
# Created:     4.11.2014


import sys
import re
import functions as func
import os.path


def make_sub_link(doc_category, doc_year, doc_code):
    return doc_category + doc_year + doc_code


def make_link(category_year_code, lang):
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

if __name__ == '__main__':
    # collect parameters
    path = os.getcwd()
    program_folder = '/'.join(re.split(r'/', sys.argv[0])[:-1])
    category = sys.argv[1]
    year = sys.argv[2]
    number = sys.argv[3]
    languages = sys.argv[4:]
    # create doc_code
    doc_code = make_sub_link(category, year, number)
    # create html and txt files for each language code
    func.scraper(languages, make_link, 'Application Error', doc_code, '',
                 is_celex=False)
    source_file = doc_code + '_' + languages[0] + '.txt'
    target_file = doc_code + '_' + languages[1] + '.txt'
    source_file = os.path.join(path, source_file)
    target_file = os.path.join(path, target_file)
    align_file = os.path.join(path, 'bi_' + doc_code)
    dictionary = os.path.join(path, languages[0].lower() +
                              languages[1].lower() + '.dic')
    func.aligner(source_file, target_file, languages[0].lower(),
                 languages[1].lower(), dictionary, align_file, program_folder)
#TODO de vazut erorile la aliniere