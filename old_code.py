import subprocess
import codecs
import re
import align

def split_token_perl(file_name, lang, program_folder):
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
    # paragraph combiner
    output = align.paragraph_combiner_sub(output)
    with codecs.open(file_name[:-4], 'w', 'utf-8') as f:
        f.write(unicode(output, 'utf-8'))
    # tokenizer
    command = ['perl', program_folder + 'tokenizer.perl', '-l', lang]
    p = subprocess.Popen(command, stdout=subprocess.PIPE,
                         stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    output = p.communicate(output)[0]  # presupun ca [1] e stderr?
    with codecs.open(file_name[:-4] + '.tok', 'w', 'utf-8') as f:
        f.write(unicode(output, 'utf-8'))
