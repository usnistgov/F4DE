#!/bin/bash
#
# $Id$
#

specfilename="AVSS09-SubmissionChecker_conf.perl"
avsssc_base="AVSS-SubmissionChecker"

tool_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($ARGV[0])); print $dir' $0`

echo "[$0]"
# Im which mode are running
specfile="$tool_dir/../../data/$specfilename"
avsssc="$tool_dir/$avsssc_base.pl"

# Check specfile
if [ -z ${specfile:-} ]; then
  echo "ERROR: No Specfile set, aborting"
  exit 1
fi
if [ ! -f $specfile ]; then
  echo "ERROR: Could not find need specfile ($specfile), aborting"
  exit 1
fi

# Check tv ed submision checker
if [ -z ${avsssc:-} ]; then
  echo "ERROR: No TrecVid Submission Checker set, aborting"
  exit 1
fi
if [ ! -f $avsssc ]; then
  echo "ERROR: Could not find need the TrecVid Submission Checker program ($avsssc), aborting"
  exit 1
fi
if [ ! -x $avsssc ]; then
  echo "ERROR: TrecVid Submission Checker program ($avsssc) is not executable, aborting"
  exit 1
fi

# Command to run
cmd="$avsssc --Specfile $specfile $*"
echo "FYI: $0 will run: [$cmd]"
echo ""

$cmd

# Exit with last command exit status
exit $?
