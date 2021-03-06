#!/bin/sh
#
# $Id$
#

#### This script assumes F4DE 2.4.0 or greater is installed

KWSEVAL=KWSEVAL
TLISTADDNGRAM=TListAddNGram
KWSLISTGEN=KWSListGenerator
KWSVALIDATE=ValidateKWSList
DETUTIL=DETUtil

tool_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($ARGV[0])); print $dir' $0`

BASE="$tool_dir/../../../"

KWSEVAL="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/KWSEval/KWSEval.pl"
TLISTADDNGRAM="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/KWSStats/TermListAnnotator.pl"
BABELPARSE="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $tool_dir/BabelTransParse.pl"
KWSLISTGEN="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/KWSListGenerator/KWSListGenerator.pl"
KWSVALIDATE="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/ValidateKWSList/ValidateKWSList.pl"
DETUTIL="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/common/tools/DETUtil/DETUtil.pl"


for langID in 101 104 105 106 english ; do
#for langID in 105-Dist-dev 104-Dist-dev; do
#for langID in 104-Dist-dev 104-Dist-eval 104-Dist-training; do
#for langID in 106-Dist-dev 106-Dist-eval 106-Dist-training ; do
#for langID in 106-Dist-scr-train 106-Dist-scr-eval  106-Dist-scr-dev ; do
#for langID in 106-Dist-scr-dev 106-Dist-scr-train 106-Dist-dev 106-Dist-training ; do
#for langID in Babel_Lang_101 ; do
    if [ $langID = "Babel_Lang_101" ] ; then
	BABELDATA=Babel_Lang_101
	language=cantonese
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "101" ] ; then
	BABELDATA=Lang101
	language=cantonese
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "104" ] ; then
	BABELDATA=Lang104
	language=pashto
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "104-Dist-training" ] ; then
	BABELDATA=BABEL_BP_104_conversational_training
	language=pashto
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "104-Dist-eval" ] ; then
	BABELDATA=BABEL_BP_104_conversational_eval
	language=pashto
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "104-Dist-dev" ] ; then
	BABELDATA=BABEL_BP_104_conversational_dev
	language=pashto
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "105" ] ; then
	BABELDATA=Lang105
	language=turkish
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "105-Dist-training" ] ; then
	BABELDATA=BABEL_BP_105_conversational_training
	language=turkish
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "105-Dist-eval" ] ; then
	BABELDATA=BABEL_BP_105_conversational_eval
	language=turkish
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "105-Dist-dev" ] ; then
	BABELDATA=BABEL_BP_105_conversational_dev
	language=turkish
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "106" ] ; then
	BABELDATA=Lang106
	language=tagalog
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "106-Dist-training" ] ; then
	BABELDATA=BABEL_BP_106_conversational_training
	 language=tagalog
	 norm=""
	 encoding=UTF-8
	 files="*.txt"
     elif [ $langID = "106-Dist-eval" ] ; then
	 BABELDATA=BABEL_BP_106_conversational_eval
	 language=tagalog
	 norm=""
	 encoding=UTF-8
	 files="*.txt"
     elif [ $langID = "106-Dist-dev" ] ; then
	 BABELDATA=BABEL_BP_106_conversational_dev
	language=tagalog
	norm=""
	encoding=UTF-8
	files="*.txt"
     elif [ $langID = "106-Dist-scr-train" ] ; then
	BABELDATA=BABEL_BP_106_scripted_training
	language=tagalog
	norm=""
	encoding=UTF-8
	files="*.txt"
     elif [ $langID = "106-Dist-scr-dev" ] ; then
	BABELDATA=BABEL_BP_106_scripted_dev
	language=tagalog
	norm=""
	encoding=UTF-8
	files="*.txt"
     elif [ $langID = "106-Dist-scr-eval" ] ; then
	BABELDATA=BABEL_BP_106_scripted_eval
	language=tagalog
	norm=""
	encoding=UTF-8
	files="*.txt"
    elif [ $langID = "english" ] ; then
	BABELDATA=LangEng
	language=english
	norm=lowercase
	encoding=""
	files="*.txt"
    else 
	echo "Error: Unknown language $langID"
	exit 1
    fi

    OUTDIR=$BABELDATA-Demo
    OUTROOT=$BABELDATA-Demo/$language
    rm -fr $OUTDIR
    mkdir -p $OUTDIR

    echo "Parsing the Babel transcript files"
    $BABELPARSE \
	-language $language \
	-encoding UTF-8 \
	-compareNormalize "$norm" \
	-Verbose \
	-root $OUTROOT.source $BABELDATA/$files
    echo ""

    echo "Generate two random systems";
    $KWSLISTGEN -t $OUTROOT.source.kwlist.xml -r $OUTROOT.source.rttm -o $OUTROOT.sys1.stdlist.xml -m 0.2 -f 0.2
    $KWSLISTGEN -t $OUTROOT.source.kwlist.xml -r $OUTROOT.source.rttm -o $OUTROOT.sys2.stdlist.xml -m 0.1 -f 0.1
    echo ""

    echo "Validating random systems"
    $KWSVALIDATE -t $BABELDATA-Demo/$language.source.kwlist.xml -e $BABELDATA-Demo/$language.source.ecf.xml -s $BABELDATA-Demo/$language.sys1.stdlist.xml
    $KWSVALIDATE -t $BABELDATA-Demo/$language.source.kwlist.xml -e $BABELDATA-Demo/$language.source.ecf.xml -s $BABELDATA-Demo/$language.sys2.stdlist.xml
    echo ""

    echo "Add N-Gram annotations to the Term list file"
    $TLISTADDNGRAM -i $OUTROOT.source.kwlist.xml -o $OUTROOT.source.kwlist.annot.xml -n
    for sys in sys1 sys2 ; do
	echo ""
	echo "Compute occurrence reports for $sys"
	mkdir $OUTROOT.$sys.Occurrence
	$KWSEVAL \
	    -I "Demo system $sys" \
	    -e $OUTROOT.source.ecf.xml \
	    -r $OUTROOT.source.rttm \
	    -t $OUTROOT.source.kwlist.annot.xml \
	    -s $OUTROOT.$sys.stdlist.xml \
	    -c \
	    -o \
	    -b \
	    -f $OUTROOT.$sys.Occurrence/$sys \
	    -d \
	    -O \
	    -B \
	    -D \
	    -q "NGram Order" \
	    -y TXT \
	    -y HTML \
	echo ""
	echo ""
	echo "Compute segment reports for $sys"
	mkdir $OUTROOT.$sys.Segment
	$KWSEVAL \
	    -I "Demo system $sys" \
	    -e $OUTROOT.source.ecf.xml \
	    -r $OUTROOT.source.rttm \
	    -t $OUTROOT.source.kwlist.annot.xml \
	    -s $OUTROOT.$sys.stdlist.xml \
	    -c \
	    -o \
	    -b \
	    -f $OUTROOT.$sys.Segment/$sys \
	    -d \
	    -O \
	    -B \
	    -D \
	    -g \
	    -q "NGram Order" \
	    -y TXT \
	    -y HTML \
	echo ""
    done

    echo "Building combined DET Curves"
    $DETUTIL -o $OUTROOT.Occurrence.ensemble.det.png $OUTROOT.sys?.Occurrence/sys?.dets/sum.Occurrence.srl.gz
    $DETUTIL -o $OUTROOT.Segment.ensemble.det.png $OUTROOT.sys?.Segment/sys?.dets/sum.Segment.srl.gz
done
exit 0;
