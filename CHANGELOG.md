# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.8.0] - 2018-07-12
### Added
- resolved bug for Curia documents
- updated download link for Eurlex (https)

## [0.7.0] - 2017-12-27
### Added
- use Jsalign 0.6
- change development status from 3 Alpha to 4 Beta

## [0.6.0] - 2016-07-20
### Added
- moved rangy-core 1.3.0 Javascript link to S3

## [0.5.0] - 2016-03-23
### Added
- resolved bug for Czech acronyms
- create Danish abbreviation file
- resolved bug for paragraph_separator with quotes
- change line endings to LF in BG, CA, ET, HU, RU, SL
- add BG, DA, DE, EL, ES, FI, FR, HR, HU, IT, LT, MT, PL, PT, RO, SV, EN abbvs
- restore (two or more character) abbreviations damaged by patterns 1 and 3
- add language parameter to paragraph_separator
- add Latin single upper case letters to BG abbreviations
- transform nested ifs into while loop in align.py
- in downloader, add new lines also before paras preceded by other tags
- bug in abbreviation loader
- join single full stop to previous paragraph
- use save_intermediates parameter in celex_aligner
- change logging level to info in eu_xml_converter
- add FI, GA, HR, LT, LV, MT prefix lists
- update HU, ET, LV negative lookaheads in paragraph_separator
- use argparse with celex_list and combine it with celex_pivot
- rename paragraph_separator to numbering_separator

## [0.4.5] - 2016-03-01
### Added
- add cut and paste buttons to the legend

## [0.4.4] - 2016-03-01
### Added
- use Jsalign 0.5

## [0.4.3] - 2016-02-25
### Added
- use Jsalign 0.4

## [0.4.2] - 2016-02-23
### Added
- use Jsalign 0.3

## [0.4.1] - 2016-02-17
### Added
- remove jsalign_cell function to vastly improve html file generation speed
- use list comprehensions instead of for loops
- some refactoring in basic aligner, tmp aligner and parallel aligner

## [0.4.0] - 2016-02-16
### Added
- better segment manual alignments in case of alignment errors 
- add warning when closing/refreshing manual alignment window

## [0.3.0] - 2016-02-14
### Added
- use Boostrap css for manual alignments 
- use Jsalign 0.2
- add CHANGELOG.md

## [0.2.0] - 2016-02-03
### Added
- change js and css files location to S3
- use Jsalign 0.1


## [0.1.0] - 2016-01-31
### Added
- first release