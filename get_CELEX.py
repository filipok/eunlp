# Name:        get_CELEX
# Purpose:     Download Eurlex documents EN and RO using the celex code
# How to use:   python get_CELEX.py 32014R0680 EN RO FR
#
# Author:      Filip
#
# Created:     4.11.2014

import sys
import os
import re
import functions as func


def make_link(celex, lang):
    part_1 = "http://eur-lex.europa.eu/legal-content/"
    part_2 = "/TXT/?uri=CELEX:"
    return part_1 + lang + part_2 + celex


if __name__ == '__main__':
    path = os.getcwd()
    program_folder = '/'.join(re.split(r'/', sys.argv[0])[:-1])
    celex = sys.argv[1]  # collect celex code
    languages = sys.argv[2:]  # collect language codes
    # create html and txt files for each language code
    func.scraper(languages, make_link, 'The requested document does not exist',
                 celex, '', is_celex=True)  # no prefix
    source_file = celex + '_' + languages[0] + '.txt'
    target_file = celex + '_' + languages[1] + '.txt'
    source_file = os.path.join(path, source_file)
    target_file = os.path.join(path, target_file)
    align_file = os.path.join(path, 'bi_' + celex)
    dictionary = os.path.join(path, languages[0].lower() +
                              languages[1].lower() + '.dic')
    func.aligner(source_file, target_file, languages[0].lower(),
                 languages[1].lower(), dictionary, align_file, program_folder)
