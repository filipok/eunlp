__author__ = 'filip'

import unittest
import convert


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


if __name__ == '__main__':
    unittest.main()
