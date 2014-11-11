#-------------------------------------------------------------------------------
# Name:        get_PV_CRE
# Purpose:     Download EP PV and  CRE in EN and RO using a list of dates
# How to use:   python get_PV_CVRE.py dates_list.txt EN RO FR
# Date format in dates_list.txt, one per line:  20131011 [= October 11, 2013]
#
# Author:      Filip
#
# Created:     4.11.2014
# Licence:     Public domain
#-------------------------------------------------------------------------------

import sys
import functions as func

def load_dates(fname):
    with open(fname) as f:
        content = f.readlines()
    return content

def make_link_PV(string, lang):
    part_1 = "http://www.europarl.europa.eu/sides/getDoc.do?pubRef=-//EP//TEXT+PV+"
    part_2 = "+SIT+DOC+XML+V0//"
    return part_1 + string + part_2 + lang

def make_link_CRE(string, lang):
    part_1 = "http://www.europarl.europa.eu/sides/getDoc.do?pubRef=-//EP//TEXT+CRE+"
    part_2 = "+ITEMS+DOC+XML+V0//"
    return part_1 + string + part_2 + lang


if __name__ == '__main__':
    ep_dates = load_dates(sys.argv[1]) # collect dates from file
    languages = sys.argv[2:] # collect language codes
    for i in range(len(ep_dates)):
        ep_dates[i] = ep_dates[i].strip('\n')
        #func.scraper(languages, make_link_PV, 'Application error', ep_dates[i], 'PV')
        func.scraper(languages, make_link_CRE, 'Application error', ep_dates[i], 'CRE')