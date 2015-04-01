# Name:        down.py
# Purpose:     Utilities to download files and use BeautifulSoup
#
# Author:      Filip
#
# Created:     1.4.2015

import os
import urllib2
import re
import codecs
import logging
from bs4 import BeautifulSoup


def downloader(link, new_name, over=False):
    # Only download if not already existing, otherwise open from disk
    # over=True overrides that behavior
    if over or (not os.path.isfile(new_name)):
        response = urllib2.urlopen(link)
        html_text = response.read()

        # some celexes have no new line between paras
        # this confuses get_text() in BeautifulSoup
        html_text = re.sub(r'</p><p>', r'</p>\n<p>', html_text)

        with open(new_name, 'w') as f:
            f.write(html_text)
    else:
        with codecs.open(new_name, "r", "utf-8") as f:
            html_text = f.read()
            logging.debug("%s: html file already downloaded.", new_name)
    return html_text


def souper(new_name, html_text, style, over=False):
    # Only convert to txt if not already existing
    # over=True overrides that behavior
    if (not over) and os.path.isfile(new_name):
        logging.warning("%s: txt file already existing.", new_name)
        return
    f = codecs.open(new_name, "w", "utf-8")
    soup = BeautifulSoup(html_text, "lxml")
    # some celexes have \n inside <p> tags
    remove_newlines(soup)
    # separate branches for each document type
    if style == "celex":
        if soup.txt_te is not None:
            # for older celexes
            clean_text = soup.txt_te.get_text()
        else:
            # for newer celexes
            # the hierarchy is rather deep
            clean_text = soup.body.div.contents[8].contents[5].contents[0]
            clean_text = clean_text.contents[4].contents[9].contents[3]
            clean_text = clean_text.contents[1].get_text()
            clean_text = re.sub(r'\n\nTop $', r'', clean_text)
    elif style == "europarl":
        clean_text = soup.get_text()
        clean_text = strip_ep(clean_text)
    else:
        clean_text = soup.get_text()
    f.write(clean_text)
    f.close()


def scraper(langs, make_link, url_code, prefix, style="", over_html=False,
            over_txt=False):
    for lang_code in langs:
            new_name = prefix + url_code + '_' + lang_code + '.html'
            try:
                link = make_link(url_code, lang_code)
                text = downloader(link, new_name, over_html)
            except urllib2.HTTPError:
                logging.error("Link error in %s_%s", url_code, lang_code)
                raise
            else:
                new_name = prefix + url_code + '_' + lang_code + '.txt'
                souper(new_name, text, style, over_txt)


def strip_ep(text):
    # double newlines, otherwise the splitter merges the first lines
    text = re.sub(r'\n', r'\n\n', text)
    # discard language list at the beginning (it ends with Swedish/svenska)
    split = re.split(r'\nsv.{3}svenska.*\n', text)
    text = split[1]
    return text


def remove_newlines(soup):
    x = soup.find_all('p')
    length = len(x)
    for i in range(length):
        new_text = unicode(x[i]).replace('\n', ' ')
        x[i].replace_with(BeautifulSoup(new_text).p)