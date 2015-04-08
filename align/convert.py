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


def tab_to_separate(input_name, output_source, output_target):
    """

    :type input_name: str
    :type output_source: str
    :type output_target: str
    """
    with codecs.open(input_name, "r", "utf-8") as fin:
        with codecs.open(output_source, "w", "utf-8") as out_s:
            with codecs.open(output_target, "w", "utf-8") as out_t:
                for line in fin:
                    line = line.strip('\n')
                    text = re.split(r'\t', line)
                    source = text[2]
                    target = text[1]
                    out_s.write(source + '\n')
                    out_t.write(target + '\n')


def tmx_header(fout, s_lang):
    # add tmx header (copied from LF Aligner output)
    """

    :type fout: file
    :type s_lang: str
    """
    fout.write('<?xml version="1.0" encoding="utf-8" ?>\n')
    fout.write('<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n')
    fout.write('<tmx version="1.4">\n')
    fout.write('  <header\n')
    fout.write('    creationtool="eunlp"\n')
    fout.write('    creationtoolversion="0.01"\n')
    fout.write('    datatype="unknown"\n')
    fout.write('    segtype="sentence"\n')
    fout.write('    adminlang="' + s_lang + '"\n')
    fout.write('    srclang="' + s_lang + '"\n')
    fout.write('    o-tmf="TW4Win 2.0 Format"\n')
    fout.write('  >\n')
    fout.write('  </header>\n')
    fout.write('  <body>\n')


def tmx_footer(fout):
    # add tmx footer
    """

    :type fout: file
    """
    fout.write('\n')
    fout.write('</body>\n')
    fout.write('</tmx>')


def make_tu_line(fout, s_lang, t_lang, source, target, now, note, tag):
    # create TU line
    """

    :type fout: file
    :type s_lang: str
    :type t_lang: str
    :type source: str
    :type target: str
    :type now: str
    :type note: str
    :type tag: str
    """
    tru = ''.join(['<tu creationdate="', now,
                   '" creationid="eunlp"><prop type="Txt::Note">',
                   note, '</prop>', tag, '\n'])
    fout.write(tru)
    #   create TUV source line
    tuv = ''.join(['<tuv xml:lang="', s_lang, '"><seg>', source,
                   '</seg></tuv>\n'])
    fout.write(tuv)
    #   create TUV target line
    tuv = ''.join(['<tuv xml:lang="', t_lang, '"><seg>', target,
                   '</seg></tuv> </tu>\n'])
    fout.write(tuv)
    fout.write('\n')


def tab_to_tmx(input_name, tmx_name, s_lang, t_lang, note):
    # get current date
    """

    :type input_name: str
    :type tmx_name: str
    :type s_lang: str
    :type t_lang: str
    :type note: str
    """
    now = datetime.datetime.now().isoformat()
    now = re.split(r"\.", re.sub(r"[-:]", r"", now))[0] + "Z"
    # create new TMX file
    with codecs.open(tmx_name, "w", "utf-8") as fout:
        tmx_header(fout, s_lang)  # add tmx header
        with codecs.open(input_name, "r", "utf-8") as fin:
            for line in fin:
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
                make_tu_line(fout, s_lang, t_lang, source, target, now, note,
                             tag)
        tmx_footer(fout)  # add tmx footer


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
    logging.warning('Preparing list of %s documents...', length)
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
    with codecs.open(tmx_file_name, 'w', 'utf-16') as fout:
        tmx_header(fout, s_lang)  # add tmx header
        for line in tu_list:
            # fout.write(line + '\n')
            source = line.split('Tuv Lang="' + ttx_s_lang + '">')[1]
            source = source.split('</Tuv><Tuv Lang="' + ttx_t_lang + '">')[0]
            target = line.split('Tuv Lang="' + ttx_s_lang + '">')[1]
            target = target.split('</Tuv><Tuv Lang="' + ttx_t_lang + '">')[1]
            target = target.split('</Tuv></Tu>')[0]
            # create TU
            make_tu_line(fout, s_lang, t_lang, source, target, now, note,
                         tag)
        tmx_footer(fout)  # add tmx footer


def merge_tmx():
    """
    Create a list of tmx files in current directory (also test for languages)


    """
    # for file in list:
    #    read file
    #    remove header and footer
    #    add remaining contents to target_file (if s_lang and t_lang?)
    pass
