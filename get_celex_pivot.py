"""
Name:        get_celex_pivot
Purpose:     Download Eurlex documents using the celex codes from an XML file
How to use:
All language pairs with the default pivot (i.e. English):
python ~/eunlp/get_celex_pivot.py searchresults.xml
All language pairs with a different pivot:
python ~/eunlp/get_celex_list.py searchresults.xml fr

Author:      Filip

Created:     20.05.2015
"""

import sys
import os
import logging

from align import align, convert
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
    xml_list = sys.argv[1]  # collect xml list name
    if len(sys.argv) > 2:
        lang = sys.argv[2].lower()  # collect pivot language code
    if len(sys.argv) > 3:
        logging.warning('Extra parameters have been ignored.')
    if lang in ALL_LANGS:
        target_langs = ALL_LANGS[:]
        target_langs.remove(lang)  # remove pivot language from list
        file_list = convert.eu_xml_converter(xml_list)
        for item in file_list:
            for t_language in target_langs:
                pair = [lang, t_language]
                print "Processing " + item[0] + ' (' + repr(pair) + ') ...'
                align.celex_aligner(pair, path, item[0], '', make_dic=False)
    else:
        logging.critical('Invalid language!')
        print "Valid languages:", ALL_LANGS
