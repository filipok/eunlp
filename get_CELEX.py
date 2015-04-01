# Name:        get_CELEX
# Purpose:     Download Eurlex documents using the celex code
# How to use:   python ~/eunlp/get_CELEX.py 32013R1024 EN RO
#
# Example:
# python ~/eunlp/get_CELEX.py 32013R1024 EN RO
# Author:      Filip
#
# Created:     4.11.2014

import sys
import os
import logging

from align import align

logging.basicConfig(filename='log.txt', level=logging.WARNING)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
logging.getLogger('').addHandler(console)

if __name__ == '__main__':
    # collect arguments
    path = os.getcwd()
    program_folder = os.path.dirname(sys.argv[0])
    if len(program_folder) != 0:
        program_folder += '/'
    celex = sys.argv[1]  # collect celex code
    languages = sys.argv[2:]  # collect language codes

    # call the celex_scraper
    align.celex_aligner(languages, path, celex, program_folder)