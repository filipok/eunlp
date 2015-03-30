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
import ladder2text_new as l2t
import subprocess
import random
import nltk
from nltk.tokenize.punkt import PunktSentenceTokenizer, PunktParameters
import logging
logging.basicConfig(filename='log.txt', level=logging.WARNING)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
logging.getLogger('').addHandler(console)
import xml.sax.saxutils
# TODO create proper module

def make_paths(path, text_id, languages):
        source_file = os.path.join(path, text_id + '_' + languages[0] + '.txt')
        target_file = os.path.join(path, text_id + '_' + languages[1] + '.txt')
        align_file = os.path.join(path, 'bi_' + text_id + '_' +
                                  languages[0].lower() + '_' +
                                  languages[1].lower())
        dictionary = os.path.join(path, languages[0].lower() +
                                  languages[1].lower() + '.dic')
        return source_file, target_file, align_file, dictionary


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
        logging.error("make_link error in %s %s", category_year_code, lang)
        part_1 = 'error'  # TODO raise exception?
    return "".join([part_1, doc_category[1], '-', p_specific, doc_year, '-',
                    doc_code, '&language=', lang])


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
    # TODO SILENT FAIL in 32014Q0714(03) EN-RO, dar eroare EN-DE
    # add warning la diferente mari de dim s/t + punctuatie diferita la final?

    # TODO fail in 32014O0015 + are glosar EN-RO, EN-DE, EN-FR.
    # TODO fail in 32014R0964 DE si FR (footnote 9 in plus)
    # TODO fail 32014R0609 DE (lipseste segment din preambul)
    # TODO fail 32014D0004(01) FR (alineate unite in vers FR)
    pattern_1 = re.compile(
        r'\n\(?([0-9]{1,3}|[a-z]{1,3}|[A-Z]{1,3})[\.\)][\n\s]')
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


def downloader(make_link, url_code, lang_code, new_name,
               over=False):
    # Only download if not already existing, otherwise open from disk
    # over=True overrides that behavior
    if over or (not os.path.isfile(new_name)):
        # TODO make link outside the downloader
        link = make_link(url_code, lang_code)
        response = urllib2.urlopen(link)
        html_text = response.read()

        # some celexes have no new line between paras
        # this confuses get_text() in BeautifulSoup
        html_text = re.sub(r'</p><p>', r'</p>\n<p>', html_text)

        with open(new_name, 'w') as f:
            f.write(html_text)
    else:
        with codecs.open(new_name, "r", "utf-8") as f:
            html_text = f.read()
            logging.debug("%s: html file already downloaded.", new_name)
    return html_text


def remove_newlines(soup):
    x = soup.find_all('p')
    length = len(x)
    for i in range(length):
        new_text = unicode(x[i]).replace('\n', ' ')
        x[i].replace_with(BeautifulSoup(new_text).p)


def souper(new_name, html_text, is_celex, is_ep, over=False):
    # TODO merge is_celex and is_ep into a single parameter
    # Only convert to txt if not already existing
    # over=True overrides that behavior
    if (not over) and os.path.isfile(new_name):
        logging.warning("%s: txt file already existing.", new_name)
        return
    f = codecs.open(new_name, "w", "utf-8")
    soup = BeautifulSoup(html_text, "lxml")
    # some celexes have \n inside <p> tags
    remove_newlines(soup)
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
        # TODO still needed?
        clean_text = re.sub(r'\n', r'\n\n', clean_text)
    elif is_ep:
        clean_text = soup.get_text()
        clean_text = strip_ep(clean_text)
    else:
        clean_text = soup.get_text()
    f.write(clean_text)
    f.close()


def scraper(langs, make_link, url_code, prefix, is_celex=False,
            is_ep=False, over_html=False, over_txt=False):
    for lang_code in langs:
            new_name = prefix + url_code + '_' + lang_code + '.html'
            try:
                text = downloader(make_link, url_code, lang_code, new_name,
                                  over_html)
            except urllib2.HTTPError:
                logging.error("Link error in %s_%s", url_code, lang_code)
                raise
            else:
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
        logging.error(
            "Dictionary files of different length or length = 0. Aborting.")


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
    now = datetime.datetime.now().isoformat()
    now = re.split(r"\.", re.sub(r"[-:]", r"", now))[0] + "Z"
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
                if text[0] == 'Err':
                    tag = '<prop type="Txt::Alignment">Long_f</prop>'
                elif text[0] == 'Nai':
                    tag = '<prop type="Txt::Alignment">Short</prop>'
                elif text[0] == 'Hun':
                    tag = '<prop type="Txt::Alignment">Hun</prop>'
                else:
                    tag = '<prop type="Txt::Alignment">Unknown</prop>'
                # remove triple tildas from hunalign
                source = source.replace('~~~ ', '')
                target = target.replace('~~~ ', '')
                # escape XML entities '&', '<', and '>'
                source = xml.sax.saxutils.escape(source)
                target = xml.sax.saxutils.escape(target)
                #   create TU line
                tu = ''.join(['<tu creationdate="', now,
                              '" creationid="eunlp"><prop type="Txt::Note">',
                              note, '</prop>', tag, '\n'])
                fout.write(tu)
                #   create TUV source line
                tuv = ''.join(['<tuv xml:lang="', s_lang, '"><seg>', source,
                               '</seg></tuv>\n'])
                fout.write(tuv)
                #   create TUV target line
                tuv = ''.join(['<tuv xml:lang="', t_lang, '"><seg>', target,
                               '</seg></tuv> </tu>\n'])
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


def file_to_list(file_name, one=False, two=False):
    # clean and convert file to list of paragraphs
    with codecs.open(file_name, "r", "utf-8") as fin:
        text = fin.read()
    text = re.sub(r'\xa0+', ' ', text)  # replace non-breaking space
    text = re.sub(r'\n\s+', r'\n', text)  # remove whitespace after newline
    text = re.sub(r'^\n+', r'', text)  # remove empty lines at the beginning
    text = re.sub(r'\n$', r'', text)  # remove empty lines at the end
    # merge segments separated by comma and whitespace, with some exceptions
    # which are language-dependent unfortunately
    # re.sub(r',\s\n(?!Whereas|Having regard|In cooperation)', r', ', text)
    text = re.sub(r'\s+\n', r'\n', text)  # remove whitespace before newline
    text = re.sub(r' +', r' ', text)  # remove double whitespaces
    text = paragraph_combiner_sub(text)  # combine para numbers with text
    if one:
        # remove one-character lines which can make the aligner to fail
        text = re.sub(r'\n.(?=\n)', r'', text)
        # also try to remove two-character lines which can make it to fail
        if two:
            text = re.sub(r'\n.{1,2}(?=\n)', r'', text)
    paragraph_list = re.split(r'\n', text)  # split file
    return paragraph_list


def smart_aligner(source_file, target_file, s_lang, t_lang, dictionary,
                  align_file, program_folder, note, over=True, para_size=300,
                  para_size_small=100):
    # functions.smart_aligner("A720120002_EN.txt", "A720120002_RO.txt", "en",
    # "ro", "enro.dic", "bi_test", "/home/filip/eunlp/", "A720120002")
    if (not over) and os.path.isfile(align_file + '.tab'):
        logging.warning("File pair already aligned: %s", align_file)
        return  # exit if already aligned and over=False
    source_list = file_to_list(source_file)
    target_list = file_to_list(target_file)
    # If different No of paragraphs, make 2 more attempts to process the files
    if len(source_list) != len(target_list):
        source_list = file_to_list(source_file, one=True)
        target_list = file_to_list(target_file, one=True)
        if len(source_list) != len(target_list):
            source_list = file_to_list(source_file, one=True, two=True)
            target_list = file_to_list(target_file, one=True, two=True)
            if len(source_list) != len(target_list):
                logging.error("Smart alignment failed in %s -> Hunalign",
                              source_file)
                # Using Hunalign on the entire file is mostly useless.
                # aligner(source_file, target_file, s_lang, t_lang, dictionary,
                #         align_file, program_folder, note, delete_temp=True)
                return
            else:
                logging.warning('Alignment at 3rd attempt in %s', source_file)
        else:
            logging.warning('Alignment at 2nd attempt in %s', source_file)
    # If equal number of paragraphs:
    parallel_aligner(source_list, target_list, s_lang, t_lang, dictionary,
                     align_file, program_folder, para_size=para_size,
                     para_size_small=para_size_small, prj_name=source_file)
    # turn alignment into tmx
    tab_to_tmx(align_file + '.tab', align_file + '.tmx', s_lang, t_lang, note)
    # create parallel source and target text files
    tab_to_separate(align_file + '.tab', source_file[:-4] + '.ali',
                    target_file[:-4] + '.ali')


def parallel_aligner(s_list, t_list, s_lang, t_lang, dictionary,
                     align_file, program_folder, para_size=300,
                     para_size_small=100, prj_name='temp'):
    if not os.path.exists("/tmp/eunlp"):
        os.makedirs("/tmp/eunlp")
    fout = codecs.open(align_file + '.tab', "w", "utf-8")
    # send paragraph to hunalign if large or if intermediate and
    # both source and target have a dot followed by whitespace.
    patt = re.compile(r'\. ')  # TODO de pus si punct si virgula si doua pcte?
    for i in range(len(s_list)):
        small = len(s_list[i]) < para_size_small
        n_pat = not (re.search(patt, s_list[i]) and re.search(patt, t_list[i]))
        clean_intermediate = ((len(s_list[i]) < para_size) and
                              (len(s_list[i]) >= para_size_small) and n_pat)
        if small or clean_intermediate:
            line = ''.join(["Nai\t", t_list[i], "\t", s_list[i], "\n"])
            fout.write(line)
        else:
            tmp_aligner(s_list[i], t_list[i], s_lang, t_lang, dictionary,
                        program_folder, fout, prj_name, i)
    fout.close()


def tmp_aligner(source, target, s_lang, t_lang, dictionary, program_folder,
                fout, prj_name, i):
    r_num = str(random.randint(0, 100000))
    tmp_source = "/tmp/eunlp/s_" + r_num + ".txt"
    tmp_target = "/tmp/eunlp/t_" + r_num + ".txt"
    tmp_align = "/tmp/eunlp/align_" + r_num
    # write the two files
    with codecs.open(tmp_source, "w", "utf-8") as sout:
        sout.write(source + '\n')
    with codecs.open(tmp_target, "w", "utf-8") as tout:
        tout.write(target + '\n')
    # process them with the classic aligner
    lines = aligner(tmp_source, tmp_target, s_lang, t_lang, dictionary,
                    tmp_align, program_folder, "a_" + r_num, tab=False,
                    tmx=False, sep=False)
    # do some checks with the hunalign aligment and use only if ok
    everything_ok = check_hunalign(lines, source, target)
    if everything_ok[0]:
        fout.write(everything_ok[1])
    else:
        logging.info("Hunalign failed in segment %s in file %s.", str(i),
                     prj_name)
        line = ''.join(["Err\t", target, "\t", source, "\n"])
        fout.write(line)
    # remove temporary files
    os.remove(tmp_source)
    os.remove(tmp_target)
    os.remove(tmp_align + '.lad')


def check_hunalign(lines, full_source, full_target):
    counter_s = 0
    counter_t = 0
    text = ''
    everything_ok = True
    for i in range(len(lines)):
        split_line = re.split("\t", lines[i])
        new_line = ''.join(["Hun\t", split_line[1], "\t", split_line[2]])
        text += new_line
        counter_s += len(split_line[2]) + 1
        counter_t += len(split_line[1]) + 1
        if len(split_line[1]) > 0:
            translation_ratio = float(
                len(split_line[2]))/len(split_line[1])
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
        everything_ok = False
    return everything_ok, text


def split_token_nltk(file_name, sent_splitter):
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
        sentences = sent_splitter.tokenize(line)
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


def sentence_splitter(program_folder, lang):
    punkt_param = PunktParameters()
    subfolder = 'sentence_splitter/nonbreaking_prefixes/nonbreaking_prefix.'
    ab_file = ''.join([program_folder, subfolder, lang])
    if os.path.isfile(ab_file):
        punkt_param.abbrev_types = set(abbreviation_loader(ab_file))
    else:
        logging.warning('Abbreviation file not found for language: %s', lang)
    splitter = PunktSentenceTokenizer(punkt_param)
    return splitter


def aligner(s_file, t_file, s_lang, t_lang, dic, a_file, program_folder, note,
            tab=True, tmx=True, sep=True):
    # prepare sentence splitters
    s_sentence_splitter = sentence_splitter(program_folder, s_lang)
    t_sentence_splitter = sentence_splitter(program_folder, t_lang)
    # call splitter & aligner
    split_token_nltk(s_file, s_sentence_splitter)
    split_token_nltk(t_file, t_sentence_splitter)
    # create empty hunalign dic from program-folder/data_raw files
    if not os.path.exists(dic):
        path = program_folder + 'data_raw/'
        create_dictionary(path + s_lang + '.txt', path + t_lang + '.txt', dic)
    # create hunalign ladder alignment
    hunalign_wrapper(s_file[:-4] + '.tok', t_file[:-4] + '.tok', dic,
                     a_file + '.lad', program_folder, realign=True)
    # create aligned output
    output_lines = l2t.make_lines(a_file + '.lad', s_file[:-4], t_file[:-4])
    output_lines = [unicode(line, "utf-8") + '\n' for line in output_lines]
    # writing .tab, .tmx and parallel .sep source and target files
    if tab:
        with codecs.open(a_file + '.tab', "w", "utf-8") as fout:
            for line in output_lines:
                fout.write(line)
        if tmx:
            tab_to_tmx(a_file + '.tab', a_file + '.tmx', s_lang, t_lang, note)
        if sep:
            tab_to_separate(a_file + '.tab', s_file[:-4] + '.ali',
                            t_file[:-4] + '.ali')
    # remove temporary files
    os.remove(s_file[:-4])
    os.remove(t_file[:-4])
    os.remove(s_file[:-4] + ".tok")
    os.remove(t_file[:-4] + ".tok")
    return output_lines


def eu_xml_converter(file_name):
    # TODO xpath http://docs.python-guide.org/en/latest/scenarios/scrape/
    with codecs.open(file_name, 'r', 'utf-8') as f:
        text = f.read()
    soup = BeautifulSoup(text, 'lxml')
    lista = []
    for item in soup.find_all('result'):
        celex = item.find('id_celex').contents[1].contents[0]
        title = item.find('expression_title').contents[1].contents[0]
        lista.append((celex, title))
    return lista


def align(langs, path, celex, program_folder):
    # create html and txt files for each language code
    try:
        scraper(langs, make_celex_link, celex, '', is_celex=True,
                over_html=False, over_txt=False)
    except urllib2.HTTPError:
        logging.error("Aborting alignment due to link error in %s.", celex)
    else:
        # prepare paths
        s_file, t_file, align_file, dic = make_paths(path, celex, langs)
        # call the aligner
        smart_aligner(s_file, t_file, langs[0].lower(), langs[1].lower(),
                      dic, align_file, program_folder, celex, over=False)


def merge_tmx():
    # create a list of tmx files in current directory (also test for languages)
    # for file in list:
    #    read file
    #    remove header and footer
    #    add remaining contents to target_file (if s_lang and t_lang?)
    pass