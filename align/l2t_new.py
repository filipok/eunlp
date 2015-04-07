"""
This is a reorganized ladder2text.py file (found in hunalign-1.1/scripts).
"""

import itertools


def readfile(name):
    """
    Open the input files and read lines
    :type name: str
    :rtype: list
    """
    infile = file(name, 'r')
    lines = map(lambda s: s.strip("\n"), infile.readlines())
    return lines


def pairwise(iterable):
    """

    :type iterable: list
    :rtype: itertools.izip
    """
    # s -> (s0,s1), (s1,s2), (s2, s3), ...
    # see http://docs.python.org/library/itertools.html
    a_var, b_var = itertools.tee(iterable)
    try:
        b_var.next()
    except StopIteration:
        raise
    return itertools.izip(a_var, b_var)


def parse_ladder_line(line):
    """

    :type line: str
    :rtype: tuple
    """
    a_split = line.split()
    assert len(a_split) == 3
    # The score we leave as a string, to avoid small diffs caused
    # by different numerical representations.
    return int(a_split[0]), int(a_split[1]), a_split[2]


def make_lines(ladder_file, s_file, t_file):
    """

    :type ladder_file: str
    :type s_file: str
    :type t_file: str
    :rtype:
    """
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
    try:
        lines = map(lambda hole:
                    hole[0][2] + "\t" +
                    " ~~~ ".join(t_lines[int(hole[0][0]):int(hole[1][0])])
                    + "\t" +
                    " ~~~ ".join(s_lines[int(hole[0][1]):int(hole[1][1])]),
                    pairwise(ladder)
                    )
    except StopIteration:
        raise
    return lines
