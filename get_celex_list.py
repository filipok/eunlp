# Name:        get_celex_list
# Purpose:     Download Eurlex documents using the celex codes from an XML file
# How to use:   python ~/eunlp/get_celex_list.py searchresults.xml EN RO
#
# Example:
# python ~/eunlp/get_celex_list.py searchresults.xml EN RO
# Author:      Filip
#
# Created:     17.02.2015

import sys
import os
import align
import convert
import logging
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
    xml_list = sys.argv[1]  # collect xml list name
    languages = sys.argv[2:]  # collect language codes

    file_list = convert.eu_xml_converter(xml_list)
    for item in file_list:
        print "Processing " + item[0] + ' ...'
        align.celex_aligner(languages, path, item[0], program_folder)