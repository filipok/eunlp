# Name:        get_EP_text
# Purpose:     Download EP reports, texts adopted and motions for resolutions
# How to use:   python get_EP_text.py [A|P|B][7|8] AAAA NUMBER EN RO
#
# Example:
# python ~/eunlp/get_EP_text.py A7 2012 0002 EN RO
# Author:      Filip
#
# Created:     4.11.2014

import sys
import os
import functions as func

if __name__ == '__main__':
    # collect arguments
    path = os.getcwd()
    program_folder = os.path.dirname(sys.argv[0])
    if len(program_folder) != 0:
        program_folder += '/'
    category = sys.argv[1]
    year = sys.argv[2]
    number = sys.argv[3]
    languages = sys.argv[4:]
    # create doc_code
    doc_code = func.make_ep_sub_link(category, year, number)
    # create html and txt files for each language code
    func.scraper(languages, func.make_ep_link, 'Application Error', doc_code,
                 '', is_ep=True, over_html=False, over_txt=False)
    # prepare paths
    source_file, target_file, align_file, dictionary = \
        func.make_paths(path, doc_code, languages)
    # call the aligner
    func.smart_aligner(source_file, target_file, languages[0].lower(),
                       languages[1].lower(), dictionary, align_file,
                       program_folder, doc_code, delete_temp=True, over=False)