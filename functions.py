#-----------------------------------------------------------------------------
# Name:        download_EP
# Purpose:     Download EP minutes in EN and RO using a list of dates
# How to use:   python dates_list.txt EN RO FR
# Date format in dates_list.txt, one per line:  20131011 [= October 11, 2013]
#
# Author:      Filip
#
# Created:     4.11.2014
# Licence:     Public domain
#-----------------------------------------------------------------------------

import urllib2
import codecs
import re
from bs4 import BeautifulSoup


def download(link):
    response = urllib2.urlopen(link)
    return response.read()


def check_error(text, error_string):
    if error_string in text:
        print "Link error!"
        return False
    return True


def strip_celex(text):
    # discard some leftover Javascript and newlines
    split = re.split(r'\n\t{5}Text\n', text)
    text = split[1]
    split = re.split(r'\nTop\s{3}\n', text)
    text = split[0]
    text = re.sub(r'\n+', r'\n', text)
    return text



def scraper(languages, make_link, error_text, url_code, prefix, is_celex = False):
    for lang_code in languages:
            link = make_link(url_code, lang_code)
            text = download(link)
            if check_error(text, error_text):
                new_name = prefix + url_code + '_' + lang_code + '.html'
                with open(new_name, 'w') as f:
                    f.write(text)
                new_name = prefix + url_code + '_' + lang_code + '.txt'
                with codecs.open(new_name, "w", "utf-8") as f:
                    soup = BeautifulSoup(text)
                    clean_text = soup.get_text()
                    # do some cleanup if is_celex
                    if is_celex:
                        clean_text = strip_celex(clean_text)
                    f.write(clean_text)
            else:
                print "Error in link " + url_code + " " + lang_code + "."
