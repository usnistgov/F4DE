#!/bin/bash

specfilename="TV13MED-SubmissionChecker_conf.perl"
tvedsc_base="MED-SubmissionChecker"

echo "[$0]"
# In which mode are we running ?
if [ -z ${F4DE_BASE:-} ]; then
  echo "Warning: Might need to be run from the directory where $tvedsc_base.pl is"
  ap=`perl -e 'use Cwd 'abs_path'; use File::Basename 'dirname'; print dirname(abs_path($ARGV[0]));' $0`
  echo "(trying to obtain tool path information: $ap)"
  specfile="$ap/../../data/$specfilename"
  tvedsc="$ap/./$tvedsc_base.pl"
else
  echo "Note: Running $0 using F4DE_BASE ($F4DE_BASE) as base location" 
  specfile="${F4DE_BASE}/lib/data/$specfilename"
  tvedsc="${F4DE_BASE}/bin/$tvedsc_base"
fi

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
