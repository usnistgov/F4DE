#!/bin/sh

#### This script assumes F4DE 2.4.0 or greater is installed and $F4DE_BASE is set

KWSEVAL=KWSEVAL
TLISTADDNGRAM=TListAddNGram
KWSLISTGEN=KWSListGenerator
KWSVALIDATE=ValidateKWSList
mode=DIST
if [ $mode ne DEV ] ; then
    if [ "$F4DE_BASE" = "" ] ; then
	echo "Error: Set the environment variable \$F4DE_BASE per the F4DE install instructions"
	exit 1
    fi
    BABELPARSE="perl -I $F4DE_BASE/common/lib -I $F4DE_BASE/KWSEval/libb ./BabelTransParse.pl"
else
    BASE=../../../
    KWEVAL="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/KWSEval/KWSEval.pl"
    TLISTADDNGRAM="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/TListAddNGram/TListAddNGram.pl"
    BABELPARSE="perl -I $BASE/common/lib -I $BASE/KWSEval/lib ./BabelTransParse.pl"
    KWSLISTGEN="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/KWSListGenerator/KWSListGenerator.pl"
    KWSVALIDATE="perl -I $BASE/common/lib -I $BASE/KWSEval/lib $BASE/KWSEval/tools/ValidateKWSList/ValidateKWSList.pl"
fi



#for langID in 101 104 105 english ; do
for langID in 101 english ; do
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
    elif [ $langID = "105" ] ; then
	BABELDATA=Lang105
	language=turkish
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
DETUtil -o $OUTROOT.ensemble.det.png $OUTROOT.sys?.det.CTS.srl.gz

exit;


