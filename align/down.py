"""
Name:        down.py
Purpose:     Utilities to download files and use BeautifulSoup

Author:      Filip

Created:     1.4.2015
"""

import os
import urllib2
import re
import codecs
import logging
from bs4 import BeautifulSoup


def downloader(link, new_name, over=False):
    """

    :type link: str
    :type new_name: str
    :type over: bool
    :rtype: str
    """
    # Only download if not already existing, otherwise open from disk
    # over=True overrides that behavior
    if over or (not os.path.isfile(new_name)):
        response = urllib2.urlopen(link)
        html_text = response.read()

        # TODO cleanup
        # some celexes have no new line between paras
        # this confuses get_text() in BeautifulSoup
        html_text = re.sub(r'</p><p>', r'</p>\n<p>', html_text)
        # some celexes have \n inside <p> tags
        html_text = re.sub(r'<p(.*?)>(.+?)(?<!</p>)(\n)(.+?)</p>',
                           r'<p>\1>\2 \4</p>', html_text)

        with open(new_name, 'w') as fout:
            fout.write(html_text)
    else:
        with codecs.open(new_name, "r", "utf-8") as fin:
            html_text = fin.read()
            logging.debug("%s: html file already downloaded.", new_name)
            # This could be redundant
            # some celexes have no new line between paras
            # this confuses get_text() in BeautifulSoup
            html_text = re.sub(r'</p><p>', r'</p>\n<p>', html_text)
            # some celexes have \n inside <p> tags
            html_text = re.sub(r'<p(.*?)>(.+?)(?<!</p>)(\n)(.+?)</p>',
                               r'<p>\1>\2 \4</p>', html_text)
    return html_text


def souper(new_name, html_text, style, over=False):
    """

    :type new_name: str
    :type html_text: str
    :type style: str
    :type over: bool
    :rtype:
    """
    # TODO aici uneste coloanele fara spatiu
    # TODO <td>Interest rate risk sub-module</td><td>105</td>
    # Only convert to txt if not already existing
    # over=True overrides that behavior
    if (not over) and os.path.isfile(new_name):
        logging.info("%s: txt file already existing.", new_name)
        return
    fout = codecs.open(new_name, "w", "utf-8")
    soup = BeautifulSoup(html_text, "lxml")
    # some celexes have \n inside <p> tags
    # remove_newlines(soup) #  very slow!
    # separate branches for each document type
    find_div = soup.find(id='text')
    if style == "celex":
        if soup.txt_te is not None:
            # for oldest celexes
            clean_text = soup.txt_te.get_text()
        elif find_div is not None:
            # for the celex format as of May 2015
            try:
                clean_text = find_div.contents[1].contents[1].get_text()
            except IndexError:
                logging.error('IndexError: Bs4 could not process %s', new_name)
                raise
            except AttributeError:
                logging.error('AttributeError: Bs4 could not process %s',
                              new_name)
                raise
        else:
            # for newer celexes, but in a format not valid after May 2015
            # the hierarchy is rather deep
            try:
                clean_text = soup.body.div.contents[8].contents[5].contents[0]
                clean_text = clean_text.contents[4].contents[9].contents[3]
                clean_text = clean_text.contents[1].get_text()
                clean_text = re.sub(r'\n\nTop $', r'', clean_text)
            except IndexError:
                logging.error('IndexError: Bs4 could not process %s', new_name)
                raise
            except AttributeError:
                logging.error('AttributeError: Bs4 could not process %s',
                              new_name)
                raise
    elif style == "europarl":
        # TODO currently not maintained
        clean_text = soup.get_text()
        clean_text = strip_ep(clean_text)
    else:
        clean_text = soup.get_text()
    fout.write(clean_text)
    fout.close()


def scraper(langs, make_link, url_code, prefix, style="", over_html=False,
            over_txt=False):
    """

    :type langs: list
    :type make_link: function
    :type url_code: str
    :type prefix: str
    :type style: str
    :type over_html: bool
    :type over_txt: bool
    """
    # TODO de utilizat linkurile cu ALL pt celex si de extras clasificarile
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
            try:
                souper(new_name, text, style, over_txt)
            except (IndexError, AttributeError):
                raise


def strip_ep(text):
    """

    :type text: str
    :rtype: str
    """
    # double newlines, otherwise the splitter merges the first lines
    text = re.sub(r'\n', r'\n\n', text)
    # discard language list at the beginning (it ends with Swedish/svenska)
    split = re.split(r'\nsv.{3}svenska.*\n', text)
    text = split[1]
    return text


def remove_newlines(soup):
    """

    :type soup: BeautifulSoup
    """
    para_list = soup.find_all('p')
    length = len(para_list)
    for i in range(length):
        new_text = unicode(para_list[i]).replace('\n', ' ')
        para_list[i].replace_with(BeautifulSoup(new_text).p)
