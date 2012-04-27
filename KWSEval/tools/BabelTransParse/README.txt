File: BabelTransParse/README.txt
Date: April 27, 2012

This directory contains an example scoring for the Babel 2012
evaluations.  The example assumes the F4DE package has been installed
and part of your shell environment.  This release covers L101 data and
some English debugging data.  The file formats are slight
modifications of the STD '06 data files discribed in the STD '06 eval
plan found on
http://www.itl.nist.gov/iad/mig//tests/std/2006/index.html.

The script 'BabelTransParse/BabelScoringPrimer.sh' demonstrates how to
use the F4DE tools to evaluate a KWS system.  The steps are as
follows:

Step 1: Parsing the Babel transcripts 

The 'BabelTransParse.pl' script is a prototype parser of BABEL,
original orthography, transcript files.  The script generates ECF and
RTTM files from the transcripts and a set of high-occurring unigram,
bigram and trigram terms.  The script applies no advanced text
translation rules beyond whitespace splitting.

Step 2: Generation of two random system output files.

Step 3: Validation of the of the system output files.

Step 4: Scoring the randomn systems

Step 5: Building a two-system composite DET Curve.
 
