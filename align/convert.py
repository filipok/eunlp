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
from itertools import izip_longest, izip
import os
import gzip


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


def m_tab_to_separate(input_name, output_source, output_targets):
    """

    :type input_name: str
    :type output_source: str
    :type output_targets: list
    """
    t_files = [codecs.open(t_file, 'w', 'utf-8') for t_file in output_targets]
    with codecs.open(input_name, "r", "utf-8") as fin:
        with codecs.open(output_source, 'w', 'utf-8') as out_s:
            for line in fin:
                text = re.split(r'\t', line)
                segments = len(text)
                source = text[segments - 1].strip('\n')
                targets = text[1:segments - 1]
                out_s.write(source + '\n')
                for pair in izip(targets, t_files):
                    pair[1].write(pair[0] + '\n')
    [t_file.close() for t_file in t_files]


def tmx_header(s_lang):
    # add tmx header (copied from LF Aligner output)
    """

    :type s_lang: str
    """
    header = ''
    header += '<?xml version="1.0" encoding="utf-8" ?>\n'
    header += '<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n'
    header += '<tmx version="1.4">\n'
    header += '  <header\n'
    header += '    creationtool="eunlp"\n'
    header += '    creationtoolversion="0.01"\n'
    header += '    datatype="unknown"\n'
    header += '    segtype="sentence"\n'
    header += '    adminlang="' + s_lang + '"\n'
    header += '    srclang="' + s_lang + '"\n'
    header += '    o-tmf="TW4Win 2.0 Format"\n'
    header += '  >\n'
    header += '  </header>\n'
    header += '  <body>\n'

    return header


def tmx_footer():
    """

    Create tmx footer
    """
    footer = ''
    footer += '\n'
    footer += '</body>\n'
    footer += '</tmx>'

    return footer


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
    tru = ''.join(['<tu creationdate="', now,
                   '" creationid="eunlp"><prop type="Txt::Note">',
                   note, '</prop>', tag, '\n'])
    #   create TUV source line
    s_tuv = ''.join(['<tuv xml:lang="', s_lang, '"><seg>', source,
                     '</seg></tuv>\n'])
    #   create TUV target line
    t_tuv = ''.join(['<tuv xml:lang="', t_lang, '"><seg>', target,
                     '</seg></tuv> </tu>\n'])
    return ''.join([tru, s_tuv, t_tuv, '\n'])


def m_make_tu_line(s_lang, t_langs, source, targets, now, note, tag):
    # create TU line
    """

    :type s_lang: str
    :type t_langs: list
    :type source: str
    :type targets: list
    :type now: str
    :type note: str
    :type tag: str
    """
    tru = ''.join(['<tu creationdate="', now,
                   '" creationid="eunlp"><prop type="Txt::Note">',
                   note, '</prop>', tag, '\n'])
    #   create TUV source line
    s_tuv = ''.join(['<tuv xml:lang="', s_lang, '"><seg>', source,
                     '</seg></tuv>\n'])
    #   create TUV target lines
    t_tuv = ''
    for pair in izip(t_langs, targets):
        tuv = ''.join(['<tuv xml:lang="', pair[0], '"><seg>', pair[1],
                       '</seg></tuv>\n'])
        t_tuv += tuv
    return ''.join([tru, s_tuv, t_tuv, '</tu>\n'])


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
    header = tmx_header(s_lang)  # add tmx header
    tmx_file += header
    for line in tab_file:
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
        tu_line = make_tu_line(s_lang, t_lang, source, target, now, note,
                               tag)
        tmx_file += tu_line

    footer = tmx_footer()  # add tmx footer
    tmx_file += footer
    return tmx_file


def m_tab_to_tmx(tab_file, tmx_name, s_lang, t_langs, note):
    # get current date
    """

    :type tab_file: str
    :type tmx_name: str
    :type s_lang: str
    :type t_langs: list
    :type note: str
    """
    now = datetime.datetime.now().isoformat()
    now = re.split(r"\.", re.sub(r"[-:]", r"", now))[0] + "Z"
    n_target = len(t_langs)
    # create new TMX file
    tmx_file = ''
    tab_file = tab_file.strip('\n')
    tab_file = re.split(r'\n', tab_file)
    with codecs.open(tmx_name, "w", "utf-8") as fout:
        header = tmx_header(s_lang)  # add tmx header
        tmx_file += header
        for line in tab_file:
            #   get source and target to temp variables
            text = re.split(r'\t', line)
            source = text[n_target + 1].strip('\n')
            targets = text[1:n_target + 1]
            if text[0] == 'Err':
                tag = '<prop type="Txt::Alignment">Long_f</prop>'
            elif text[0] == 'Nai':
                tag = '<prop type="Txt::Alignment">Short</prop>'
            elif text[0] == 'Hun':
                tag = '<prop type="Txt::Alignment">Hun</prop>'
            else:
                tag = '<prop type="Txt::Alignment">Unknown</prop>'

            # remove triple tildas from hunalign
            # source = source.replace('~~~ ', '')
            # target = target.replace('~~~ ', '')

            # escape XML entities '&', '<', and '>'
            source = xml.sax.saxutils.escape(source)
            targets = map(xml.sax.saxutils.escape, targets)
            # create TU
            tu_line = m_make_tu_line(s_lang, t_langs, source, targets, now,
                                     note, tag)
            tmx_file += tu_line
        footer = tmx_footer()  # add tmx footer
        tmx_file += footer
        fout.write(tmx_file)


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


def m_gzipper(files):
    """

    :type files: list
    """
    for text_file in files:
        gzipper(text_file)


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
        footer = tmx_footer()  # add tmx footer
        tmx_file += footer
        fout.write(tmx_file)
    return tmx_file


def html_table(source_list, target_list, file_name, page_title='No title'):
    """

    :type source_list: list
    :type target_list: list
    :type file_name: str
    :type page_title: str
    """
    with codecs.open(file_name,  'w', 'utf-8') as fout:
        fout.write('<!DOCTYPE html>\n')
        fout.write('<html>\n')
        fout.write('<head>\n')
        fout.write('<meta charset="UTF-8">\n')
        fout.write('<style>\n'
                   'table, th, td {\n'
                   'border: 1px solid black;\n'
                   '}\n'
                   '</style>\n')
        fout.write('<title>' + page_title + '</title>\n')
        fout.write('</head>\n')
        fout.write('<body>')
        fout.write('<table>')
        for pair in izip_longest(source_list, target_list, fillvalue='N/A'):
            fout.write('<tr>\n')
            fout.write('<td>')
            fout.write(pair[0])
            fout.write('</td>\n')
            fout.write('<td>')
            fout.write(pair[1])
            fout.write('</td>\n')
            fout.write('</tr>\n')
        fout.write('</table>\n')
        fout.write('</body>\n')
        fout.write('</html>\n')


def jsalign_table(source_list, target_list, s_lang, t_lang, note):
    """

    :type source_list: list
    :type target_list: list
    :type s_lang: str
    :type t_lang: str
    :type note: str
    """
    jsalign = ''
    jsalign += '<!DOCTYPE html>\n'
    jsalign += '<html>\n'

    jsalign += '<head>\n'
    jsalign += '<meta charset="UTF-8">\n'
    jsalign += '<meta name="source-language" content="' + s_lang + '">\n'
    jsalign += '<meta name="target-language" content="' + t_lang + '">\n'
    jsalign += '<meta name="doc-code" content="' + note + '">\n'
    jsalign += ''.join(
        ['<!-- <script class="links" type="text/javascript" src=',
         '"http://code.jquery.com/jquery-1.9.1.js"></script> -->\n'])
    jsalign += '<script class="links" type="text/javascript" '
    jsalign += ''.join(
        ['src="https://rawgit.com/filipok/jsalign/master/jsalign.js">',
         '</script>\n'])
    jsalign += '<script class="links" type="text/javascript" '
    jsalign += ''.join(['src="http://rangy.googlecode.com/svn/trunk/',
                        'currentrelease/rangy-core.js"></script>\n'])
    jsalign += '<link class="links" rel="stylesheet" type="text/css" href'
    jsalign += '="https://rawgit.com/filipok/jsalign/master/jsalign.css">\n'
    jsalign += ''.join(['<title>', note, ' - ', s_lang, ' - ', t_lang,
                        '</title>\n'])
    jsalign += '</head>\n'

    jsalign += '<body>\n'

    jsalign += '<table id = "header">\n'
    jsalign += '<tr>\n'

    jsalign += '<td>\n'
    jsalign += '<div id="doc-info">\n'
    jsalign += '<div id="doc-title">Document: ' + note + '</div>\n'
    jsalign += ''.join(['<div id="doc-source-language">Source language: ',
                        s_lang, '</div>\n'])
    jsalign += ''.join(['<div id="doc-target-language">Target language: ',
                        t_lang, '</div>\n'])
    jsalign += '<div id="help"><br/>Save a backup:<br/>\n'
    jsalign += '<button id="backup-button">Save and continue later'
    jsalign += '</button>\n'
    jsalign += '</div>\n'

    jsalign += '</td>\n'
    jsalign += '<td>\n'
    jsalign += '<div id="legend">\n'
    jsalign += '<div class="demo"><strong>Edit</strong> the text by'
    jsalign += ' clicking into the cell. The text will turn red.</div>\n'
    jsalign += '<div class="demo"><span class="buttons"><a class="button'
    jsalign += ' add-demo" href="#">+ &#8595</a>  Add new segment</div>\n'
    jsalign += '<div class="demo"><a class="button-demo delete-demo"'
    jsalign += ' href="#">Del</a> Delete segment</div>\n'
    jsalign += '<div class="demo"><a class="button-demo merge-demo"'
    jsalign += ' href="#">&#9939 &#8595</a></span> Merge segment'
    jsalign += ' with next</div>\n'
    jsalign += '<div class="demo"><a class="button-demo split-demo"'
    jsalign += ' href="#">&#9932 &#9932</a></span> Split segment (click'
    jsalign += ' where you want to split)</div>\n'
    jsalign += '<span class="celltext"></span>\n'
    jsalign += '</div>\n'
    jsalign += '</td>\n'
    jsalign += '</tr>\n'
    jsalign += '</table>\n'

    jsalign += '<table class="main-table">\n'
    jsalign += '  <tr class="main-row">\n'

    buttons = ''.join(
        ['\n<span class="buttons">\n',
            '<a href="#" class="button add" onclick="addFunction(this)">',
            '+ &#8595</a>\n',
            '<a href="#" class="button delete"',
            ' onclick="deleteFunction(this)">Del</a>\n',
            '<a href="#" class="button merge"',
            ' onclick="mergeFunction(this)">&#9939 &#8595</a>\n',
            '<a href="#" class="button split"',
            ' onclick="splitFunction(this)">&#9932&#9932</a>\n',
            '</span>\n'])

    jsalign += '    <td id="source-col">\n'
    for line in source_list:
        jsalign += ''.join(['      <div class="cell">', buttons,
                           '<span class="celltext" '])
        jsalign += ' contenteditable="true">'
        jsalign += line
        jsalign += '</span></div>\n'
    jsalign += '    </td>\n'

    jsalign += '    <td id="target-col">\n'
    for line in target_list:
        jsalign += ''.join(['      <div class="cell">', buttons,
                           '<span class="celltext" '])
        jsalign += ' contenteditable="true">'
        jsalign += line
        jsalign += '</span></div>\n'
    jsalign += '    </td>\n'

    jsalign += '  </tr>\n'
    jsalign += '</table>\n'

    jsalign += '<div class="div-button">\n'
    jsalign += '  <button id="save-button">Save alignment</button>\n'
    jsalign += '</div>\n'
    jsalign += '</body>\n'
    jsalign += '</html>\n'

    return jsalign


def m_html_table(source_list, targets, file_name, page_title='No title'):
    """

    :type source_list: list
    :type targets: list
    :type file_name: str
    :type page_title: str
    """
    with codecs.open(file_name,  'w', 'utf-8') as fout:
        fout.write('<!DOCTYPE html>\n')
        fout.write('<html>\n')
        fout.write('<head>\n')
        fout.write('<meta charset="UTF-8">\n')
        fout.write('<style>\n'
                   'table, th, td {\n'
                   'border: 1px solid black;\n'
                   '}\n'
                   '</style>\n')
        fout.write('<title>' + page_title + '</title>\n')
        fout.write('</head>\n')
        fout.write('<body>')
        fout.write('<table>')
        for row in izip_longest(source_list, *targets, fillvalue='N/A'):
            fout.write('<tr>\n')
            for cell in row:
                fout.write('<td>')
                fout.write(cell)
                fout.write('</td>\n')
            fout.write('</tr>\n')
        fout.write('</table>\n')
        fout.write('</body>\n')
        fout.write('</html>\n')


def paragraph_combiner_sub(text):
    """

    :type text: str
    :rtype: str
    """
    # pattern 1 combines 1-3 letters/numbers with dot/brackets with next line
    # negative lookahead cikk|FEJEZET|szakasz for Hungarian.
    # negative lookahead pants|ieda\wa for Latvian.
    # negative lookahead Jagu for Estonian.
    # negative lookahead for Estonian months:
    #     jaanuar|veebruar|m\wrts|aprill|mai|juuni|juuli|august|september|
    #     oktoober|november|detsember
    pattern_1_unicode = re.compile(
        r'\n(\(?(\w{1,3})[\.\)])\s+'
        r'(?!(cikk|FEJEZET|szakasz))'
        r'(?!(pants|ieda\wa|Jagu))'
        r'(?!(jaanuar|veebruar|m\wrts|aprill|mai|juuni))'
        r'(?!(juuli|august|september|oktoober|november|detsember))',
        re.UNICODE)
    # pattern 3 combines 1-3 numbers + single letter with the next line
    pattern_3_unicode = re.compile(
        r'\n(\(?([0-9]{1,3}(?![0-9])\w+)[\.\)])\s+', re.UNICODE)
    # combine lines consisting of Roman numerals to 9 with the next line
    pattern_4 = re.compile(r'\n(\(?i{1,3}[\.\)])\s+')  # 1-3
    pattern_5 = re.compile(r'\n(\(?iv[\.\)])\s+')  # 4
    pattern_6 = re.compile(r'\n(\(?vi{0,3}[\.\)])\s+')  # 5-8
    pattern_7 = re.compile(r'\n(\(?ix[\.\)])\s+')  # 9
    # the replacements
    text = re.sub(pattern_1_unicode, r'\n\1\n', text)
    text = re.sub(pattern_3_unicode, r'\n\1\n', text)
    text = re.sub(pattern_4, r'\n\1\n', text)
    text = re.sub(pattern_5, r'\n\1\n', text)
    text = re.sub(pattern_6, r'\n\1\n', text)
    text = re.sub(pattern_7, r'\n\1\n', text)
    return text


def file_to_list(file_name, tries=0):
    # clean and convert file to list of paragraphs
    """[\s|\xa0]+

    :type file_name: str
    :type tries: int
    :rtype: list
    """
    with codecs.open(file_name, "r", "utf-8") as fin:
        text = fin.read()
    text = re.sub(r'\xa0+', ' ', text)  # replace non-breaking space
    text = re.sub(r'\n\s+', r'\n', text)  # remove whitespace after newline
    text = re.sub(r'^\n+', r'', text)  # remove empty lines at the beginning
    text = re.sub(r'\n$', r'', text)  # remove empty lines at the end
    # merge segments separated by comma and whitespace, with some exceptions
    # which are language-dependent unfortunately
    # re.sub(r',\s\n(?!Whereas|Having regard|In cooperation)', r', ', text)
    text = re.sub(r'\s+\n', r'\n', text)  # remove whitespace before newline
    text = re.sub(r' +', r' ', text)  # remove double whitespaces
    text = re.sub(r'^ +', r'', text)  # remove whitespace at the beginning
    text = paragraph_combiner_sub(text)  # combine para numbers with text
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
    return paragraph_list


def merge_tmx():
    """
    Create a list of tmx files in current directory (also test for languages)


    """
    # for file in list:
    #    read file
    #    remove header and footer
    #    add remaining contents to target_file (if s_lang and t_lang?)
    # TODO function
    pass


def tmx_to_sqlite():
    """
    Convert tmx to existing or new sqlite file


    """
    # TODO function
    pass
