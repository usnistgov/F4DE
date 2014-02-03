#!/bin/bash

# BABEL Participant Submission Helper Checker
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
Usage: $0 [-h] [-A] [-R] [-V] [-X] CompsDir|CompsFile [...]

The script will submit files to the BABEL Scoring Server

OPTIONS:
   -h      Show this message
   -A      Authorize TERMs defined in KWList file but not in the KWSlist file
   -R      Resubmit a system file
   -V      re-Validate input file (in case component of the scoring tools was modified)
   -X      Pass the XmllintBypass option to KWSList validation and scoring tools
   -Q      When -R is used, quit after each upload so that the server is queued up.  A subsequent run WITHOUT -Q and -R will get the results
EOF
}

RESUBMIT=0
REVALIDATE=0
AUTH_TERM=0
XMLLINTBYPASS=0
QUITAFTERUPLOAD=0
subhelp_xtras=""
while getopts "hARXVQ" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        A)
            AUTH_TERM=1
            subhelp_xtras="${subhelp_xtras} -A"
            shift $((OPTIND-1)); OPTIND=1
            ;;
        R)
            RESUBMIT=1
            subhelp_xtras="${subhelp_xtras} -R"
            shift $((OPTIND-1)); OPTIND=1
            ;;
        Q)
            QUITAFTERUPLOAD=1
            subhelp_xtras="${subhelp_xtras} -Q"
            shift $((OPTIND-1)); OPTIND=1
            ;;
        V)
            REVALIDATE=1
            subhelp_xtras="${subhelp_xtras} -V"
            shift $((OPTIND-1)); OPTIND=1
            ;;
        X)
            XMLLINTBYPASS=1
            subhelp_xtras="${subhelp_xtras} -X"
            shift $((OPTIND-1)); OPTIND=1
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

for f in $cfl
do
    xtra=""
    xtraf="$f.conf_SubmissionHelper"
    if [ -f $xtraf ]; then
        xtra=`cat $xtraf`
    fi
    $tool -A $f $subhelp $subhelp -E $subhelp_xtras $xtra

    if [ "${?}" -ne "0" ]; then
        run_bad="${run_bad} $f"
    else
        run_good="${run_good} $f"
    fi
    
done

echo ""
echo ""
echo "***** "`echo $run_good | wc -w`" OK"
for i in $run_good; do echo $i; done
echo ""
echo "***** "`echo $run_bad | wc -w`" BAD"
for i in $run_bad; do echo $i; done

exit 0


