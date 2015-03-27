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
import functions
import codecs

if __name__ == '__main__':
    # collect arguments
    path = os.getcwd()
    program_folder = os.path.dirname(sys.argv[0])
    if len(program_folder) != 0:
        program_folder += '/'
    xml_list = sys.argv[1]  # collect xml list name
    languages = sys.argv[2:]  # collect language codes

    file_list = functions.eu_xml_converter(xml_list)
    for item in file_list:
        print "Downloading " + item[0] + ' ...'
        try:
            functions.celex_scraper(languages, path, item[0], program_folder)
        except:
            # TODO except https://docs.python.org/2/howto/doanddont.html            
            message = "Could not align " + item[0] + ": " + \
                      str(sys.exc_info()[0]) + '\n'
            print message
            with codecs.open('log.txt', 'a', 'utf-8') as f:
                f.write(message)