"""
Some old code for communication with Perl
"""

import subprocess
import codecs
import re
import os

from . import align


def split_token_perl(file_name, lang):
    """

    :type file_name: str
    :type lang: str
    """
    # TO DO http://search.cpan.org/dist/PersistentPerl/lib/PersistentPerl.pm
    # sentence splitter
    program_folder = os.path.dirname(__file__)
    with codecs.open(file_name, 'r', 'utf-8') as fin:
        command = ['perl',
                   program_folder + '/split-sentences.perl',
                   '-l', lang]
        proc = subprocess.Popen(command, stdin=fin, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        output, err = proc.communicate()  # output contains the splitter output
    # remove <P> created by the sentence splitter
    output = re.sub(r'\n<P>', '', output)
    # paragraph combiner
    output = align.paragraph_combiner_sub(output)
    with codecs.open(file_name[:-4], 'w', 'utf-8') as fout:
        fout.write(unicode(output, 'utf-8'))
    # tokenizer
    command = ['perl', program_folder + '/tokenizer.perl', '-l', lang]
    pro = subprocess.Popen(command, stdout=subprocess.PIPE,
                          stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    output = pro.communicate(output)[0]  # presupun ca [1] e stderr?
    with codecs.open(file_name[:-4] + '.tok', 'w', 'utf-8') as fout:
        fout.write(unicode(output, 'utf-8'))
