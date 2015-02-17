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
import re
import functions

if __name__ == '__main__':
    # collect arguments
    path = os.getcwd()
    program_folder = '/'.join(re.split(r'/', sys.argv[0])[:-1])
    if len(program_folder) != 0:
        program_folder += '/'
    xml_list = sys.argv[1]  # collect xml list name
    languages = sys.argv[2:]  # collect language codes

    file_list = functions.eu_xml_converter(xml_list)
    for item in file_list:
        print "Downloading " + item[0] + ' ...'
        functions.celex_scraper(languages, path, item[0], program_folder)

