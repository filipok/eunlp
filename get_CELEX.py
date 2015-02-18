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
import re
import functions

if __name__ == '__main__':
    # collect arguments
    path = os.getcwd()
    program_folder = '/'.join(re.split(r'/', sys.argv[0])[:-1])
    if len(program_folder) != 0:
        program_folder += '/'
    celex = sys.argv[1]  # collect celex code
    languages = sys.argv[2:]  # collect language codes

    # call the celex_scraper
    functions.celex_scraper(languages, path, celex, program_folder, 'log.txt')