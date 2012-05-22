#!/bin/sh

#### This script assumes F4DE 2.4.0 or greater is installed and $F4DE_BASE is set

KWSEVAL=KWSEVAL
TLISTADDNGRAM=TListAddNGram
KWSLISTGEN=KWSListGenerator
KWSVALIDATE=ValidateKWSList
DETUTIL=DETUtil
mode=DEV
if [ ! "$mode" = DEV ] ; then
    if [ "$F4DE_BASE" = "" ] ; then
	echo "Error: Set the environment variable \$F4DE_BASE per the F4DE install instructions"
	exit 1
    fi
    BABELPARSE="perl -I $F4DE_BASE/common/lib -I $F4DE_BASE/KWSEval/libb ./BabelTransParse.pl"
else
    BASE=../../../
    KWSEVAL="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/KWSEval/KWSEval.pl"
    TLISTADDNGRAM="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/TListAddNGram/TListAddNGram.pl"
    BABELPARSE="perl -I $BASE/common/lib -I $BASE/KWSEval/lib ./BabelTransParse.pl"
    KWSLISTGEN="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/KWSListGenerator/KWSListGenerator.pl"
    KWSVALIDATE="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/ValidateKWSList/ValidateKWSList.pl"
    DETUTIL="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/common/tools/DETUtil/DETUtil.pl"
fi


#for langID in 101 104 105 english ; do
#for langID in 105-Dist-dev 104-Dist-dev; do
#for langID in 104-Dist-dev 104-Dist-eval 104-Dist-training; do
#for langID in 106-Dist-dev 106-Dist-eval 106-Dist-training ; do
#for langID in 106-Dist-scr-train 106-Dist-scr-eval  106-Dist-scr-dev ; do
for langID in 106-Dist-scr-dev 106-Dist-scr-train 106-Dist-dev 106-Dist-training ; do
    if [ $langID = "101" ] ; then
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
    $KWSLISTGEN -t $OUTROOT.source.tlist.xml -r $OUTROOT.source.rttm -o $OUTROOT.sys1.stdlist.xml -m 0.2 -f 0.2
    $KWSLISTGEN -t $OUTROOT.source.tlist.xml -r $OUTROOT.source.rttm -o $OUTROOT.sys2.stdlist.xml -m 0.1 -f 0.1
    echo ""

    echo "Validating random systems"
    $KWSVALIDATE -t Lang101-Demo/cantonese.source.tlist.xml -e Lang101-Demo/cantonese.source.ecf.xml -s Lang101-Demo/cantonese.sys1.stdlist.xml
    $KWSVALIDATE -t Lang101-Demo/cantonese.source.tlist.xml -e Lang101-Demo/cantonese.source.ecf.xml -s Lang101-Demo/cantonese.sys2.stdlist.xml
    echo ""

    echo "Add N-Gram annotations to the Term list file"
    $TLISTADDNGRAM -t $OUTROOT.source.tlist.xml -o $OUTROOT.source.tlist.annot.xml
    echo ""

    for sys in sys1 sys2 ; do
	echo "Compute reports for $sys"
	$KWSEVAL \
	    -I "Demo system $sys" \
	    -e $OUTROOT.source.ecf.xml \
	    -r $OUTROOT.source.rttm \
	    -t $OUTROOT.source.tlist.annot.xml \
	    -s $OUTROOT.$sys.stdlist.xml \
	    -C $OUTROOT.$sys.csv \
	    -o $OUTROOT.$sys.report.txt \
	    -H $OUTROOT.$sys.report.html \
	    -d $OUTROOT.$sys.det 
### These options will be in the next release
#	    -O $OUTROOT.$sys.conditional.report.txt \
#	    -Q $OUTROOT.$sys.conditional.report.html \
#	    -D $OUTROOT.$sys.conditional.det \
#	    -q "NGram Order" 
	echo ""
    done
done

echo "Building a combined DET Curve"
$DETUTIL -o $OUTROOT.ensemble.det.png $OUTROOT.sys?.det.CTS.srl.gz

exit;


