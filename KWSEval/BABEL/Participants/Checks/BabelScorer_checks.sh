#!/bin/bash

# BABEL Participant Scorer Checker
#   (by Martial Michel)
# ID: $Id$
# Revision: $Revision$

## Exit with error status
# call: error_quit errormessage
error_quit () {
    echo "ERROR: $1"
    exit 1
}

########## Usage/Options Processing
usage () {
    cat << EOF
Usage: $0 [-h] [-X] CompsDir|CompsFile [...]

The script will submit files to the local BABEL_Scorer

OPTIONS:
   -h        Show this message
   -X        Pass the XmllintBypass option to KWSList validation and scoring tools
   -D <BAD>  Documet the Bad runs in the file BAD
EOF
}

XMLLINTBYPASS=0
babscr_xtras=""
DOCUMENTBAD=""
toolOpt=""
while getopts "hXD:" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        X)
            XMLLINTBYPASS=1
            babscr_xtras="${babscr_xtras} -X"
            shift $((OPTIND-1)); OPTIND=1
            ;;
        D)
            DOCUMENTBAD=$OPTARG
            shift $((OPTIND-1));
	    toolOpt="-D $DOCUMENTBAD"
	    echo "Writing BAD summary to $DOCUMENTBAD"
	    if [ -f "$DOCUMENTBAD" ] ; then
		echo "    $DOCUMENTBAD exists!  NOT overwriting!!!!!"
		DOCUMENTBAD=""
		toolOpt=""
	    fi
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done

## Check that a file exists, is a file and is readable
# call: check_file filename
check_file () {
    if [ ! -e "$1" ]; then error_quit "File ($1) does not exist"; fi
    if [ ! -f "$1" ]; then error_quit "File ($1) is not a file"; fi
    if [ ! -r "$1" ]; then error_quit "File ($1) is not readable"; fi
}

## Check that a file pass check_file and is also executable
# call: check_file_x filename
check_file_x () {
    check_file "$1"
    if [ ! -x "$1" ]; then error_quit "File ($1) is not executable"; fi
}  

## Check that a directory exists, is a directory and is readable
# call: check_dir filename
check_dir () {
    if [ ! -e "$1" ]; then error_quit "Directory ($1) does not exist"; fi
    if [ ! -d "$1" ]; then error_quit "Directory ($1) is not a directory"; fi
    if [ ! -r "$1" ]; then error_quit "Directory ($1) is not readable"; fi
}

get_basedir () {
    wbd=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname"; print dirname(abs_path($ARGV[0]));' $1`
}

find_file_in_dbDir () {
  filev=""
  for dbd in $dbDir_list
  do
      if [ "A$filev" == "A" ]; then
          tmp_filev="$dbd/samples/$1"
          if [ -f $tmp_filev ]; then
            filev=$tmp_filev
          fi
      fi
  done
}

########################################
## Command line check

if  [ $# -lt 1 ]; then usage; error_quit "No check directory or files on command line, quitting" ; fi

####################

get_basedir $0
tool_dir="$wbd"
check_dir $tool_dir

subhelp="${tool_dir}/../SubmissionHelper.sh"
check_file_x "$subhelp"

get_basedir $subhelp
subhelp_dir="$wbd"
check_dir $subhelp_dir

tool="$tool_dir/do_checks_core.sh"
check_file_x "$tool"

babscr="$subhelp_dir/BABEL_Scorer.pl"
check_file_x "$babscr"

####################
# Get list of available files to work with
fl=""
for e in $*
do
    if [ -f $e ]; then
        fl="$fl $e"
    elif [ -d $e ]; then
        t=`ls $e`
        for x in $t; do if [ -f "$e/$x" ]; then fl="$fl $e/$x"; fi; done
    else
        echo "Skipping: Not a file or a dir [$e]"
    fi
done

# Prune extra configuration files
cfl=""
for e in $fl
do
  xconf=`echo $e | perl -ne 'print $1 if (m%^\.conf_\w+$%);'`
  if [ "A$xconf" == "A" ]; then
    cfl="$cfl $e"
  fi
done

run_bad=""
run_good=""

for ff in $cfl
do
    f=`echo $ff | perl -ne 'if (m%^.+/([^\/]+)$%){ print $1;}else{print $_;}'`

    eval=`echo $f | perl -ne 'print $1 if (m%^(\w+?)_%);'`
    inf=`echo $f | perl -ne 'print $1 if (m%^(.+?)_____%);'`
    expid=`echo $inf | perl -ne 'print $1 if (m%^(.+?)\.[a-z\d\.]+$%i);'`
    
# Checks
    doit=1
    if [ "A$eval" == "A" ]; then doit=0; fi
    if [ "A$inf" == "A" ]; then doit=0; fi
    if [ "A$expid" == "A" ]; then doit=0; fi

### Doit
    if [ "A$doit" == "A1" ]; then
        # Load configuration file
        conf="$subhelp_dir/${eval}_SubmissionHelper.cfg"
        if [ ! -f "$conf" ]; then
            echo "!! Skipping test: No $eval configuration file ($conf)"
        else
            # Confirm we have the proper SubmissionChecker configuration file
            scconf="$subhelp_dir/../../data/${eval}-SubmissionChecker_conf.perl"
            if [ ! -f "$scconf" ]; then
                echo "!! Force Skipping test: No $eval Scorer configuration file ($scconf)"
            else
                source "$conf"

                dbDir_list=$(echo $dbDir | tr ":" "\n")
                find_file_in_dbDir "$inf"
                finf="$filev"
                if [ ! -f "$finf" ]; then
                    echo "!! Skipping test: No $eval input file ($inf) in dbDir $dbDir"
                else
                    compdir=`mktemp -d -t ${expid}`
                    resdir="$uncompdir/$inf"
                    if [ -d "$resdir" ]; then rm -rf $resdir; fi
                    mkdir -p $resdir

                    xtra=""
                    xtraf="$ff.conf_BabelScorer"
                    if [ -f $xtraf ]; then
                        xtra=`cat $xtraf`
                    fi

		    if [ ! -z $DOCUMENTBAD ] ; then 
			echo TESTING $ff >> $DOCUMENTBAD
		    fi
		    com="$subhelp $babscr --Specfile $scconf --expid $expid --sysfile $finf --compdir $compdir --resdir $resdir --dbDir $dbDir --Tsctkbin $sctkbindir --ExcludePNGFileFromTxtTable $babscr_xtras $xtra"
                    $tool $toolOpt $ff $com
                    if [ "${?}" -ne "0" ]; then
			if [ ! -z $DOCUMENTBAD ] ; then 
			    echo COMMAND $com >> $DOCUMENTBAD
			fi
                        run_bad="${run_bad} $ff"
                    else
                        run_good="${run_good} $ff"
                    fi
                fi
            fi
        fi
    fi
done

echo ""
echo ""
echo "***** "`echo $run_good | wc -w`" OK"
for i in $run_good; do echo $i; done
echo ""
echo "***** "`echo $run_bad | wc -w`" BAD"
for i in $run_bad; do
    echo $i;
    if [ ! -z $DOCUMENTBAD ] ; then 
	echo BAD $i >> $DOCUMENTBAD
    fi
done

exit 0
