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
Usage: $0 [-h] [-A] [-R] [-X] CompsDir|CompsFile [...]

The script will submit files to the BABEL Scoring Server

OPTIONS:
   -h      Show this message
   -A      Authorize TERMs defined in KWList file but not in the KWSlist file
   -R      Resubmit a system file
   -X      Pass the XmllintBypass option to KWSList validation and scoring tools
EOF
}

RESUBMIT=0
AUTH_TERM=0
XMLLINTBYPASS=0
subhelp_xtras=""
while getopts "hARX" OPTION
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

if  [[ $# < 1 ]]; then usage; error_quit "No check directory or files on command line, quitting" ; fi

####################

subhelp="../SubmissionHelper.sh"
check_file_x "$subhelp"

get_basedir $subhelp
subhelp_dir="$wbd"
check_dir $subhelp_dir

get_basedir $0
tool_dir="$wbd"
check_dir $tool_dir

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
        fl="$fl $t"
    else
        echo "Skipping: Not a file or a dir [$e]"
    fi
done

for f in $fl
do
    $tool $f $subhelp $subhelp $subhelp_xtras
done

exit 0


