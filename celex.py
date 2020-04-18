#!/usr/bin/python
"""
# Name:        celex.py
# Purpose:     Download Eurlex documents using the celex code
# How to use:   python ~/eunlp/celex.py 32013R1024 EN RO
#
# Example:
# python ~/eunlp/celex.py 32013R1024 EN RO
# Author:      Filip
#
# Created:     4.11.2014
"""

import sys
import os
import logging
import argparse

from align import align
from align.const import ALL_LANGS

parser = argparse.ArgumentParser(description="Align a Celex document.")
parser.add_argument("Celex_number", help="the Celex number of the document")
parser.add_argument("Source_language", type=str.lower, choices=ALL_LANGS,
                    help="the source language of the document")
parser.add_argument("Target_language", type=str.lower, choices=ALL_LANGS,
                    help="the target language of the document")

logging.basicConfig(filename='log.txt', level=logging.WARNING)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
logging.getLogger('').addHandler(console)


def main():
    """

    :return:
    """
    args = parser.parse_args()
    # collect arguments
    celex = args.Celex_number
    languages = [args.Source_language, args.Target_language]
    # get script path
    path = os.getcwd()
    program_folder = os.path.dirname(sys.argv[0])
    if len(program_folder) != 0:
        program_folder += '/'

    # call the celex_scraper
    align.celex_aligner(languages, path, celex, '', make_dic=False,
                        save_intermediates=True)

if __name__ == '__main__':
    sys.exit(main())