"""
Name:        celex_list.py
Purpose:     Download Eurlex documents using the celex codes from an XML file
How to use:
One language pair: python ~/eunlp/celex_list.py searchresults.xml en ro
All language pairs: python ~/eunlp/celex_list.py searchresults.xml all

Author:      Filip

Created:     17.02.2015
"""

import sys
import os
import logging

from align import align, convert
from align.const import ALL_LANGS


logging.basicConfig(filename='log.txt', level=logging.WARNING)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
logging.getLogger('').addHandler(console)

if __name__ == '__main__':
    # collect arguments
    path = os.getcwd()
    if len(sys.argv) > 2:
        program_folder = os.path.dirname(sys.argv[0])
        if len(program_folder) != 0:
            program_folder += '/'
        xml_list = sys.argv[1]  # collect xml list name
        langs = [x.lower() for x in sys.argv[2:]]  # collect language codes
        if (len(langs) == 2 and len(set(langs)) == 2 and
                set(langs).issubset(set(ALL_LANGS))):
            file_list = convert.eu_xml_converter(xml_list)
            for item in file_list:
                print "Processing " + item[0] + ' ...'
                align.celex_aligner(langs, path, item[0], '', make_dic=False)
        elif len(langs) == 1 and langs[0] == 'all':
            file_list = convert.eu_xml_converter(xml_list)
            for i in range(len(ALL_LANGS)):
                languages = ALL_LANGS[:]
                s_lang = languages.pop(i)
                for t_lang in languages:
                    for item in file_list:
                        print "Processing pair {}-{}, document {}".format(
                            s_lang, t_lang, item[0])
                        align.celex_aligner([s_lang, t_lang], path, item[0],
                                            '', make_dic=False)

        else:
            logging.critical('Invalid languages!')
            print "Either pass 'ALL' or a pair of valid languages."
            print "Valid languages:", ALL_LANGS
    else:
        logging.critical('Too few parameters!')