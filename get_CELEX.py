#-----------------------------------------------------------------------------
# Name:        download_EP
# Purpose:     Download Eurlex documents EN and RO using the celex code
# How to use:   python get_CELEX.py 32014R0680 EN RO FR
#
# Author:      Filip
#
# Created:     4.11.2014
# Licence:     Public domain
#-----------------------------------------------------------------------------

import sys
import functions as func


def make_link(celex, lang):
    part_1 = "http://eur-lex.europa.eu/legal-content/"
    part_2 = "/TXT/?uri=CELEX:"
    return part_1 + lang + part_2 + celex


if __name__ == '__main__':
    celex = sys.argv[1]  # collect celex code
    languages = sys.argv[2:]  # collect language codes
    #create html and txt files for each language code
    func.scraper(languages, make_link, 'The requested document does not exist',
                 celex, '', is_celex = True) # no prefix
    source_file = celex + '_' + languages[0] + '.txt'
    target_file = celex + '_' + languages[1] + '.txt'
    func.aligner(source_file, target_file, languages[0].lower(), languages[1].lower())

# model pentru apelat LF Aligner
# C:\Users\Filip\Dropbox\Tranzit\LFalign\LF_aligner_4.05.exe --filetype="t" --infiles="C:\Users\Filip\Dropbox\Python_Work\Diverse Moses\32014R0468_EN.txt","C:\Users\Filip\Dropbox\Python_Work\Diverse Moses\32014R0468_RO.txt" --languages="en","ro" --segment="y" --review="n" --tmx="y"
#from subprocess import check_output
#check_output('C:\Users\Filip\Dropbox\Tranzit\LFalign\LF_aligner_4.05.exe --filetype="t" --infiles="32014R0468_EN.txt","32014R0468_RO.txt" --languages="en","ro" --segment="y" --review="n" --tmx="y"', shell = True)
