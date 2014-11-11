#-------------------------------------------------------------------------------
# Name:        get_EP_text
# Purpose:     Download EP reports, texts adopted and motions for resolutions
# How to use:   python get_EP_text.py path [A|P|B][7|8] AAAA START STOP EN RO
#
# Example: python get_EP_text.py C:\Users\Filip\Dropbox\Python_Work\Divers~1 A7 2012 0001 0002 EN RO FR
# Author:      Filip
#
# Created:     4.11.2014
# Licence:     Public domain
#-------------------------------------------------------------------------------
import sys
import functions as func
import os.path
import codecs
from bs4 import BeautifulSoup
from subprocess import check_output

def make_link(category, year, code, language):
    if category[0] == 'A':
        part_1 = 'http://www.europarl.europa.eu/sides/getDoc.do?type=REPORT&reference=A'
    elif category[0] == 'P':
        part_1 = 'http://www.europarl.europa.eu/sides/getDoc.do?type=TA&reference=P'
    elif category[0] == 'B':
        part_1 = 'http://www.europarl.europa.eu/sides/getDoc.do?type=MOTION&reference=B'
    else:
        print "make_link error"
        part_1 = 'error' #dubios
    return part_1 + category[1] + '-'+ year + '-' + code + '&language=' + language

if __name__ == '__main__':
    #be careful, no validation here
    path = sys.argv[1]
    #print path
    category = sys.argv[2]
    #print category
    year = sys.argv[3]
    #print year
    start = sys.argv[4]
    #print start
    stop = sys.argv[5]
    #print stop
    languages = sys.argv[6:]
    #print languages
    for code in range(int(start), int(stop) + 1):
        base_name= category + '_' + year + '_' + str(code).zfill(4) + '_'
        for language in languages:
            link = make_link(category, year, str(code).zfill(4), language)
            text = func.download(link)
            new_name = base_name + language + '.html'
            new_name = os.path.join(path, new_name)
            #print new_name
            with open(new_name, 'w') as f:
                f.write(text)
            new_name = base_name + language + '.txt'
            new_name = os.path.join(path, new_name)
            #print new_name
            with codecs.open(new_name, "w", "utf-8") as f:
                soup = BeautifulSoup(text)
                clean_text = soup.get_text()
                f.write(clean_text)
        # get first two language files
        source = os.path.join(path, base_name + languages[0] + '.txt')
        target = os.path.join(path, base_name + languages[1] + '.txt')
        command = 'C:\Users\Filip\Dropbox\Tranzit\LFalign\LF_aligner_4.05.exe --filetype="t" --infiles="' + source + '","' + target + '" --languages="en","ro" --segment="y" --review="n" --tmx="y"'
        print command
        check_output(command, shell = True)

