#-------------------------------------------------------------------------------
# Name:        Diacritice
# Purpose:     Replace old Romanian diacritics with correct new diacritics
#
# Author:      Filip
#
# Created:     24.10.2014
# Licence:     Public domain
#-------------------------------------------------------------------------------

import sys
import codecs


def one_letter(new, old, line, count):
    new.encode('utf-8')
    old.encode('utf-8')
    count += line.count(old)
    line = line.replace(old, new) #SH
    return line, count

def diacritice(file_name):
    count = 0
    letters = [(u'\u0219',u'\u015f'),(u'\u021b',u'\u0163'),(u'\0218',u'\u015e'),
            (u'\u021a',u'\u0162')] #(new diacritic, old diacritic)
    try:
        new_name = 'comma_'+ file_name
        with codecs.open(new_name, "w", "utf-8") as fout:
            with codecs.open(file_name, "r", "utf-8") as fin:
                for line in fin:
                    for replacement in letters:
                        new = replacement[0]
                        old = replacement[1]
                        line, count = one_letter(new, old, line, count)
                    fout.write(line)
                print str(count) + " replacements."
    except IOError:
        print "File not found."


if __name__ == '__main__':
    if len(sys.argv) > 1:
            diacritice(sys.argv[1])
    else:
        print "Please indicate a filename."
