#!/bin/bash

# BABEL Participant SubmissionHelper + BABELScorer Checker (Core)
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
Usage: $0 [-h] FileToUse SubHelpLocation CommandToRun

The script run "CommandToRun MatchingFile" and matching the result to the FileToRun
(the script needs the location of the SubmissionHelper tool to load the Evaluation specific configuration file)

OPTIONS:
   -h      Show this message
EOF
}

while getopts "h" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
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

########################################
## Command line check

if [[ $# < 3 ]]; then usage; error_quit "No FileToRun or CommandToRun on command line, quitting" ; fi

####################

ff=$1
shift

subhelp=$1
shift
check_file_x "$subhelp"

subhelp_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($1)); print $dir' $subhelp`

####################
# Obtaining relevant information

f=`echo $ff | perl -ne 'print $1 if (m%^[^\/]+/(.+)$%);'`

echo ""
echo "[**********] [TestFile] $ff"
eval=`echo $f | perl -ne 'print $1 if (m%^(\w+?)_%);'`
inf=`echo $f | perl -ne 'print $1 if (m%^(.+?)_____%);'`
base=`echo $inf | perl -ne 'print $1 if (m%^(.+?)\.[a-z\.]+$%i);'`
ext=`echo $inf | perl -ne 'print $1 if (m%^.+?\.([a-z\.]+)$%);'`
resf=`echo $f | perl -ne 'print $1 if (m%_____(.+)$%);'`
#  echo "[EVAL:$eval] [base:$base |ext:$ext] [Res:$resf]"
    
# Checks
doit=1
if [ "A$eval" == "A" ]; then echo "!! Could not extract Evaluation information, skipping"; doit=0; fi
if [ "A$inf" == "A" ]; then echo "!! Could not extract Input File information, skipping"; doit=0; fi
if [ "A$base" == "A" ]; then echo "!! Could not extract Base File information, skipping"; doit=0; fi
if [ "A$ext" == "A" ]; then echo "!! Could not extract Expected File Extension information, skipping"; doit=0; fi
if [ "A$resf" == "A" ]; then echo "!! Could not extract Expected Result File information, skipping"; doit=0; fi

### Doit
if [ "A$doit" == "A1" ]; then
  # Load configuration file
    conf="$subhelp_dir/${eval}_SubmissionHelper.cfg"
    if [ ! -f "$conf" ]; then
        echo "!! Skipping test: No $eval configuration file ($conf)"
    else
        source "$conf"
        finf="${dbDir}/samples/$inf"
        if [ ! -f "$finf" ]; then
            echo "!! Skipping test: No $eval input file ($finf)"
        else
            echo ""
            res1=".__tmp_res1"
            res2=".__tmp_res2"
            rm -f $res1 $res2
            echo "[*****] Running: $subhelp $subhelp_xtras $finf"
            $* $finf
            if [ "${?}" -ne "0" ]; then error_quit "Problem running tool, aborting"; fi
      # confirm results are present
            echo "[-----] Checking for comparison file: $resf"
            resdir="$uncompdir/$base"
            check_dir "$resdir"
            resfile="$resdir/$resf"
            check_file "$resfile"
            perl -pe 's%/tmp/\S+?\.png%%g' "$resfile"> $res1
            cmpfile="$ff"
            check_file "$cmpfile"
            perl -pe 's%/tmp/\S+?\.png%%g' "$cmpfile"> $res2
            cmp -s $res1 $res2
            if [ "${?}" -ne "0" ]; then error_quit "Resulting file ($resfile) does not contain the same numbers as expected file ($cmpfile) [temporary file names location excluded]"; fi
            echo "[=====] ok"
            rm -f $res1 $res2
        fi
    fi
fi

exit 0
