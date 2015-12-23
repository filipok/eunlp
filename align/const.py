"""
Name:        const.py
Purpose:     Constants

Author:      Filip

Created:     2.4.2015

"""

ALL_LANGS = ['bg', 'es', 'cs', 'da', 'de', 'et', 'el', 'en', 'fr', 'ga', 'hr',
             'it', 'lv', 'lt', 'hu', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl',
             'fi', 'sv']

PIVOT = 'en'

PARA_MAX = 300
PARA_MIN = 100

TMX_FOOTER = '\n</body>\n</tmx>'

TMX_HEADER = ('<?xml version="1.0" encoding="utf-8" ?>\n'
              '<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n'
              '<tmx version="1.4">\n'
              '  <header\n'
              '    creationtool="eunlp"\n'
              '    creationtoolversion="0.01"\n'
              '    datatype="unknown"\n'
              '    segtype="sentence"\n'
              '    adminlang="{}"\n'
              '    srclang="{}"\n'
              '    o-tmf="TW4Win 2.0 Format"\n'
              '  >\n'
              '  </header>\n'
              '  <body>\n')

TRU = ('<tu creationdate="{}" creationid="eunlp">'
       '<prop type="Txt::Note">{}</prop>{}\n')

TUV = '<tuv xml:lang="{}"><seg>{}</seg></tuv>'