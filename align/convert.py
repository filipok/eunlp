"""
Name:        convert.py
Purpose:     Converters

Author:      Filip

Created:     1.4.2015
"""


import codecs
import re
import datetime
import xml.sax.saxutils
import logging
from bs4 import BeautifulSoup
import os
import gzip
from jinja2 import Template
from const import TMX_FOOTER, TMX_HEADER, TRU, TUV, CELL, PAGE, SUBFOLDER
import util


def tmx_header(s_lang):
    # add tmx header (copied from LF Aligner output)
    """

    :type s_lang: str
    """
    return TMX_HEADER.format(s_lang, s_lang)


def make_tu_line(s_lang, t_lang, source, target, now, note, tag):
    # create TU line
    """

    :type s_lang: str
    :type t_lang: str
    :type source: str
    :type target: str
    :type now: str
    :type note: str
    :type tag: str
    """
    tru = TRU.format(now, note, tag)
    #   create TUV source line
    s_tuv = TUV.format(s_lang, source)
    #   create TUV target line
    t_tuv = TUV.format(t_lang, target)
    return ''.join([tru, s_tuv, '\n', t_tuv, ' </tu>\n\n'])


def tab_line(line, s_lang, t_lang, now, note):
    """

    :type line: str
    :type s_lang: str
    :type t_lang: str
    :type now: str
    :type note: str
    :rtype: str
    """
    #   get source and target to temp variables
    text = re.split(r'\t', line)
    source = text[2].strip('\n')
    target = text[1]
    if text[0] == 'Err':
        tag = '<prop type="Txt::Alignment">Long_f</prop>'
    elif text[0] == 'Nai':
        tag = '<prop type="Txt::Alignment">Short</prop>'
    elif text[0] == 'Hun':
        tag = '<prop type="Txt::Alignment">Hun</prop>'
    else:
        tag = '<prop type="Txt::Alignment">Unknown</prop>'
    # remove triple tildas from hunalign
    source = source.replace('~~~ ', '')
    target = target.replace('~~~ ', '')
    # escape XML entities '&', '<', and '>'
    source = xml.sax.saxutils.escape(source)
    target = xml.sax.saxutils.escape(target)
    # create TU
    return make_tu_line(s_lang, t_lang, source, target, now, note, tag)


def tab_to_tmx(tab_file, s_lang, t_lang, note):
    # get current date
    """

    :type tab_file: str
    :type s_lang: str
    :type t_lang: str
    :type note: str
    """
    now = datetime.datetime.now().isoformat()
    now = re.split(r"\.", re.sub(r"[-:]", r"", now))[0] + "Z"
    # create new TMX file
    tmx_file = ''
    tab_file = tab_file.strip('\n')
    tab_file = re.split(r'\n', tab_file)
    tmx_file += tmx_header(s_lang)  # add tmx header
    tmx_file += ''.join(
        [tab_line(line, s_lang, t_lang, now, note) for line in tab_file])
    tmx_file += TMX_FOOTER
    return tmx_file


def tab_to_separate(tab_file):
    """

    :type tab_file: str
    :return:
    """
    tab_file = tab_file.strip('\n')
    tab_file = re.split(r'\n', tab_file)
    s_list, t_list = zip(*[split_line(line) for line in tab_file])
    return list(s_list), list(t_list)


def split_line(line):
    """

    :type line: str
    """
    text = re.split(r'\t', line)
    return text[2].strip('\n'), text[1]


def gzipper(source_file):
    """

    :type source_file: str
    """
    f_in = open(source_file, 'rb')
    f_out = gzip.open(source_file + '.gz', 'wb')
    f_out.writelines(f_in)
    f_out.close()
    f_in.close()
    os.remove(source_file)


def eu_xml_converter(file_name):
    """

    :type file_name: str
    :rtype: list
    """
    with codecs.open(file_name, 'r', 'utf-8') as fin:
        text = fin.read()
    soup = BeautifulSoup(text, 'lxml')
    lista = []
    res_list = soup.find_all('result')
    length = len(res_list)
    logging.info('Preparing list of %s documents...', length)
    for i in range(length):
        if res_list[i].find('id_celex') is not None:
            celex = res_list[i].find('id_celex').contents[1].contents[0]
        else:
            celex = 'NoCELEX'
        title = res_list[i].find('expression_title').contents[1].contents[0]
        lista.append((celex, title))
    return lista


def dirty_ttx_to_tmx(ttx_file_name, tmx_file_name, ttx_s_lang, ttx_t_lang,
                     s_lang, t_lang, note):
    """
    Usage: dirty_ttx_to_tmx('test.ttx', 'rez.tmx', "EN-GB", "RO-RO",
                            'en', 'ro', 'test_note')

    :type ttx_file_name: str
    :type tmx_file_name: str
    :type s_lang: str
    :type t_lang: str
    :type ttx_s_lang: str
    :type ttx_t_lang: str
    :type note: str
    """
    with codecs.open(ttx_file_name, 'r', 'utf-16') as fin:
        text = fin.read()
    # add newline before Tu tag if missing
    text = re.sub(r'\t<Tu', r'\r\n<Tu', text)
    text = re.sub(r'&lt;.+?&gt;', r'', text)
    # remove all df tags
    text = re.sub(r'<df.+?>', r'', text)
    text = re.sub(r'</df>', r'', text)
    # remove all ut tags
    text = re.sub(r'<ut.+?>', r'', text)
    text = re.sub(r'</ut>', r'', text)
    # convert to list of lines and select those starting with the Tu tag
    tu_list = re.split('\r\n', text)
    tu_list = [line for line in tu_list if line[:3] == u'<Tu']

    now = datetime.datetime.now().isoformat()
    now = re.split(r"\.", re.sub(r"[-:]", r"", now))[0] + "Z"
    tag = '<prop type="Txt::Alignment">TTX</prop>'
    tmx_file = ''
    with codecs.open(tmx_file_name, 'w', 'utf-16') as fout:
        header = tmx_header(s_lang)  # add tmx header
        tmx_file += header
        for line in tu_list:
            source = line.split('Tuv Lang="' + ttx_s_lang + '">')[1]
            source = source.split('</Tuv><Tuv Lang="' + ttx_t_lang + '">')[0]
            target = line.split('Tuv Lang="' + ttx_s_lang + '">')[1]
            target = target.split('</Tuv><Tuv Lang="' + ttx_t_lang + '">')[1]
            target = target.split('</Tuv></Tu>')[0]
            # create TU
            tu_line = make_tu_line(s_lang, t_lang, source, target, now, note,
                                   tag)
            tmx_file += tu_line
        tmx_file += TMX_FOOTER
        fout.write(tmx_file)
    return tmx_file


def jsalign_table(source_list, target_list, s_lang, t_lang, note):
    """

    :type source_list: list
    :type target_list: list
    :type s_lang: str
    :type t_lang: str
    :type note: str
    """
    s_cells = ''.join([CELL.format(line) for line in source_list])
    t_cells = ''.join([CELL.format(line) for line in target_list])

    return Template(PAGE).render(s_lang=s_lang, t_lang=t_lang, note=note,
                                 s_cells=s_cells, t_cells=t_cells)


def numbering_separator(text, lang):
    """

    :type text: str
    :type lang: str
    :rtype: str
    """
    # pattern 1 separate 1-3 letters/numbers with dot/brackets from the line.
    # they can be preceded by one quotation mark (W?)
    # negative lookahead cikk|FEJEZET|szakasz etc. for Hungarian.
    # negative lookahead pants|ieda\wa etc. for Latvian.
    # negative lookahead Jagu, detsembriks etc. for Estonian.
    # negative lookahead for Estonian months:
    #     jaanuar|veebruar|m\wrts|aprill|mai|juuni|juuli|august|september|
    #     oktoober|november|detsember
    # TODO eventual de rulat doar pentru limba respectiva
    pattern_1_unicode = re.compile(
        r'\n(\W?\(?(\w{1,3})[\.\)])(?!\n)\s+'
        r'(?!(cikk|FEJEZET|szakasz|SZAKASZ|MELL\wKLET|R\wSZ|t\wbl\wzat))'  # HU
        r'(?!(T\wbl\wzat|sablon|C\wM|fejezet|mell\wklet))'  # HU
        r'(?!(pants|ieda\wa|IEDA\wA|panta|DA\wA|tabula|sk|sada\wa))'  # LV
        r'(?!(Tabula|posms|NODA\wA|l\wdz ))'  # LV'
        r'(?!(Jagu|JAGU|jagu|detsembriks|OSA|etapp|PEAT\wKK))'  # ET
        r'(?!(jaanuar|veebruar|m\wrts|aprill|mai|juuni))'  # ET
        r'(?!(juuli|august|september|oktoober|november|detsember))',  # ET
        re.UNICODE)
    # pattern 3 separates 1-3 numbers + single letter from the line
    # they can be preceded by one quotation mark (W?)
    # negative lookahead cikk for Hungarian.
    # TODO acelasi negativ lookahead ca la pattern 1
    pattern_3_unicode = re.compile(
        r'\n(\W?\(?([0-9]{1,3}(?![0-9])\w+)[\.\)])\s+'
        r'(?!(cikk|t\wbl\wzat))',  # HU
        re.UNICODE)

    # separate lines consisting of Roman numerals to 9 from the line
    pattern_4 = re.compile(r'\n(\W?\(?i{1,3}[\.\)])\s+')  # 1-3
    pattern_5 = re.compile(r'\n(\W?\(?iv[\.\)])\s+')  # 4
    pattern_6 = re.compile(r'\n(\W?\(?vi{0,3}[\.\)])\s+')  # 5-8
    pattern_7 = re.compile(r'\n(\W?\(?ix[\.\)])\s+')  # 9

    # the replacements
    text = re.sub(pattern_1_unicode, r'\n\1' + u'\xa0', text)
    text = re.sub(pattern_3_unicode, r'\n\1' + u'\xa0', text)
    text = re.sub(pattern_4, r'\n\1' + u'\xa0', text)
    text = re.sub(pattern_5, r'\n\1' + u'\xa0', text)
    text = re.sub(pattern_6, r'\n\1' + u'\xa0', text)
    text = re.sub(pattern_7, r'\n\1' + u'\xa0', text)
    # restore start-of-the-line abbreviations damaged by pattern 1
    path = os.path.dirname(__file__)
    ab_file = ''.join([path, SUBFOLDER, lang])
    abbrevs = util.abbreviation_loader(ab_file)
    for abb in abbrevs:
        # TODO pentru HU sa restaurez si alea gen '3.'?
        # TODO test 32015R0003_en_hu
        # TODO daca in HU nu incep alineate cu cifra plus punct, ar fi ok.
        # only restore abbreviations of two or more characters, if not numeric
        roman_num = ['ii', 'iii', 'iv', 'vi', 'vii', 'viii', 'ix']
        if len(abb) > 1 and not abb.isdigit() and abb not in roman_num:
            text = re.sub(r'\n' + abb + r'(\.\xa0)', r'\n' + abb + r'. ', text)
    text = re.sub(r'\xa0', r'\n', text)
    return text


def file_to_list(text, lang, tries=0):
    # clean and convert file to list of paragraphs
    """[\s|\xa0]+

    :type text: str
    :type lang: str
    :type tries: int
    :rtype: list
    """
    text = re.sub(r'\xa0+', ' ', text)  # replace non-breaking space
    text = re.sub(r'\n\s+', r'\n', text)  # remove whitespace after newline
    text = re.sub(r'^\n+', r'', text)  # remove empty lines at the beginning
    text = re.sub(r'\n$', r'', text)  # remove empty lines at the end
    text = re.sub(r'\s+\n', r'\n', text)  # remove whitespace before newline
    text = re.sub(r' +', r' ', text)  # remove double whitespaces
    text = re.sub(r'^\s+', r'', text)  # remove whitespace at the beginning
    text = re.sub(r'\n\.\n', r'.\n', text)  # single full stop to prev. para.
    text = numbering_separator(text, lang)  # separate para numbers from text
    if tries in [1, 2, 3]:
        # remove one-character lines which can make the aligner to fail
        text = re.sub(r'\n.(?=\n)', r'', text)
    if tries in [2, 3]:
        # also try to remove two-character lines which can make it to fail
        text = re.sub(r'\n.{1,2}(?=\n)', r'', text)
    if tries == 3:
        # also try to remove three-character lines which can make it to fail
        text = re.sub(r'\n.{1,3}(?=\n)', r'', text)
    paragraph_list = re.split(r'\n', text)  # split file
    # TODO split 'Bla bla bla V. Bla bla' because nltk ignores them.
    # TODO split 'Bla bla bla.Bla bla'
    # TODO verificator de abrevieri noi.
    return paragraph_list
