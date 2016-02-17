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

TMX_FOOTER = unicode('\n</body>\n</tmx>\n')

TMX_HEADER = unicode('<?xml version="1.0" encoding="utf-8" ?>\n'
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

TRU = unicode('<tu creationdate="{}" creationid="eunlp">'
              '<prop type="Txt::Note">{}</prop>{}\n')

TUV = unicode('<tuv xml:lang="{}"><seg>{}</seg></tuv>')

CELL = unicode('      <div class="cell">'
               '\n<span class="buttons">\n'
               '<a href="#" class="btn btn-success btn-xs add" '
               'onclick="addFunction(this)"><span class="glyphicon '
               'glyphicon-plus"></a>\n'
               '<a href="#" class="btn btn-danger btn-xs delete"'
               ' onclick="deleteFunction(this)"><span class="glyphicon '
               'glyphicon-remove"></a>\n'
               '<a href="#" class="btn btn-info btn-xs merge"'
               ' onclick="mergeFunction(this)"><span class="glyphicon '
               'glyphicon-arrow-down"></a>\n'
               '<a href="#" class="btn btn-warning btn-xs split"'
               ' onclick="splitFunction(this)"><span class="glyphicon '
               'glyphicon-flash"></a>\n'
               '</span>\n<span class="celltext" '
               ' contenteditable="true">{}</span></div>')

PAGE = unicode('<!DOCTYPE html>\n'
               '<html>\n'
               '<head>\n'
               '<meta charset="UTF-8">\n'
               '<meta name="source-language" content="{{s_lang}}">\n'
               '<meta name="target-language" content="{{t_lang}}">\n'
               '<meta name="doc-code" content="{{note}}">\n'
               '<!-- <script class="links" type="text/javascript" src='
               '"http://code.jquery.com/jquery-1.9.1.js"></script> -->\n'
               '<script type="text/javascript">\n'
               '   // https://developer.mozilla.org/en-US/docs/'
               'Web/Events/beforeunload\n'
               '   window.addEventListener("beforeunload", function (e) {\n'
               '   var confirmationMessage = '
               '"Do not close/refresh this window without exporting the TMX '
               'alignment (using the button at the end of the page) or saving '
               'a backup (using the button at the top of the page), otherwise '
               'you will lose your work.";\n'
               '   e.returnValue = confirmationMessage;\n'
               '   return confirmationMessage;\n'
               '   });\n'
                '</script>\n'
               '<script class="links" type="text/javascript" '
               'src="https://s3.eu-central-1.amazonaws.com/jsalign/0.2/jsalign.js">'
                '</script>\n'
               '<script class="links" type="text/javascript" '
               'src="https://rangy.googlecode.com/svn/trunk/'
               'currentrelease/rangy-core.js"></script>\n'
               '<link rel="stylesheet" '
               'href="https://maxcdn.bootstrapcdn.com/bootswatch/3.3.6/cosmo/bootstrap.min.css">\n'
               '<link class="links" rel="stylesheet" type="text/css" href'
               '="https://s3.eu-central-1.amazonaws.com/jsalign/0.2/jsalign.css">\n'
               '<title>{{note}} - {{s_lang}} - {{t_lang}}</title>\n'
               '</head>\n'
               '<body>\n'
               '<table id = "header">\n'
               '<tr>\n'
               '<td>\n'
               '<div id="doc-info">\n'
               '<div id="doc-title">Document: {{note}}</div>\n'
               '<div id="doc-source-language">Source language: {{s_lang}}'
               '</div>\n'
               '<div id="doc-target-language">Target language: {{t_lang}}'
               '</div>\n'
               '<div id="help"><br/>Save a backup:<br/>\n'
               '<button type="button" class="btn btn-primary" '
               'id="backup-button">Save and continue later</button>\n'
               '</div>\n'
               '</td>\n'
               '<td>\n'
               '<div id="legend">\n'
               '<div class="demo"><strong>Edit</strong> the text by'
               ' clicking into the cell. The text will turn red.</div>\n'
               '<div class="demo"><span class="buttons"><a class="btn'
               ' btn-success btn-xs" href="#"><span class="glyphicon '
               'glyphicon-plus"></a>  Add new segment</div>\n'
               '<div class="demo"><a class="btn btn-danger btn-xs"'
               ' href="#"><span class="glyphicon '
               'glyphicon-remove"></a> Delete segment</div>\n'
               '<div class="demo"><a class="btn btn-info btn-xs"'
               ' href="#"><span class="glyphicon '
               'glyphicon-arrow-down"></a></span> Merge segment'
               ' with next</div>\n'
               '<div class="demo"><a class="btn btn-warning btn-xs"'
               ' href="#"><span class="glyphicon '
               'glyphicon-flash"></a></span> Split segment (click'
               ' where you want to split)</div>\n'
               '<span class="celltext"></span>\n'
               '</div>\n'
               '</td>\n'
               '</tr>\n'
               '</table>\n'
               '<br/>\n'
               '<table class="main-table">\n'
               '  <tr class="main-row">\n'
               '    <td id="source-col">\n'
               '{{s_cells}}'
               '\n    </td>\n'
               '    <td id="target-col">\n'
               '{{t_cells}}'
               '\n    </td>\n'
               '  </tr>\n'
               '</table>\n'
               '<br/>\n'
               '<div class="div-button">\n'
               '  <button type="button" class="btn btn-success btn-large" '
               'id="save-button">Save alignment</button>\n'
               '</div>\n'
               '</body>\n'
               '</html>')