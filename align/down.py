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


def downloader(link, new_name, over=False, save_file=False):
    """

    :type link: str
    :type new_name: str
    :type over: bool
    :type save_file: bool
    :rtype: str
    """
    # Only download if not already existing, otherwise open from disk
    # over=True overrides that behavior
    if over or (not os.path.isfile(new_name)):
        response = urllib2.urlopen(link)
        html_text = response.read()
        if save_file:
            with open(new_name, 'w') as fout:
                fout.write(html_text)
    else:
        with codecs.open(new_name, "r", "utf-8") as fin:
            html_text = fin.read()
            logging.debug("%s: html file already downloaded.", new_name)

    # some celexes have one to three \n's inside <p> tags
    # remove all new lines and then recreate them after </p>
    # this hopefully eliminates all \n's inside <p> tags
    html_text = html_text.replace('\n', ' ')
    html_text = re.sub(r'</p> +', r'</p>\n', html_text)
    # Some celexes have no new line between paras
    # This confuses get_text() in BeautifulSoup
    html_text = re.sub(r'</p><p>', r'</p>\n<p>', html_text)
    html_text = re.sub(r'</p><p ', r'</p>\n<p ', html_text)
    # add whitespace between two adjacent columns
    html_text = re.sub(r'</td><td', r'</td> <td', html_text)
    # TODO de pus enter la chestii gen '>                            <p'
    # TODO de testat cu 32014L0095
    # TODO abort when server error
    return html_text


def souper(file_name, html_text, style, over=False, save_file=False):
    """

    :type file_name: str
    :type html_text: str
    :type style: str
    :type over: bool
    :type save_file: bool
    :rtype:
    """
    # Only convert to txt if not already existing
    # over=True overrides that behavior
    if (not over) and os.path.isfile(file_name):
        logging.info("%s: txt file already existing.", file_name)
        return
    soup = BeautifulSoup(html_text, "lxml")
    # separate branches for each document type
    find_div = soup.find(id='text')
    if style == "celex":
        try:
            if soup.txt_te is not None:
                # for oldest celexes
                clean_text = soup.txt_te.get_text()
            elif find_div is not None:
                # for the celex format as of May 2015
                clean_text = find_div.contents[1].contents[1].get_text()
            else:
                # for newer celexes, but in a format not valid after May 2015
                clean_text = soup.body.div.contents[8].contents[5].contents[0]
                clean_text = clean_text.contents[4].contents[9].contents[3]
                clean_text = clean_text.contents[1].get_text()
                clean_text = re.sub(r'\n\nTop $', r'', clean_text)
        except IndexError:
            logging.error('IndexError: Bs4 could not process %s', file_name)
            raise
        except AttributeError:
            logging.error('AttributeError: Bs4 could not process %s',file_name)
            raise
    elif style == "europarl":
        # TODO currently not maintained
        clean_text = soup.get_text()
        clean_text = strip_ep(clean_text)
    else:
        clean_text = soup.get_text()
    if save_file:
        with codecs.open(file_name, "w", "utf-8") as fout:
            fout.write(clean_text)
    return clean_text


def scraper(langs, make_link, url_code, prefix, style="", over_html=False,
            over_txt=False, save_files=False):
    """
    It downloads EU documents as html files and converts them to txt.
    Example usage:
    align.down.scraper(['bg', 'es'], align.util.make_celex_link, '32014D0390',
                       '', style='celex')

    :type langs: list
    :type make_link: function
    :type url_code: str
    :type prefix: str
    :type style: str
    :type over_html: bool
    :type over_txt: bool
    :type save_files: bool
    """
    # TODO de utilizat linkurile cu ALL pt celex si de extras clasificarile
    texts = []
    # TODO move exceptions outside
    for lang_code in langs:
        new_name = prefix + url_code + '_' + lang_code + '.html'
        try:
            link = make_link(url_code, lang_code)
            text = downloader(link, new_name, over_html, save_files)
        except urllib2.HTTPError:
            logging.error("Link error in %s_%s", url_code, lang_code)
            raise
        else:
            new_name = prefix + url_code + '_' + lang_code + '.txt'
            try:
                texts.append(
                    souper(new_name, text, style, over_txt, save_files))
            except (IndexError, AttributeError):
                raise
    return texts


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
