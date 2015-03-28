# Name:        get_PV_CRE
# Purpose:     Download EP PV and  CRE in EN and RO using a list of dates
# How to use:   python get_PV_CVRE.py dates_list.txt EN RO FR
# Date format in dates_list.txt, one per line:  20131011 [= October 11, 2013]
#
# Author:      Filip
#
# Created:     4.11.2014

import sys
import functions as func


def load_dates(fname):
    with open(fname) as f:
        content = f.readlines()
    return content


def make_link_pv(string, lang):
    a = "http://www.europarl.europa.eu/sides/getDoc.do?pubRef=-//EP//TEXT+PV+"
    b = "+SIT+DOC+XML+V0//"
    return a + string + b + lang


def make_link_cre(string, lang):
    a = "http://www.europarl.europa.eu/sides/getDoc.do?pubRef=-//EP//TEXT+CRE+"
    b = "+ITEMS+DOC+XML+V0//"
    return a + string + b + lang


if __name__ == '__main__':
    ep_dates = load_dates(sys.argv[1])  # collect dates from file
    languages = sys.argv[2:]  # collect language codes
    for i in range(len(ep_dates)):
        ep_dates[i] = ep_dates[i].strip('\n')
        # Or replace make_link_cre with make_link_pv
        func.scraper(languages, make_link_cre, ep_dates[i], 'CRE')