#!/usr/bin/env perl -w
#
# $Id$
#

use strict;

use Encode;
use encoding 'euc-cn';
use encoding 'utf8';


# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));
  print "f4d :: " . $f4d . "\n";
  push @f4bv, ("$f4d../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);
#

use Data::Dumper;
use MMisc;
use Getopt::Long;

my $termList = "";
my $language = "";
my $normalization = "";
my $encoding = "";
my $transPath = "";
my $fileOfTF = "";
my $query = "NGram Order";

my $BASE = "$f4d/../../..";

GetOptions
(
 'term-list=s' => \$termList,
 'file-of-transfiles=s' => \$fileOfTF,
 'language=s' => \$language,
 'encoding=s' => \$encoding,
 'normalization=s' => \$normalization,
 'query=s' => \$query,
 'path-of-transcripts=s' => \$transPath,
) or MMisc::error_quit("Unknown option(s)\n");

MMisc::error_quit("Must specify a TermList file.") if ($termList eq "");
MMisc::error_quit("Must specify a transcripts path.") if ($transPath eq "");
MMisc::error_quit("'language' option required.") if ($language eq "");
$encoding = "UTF-8" if ($encoding eq "" || $encoding =~ m/utf-?8/i);

my $KWSEVAL="$BASE/KWSEval/tools/KWSEval/KWSEval.pl";
my $TLISTGEN="$BASE/KWSEval/tools/KWSStats/TermListGen.pl";
my $ANNOTGEN="$BASE/KWSEval/tools/KWSStats/AnnotGen.sh";
my $TLISTANNOT="$BASE/KWSEval/tools/KWSStats/TermListAnnotator.pl";
my $BABELPARSE="$BASE/KWSEval/tools/BabelTransParse/BabelTransParse.pl";
my $KWSLISTGEN="$BASE/KWSEval/tools/KWSListGenerator/KWSListGenerator.pl";
my $KWSVALIDATE="$BASE/KWSEval/tools/ValidateKWSList/ValidateKWSList.pl";
my $DETUTIL="$BASE/common/tools/DETUtil/DETUtil.pl";

my $truncdir = $transPath;
$truncdir = $1 if ($truncdir =~ m:/([^/]+)/+$:);
my $OUTDIR="./" . $truncdir . "-DryRun";
my $OUTROOT=$OUTDIR . "/" . $language;
#format options
$fileOfTF = "-f ". $fileOfTF if ($fileOfTF ne "");
`rm -fr $OUTDIR`;
`mkdir -p $OUTDIR`;
print "Parsing the Babel transcript files\n";
system "$BABELPARSE -language $language -encoding $encoding -compareNormalize \"$normalization\" -Verbose -root $OUTROOT.source -t $transPath $fileOfTF";
print "\n";

print "Generating random systems\n";
`$KWSLISTGEN -t $termList -r $OUTROOT.source.rttm -o $OUTROOT.sys1.stdlist.xml -m 0.1 -f 0.1`;
`$KWSLISTGEN -t $termList -r $OUTROOT.source.rttm -o $OUTROOT.sys2.stdlist.xml -m 0.2 -f 0.2`;
`$KWSLISTGEN -t $termList -r $OUTROOT.source.rttm -o $OUTROOT.sys3.stdlist.xml -m 0.3 -f 0.3`;
print "\n";

print "Validating random systems\n";
`$KWSVALIDATE -t $termList -e $OUTROOT.source.ecf.xml -s $OUTROOT.sys1.stdlist.xml`;
`$KWSVALIDATE -t $termList -e $OUTROOT.source.ecf.xml -s $OUTROOT.sys2.stdlist.xml`;
`$KWSVALIDATE -t $termList -e $OUTROOT.source.ecf.xml -s $OUTROOT.sys3.stdlist.xml`;
print "\n";

#Generate Reports
for my $sys ("sys1", "sys2", "sys3") {
  print "Computing occurence reports for $sys\n";
  mkdir ("$OUTROOT.$sys.Occurrence");
  system "$KWSEVAL -I \"DryRun system $sys\" -e $OUTROOT.source.ecf.xml -r $OUTROOT.source.rttm -t $termList -s $OUTROOT.$sys.stdlist.xml -c -o -b -f $OUTROOT.$sys.Occurrence/$sys -d -O -B -D -q \"$query\" -y TXT -y HTML -c";
  print "\n";
  print "Computing segment reports for $sys\n";
  mkdir ("$OUTROOT.$sys.Segment");
  system "$KWSEVAL -I \"DryRun system $sys\" -e $OUTROOT.source.ecf.xml -r $OUTROOT.source.rttm -t $termList -s $OUTROOT.$sys.stdlist.xml -c -o -b -f $OUTROOT.$sys.Segment/$sys -d -O -B -D -g -q \"$query\" -y TXT -y HTML -c";
  print "\n";

  print "Building combined DET Curves\n";
  system "$DETUTIL -o $OUTROOT.Occurrence.ensemble.det.png $OUTROOT.$sys.Occurrence/$sys.dets/sum.Occurrence.srl.gz";
  system "$DETUTIL -o $OUTROOT.Segment.ensemble.det.png $OUTROOT.$sys.Segment/$sys.dets/sum.Segment.srl.gz";
}

MMisc::ok_quit();
