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

if __name__ == '__main__':
    unittest.main()
