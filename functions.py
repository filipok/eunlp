# Name:        functions.py
# Purpose:     Various project functions
#
# Author:      Filip
#
# Created:     4.11.2014

import urllib2
import codecs
import re
import os
from bs4 import BeautifulSoup
import datetime
import ladder2text_new
import subprocess
import random
import nltk
from nltk.tokenize.punkt import PunktSentenceTokenizer, PunktParameters


def make_paths(path, text_id, languages):
        source_file = os.path.join(path, text_id + '_' + languages[0] + '.txt')
        target_file = os.path.join(path, text_id + '_' + languages[1] + '.txt')
        align_file = os.path.join(path, 'bi_' + text_id + '_' +
                                  languages[0].lower() + '_' +
                                  languages[1].lower())
        dictionary = os.path.join(path, languages[0].lower() +
                                  languages[1].lower() + '.dic')
        return source_file, target_file, align_file, dictionary


def check_error(text, error_string):
    if error_string in text:
        print "Link error!"
        return False
    return True


def make_ep_sub_link(doc_category, doc_year, doc_code):
    return doc_category + doc_year + doc_code


def make_ep_link(category_year_code, lang):
    doc_category = category_year_code[0:2]
    doc_year = category_year_code[2:6]
    doc_code = category_year_code[6:10]
    a = 'http://www.europarl.europa.eu/sides/getDoc.do?type=REPORT&reference=A'
    p = 'http://www.europarl.europa.eu/sides/getDoc.do?type=TA&reference=P'
    b = 'http://www.europarl.europa.eu/sides/getDoc.do?type=MOTION&reference=B'
    p_specific = ''  # this is specific to P links
    if doc_category[0] == 'A':
        part_1 = a
    elif doc_category[0] == 'P':
        part_1 = p
        p_specific = 'TA-'
    elif doc_category[0] == 'B':
        part_1 = b
    else:
        print "make_link error"
        part_1 = 'error'  # dubious
    return part_1 + doc_category[1] + '-' + p_specific + doc_year + '-' + \
        doc_code + '&language=' + lang


def make_celex_link(celex, lang):
    part_1 = "http://eur-lex.europa.eu/legal-content/"
    part_2 = "/TXT/?uri=CELEX:"
    return part_1 + lang + part_2 + celex


def strip_ep(text):
    # double newlines, otherwise the splitter merges the first lines
    text = re.sub(r'\n', r'\n\n', text)
    # discard language list at the beginning (it ends with Swedish/svenska)
    split = re.split(r'\nsv.{3}svenska.*\n', text)
    text = split[1]
    return text


def paragraph_combiner_sub(text):
    # combine single lines consisting of numbers/letters with next line
    pattern_1 = re.compile(r'\n\(?([0-9]+|[a-z]+|[A-Z]+)[\.\)][\n\s]')
    # combine single lines consisting of single number + single letter
    # with the next line
    pattern_3 = re.compile(r'\n\(?([0-9]+[a-z]+)[\.\)][\n\s]')
    # combine lines consisting of Roman numerals to 9 with the next line
    pattern_4 = re.compile(r'\n\(?(i{1,3})[\.\)][\n\s]')  # 1-3
    pattern_5 = re.compile(r'\n\(?(iv)[\.\)][\n|\s]')  # 4
    pattern_6 = re.compile(r'\n\(?(vi{0,3})[\.\)][\n\s]')  # 5-8
    pattern_7 = re.compile(r'\n\(?(ix)[\.\)][\n\s]')  # 9
    # the replacements
    text = re.sub(pattern_1, '\n', text)
    text = re.sub(pattern_3, r'\n', text)
    text = re.sub(pattern_4, r'\n', text)
    text = re.sub(pattern_5, r'\n', text)
    text = re.sub(pattern_6, r'\n', text)
    text = re.sub(pattern_7, r'\n', text)
    return text

# TODO valabil doar pentru A!
# remove tag attrs
# https://gist.github.com/bradmontgomery/673417
# get first part
# clean_soup.body.table.table.next_sibling.next_sibling.next_sibling.next_sibling.get_text()
# get second part
# clean_soup.body.table.table.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.get_text()
# get third part
# clean_soup.body.table.table.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.get_text()
# get fourth part
# clean_soup.body.table.table.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.next_sibling.get_text()
#
#
# eventual cu find_next_siblings()?


def downloader(make_link, error_text, url_code, lang_code, new_name,
               over=False):
    # Only download if not already existing, otherwise open from disk
    # over=True overrides that behavior
    if over or (not os.path.isfile(new_name)):
        link = make_link(url_code, lang_code)
        response = urllib2.urlopen(link)
        text = response.read()

        # some celexes have no new line between paras
        # this confuses get_text() in BeautifulSoup
        text = re.sub(r'</p><p>', r'</p>\n<p>', text)

        if check_error(text, error_text):
            with open(new_name, 'w') as f:
                f.write(text)
        else:
            print "Error in link " + url_code + " " + lang_code + "."
    else:
        with codecs.open(new_name, "r", "utf-8") as f:
            text = f.read()
            print new_name + ": html file already downloaded."
    return text


def souper(new_name, text, is_celex, is_ep, over=False):
    # Only convert to txt if not already existing
    # over=True overrides that behavior
    if (not over) and os.path.isfile(new_name):
        print new_name + ": txt file already existing."
        return

    f = codecs.open(new_name, "w", "utf-8")
    soup = BeautifulSoup(text, "lxml")
    # separate branches for each document type
    if is_celex:
        if soup.txt_te is not None:
            # for older celexes
            clean_text = soup.txt_te.get_text()
        else:
            # for newer celexes
            # the hierarchy is rather deep
            clean_text = soup.body.div.contents[8].contents[5].contents[0]
            clean_text = clean_text.contents[4].contents[9].contents[3]
            clean_text = clean_text.contents[1].get_text()
            clean_text = re.sub(r'\n\nTop $', r'', clean_text)
        # double \n, otherwise the Perl splitter merges the first lines
        clean_text = re.sub(r'\n', r'\n\n', clean_text)
    elif is_ep:
        clean_text = soup.get_text()
        clean_text = strip_ep(clean_text)
    else:
        clean_text = soup.get_text()
    f.write(clean_text)
    f.close()


def scraper(langs, make_link, error_text, url_code, prefix, is_celex=False,
            is_ep=False, over_html=False, over_txt=False):
    for lang_code in langs:
            new_name = prefix + url_code + '_' + lang_code + '.html'
            text = downloader(make_link, error_text, url_code, lang_code,
                              new_name, over_html)

            new_name = prefix + url_code + '_' + lang_code + '.txt'
            souper(new_name, text, is_celex, is_ep, over_txt)


def create_dictionary(input_source, input_target, output_file):
    with codecs.open(input_source, "r", "utf-8") as sin:
        s_list = list(sin)
    with codecs.open(input_target, "r", "utf-8") as tin:
        t_list = list(tin)
    if len(s_list) == len(t_list) and len(s_list) != 0:
        with codecs.open(output_file, "w", "utf-8") as fout:
            for i in range(len(s_list)):
                s_term = s_list[i].rstrip()
                t_term = t_list[i].rstrip()
                if len(s_term) > 0 and len(t_term) > 0:
                    line_to_add = t_term + ' @ ' + s_term + '\r\n'
                    fout.write(line_to_add)
    else:
        print "Dictionary files of different lenght or length = 0. Aborting."


def tab_to_separate(input_name, output_source, output_target):
    with codecs.open(input_name, "r", "utf-8") as fin:
        with codecs.open(output_source, "w", "utf-8") as out_s:
            with codecs.open(output_target, "w", "utf-8") as out_t:
                for line in fin:
                    line = line.strip('\n')
                    text = re.split(r'\t', line)
                    source = text[2]
                    target = text[1]
                    out_s.write(source + '\n')
                    out_t.write(target + '\n')


def tab_to_tmx(input_name, tmx_name, s_lang, t_lang, note):
    # get current date
    current_date = datetime.datetime.now().isoformat()
    current_date = current_date[0:4] + current_date[5:7] + current_date[8:10] \
        + "T" + current_date[11:13] + current_date[14:16] + \
        current_date[17:19] + "Z"
    # create new TMX file
    with codecs.open(tmx_name, "w", "utf-8") as fout:
        # add tmx header (copied from LF Aligner output)
        fout.write('<?xml version="1.0" encoding="utf-8" ?>\n')
        fout.write('<!DOCTYPE tmx SYSTEM "tmx14.dtd">\n')
        fout.write('<tmx version="1.4">\n')
        fout.write('  <header\n')
        fout.write('    creationtool="eunlp"\n')
        fout.write('    creationtoolversion="0.01"\n')
        fout.write('    datatype="unknown"\n')
        fout.write('    segtype="sentence"\n')
        fout.write('    adminlang="' + s_lang + '"\n')
        fout.write('    srclang="' + s_lang + '"\n')
        fout.write('    o-tmf="TW4Win 2.0 Format"\n')
        fout.write('  >\n')
        fout.write('  </header>\n')
        fout.write('  <body>\n')
        with codecs.open(input_name, "r", "utf-8") as fin:
            for line in fin:
                #   get source and target to temp variables
                text = re.split(r'\t', line)
                source = text[2].strip('\n')
                target = text[1]
                # remove triple tildas from hunalign
                source = source.replace('~~~ ', '')
                target = target.replace('~~~ ', '')
                #   create TU line
                tu = '<tu creationdate="' + current_date + \
                     '" creationid="eunlp"><prop type="Txt::Note">' + \
                     note + '</prop>\n'
                fout.write(tu)
                #   create TUV source line
                tuv = '<tuv xml:lang="' + s_lang + '"><seg>' + source\
                      + '</seg></tuv>\n'
                fout.write(tuv)
                #   create TUV target line
                tuv = '<tuv xml:lang="' + t_lang + '"><seg>' + target\
                      + '</seg></tuv> </tu>\n'
                fout.write(tuv)
                fout.write('\n')
        # add tmx footer
        fout.write('\n')
        fout.write('</body>\n')
        fout.write('</tmx>')


def hunalign_wrapper(source_file, target_file, dictionary, align_file,
                     program_folder, realign=True):
    realign_parameter = '-realign'
    if realign:
        command = [program_folder + 'hunalign-1.1/src/hunalign/hunalign',
                   '-utf', realign_parameter, dictionary, source_file,
                   target_file]
    else:
        command = [program_folder + 'hunalign-1.1/src/hunalign/hunalign',
                   '-utf', dictionary, source_file, target_file]
    proc = subprocess.Popen(command, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    output, err = proc.communicate()
    with codecs.open(align_file, 'w', 'utf-8') as f:
        f.write(unicode(output, 'utf-8'))


def file_to_list(file_name):
    # clean and convert file to list of paragraphs
    with codecs.open(file_name, "r", "utf-8") as fin:
        text = fin.read()
    text = re.sub(r'\xa0+', ' ', text)  # replace non-breaking space
    text = re.sub(r'\n\s+', r'\n', text)  # remove whitespace after newline
    text = re.sub(r'\n+', r'\n', text)  # remove empty lines
    text = re.sub(r'^\n+', r'', text)  # remove empty lines at the beginning
    text = re.sub(r'\n$', r'', text)  # remove empty lines at the end
    text = re.sub(r',\s\n', r', ', text)  # merge segments separated by comma
    # TODO do not merge segments starting with Whereas, Having regard, In cooperation
    text = re.sub(r'\s+\n', r'\n', text)  # remove whitespace before newline
    text = re.sub(r' +', r' ', text)  # remove double whitespaces
    text = paragraph_combiner_sub(text)  # combine para numbers with text
    paragraph_list = re.split(r'\n', text)  # split file
    return paragraph_list


def ep_aligner(source_file, target_file, s_lang, t_lang, dictionary,
               align_file, program_folder, note, delete_temp=True, over=True,
               para_size=300):
    #TODO speed it up
    # TODO run downloader, souper and ep_aligner in parallel?
    # Example in Python console:
    # functions.ep_aligner("A720120002_EN.txt", "A720120002_RO.txt", "en",
    # "ro", "enro.dic", "bi_test", "/home/filip/eunlp/", "A720120002", 300)
    if (not over) and os.path.isfile(align_file + '.tmx'):
        print "File pair already aligned: " + align_file
        return  # exit if already aligned and over=False

    source_list = file_to_list(source_file)
    target_list = file_to_list(target_file)

    # If different number of paragraphs
    if len(source_list) != len(target_list):
        # call classic aligner
        print "Different number of paras, yielding to hunalign in ", \
            source_file
        aligner(source_file, target_file, s_lang, t_lang, dictionary,
                align_file, program_folder, note, delete_temp=True)
        return

    # If same number of paragraphs:
    # mkdir /tmp/eunlp
    if not os.path.exists("/tmp/eunlp"):
        os.makedirs("/tmp/eunlp")
    # open .tab align_file for writing
    fout = codecs.open(align_file + '.tab', "w", "utf-8")
    # for each line, write directly or call hunalign according to size
    for i in range(len(source_list)):
        if len(source_list[i]) < para_size:
            line = "1\t" + target_list[i] + "\t" + source_list[i] + \
                   "\n"
            fout.write(line)
        else:
            print "Creating temporary file from large paragraph ", i, \
                "..."
            r_num = str(random.randint(0, 100000))
            temp_source = "/tmp/eunlp/s_" + r_num + ".txt"
            temp_target = "/tmp/eunlp/t_" + r_num + ".txt"
            temp_align = "/tmp/eunlp/align_" + r_num
            # write the two files
            with codecs.open(temp_source, "w", "utf-8") as sout:
                sout.write(source_list[i] + '\n')
            with codecs.open(temp_target, "w", "utf-8") as tout:
                tout.write(target_list[i] + '\n')
            # process them with the classic aligner
            lines = aligner(temp_source, temp_target, s_lang, t_lang,
                    dictionary, temp_align, program_folder, "a_" + r_num,
                    delete_temp=True, tab=False, tmx=False, sep=False)
            # do some checks with the hunalign aligment
            # and use alignment only if checks are fine
            everything_ok = check_hunalign(lines, source_list[i],
                                           target_list[i])
            if everything_ok[0]:
                # merge resulting alignment into the current tab file
                fout.write(everything_ok[1])
            else:
                # TODO mark in tmx naive/hun/failed_hun alignment
                print source_list[i]
                print "Hunalign failed to align properly segment " + \
                      str(i) + '. Reverting to naive alignment.'
                line = "1\t" + target_list[i] + "\t" + source_list[i] + \
                       "\n"
                fout.write(line)
            # remove temporary files
            os.remove(temp_source)
            os.remove(temp_target)
            os.remove(temp_align + '.lad')


    fout.close()
    # turn alignment into tmx
    tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang, t_lang, note)
    # create parallel source and target text files
    tab_to_separate(align_file + '.tab', source_file[:-4] + '.ali',
                    target_file[:-4] + '.ali')


def check_hunalign(lines, full_source, full_target):
    counter_s = 0
    counter_t = 0
    text = ''
    everything_ok = True
    for i in range(len(lines)):
        split_line = re.split("\t", lines[i])
        if len(split_line) == 3:  # avoid out of range errors
            new_line = "1\t" + split_line[1] + "\t" + \
                       split_line[2]
            text += new_line
            counter_s += len(split_line[2]) + 1
            counter_t += len(split_line[1]) + 1
            if len(split_line[1]) > 0:
                translation_ratio = \
                    float(len(split_line[2]))/len(split_line[1])
            else:
                translation_ratio = 0
            # check source and target size
            if not(0.5 < translation_ratio < 2.0):
                everything_ok = False
            # check segment length
            if len(split_line[2]) < 2 or len(split_line[1]) < 2:
                everything_ok = False
    # check total characters (hunalign drops text sometimes)
    if counter_s < len(full_source) or counter_t < len(full_target):
        print counter_s, len(full_source)
        print counter_t, len(full_target)
        everything_ok = False
    return everything_ok, text


def subprocessing(file_name, lang, program_folder):
    # TO DO http://search.cpan.org/dist/PersistentPerl/lib/PersistentPerl.pm
    # sentence splitter
    with codecs.open(file_name, 'r', 'utf-8') as f:
        command = ['perl',
                   program_folder + 'sentence_splitter/split-sentences.perl',
                   '-l', lang]
        proc = subprocess.Popen(command, stdin=f, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        output, err = proc.communicate()  # output contains the splitter output
    # remove <P> created by the sentence splitter
    output = re.sub(r'\n<P>', '', output)
    # paragraph combiner TODO still needed?
    output = paragraph_combiner_sub(output)
    with codecs.open(file_name[:-4], 'w', 'utf-8') as f:
        f.write(unicode(output, 'utf-8'))
    # tokenizer
    command = ['perl', program_folder + 'tokenizer.perl', '-l', lang]
    p = subprocess.Popen(command, stdout=subprocess.PIPE,
                         stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    output = p.communicate(output)[0]  # presupun ca [1] e stderr?
    with codecs.open(file_name[:-4] + '.tok', 'w', 'utf-8') as f:
        f.write(unicode(output, 'utf-8'))


def subprocessing_nltk(file_name, sentence_splitter):
    # Source for sentence tokenizer:
    # stackoverflow.com/
    # questions/14095971/how-to-tweak-the-nltk-sentence-tokenizer

    # read file
    with codecs.open(file_name, 'r', 'utf-8') as f:
        text = list(f)
    # sentence splitter line by line
    # Source: https://groups.google.com/forum/#!topic/nltk-dev/2eH630nHONI
    # because Punkt ignores line breaks
    sentence_list = []
    for line in text:
        sentences = sentence_splitter.tokenize(line)
        sentence_list.extend(sentences)
    # write file without extension
    with codecs.open(file_name[:-4], 'w', 'utf-8') as f:
        for sent in sentence_list:
            f.write(sent + '\n')
        # remove last new line
        # stackoverflow.com/
        # questions/18857352/python-remove-very-last-character-in-file
        f.seek(-1, os.SEEK_END)
        f.truncate()

    # word tokenizer
    tokenized_sentences = [nltk.word_tokenize(sent) for sent in sentence_list]
    # write .tok file
    with codecs.open(file_name[:-4] + '.tok', 'w', 'utf-8') as f:
        for sent in tokenized_sentences:
            f.write(' '.join(sent) + '\n')


def abbreviation_loader(file_name):
    abbreviations = []
    with codecs.open(file_name, 'r', 'utf-8') as f:
        lines = list(f)
    for line in lines:
        if len(line) > 0 and line[0] != '#':
            abb = line.strip('\n')
            abb = re.split(' #', abb)[0]
            abbreviations.append(abb)
    return abbreviations


def aligner(source_file, target_file, s_lang, t_lang, dictionary, align_file,
            program_folder, note, delete_temp=True, over=True, tab=True,
            tmx=True, sep=True, use_nltk=True):
    # TODO in germana nu separa "... Absaetze 5 und 6. Diese ..."
    # TODO eventual alt splitter cu supervised learning pt DE?
    if (not over) and os.path.isfile(align_file + '.tmx'):
        print "File pair already aligned: " + align_file
        return  # exit if already aligned and over=False
    # Nltk is used by default, as it has a 5x speed compared to Perl
    if use_nltk:
        # prepare sentence splitters
        punkt_param = PunktParameters()
        ab_file = program_folder + \
            'sentence_splitter/nonbreaking_prefixes/nonbreaking_prefix.' \
            + s_lang
        if os.path.isfile(ab_file):
            punkt_param.abbrev_types = set(abbreviation_loader(ab_file))
        else:
            print 'Abbreviation file not found for language: ' + s_lang + '.'
        s_sentence_splitter = PunktSentenceTokenizer(punkt_param)
        punkt_param = PunktParameters()
        ab_file = program_folder + \
            'sentence_splitter/nonbreaking_prefixes/nonbreaking_prefix.' \
            + t_lang
        if os.path.isfile(ab_file):
            punkt_param.abbrev_types = set(abbreviation_loader(ab_file))
        else:
            print 'Abbreviation file not found for language: ' + t_lang + '.'
        t_sentence_splitter = PunktSentenceTokenizer(punkt_param)
        # call splitter & aligner
        subprocessing_nltk(source_file, s_sentence_splitter)
        subprocessing_nltk(target_file, t_sentence_splitter)
    else:
        subprocessing(source_file, s_lang, program_folder)
        subprocessing(target_file, t_lang, program_folder)
    # create empty hunalign dic from program-folder/data_raw files
    if not os.path.exists(dictionary):
        create_dictionary(program_folder + 'data_raw/' + s_lang + '.txt',
                          program_folder + 'data_raw/' + t_lang + '.txt',
                          dictionary)
    # create hunalign ladder alignment
    hunalign_wrapper(source_file[:-4] + '.tok', target_file[:-4] + '.tok',
                     dictionary, align_file + '.lad', program_folder,
                     realign=True)
    # create aligned output
    output_lines = ladder2text_new.create_output_lines(align_file + '.lad',
                                                       source_file[:-4],
                                                       target_file[:-4])
    output_lines = [unicode(line, "utf-8") + '\n' for line in output_lines]
    # writing to disk
    if tab:
        with codecs.open(align_file + '.tab', "w", "utf-8") as fout:
            for line in output_lines:
                fout.write(line)
        # turn alignment into tmx
        if tmx:
            tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang, t_lang,
                       note)
        # create parallel source and target text files
        if sep:
            tab_to_separate(align_file + '.tab', source_file[:-4] + '.ali',
                            target_file[:-4] + '.ali')
    # remove temporary files
    if delete_temp:
        os.remove(source_file[:-4])
        os.remove(target_file[:-4])
        os.remove(source_file[:-4] + ".tok")
        os.remove(target_file[:-4] + ".tok")
    return output_lines

def merge_tmx(target_file, s_lang, t_lang):
    # create a list of tmx files in current directory (also test for languages)
    # for file in list:
    #    read file
    #    remove header and footer
    #    add remaining contents to target_file (if s_lang and t_lang?)
    pass