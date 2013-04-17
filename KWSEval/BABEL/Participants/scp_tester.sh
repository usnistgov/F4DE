#!/bin/bash

# BABEL Participant scp_tester
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
usage()
{
cat << EOF
Usage:
$0 [-h] 

The script will try to upload the SubmissionHelper_common.cfg file to the upload server using setting in configuration file.

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

##########
subhelp_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($ARGV[0])); print $dir' $0`
conf="${subhelp_dir}/SubmissionHelper_common.cfg"

echo "-- Loading Configuration file: $conf"
check_file "$conf"
source "$conf"

#####
if [ -z "${scp_cmd+xxx}" ]; then error_quit "scp_cmd is not set"; fi
if [ -z "$scp_cmd" ] && [ "${scp_cmd+xxx}" = "xxx" ]; then error_quit "scp_cmd has no value set"; fi
#
if [ -z "${scp_user+xxx}" ]; then error_quit "scp_user is not set"; fi
if [ -z "$scp_user" ] && [ "${scp_user+xxx}" = "xxx" ]; then error_quit "scp_user has no value set"; fi
#
if [ -z "${scp_host+xxx}" ]; then error_quit "scp_host is not set"; fi
if [ -z "$scp_host" ] && [ "${scp_host+xxx}" = "xxx" ]; then error_quit "scp_host has no value set"; fi
#
if [ -z "${scp_status+xxx}" ]; then error_quit "scp_status is not set"; fi
if [ -z "$scp_status" ] && [ "${scp_status+xxx}" = "xxx" ]; then error_quit "scp_status has no value set"; fi

check_file_x "$scp_cmd"

#####
lf="$0.log"
cmd="${scp_cmd} ${scp_args} -v -v $conf ${scp_user}@${scp_host}:${scp_status}/."
echo "** Will run: $cmd"
echo "** and store log into: $lf"
echo ""
echo ""

echo "COMMAND: $cmd" > $lf
echo "" >> $lf
$cmd 2>&1 | tee -a $lf

echo ""
echo ""
if [ "${?}" -ne "0" ]; then error_quit "Problem running command, see: $lf"; fi

echo "** The scp upload attempt appears to have been succesful, please try a submission (see README)"
exit 0
