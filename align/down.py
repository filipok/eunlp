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
import datetime


def downloader(link, new_name, over=False, save_intermediates=False, merge_count=False, add_para=False,
               remove_s38=True, dizpozitiv=False, sumar_ro=True):
    """

    :type link: str
    :type new_name: str
    :type over: bool
    :type save_intermediates: bool
    :type merge_count: bool
    :type add_para: bool
    :type remove_s38: bool
    :type dizpozitiv: bool
    :type sumar_ro: bool
    :rtype: str
    """
    # Only download if not already existing, otherwise open from disk
    # over=True overrides that behavior
    if over or (not os.path.isfile(new_name)):
        response = urllib2.urlopen(link)
        html_text = response.read()
        if save_intermediates:
            with open(new_name, 'w') as fout:
                fout.write(html_text)
    else:
        with codecs.open(new_name, "r", "utf-8") as fin:
            html_text = fin.read()
            logging.debug("%s: html file already downloaded.", new_name)

    # for consolidated versions; hopefully it does not break anything
    html_text = re.sub(
        r'<span style="word-spacing: [0-9]{2}pt">\xa0</span>', r'</p><p>',
        html_text)
    html_text = re.sub(r'<p class="disclaimer">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<p class="arrow">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<p class="modref">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<p class="title-fam-member">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<p class="hd-modifiers">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    # mostly for special edition OJ texts
    html_text = re.sub(r'<p class="hd-date">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<p class="hd-lg">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<p class="hd-ti">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<p class="hd-oj">.+?</p>', r'', html_text,
                       flags=re.DOTALL)
    html_text = re.sub(r'<hr class="separator"/>\n\s+<p class="normal">.+?</p>',
                       r'', html_text, flags=re.DOTALL)
    # remove signatures from Court documents
    html_text = re.sub(r'<td\s*>\n\s+<div class="signaturecase">.+?</td>',
                       r'', html_text, flags=re.DOTALL)
    # currently useful for Czech texts
    html_text = html_text.replace('&nbsp;', ' ')
    # Curia documents use upper-case tags and other corrections
    html_text = html_text.replace(r'</P>', r'</p>')
    html_text = html_text.replace(r'<P>', r'<p>')
    html_text = html_text.replace(r'<P >', r'<p >')
    html_text = html_text.replace(r'<P class', r'<p class')
    html_text = re.sub(r'<BR>et<BR>', r'</p>\n<p>et</p>\n<p>', html_text)
    html_text = re.sub(r'<BR>contre<BR>', r'</p>\n<p>contre</p>\n<p>', html_text)
    html_text = re.sub(r'<p class="C39Centre">ARR(.+?)<BR>(\d{1,2}) ',
                       r'<p class="C39Centre">ARR\1</p>\n<p>\2 ', html_text)

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
    # add new lines also before paras preceded by other tags (such as table)
    html_text = re.sub(r'> +<p', r'>\n<p', html_text)
    if merge_count:
        html_text = re.sub(r'<p class="count">(.+?)</p>.+?<p class="normal">',
                           r'<p class="normal">\1 ', html_text, flags=re.DOTALL)
    if add_para:
        print 'in add para'
        with codecs.open(datetime.datetime.now().isoformat() + '_before_addpara.html', 'w', 'utf-8') as fout:
            fout.write(html_text)
        html_text = re.sub(r'\r\n', r'\n', html_text)
        html_text = re.sub(r'\r', r'\n', html_text)
        with codecs.open(datetime.datetime.now().isoformat() + '_crreplace.html', 'w', 'utf-8') as fout:
            fout.write(html_text)

        html_text = re.sub(r'</table>\s+?<table',
                           r'</table>\n<table', html_text)
        html_text = re.sub(r'</p>\s+?<p class="pnormal">',
                           r'</p>\n<p class="pnormal">', html_text)
        html_text = re.sub(r'</p>\s+?<p class="normal">',
                           r'</p>\n<p class="normal">', html_text)
        html_text = re.sub(r'</table>\s+?<p class="normal">',
                           r'</table>\n<p class="normal">', html_text)
        html_text = re.sub(r'<p class="note">',
                           r'\n<p class="note">', html_text)
        html_text = re.sub(r'</p>\s+?<table',
                           r'</p>\n<table', html_text)
        html_text = re.sub(r'<p class="sum-title-1">',
                           r'\n<p class="sum-title-1">', html_text)
        html_text = re.sub(r'<p class="index">',
                           r'\n<p class="index">', html_text)
        html_text = re.sub(r'<p class="pstatus">',
                           r'\n<p class="pstatus">', html_text)
        html_text = re.sub(r'<p class="ti-art">',
                           r'\n<p class="ti-art">', html_text)
        html_text = re.sub(r'<p class="title-grseq-(\d)">',
                           r'\n<p class="title-grseq-\1">', html_text)
        with codecs.open(datetime.datetime.now().isoformat() + '_after_addpara.html', 'w', 'utf-8') as fout:
            fout.write(html_text)
    if remove_s38:
        html_text = re.sub(r'<p class="S38ReferenceIntro">.+?</p>',
                           r'', html_text)
    # for RO curia docs from 2008-2009
    if not sumar_ro:
        with codecs.open(datetime.datetime.now().isoformat() + '_before_notsumar.html', 'w', 'utf-8') as fout:
            fout.write(html_text)
        html_text = re.sub(r'<p class="S73Alineacentregras"><B>Cauza .+?</p>\n<br>',
                           r'', html_text, flags=re.DOTALL)
        with codecs.open(datetime.datetime.now().isoformat() + '_after_notsumar.html', 'w', 'utf-8') as fout:
            fout.write(html_text)
    # for some FR-RO Curia alignments from 2008-2009
    if dizpozitiv:
        print 'in dizpozitiv'
        with codecs.open(datetime.datetime.now().isoformat() + '_before_dizpozitiv.html', 'w', 'utf-8') as fout:
            fout.write(html_text)
        html_text = re.sub(r'<h2 class="rech">Dizpozitiv</h2>', r'', html_text) #RO
        html_text = re.sub(r'<h2 class="rech">Motivele</h2>', r'', html_text) #RO
        html_text = re.sub(r'<p class="normal">Signatures</p>', r'', html_text) #FR
        html_text = re.sub(r'<p class="note">.+?</p>',r'', html_text, flags=re.DOTALL) #FR
        html_text = re.sub(r'<p class="index">.+?</p>', r'', html_text)  #FR
        html_text = re.sub(r'<a href="#I1">P.r.i</a>', r'', html_text)  # RO
        html_text = re.sub(r'<a href="#MO">Motivele</a>', r'', html_text)  # RO
        html_text = re.sub(r'<a href="#DI">Dizpozitiv</a>', r'', html_text)  # RO
        html_text = re.sub(r'<h2 class="rech">P.r.i</h2>', r'', html_text)  # RO
        html_text = re.sub(r'<p class="sum-title-1">.+?ARR.T DE LA COUR.+?</p>.+?<p class="sum-title-1">.+?</p>',
                           r'', html_text, flags=re.DOTALL)  # FR
        with codecs.open(datetime.datetime.now().isoformat() + '_after_dizpozitiv.html', 'w', 'utf-8') as fout:
            fout.write(html_text)
    # TODO abort when server error
    return html_text


def souper(file_name, html_text, style, over=False, save_intermediates=False):
    """

    :type file_name: str
    :type html_text: str
    :type style: str
    :type over: bool
    :type save_intermediates: bool
    :rtype:
    """
    # Only convert to txt if not already existing
    # over=True overrides that behavior
    if (not over) and os.path.isfile(file_name):
        with codecs.open(file_name, "r", "utf-8") as fin:
            clean_text = fin.read()
            logging.debug("%s: txt file already existing.", file_name)
        return clean_text
    soup = BeautifulSoup(html_text, "lxml")
    # separate branches for each document type
    find_div = soup.find(id='document1')
    if style == "celex":
        try:
            if soup.txt_te is not None:
                # for oldest celexes
                clean_text = soup.txt_te.get_text()
            elif find_div is not None:
                # for the celex format as of September 2018
                clean_text = find_div.contents[1].contents[1].get_text()
            elif len(soup.findAll("div", {"class": "alert-warning"}))>0:
                # for very big files that do not load automatically
                logging.warning(
                    "File is very big, manual alignment might crash browser!")
                big_file_link = soup.findAll("div", {"class": "alert-warning"})[0].findAll("a")[0]['href']
                new_html_text = downloader(
                    big_file_link, file_name + '_big.html', save_intermediates=save_intermediates)
                new_soup = BeautifulSoup(new_html_text, "lxml")
                clean_text = new_soup.find('body').get_text()
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
            logging.error('AttributeError: Bs4 could not process %s',
                          file_name)
            raise
    elif style == "europarl":
        # TODO currently not maintained
        clean_text = soup.get_text()
        clean_text = strip_ep(clean_text)
    else:
        clean_text = soup.get_text()
    if save_intermediates:
        with codecs.open(file_name, "w", "utf-8") as fout:
            fout.write(clean_text)
    return clean_text


def scraper(langs, make_link, url_code, prefix, style="", over_html=False,
            over_txt=False, save_intermediates=False, merge_count=False, add_para=False,
            dizpozitiv=False,sumar_ro=True):
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
    :type save_intermediates: bool
    :type merge_count: bool
    :type add_para: bool
    :type dizpozitiv: bool
    :type sumar_ro: bool
    """
    # TODO de utilizat linkurile cu ALL pt celex si de extras clasificarile
    texts = []
    # TODO move exceptions outside
    for lang_code in langs:
        new_name = prefix + url_code + '_' + lang_code + '.html'
        new_name = re.sub(r'/', r'_', new_name)
        try:
            link = make_link(url_code, lang_code)
            text = downloader(link, new_name, over_html, save_intermediates, merge_count, add_para,
                              dizpozitiv=dizpozitiv, sumar_ro=sumar_ro)
        except urllib2.HTTPError:
            logging.error("Link error in %s_%s", url_code, lang_code)
            raise
        else:
            new_name = prefix + url_code + '_' + lang_code + '.txt'
            new_name = re.sub(r'/', r'_', new_name)
            try:
                texts.append(
                    souper(new_name, text, style, over_txt, save_intermediates))
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
