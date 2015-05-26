"""
Name:        get_celex_multi
Purpose:     Download Eurlex documents using the celex codes from an XML file
How to use:
All language pairs with the default pivot (i.e. English):
python ~/eunlp/get_celex_multi.py 32013R1024
All language pairs with a different pivot:
python ~/eunlp/get_celex_multi.py 32013R1024 fr
Two language pairs
python ~/eunlp/get_celex_multi.py 32013R1024 en ro

Author:      Filip

Created:     26.05.2015
"""

import sys
import os
import logging

from align import multi
from align.const import ALL_LANGS, PIVOT


logging.basicConfig(filename='log.txt', level=logging.WARNING)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
logging.getLogger('').addHandler(console)

if __name__ == '__main__':
    # collect arguments
    lang = PIVOT
    path = os.getcwd()
    if len(sys.argv) < 2:
        sys.exit("Too few parameters!")
    program_folder = os.path.dirname(sys.argv[0])
    if len(program_folder) != 0:
        program_folder += '/'
    celex = sys.argv[1]  # collect celex code
    if len(sys.argv) > 2:
        lang = sys.argv[2].lower()  # collect pivot language code
        if lang not in ALL_LANGS:
            logging.critical('Invalid pivot language! Using defaults...')
            print "Valid languages:", ALL_LANGS
            lang = PIVOT
    else:
        lang = PIVOT
    if len(sys.argv) > 3:
        temp_langs = [t_lang.lower() for t_lang in sys.argv[3:]]
        t_langs = []
        # add to target languages if valid language and if != pivot
        for t_lang in temp_langs:
            if t_lang in ALL_LANGS and t_lang != lang:
                t_langs.append(t_lang)
        if len(t_langs) == 0:
            logging.critical('Invalid target languages! Using defaults...')
            print "Valid languages:", ALL_LANGS
            t_langs = ALL_LANGS[:]
            t_langs.remove(lang)  # remove pivot from target languages
    else:
        t_langs = ALL_LANGS[:]
        t_langs.remove(lang)  # remove pivot from target languages

    langs =[lang] + t_langs
    print "Starting alignment of " + celex + " ..."
    multi.celex_aligner(langs, path, celex, '', make_dic=False)
