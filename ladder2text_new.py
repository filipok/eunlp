#!/usr/bin/python
# This is a reorganized ladder2text.py file (found in hunalign-1.1/scripts).
import sys
import itertools


def readfile(name):
    # Open the input files and read lines
    infile = file(name, 'r')
    lines = map(lambda s: s.strip("\n"), infile.readlines())
    return lines


def pairwise(iterable):
    # s -> (s0,s1), (s1,s2), (s2, s3), ...
    # see http://docs.python.org/library/itertools.html
    a, b = itertools.tee(iterable)
    b.next()
    return itertools.izip(a, b)


def parse_ladder_line(l):
    a = l.split()
    assert len(a) == 3
    # The score we leave as a string, to avoid small diffs caused
    # by different numerical representations.
    return int(a[0]), int(a[1]), a[2]

'''Create aligned text from two sentence files and hunalign's ladder-style
output.
Usage: ladder2text.py <aligner.ladder> <hu.sen> <en.sen> > aligned.txt
See http://mokk.bme.hu/resources/hunalign for detailed format specification
and more.
The output file is tab-delimited, with three columns. The first is a
probability score.
The second and third columns are the chunks corresponding to each other.
" ~~~ " is the sentence delimiter inside chunks.
'''


def create_output_lines(ladder_file, s_file, t_file):
    ladder_lines = readfile(ladder_file)
    s_lines = readfile(s_file)
    t_lines = readfile(t_file)
    ladder = map(parse_ladder_line, ladder_lines)
    # the next map() does all the work, so here are some comments...
    # the map() iterates over the holes of the ladder.
    # a hole is supposed to be two consecutive items in the array
    # holding the lines of the ladder.
    # /an array of holes is returned by pairwise(ladder)/
    # the following segment returns an interval of sentences
    # corresponding to a hole:
    # t_lines[int(hole[0][0]):int(hole[1][0])]
    return map(lambda hole:
        hole[0][2] + "\t" +
        " ~~~ ".join(t_lines[int(hole[0][0]):int(hole[1][0])])
        + "\t" +
        " ~~~ ".join(s_lines[int(hole[0][1]):int(hole[1][1])])
        , pairwise(ladder)
    )


def main():
    if len(sys.argv) == 4:
        ladderlines = readfile(sys.argv[1])
        hulines = readfile(sys.argv[2])
        enlines = readfile(sys.argv[3])

        outputlines = create_output_lines(ladderlines, enlines, hulines)

        for l in outputlines:
            print l
    else:
        print 'usage: ladder2text.py <aligned.ladder> <hu.raw> <en.raw> > aligned.txt'
        sys.exit(-1)


if __name__ == "__main__":
    main()
