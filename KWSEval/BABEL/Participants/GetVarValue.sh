#!/bin/bash
#
# $Id$
#

## Exit with error status
# call: error_quit errormessage
error_quit () {
    echo "ERROR: $1"
    exit 1
}

## Check that a file exists, is a file and is readable
# call: check_file filename
check_file () {
  if [ ! -e "$1" ]; then error_quit "File ($1) does not exist"; fi
  if [ ! -f "$1" ]; then error_quit "File ($1) is not a file"; fi
  if [ ! -r "$1" ]; then error_quit "File ($1) is not readable"; fi
}

##########
usage()
{
cat <<EOF
Usage: $0 ConfigFile Variable
prints the Variable values extracted from ConfigFile
EOF
}

if  [ $# -lt 2 ]; then usage; error_quit "Not enough arguments on the command line, quitting" ; fi

##########

conf="$1"
check_file "$conf"
source "$conf"

var="$2"
eval echo $`echo $var`

exit 0



