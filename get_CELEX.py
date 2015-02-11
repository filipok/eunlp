# Name:        get_CELEX
# Purpose:     Download Eurlex documents EN and RO using the celex code
# How to use:   python ~/eunlp/get_CELEX.py 32013R1024 EN RO
#
# Example:
# python ~/eunlp/get_EP_text.py A7 2012 0002 EN RO#
# Author:      Filip
#
# Created:     4.11.2014

import sys
import os
import re
import functions as func

if __name__ == '__main__':
    # collect arguments
    path = os.getcwd()
    program_folder = '/'.join(re.split(r'/', sys.argv[0])[:-1])
    if len(program_folder) != 0:
        program_folder += '/'
    celex = sys.argv[1]  # collect celex code
    languages = sys.argv[2:]  # collect language codes
    # create html and txt files for each language code
    func.scraper(languages, func.make_celex_link,
                 'The requested document does not exist', celex, '',
                 is_celex=True, over_html=False, over_txt=False)  # no prefix
    # prepare paths
    source_file, target_file, align_file, dictionary = \
        func.make_paths(path, celex, languages)
    # call the aligner
    func.ep_aligner(source_file, target_file, languages[0].lower(),
                    languages[1].lower(), dictionary, align_file,
                    program_folder, celex,delete_temp=True, over=False)
