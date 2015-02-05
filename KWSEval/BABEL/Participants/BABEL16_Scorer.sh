#!/bin/bash

########## BABEL
# ID: $Id$
# Revision: $Revision$

specfilename="KWS16-SubmissionChecker_conf.perl"
tvedsc_base="BABEL_Scorer"

tool_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($ARGV[0])); print $dir' $0`

echo "[$0]"
# In which mode are we running ?
specfile="$tool_dir/../../data/$specfilename"
tvedsc="$tool_dir/$tvedsc_base.pl"

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
if [ -z ${tvedsc:-} ]; then
  echo "ERROR: No TrecVid Submission Checker set, aborting"
  exit 1
fi
if [ ! -f $tvedsc ]; then
  echo "ERROR: Could not find need the TrecVid Submission Checker program ($tvedsc), aborting"
  exit 1
fi
if [ ! -x $tvedsc ]; then
  echo "ERROR: TrecVid Submission Checker program ($tvedsc) is not executable, aborting"
  exit 1
fi

# Command to run
cmd="$tvedsc --Specfile $specfile $*"
echo "FYI: $0 will run: [$cmd]"
echo ""

$cmd

# Exit with last command exit status
exit $?
