"""
Name:        celex_list.py
Purpose:     Download Eurlex documents using the celex codes from an XML file
How to use:
One language pair: python ~/eunlp/celex_list.py searchresults.xml en ro
All language pairs: python ~/eunlp/celex_list.py searchresults.xml all
Pivot language: python ~/eunlp/celex_list.py searchresults.xml en

Author:      Filip

Created:     17.02.2015
"""

import sys
import os
import logging
import argparse
import urllib2

from align import align, convert
from align.const import ALL_LANGS

parser = argparse.ArgumentParser(
    description="Align a list of Celex documents.")
parser.add_argument("XML_list", help="the XML list with Celex numbers")
parser.add_argument("Source_language", type=str.lower,
                    choices=ALL_LANGS + ['all'],
                    help="the source languages of the document; "
                         "ALL if all possible language pairs")
parser.add_argument("-t", "--target",  type=str.lower, choices=ALL_LANGS,
                    help="the target language of the document "
                         "(incompatible with using ALL for source language)")

logging.basicConfig(filename='log.txt', level=logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
logging.getLogger('').addHandler(console)


def main():
    """

    :return:
    """
    args = parser.parse_args()
    # get script path
    path = os.getcwd()
    program_folder = os.path.dirname(sys.argv[0])
    if len(program_folder) != 0:
        program_folder += '/'
    # collect xml list name
    xml_list = args.XML_list
    try:
        response = urllib2.urlopen(xml_list)
    except ValueError:
        logging.error('ValueError: invalid file url %s', xml_list)
        raise
    xml_text = response.read()
    with open('file_list.xml', 'w') as fout:
        fout.write(xml_text)
    file_list = convert.eu_xml_converter('file_list.xml')
    file_no = len(file_list)
    # collect source language
    s_lang = args.Source_language
    # collect target language, if any, and run alignments

    # one language pair
    if args.target is not None and args.Source_language != 'all':
        t_lang = args.target
        logging.info('Aligning one language pair: %s - %s ...', s_lang,
                     t_lang)
        for item in enumerate(file_list):
            logging.info("F: %s/%s: Processing %s ...", str(item[0] + 1),
                         str(file_no), item[1][0])
            align.celex_aligner([s_lang, t_lang], path, item[1][0], '',
                                make_dic=False, save_intermediates=True)
    # all language pairs
    elif s_lang == 'all':
        logging.info('Aligning all language pairs')
        langs_no = len(ALL_LANGS)
        for item in enumerate(file_list):
            for i in range(langs_no):
                languages = ALL_LANGS[:]
                s_lang = languages.pop(i)
                target_no = len(languages)
                for t_lang in enumerate(languages):
                    pair = [s_lang, t_lang[1]]
                    logging.info(
                        "F: %s/%s S: %s/%s T: %s/%s: Processing %s (%s) ...",
                        str(item[0] + 1), str(file_no),
                        str(i + 1), str(langs_no),
                        str(t_lang[0] + 1), str(target_no),
                        item[1][0], repr(pair))
                    align.celex_aligner(pair, path, item[1][0],
                                        '', make_dic=False,
                                        save_intermediates=True)

    # pivot source language
    else:
        logging.info('Aligning with pivot language: %s ...', s_lang)
        target_langs = ALL_LANGS[:]
        target_langs.remove(s_lang)  # remove pivot language from list
        target_no = len(target_langs)
        for item in enumerate(file_list):
            for t_language in enumerate(target_langs):
                pair = [s_lang, t_language[1]]
                logging.info("F: %s/%s T: %s/%s: Processing %s (%s) ...",
                             str(item[0] + 1), str(file_no),
                             str(t_language[0] + 1), str(target_no),
                             item[1][0], repr(pair))
                align.celex_aligner(pair, path, item[1][0], '',
                                    make_dic=False,
                                    save_intermediates=True)

if __name__ == '__main__':
    sys.exit(main())
