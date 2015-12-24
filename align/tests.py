__author__ = 'filip'

import unittest
import convert
import re


class TestConvert(unittest.TestCase):
    def test_tmx_header(self):
        header_en = ('<?xml version="1.0" encoding="utf-8" ?>\n'
                     '<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n'
                     '<tmx version="1.4">\n'
                     '  <header\n'
                     '    creationtool="eunlp"\n'
                     '    creationtoolversion="0.01"\n'
                     '    datatype="unknown"\n'
                     '    segtype="sentence"\n'
                     '    adminlang="' + 'en' + '"\n'
                     '    srclang="' + 'en' + '"\n'
                     '    o-tmf="TW4Win 2.0 Format"\n'
                     '  >\n'
                     '  </header>\n'
                     '  <body>\n')

        self.assertEqual(header_en, convert.tmx_header('en'))

    def test_make_tu_line(self):

        line = ('<tu creationdate="20151223T190423Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Hun</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n')
        self.assertEqual(
            line,
            convert.make_tu_line('en', 'ro', 'This is a line.',
                                 'Acesta e un rand.',
                                 '20151223T190423Z', '32013R1024',
                                 '<prop type="Txt::Alignment">Hun</prop>'))

    def test_tab_line_hun(self):
        s_lang = 'en'
        t_lang = 'ro'
        now = '20151223T190423Z'
        note = '32013R1024'
        line ='Hun\tAcesta e un rand.\tThis is a line.\n'
        resu = ('<tu creationdate="20151223T190423Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Hun</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n')
        self.assertEqual(resu, convert.tab_line(line, s_lang, t_lang, now,
                                                note))

    def test_tab_line_nai(self):
        s_lang = 'en'
        t_lang = 'ro'
        now = '20151223T190423Z'
        note = '32013R1024'
        line ='Nai\tAcesta e un rand.\tThis is a line.\n'
        resu = ('<tu creationdate="20151223T190423Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Short</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n')
        self.assertEqual(resu, convert.tab_line(line, s_lang, t_lang, now,
                                                note))

    def test_tab_line_err(self):
        s_lang = 'en'
        t_lang = 'ro'
        now = '20151223T190423Z'
        note = '32013R1024'
        line ='Err\tAcesta e un rand.\tThis is a line.\n'
        resu = ('<tu creationdate="20151223T190423Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Long_f</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n')
        self.assertEqual(resu, convert.tab_line(line, s_lang, t_lang, now,
                                                note))

    def test_tab_line_other(self):
        s_lang = 'en'
        t_lang = 'ro'
        now = '20151223T190423Z'
        note = '32013R1024'
        line ='Blabla\tAcesta e un rand.\tThis is a line.\n'
        resu = ('<tu creationdate="20151223T190423Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Unknown</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n')
        self.assertEqual(resu, convert.tab_line(line, s_lang, t_lang, now,
                                                note))

    def test_tab_line_other_tildas(self):
        s_lang = 'en'
        t_lang = 'ro'
        now = '20151223T190423Z'
        note = '32013R1024'
        line ='Blabla\t~~~ Acesta e un rand.\t~~~ This is a line.\n'
        resu = ('<tu creationdate="20151223T190423Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Unknown</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n')
        self.assertEqual(resu, convert.tab_line(line, s_lang, t_lang, now,
                                                note))

    def test_tab_line_other_xml_escapes(self):
        s_lang = 'en'
        t_lang = 'ro'
        now = '20151223T190423Z'
        note = '32013R1024'
        line ='Blabla\t& < > e un rand.\t& < > is a line.\n'
        resu = ('<tu creationdate="20151223T190423Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Unknown</prop>\n'
                '<tuv xml:lang="en"><seg>&amp; &lt; &gt; is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>&amp; &lt; &gt; e un rand.</seg></tuv> </tu>\n'
                '\n')
        self.assertEqual(resu, convert.tab_line(line, s_lang, t_lang, now,
                                                note))

    def test_tab_to_tmx(self):
        resu = ('<?xml version="1.0" encoding="utf-8" ?>\n'
                '<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n'
                '<tmx version="1.4">\n'
                '  <header\n'
                '    creationtool="eunlp"\n'
                '    creationtoolversion="0.01"\n'
                '    datatype="unknown"\n'
                '    segtype="sentence"\n'
                '    adminlang="en"\n'
                '    srclang="en"\n'
                '    o-tmf="TW4Win 2.0 Format"\n'
                '  >\n'
                '  </header>\n'
                '  <body>\n'
                '<tu creationdate="20151224T000530Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Long_f</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n'
                '<tu creationdate="20151224T000530Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Hun</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n'
                '<tu creationdate="20151224T000530Z" creationid="eunlp">'
                '<prop type="Txt::Note">32013R1024</prop>'
                '<prop type="Txt::Alignment">Short</prop>\n'
                '<tuv xml:lang="en"><seg>This is a line.</seg></tuv>\n'
                '<tuv xml:lang="ro"><seg>Acesta e un rand.</seg></tuv> </tu>\n'
                '\n'
                '\n'
                '</body>\n'
                '</tmx>')
        tab_file = ('Err\tAcesta e un rand.\tThis is a line.\n'
                    'Hun\tAcesta e un rand.\tThis is a line.\n'
                    'Nai\tAcesta e un rand.\tThis is a line.\n')
        s_lang = 'en'
        t_lang = 'ro'
        note = '32013R1024'
        actual_resu = convert.tab_to_tmx(tab_file, s_lang, t_lang, note)
        resu = re.sub(r'([0-9]){8}T([0-9]){6}Z', r'00000000T000000Z', resu)
        actual_resu = re.sub(r'([0-9]){8}T([0-9]){6}Z', r'00000000T000000Z',
                             actual_resu)
        self.assertEqual(resu, actual_resu)

    def test_tab_to_separate(self):
        tab_file = ('Err\tAcesta e un rand.\tThis is a line.\n'
                    'Hun\tAcesta e un rand.\tThis is a line.\n'
                    'Nai\tAcesta e un rand.\tThis is a line.\n')
        s_list = ['This is a line.', 'This is a line.', 'This is a line.']
        t_list = ['Acesta e un rand.', 'Acesta e un rand.',
                  'Acesta e un rand.']
        self.assertEqual((s_list, t_list), convert.tab_to_separate(tab_file))

    def test_split_line(self):
        line = 'Err\tAcesta e un rand.\tThis is a line.\n'
        self.assertEqual(('This is a line.', 'Acesta e un rand.'),
                         convert.split_line(line))

    def test_jsalign_cell(self):

        line = 'This is a line.'

        cell = ''.join(['      <div class="cell">',
                        '\n<span class="buttons">\n',
                        '<a href="#" class="button add" ',
                        'onclick="addFunction(this)">', '+ &#8595</a>\n',
                        '<a href="#" class="button delete"',
                        ' onclick="deleteFunction(this)">Del</a>\n',
                        '<a href="#" class="button merge"',
                        ' onclick="mergeFunction(this)">&#9939 &#8595</a>\n',
                        '<a href="#" class="button split"',
                        ' onclick="splitFunction(this)">&#9932&#9932</a>\n',
                        '</span>\n', '<span class="celltext" ',
                        ' contenteditable="true">', line, '</span></div>\n'])

        self.assertEqual(cell, convert.jsalign_cell(line))

    def test_jsalign_table(self):

        s_list = ['This is a line.', 'This is a line.', 'This is a line.']
        t_list = ['Acesta e un rand.', 'Acesta e un rand.',
                  'Acesta e un rand.']
        s_lang = 'en'
        t_lang = 'ro'
        note = '32013R1024'

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
        jsalign += ''.join(['src="https://rangy.googlecode.com/svn/trunk/',
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

        jsalign += '    <td id="source-col">\n'
        jsalign += ''.join([convert.jsalign_cell(line) for line in s_list])
        jsalign += '    </td>\n'

        jsalign += '    <td id="target-col">\n'
        jsalign += ''.join([convert.jsalign_cell(line) for line in t_list])
        jsalign += '    </td>\n'

        jsalign += '  </tr>\n'
        jsalign += '</table>\n'

        jsalign += '<div class="div-button">\n'
        jsalign += '  <button id="save-button">Save alignment</button>\n'
        jsalign += '</div>\n'
        jsalign += '</body>\n'
        jsalign += '</html>\n'

        self.assertEqual(jsalign, convert.jsalign_table(s_list, t_list, s_lang,
                                                        t_lang, note))

if __name__ == '__main__':
    unittest.main()
