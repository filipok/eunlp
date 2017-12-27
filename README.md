# eunlp


The eunlp project enables the [bilingual alignment](https://en.wikipedia.org/wiki/Parallel_text) of EU documents identified with their [Celex number](http://eur-lex.europa.eu/content/help/faq/celex-number.html).

## Usage

The common usage is as follows:

```python celex.py celex_number source_language target_language```


for example:

```python celex.py 32013R1024 en ro```

The output of the command is a [TMX](https://en.wikipedia.org/wiki/Translation_Memory_eXchange) file and an editable HTML file, where the alignment can be manually improved. An example is available [here](http://www.transverbis.ro/code/jobs/525/). The HTML file uses [jsalign](https://github.com/filipok/jsalign) JavaScript code to enable the interactive editing of the alignment.

## Details

The project uses Python 2.

The repository consists of a Python package called *align* and several separate scripts making use of it.

Dependencies include the following:

```install_requires=['nltk', 'beautifulsoup4', 'lxml', 'Jinja2']```

The package also includes the [hunalign](https://github.com/danielvarga/hunalign) executable.

## Working example

The [Celex aligner](http://www.transverbis.ro/code/scripts/celex-aligner/) uses this project as a script available via Django and [Wooey](https://github.com/wooey/Wooey).

## Inner workings

First, the source and target language files are downloaded from Eur-Lex. The downloaded HTML files are converted to TXT.

The the TXT files are converted to lists of lines. If the number of lines is different between the two files, the aligner tries euristically to remove very short lines. The reason is that sometimes Eur-Lex documents have lines containing only punctuation marks, due to formatting errors.

If the aligner is unable to obtain two lists with the same number of lines, it only generates a manual alignment, which is editable in a browser.

On the other hand, if the aligner is able to obtain two lists with the same number of lines, it goes to the next stage. At this point, the script capitalizes on the fact that the Eur-Lex documents are usually well aligned. So it presumes that an identical number of lines means a valid alignment.

However, an issue is that in many cases the segments are actually rather long paragraphs with multiple sentences. Therefore, the aligner sends to hunalign the lines that are longer than a certain amont of characters. Then it checks the result from hunalign (such as reasonable number of source and target characters for a bilingual pair of segments) and uses it if it looks fine.

After the alignment is generated, it is exported to two files: a TMX file, which can then be imported into mainstream translation memories, and an HTML file, where the alignment can be edited and corrected if necessary.

## Todo

Perhaps eliminate hunalign to reduce package size. Improve heuristics. Various minor bugs.
