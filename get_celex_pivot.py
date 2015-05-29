"""
Name:        get_celex_pivot
Purpose:     Download Eurlex documents using the celex codes from an XML file
How to use:
All language pairs with the default pivot (i.e. English):
python ~/eunlp/get_celex_pivot.py searchresults.xml
All language pairs with a different pivot:
python ~/eunlp/get_celex_pivot.py searchresults.xml fr

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


def main(s_lang, file_list):
    """
    How to use main() independently:
    main('en', [('32013R1024', 'celex_title')])

    :type s_lang: str
    :type file_list: list
    """
    path = os.getcwd()
    target_langs = ALL_LANGS[:]
    target_langs.remove(s_lang)  # remove pivot language from list
    target_no = len(target_langs)
    file_no = len(file_list)
    for item in enumerate(file_list):
        for t_language in enumerate(target_langs):
            pair = [s_lang, t_language[1]]
            print str(item[0] + 1) + '/' + str(file_no) + ',',
            print str(t_language[0] + 1) + '/' + str(target_no) + ':',
            print "Processing " + item[1][0] + ' (' + repr(pair) + ') ...'
            align.celex_aligner(pair, path, item[1][0], '', make_dic=False)

if __name__ == '__main__':
    # collect arguments
    lang = PIVOT
    if len(sys.argv) < 2:
        sys.exit("Too few parameters!")
    program_folder = os.path.dirname(sys.argv[0])
    if len(program_folder) != 0:
        program_folder += '/'
    xml_list = sys.argv[1]  # collect xml list name
    celex_list = convert.eu_xml_converter(xml_list)
    if len(sys.argv) > 2:
        lang = sys.argv[2].lower()  # collect pivot language code
    if len(sys.argv) > 3:
        logging.warning('Extra parameters have been ignored.')
    if lang in ALL_LANGS:
        main(lang, celex_list)
    else:
        logging.critical('Invalid language!')
        print "Valid languages:", ALL_LANGS
