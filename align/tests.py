__author__ = 'filip'

import unittest
import convert
from align import align
import re
import codecs
import os
from const import CELL


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
        line = 'Hun\tAcesta e un rand.\tThis is a line.\n'
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
        line = 'Nai\tAcesta e un rand.\tThis is a line.\n'
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
        line = 'Err\tAcesta e un rand.\tThis is a line.\n'
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
        line = 'Blabla\tAcesta e un rand.\tThis is a line.\n'
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
        line = 'Blabla\t~~~ Acesta e un rand.\t~~~ This is a line.\n'
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
        line = 'Blabla\t& < > e un rand.\t& < > is a line.\n'
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
                '</tmx>\n')
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

        cell = ''.join(['<div class="cell" draggable="true" '
                        'ondragstart="drag(event)" ',
                        'onmouseover="addId(this)" ',
                        'onmouseout="removeId(this, event)">\n',
                        '<span class="celltext" ',
                        ' contenteditable="true">', line, '</span></div>'])
        cell = unicode(cell)

        self.maxDiff = None
        self.assertEqual(cell, CELL.format(line))

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

        jsalign += '<script type="text/javascript">\n'
        jsalign += '   // https://developer.mozilla.org/en-US/docs/'
        jsalign += 'Web/Events/beforeunload\n'
        jsalign += '   window.addEventListener("beforeunload", function (e) {\n'
        jsalign += '   var confirmationMessage = '
        jsalign += '"Do not close/refresh this window without exporting the TMX '
        jsalign += 'alignment (using the button at the end of the page) or saving '
        jsalign += 'a backup (using the button at the top of the page), otherwise '
        jsalign += 'you will lose your work.";\n'
        jsalign += '   e.returnValue = confirmationMessage;\n'
        jsalign += '   return confirmationMessage;\n'
        jsalign += '   });\n'
        jsalign += '</script>\n'


        jsalign += '<script class="links" type="text/javascript" '
        jsalign += ''.join(
            ['src="https://s3.eu-central-1.amazonaws.com/jsalign/0.7/jsalign.js">',
             '</script>\n'])
        jsalign += '<script class="links" type="text/javascript" '
        jsalign += ''.join(['src="https://s3.eu-central-1.amazonaws.com/rangy/',
                            'rangy-1.3.0/rangy-core.js"></script>\n'])
        jsalign += '<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootswatch/3.3.6/cosmo/bootstrap.min.css">\n'
        jsalign += '<link class="links" rel="stylesheet" type="text/css" href'
        jsalign += '="https://s3.eu-central-1.amazonaws.com/jsalign/0.7/jsalign.css">\n'
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
        jsalign += '<button type="button" class="btn btn-primary" id="backup-button">Save and continue later'
        jsalign += '</button>\n'
        jsalign += '</div>\n'

        jsalign += '</td>\n'
        jsalign += '<td>\n'
        jsalign += '<div id="legend">\n'
        jsalign += '<div class="demo"><strong>Edit</strong> the text by'
        jsalign += ' clicking into the cell. The text will turn red.</div>\n'
        jsalign += '<div class="demo"><span class="buttons"><a class="btn'
        jsalign += ' btn-success btn-xs" href="#"><span class="glyphicon glyphicon-plus"></a>  Add new segment</div>\n'
        jsalign += '<div class="demo"><a class="btn btn-danger btn-xs"'
        jsalign += ' href="#"><span class="glyphicon glyphicon-remove"></a> Delete segment</div>\n'
        jsalign += '<div class="demo"><a class="btn btn-info btn-xs"'
        jsalign += ' href="#"><span class="glyphicon glyphicon-arrow-down"></a></span> Merge segment'
        jsalign += ' with next</div>\n'
        jsalign += '<div class="demo"><a class="btn btn-warning btn-xs"'
        jsalign += ' href="#"><span class="glyphicon glyphicon-flash"></a></span> Split segment (click'
        jsalign += ' where you want to split)</div>\n'
        jsalign += '<div class="demo"><a class="btn btn-default btn-xs"'
        jsalign += ' href="#"><span class="glyphicon '
        jsalign += 'glyphicon-move"></a></span> Cut the segments you want to '
        jsalign += 'move</div>\n'
        jsalign += '<div class="demo"><a class="btn btn-primary btn-xs"'
        jsalign += ' href="#"><span class="glyphicon '
        jsalign += 'glyphicon-paste"></a></span> Paste the segments you want to '
        jsalign += 'move below the current segment</div>\n'

        jsalign += '<span class="celltext"></span>\n'
        jsalign += '</div>\n'
        jsalign += '</td>\n'
        jsalign += '</tr>\n'
        jsalign += '</table>\n'

        jsalign += '<br/>\n'
        jsalign += '<table class="main-table">\n'
        jsalign += '  <tr class="main-row">\n'

        jsalign += '    <td id="source-col"  ondrop="drop(event)" '
        jsalign += 'ondragover="allowDrop(event)">\n'
        jsalign += ''.join([CELL.format(line) for line in s_list])
        jsalign += '\n    </td>\n'

        jsalign += '    <td id="target-col"  ondrop="drop(event)" '
        jsalign += 'ondragover="allowDrop(event)">\n'
        jsalign += ''.join([CELL.format(line) for line in t_list])
        jsalign += '\n    </td>\n'

        jsalign += '  </tr>\n'
        jsalign += '</table>\n'

        jsalign += '<br/>\n'
        jsalign += '<div class="div-button">\n'
        jsalign += '  <button type="button" class="btn btn-success btn-large" '
        jsalign += 'id="save-button">Save alignment</button>\n'
        jsalign += '</div>\n'
        jsalign += '</body>\n'
        jsalign += '</html>'

        self.maxDiff = None
        self.assertEqual(jsalign, convert.jsalign_table(s_list, t_list, s_lang,
                                                        t_lang, note))

    def test_paragraph_separator_1(self):
        self.assertEqual(convert.numbering_separator('\n1. Bla', 'ro'),
                         '\n1.\nBla')

    def test_paragraph_separator_2(self):
        self.assertEqual(convert.numbering_separator('\n1) Bla', 'ro'),
                         '\n1)\nBla')

    def test_paragraph_separator_3(self):
        self.assertEqual(convert.numbering_separator('\n(1) Bla', 'ro'),
                         '\n(1)\nBla')

    def test_paragraph_separator_11(self):
        self.assertEqual(convert.numbering_separator('\n1a. Bla', 'ro'),
                         '\n1a.\nBla')

    def test_paragraph_separator_22(self):
        self.assertEqual(convert.numbering_separator('\n11) Bla', 'ro'),
                         '\n11)\nBla')

    def test_paragraph_separator_33(self):
        self.assertEqual(convert.numbering_separator('\n(11b) Bla', 'ro'),
                         '\n(11b)\nBla')

    def test_paragraph_separator_33_lett(self):
        self.assertEqual(convert.numbering_separator('\n(ABC) Bla', 'ro'),
                         '\n(ABC)\nBla')

    def test_paragraph_separator_33_lett_2(self):
        self.assertEqual(convert.numbering_separator('\n(AB2) Bla', 'ro'),
                         '\n(AB2)\nBla')

    def test_paragraph_separator_11_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + "1a. Bla", 'ro'),
                         "\n" + u"\u201e" + "1a.\nBla")

    def test_paragraph_separator_22_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + "11) Bla", 'ro'),
                         "\n" + u"\u201e" + "11)\nBla")

    def test_paragraph_separator_33_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + "(11b) Bla", 'ro'),
                         "\n" + u"\u201e" + "(11b)\nBla")

    def test_paragraph_separator_33_lett_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + "(ABC) Bla", 'ro'),
                         "\n" + u"\u201e" + "(ABC)\nBla")

    def test_paragraph_separator_33_lett_2_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + "(AB2) Bla", 'ro'),
                         "\n" + u"\u201e" + "(AB2)\nBla")

    def test_paragraph_separator_1_tab(self):
        self.assertEqual(convert.numbering_separator('\n1.\tBla', 'ro'),
                         '\n1.\nBla')

    def test_paragraph_separator_1_n(self):
        self.assertEqual(convert.numbering_separator('\n1.\nBla', 'ro'),
                         '\n1.\nBla')

    def test_paragraph_separator_1_tab_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + "1.\tBla", 'ro'),
                         "\n" + u"\u201e" + "1.\nBla")

    def test_paragraph_separator_1_n_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + "1.\nBla", 'ro'),
                         "\n" + u"\u201e" + "1.\nBla")

    def test_paragraph_separator_hun_1(self):
        self.assertEqual(convert.numbering_separator('\n1. cikk', 'ro'),
                         '\n1. cikk')

    def test_paragraph_separator_hun_2(self):
        self.assertEqual(convert.numbering_separator('\n1. FEJEZET', 'ro'),
                         '\n1. FEJEZET')

    def test_paragraph_separator_hun_3(self):
        self.assertEqual(convert.numbering_separator('\n1. szakasz', 'ro'),
                         '\n1. szakasz')

    def test_paragraph_separator_lat_1(self):
        self.assertEqual(convert.numbering_separator('\n1. pants', 'ro'),
                         '\n1. pants')

    def test_paragraph_separator_lat_2(self):
        self.assertEqual(
            convert.numbering_separator('\n1. ieda' + u"\u013C" + 'a', 'ro'),
            '\n1. ieda' + u"\u013C" + 'a')

    def test_paragraph_separator_est_1(self):
        self.assertEqual(convert.numbering_separator('\n1. Jagu', 'ro'),
                         '\n1. Jagu')

    def test_paragraph_separator_est_month_1(self):
        self.assertEqual(convert.numbering_separator('\n1. jaanuar', 'ro'),
                         '\n1. jaanuar')

    def test_paragraph_separator_est_month_2(self):
        self.assertEqual(convert.numbering_separator('\n1. veebruar', 'ro'),
                         '\n1. veebruar')

    def test_paragraph_separator_est_month_3(self):
        self.assertEqual(
            convert.numbering_separator('\n1. m' + u"\u00E4" + 'rts', 'ro'),
            '\n1. m' + u"\u00E4" + 'rts')

    def test_paragraph_separator_est_month_4(self):
        self.assertEqual(convert.numbering_separator('\n1. aprill', 'ro'),
                         '\n1. aprill')

    def test_paragraph_separator_est_month_5(self):
        self.assertEqual(convert.numbering_separator('\n1. mai', 'ro'),
                         '\n1. mai')

    def test_paragraph_separator_est_month_6(self):
        self.assertEqual(convert.numbering_separator('\n1. juuni', 'ro'),
                         '\n1. juuni')

    def test_paragraph_separator_est_month_7(self):
        self.assertEqual(convert.numbering_separator('\n1. juuli', 'ro'),
                         '\n1. juuli')

    def test_paragraph_separator_est_month_8(self):
        self.assertEqual(convert.numbering_separator('\n1. august', 'ro'),
                         '\n1. august')

    def test_paragraph_separator_est_month_9(self):
        self.assertEqual(convert.numbering_separator('\n1. september', 'ro'),
                         '\n1. september')

    def test_paragraph_separator_est_month_10(self):
        self.assertEqual(convert.numbering_separator('\n1. oktoober', 'ro'),
                         '\n1. oktoober')

    def test_paragraph_separator_est_month_11(self):
        self.assertEqual(convert.numbering_separator('\n1. november', 'ro'),
                         '\n1. november')

    def test_paragraph_separator_est_month_12(self):
        self.assertEqual(convert.numbering_separator('\n1. detsember', 'ro'),
                         '\n1. detsember')

    def test_paragraph_separator_333c_1_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + '1. Bla', 'ro'),
                         "\n" + u"\u201e" + '1.\nBla')

    def test_paragraph_separator_333c_2_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + '1) Bla', 'ro'),
                         "\n" + u"\u201e" +'1)\nBla')

    def test_paragraph_separator_333c_3_quote(self):
        self.assertEqual(convert.numbering_separator("\n" + u"\u201e" + '(1) Bla', 'ro'),
                         "\n" + u"\u201e" +'(1)\nBla')

    def test_paragraph_separator_roman_1(self):
        self.assertEqual(convert.numbering_separator('\ni. Bla', 'ro'),
                         '\ni.\nBla')

    def test_paragraph_separator_roman_2(self):
        self.assertEqual(convert.numbering_separator('\nii. Bla', 'ro'),
                         '\nii.\nBla')

    def test_paragraph_separator_roman_3(self):
        self.assertEqual(convert.numbering_separator('\niii. Bla', 'ro'),
                         '\niii.\nBla')

    def test_paragraph_separator_roman_4(self):
        self.assertEqual(convert.numbering_separator('\niii) Bla', 'ro'),
                         '\niii)\nBla')

    def test_paragraph_separator_roman_5(self):
        self.assertEqual(convert.numbering_separator('\n(iii) Bla', 'ro'),
                         '\n(iii)\nBla')

    def test_paragraph_separator_roman_6(self):
        self.assertEqual(convert.numbering_separator('\niv. Bla', 'ro'),
                         '\niv.\nBla')

    def test_paragraph_separator_roman_7(self):
        self.assertEqual(convert.numbering_separator('\niv) Bla', 'ro'),
                         '\niv)\nBla')

    def test_paragraph_separator_roman_8(self):
        self.assertEqual(convert.numbering_separator('\n(iv) Bla', 'ro'),
                         '\n(iv)\nBla')

    def test_paragraph_separator_roman_9(self):
        self.assertEqual(convert.numbering_separator('\nv. Bla', 'ro'),
                         '\nv.\nBla')

    def test_paragraph_separator_roman_10(self):
        self.assertEqual(convert.numbering_separator('\nv) Bla', 'ro'),
                         '\nv)\nBla')

    def test_paragraph_separator_roman_11(self):
        self.assertEqual(convert.numbering_separator('\n(v) Bla', 'ro'),
                         '\n(v)\nBla')

    def test_paragraph_separator_roman_12(self):
        self.assertEqual(convert.numbering_separator('\nvi. Bla', 'ro'),
                         '\nvi.\nBla')

    def test_paragraph_separator_roman_13(self):
        self.assertEqual(convert.numbering_separator('\nvi) Bla', 'ro'),
                         '\nvi)\nBla')

    def test_paragraph_separator_roman_14(self):
        self.assertEqual(convert.numbering_separator('\n(vi) Bla', 'ro'),
                         '\n(vi)\nBla')

    def test_paragraph_separator_roman_15(self):
        self.assertEqual(convert.numbering_separator('\nix. Bla', 'ro'),
                         '\nix.\nBla')

    def test_paragraph_separator_roman_16(self):
        self.assertEqual(convert.numbering_separator('\nix) Bla', 'ro'),
                         '\nix)\nBla')

    def test_paragraph_separator_roman_17(self):
        self.assertEqual(convert.numbering_separator('\n(ix) Bla', 'ro'),
                         '\n(ix)\nBla')

    def test_paragraph_separator_roman_18(self):
        self.assertEqual(convert.numbering_separator('\nviii. Bla', 'ro'),
                         '\nviii.\nBla')

    def test_paragraph_separator_roman_19(self):
        self.assertEqual(convert.numbering_separator('\nviii) Bla', 'ro'),
                         '\nviii)\nBla')

    def test_paragraph_separator_roman_20(self):
        self.assertEqual(convert.numbering_separator('\n(viii) Bla', 'ro'),
                         '\n(viii)\nBla')

    def test_paragraph_separator_roman_1_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'i. Bla', 'ro'),
                         '\n' + u"\u201e" + 'i.\nBla')

    def test_paragraph_separator_roman_2_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'ii. Bla', 'ro'),
                         '\n' + u"\u201e" + 'ii.\nBla')

    def test_paragraph_separator_roman_3_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'iii. Bla', 'ro'),
                         '\n' + u"\u201e" + 'iii.\nBla')

    def test_paragraph_separator_roman_4_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'iii) Bla', 'ro'),
                         '\n' + u"\u201e" + 'iii)\nBla')

    def test_paragraph_separator_roman_5_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + '(iii) Bla', 'ro'),
                         '\n' + u"\u201e" + '(iii)\nBla')

    def test_paragraph_separator_roman_6_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'iv. Bla', 'ro'),
                         '\n' + u"\u201e" + 'iv.\nBla')

    def test_paragraph_separator_roman_7_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'iv) Bla', 'ro'),
                         '\n' + u"\u201e" + 'iv)\nBla')

    def test_paragraph_separator_roman_8_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + '(iv) Bla', 'ro'),
                         '\n' + u"\u201e" + '(iv)\nBla')

    def test_paragraph_separator_roman_9_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'v. Bla', 'ro'),
                         '\n' + u"\u201e" + 'v.\nBla')

    def test_paragraph_separator_roman_10_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'v) Bla', 'ro'),
                         '\n' + u"\u201e" + 'v)\nBla')

    def test_paragraph_separator_roman_11_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + '(v) Bla', 'ro'),
                         '\n' + u"\u201e" + '(v)\nBla')

    def test_paragraph_separator_roman_12_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'vi. Bla', 'ro'),
                         '\n' + u"\u201e" + 'vi.\nBla')

    def test_paragraph_separator_roman_13_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'vi) Bla', 'ro'),
                         '\n' + u"\u201e" + 'vi)\nBla')

    def test_paragraph_separator_roman_14_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + '(vi) Bla', 'ro'),
                         '\n' + u"\u201e" + '(vi)\nBla')

    def test_paragraph_separator_roman_15_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'ix. Bla', 'ro'),
                         '\n' + u"\u201e" + 'ix.\nBla')

    def test_paragraph_separator_roman_16_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'ix) Bla', 'ro'),
                         '\n' + u"\u201e" + 'ix)\nBla')

    def test_paragraph_separator_roman_17_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + '(ix) Bla', 'ro'),
                         '\n' + u"\u201e" + '(ix)\nBla')

    def test_paragraph_separator_roman_18_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'viii. Bla', 'ro'),
                         '\n' + u"\u201e" + 'viii.\nBla')

    def test_paragraph_separator_roman_19_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + 'viii) Bla', 'ro'),
                         '\n' + u"\u201e" + 'viii)\nBla')

    def test_paragraph_separator_roman_20_quote(self):
        self.assertEqual(convert.numbering_separator('\n' + u"\u201e" + '(viii) Bla', 'ro'),
                         '\n' + u"\u201e" + '(viii)\nBla')

    def test_paragraph_separator_abbrev(self):
        self.assertEqual(convert.numbering_separator("\nRegulamentul\nnr. 575/2013\n", 'ro'),
                         "\nRegulamentul\nnr. 575/2013\n")

    def test_file_to_list_tries_0(self):
        # Not testing numbering_separator here.
        text = (' \t\nnon-breaking'
                u"\u00A0"
                'space \n  \t  '
                'u\n'
                'uu\n'
                'uuu\n'
                '    Another  line!\n \n \n \n \n \n \n \n \n \n ')
        result = ['non-breaking space', 'u', 'uu', 'uuu', 'Another line!']
        self.assertEqual(result, convert.file_to_list(text, 'ro'))

    def test_file_to_list_tries_1(self):
        # Not testing numbering_separator here.
        text = (' \t\nnon-breaking'
                u"\u00A0"
                'space \n  \t  '
                'u\n'
                'uu\n'
                'uuu\n'
                '    Another  line!\n \n \n \n \n \n \n \n \n \n ')
        result = ['non-breaking space', 'uu', 'uuu', 'Another line!']
        self.assertEqual(result, convert.file_to_list(text, 'ro', 1))

    def test_file_to_list_tries_2(self):
        # Not testing numbering_separator here.
        text = (' \t\nnon-breaking'
                u"\u00A0"
                'space \n  \t  '
                'u\n'
                'uu\n'
                'uuu\n'
                '    Another  line!\n \n \n \n \n \n \n \n \n \n ')
        result = ['non-breaking space', 'uuu', 'Another line!']
        self.assertEqual(result, convert.file_to_list(text, 'ro', 2))

    def test_file_to_list_tries_3(self):
        # Not testing numbering_separator here.
        text = (' \t\nnon-breaking'
                u"\u00A0"
                'space \n  \t  '
                'u\n'
                'uu\n'
                'uuu\n'
                '    Another  line!\n \n \n \n \n \n \n \n \n \n ')
        result = ['non-breaking space', 'Another line!']
        self.assertEqual(result, convert.file_to_list(text, 'ro', 3))

    def test_downloadfullfile_01_tmx_file(self):
        align.celex_aligner(['en', 'ro'], '', '32013R1024', '', make_dic=False)
        with codecs.open('bi_32013R1024_en_ro.tmx', 'r', 'utf-8') as tmx_in:
            test_tmx = tmx_in.read()
        test_tmx = re.sub(r'([0-9]){8}T([0-9]){6}Z', r'00000000T000000Z',
                          test_tmx)
        with codecs.open('test_ref/bi_32013R1024_en_ro_ref.tmx', 'r',
                         'utf-8') as tmx_ref:
            ref_tmx = tmx_ref.read()

        self.assertEqual(test_tmx, ref_tmx)

    def test_downloadfullfile_02_html_file(self):
        with codecs.open('bi_32013R1024_en_ro_manual.html', 'r',
                         'utf-8') as html_in:
            test_html = html_in.read()
        with codecs.open('test_ref/bi_32013R1024_en_ro_manual_ref.html', 'r',
                         'utf-8') as html_ref:
            ref_html = html_ref.read()
        os.remove('bi_32013R1024_en_ro.tmx')
        os.remove('bi_32013R1024_en_ro_manual.html')
        self.assertEqual(test_html, ref_html)

if __name__ == '__main__':
    unittest.main()
