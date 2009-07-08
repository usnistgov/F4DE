#!/bin/bash

specfilename="AVSS09-SubmissionChecker_conf.perl"
avsssc_base="AVSS-SubmissionChecker"

echo "[$0]"
# Im which mode are running
if [ -z ${F4DE_BASE:-} ]; then
  echo "Warning: Needs to run from the directory where $avsssc_base.pl is"
  specfile="../../data/$specfilename"
  avsssc="./$avsssc_base.pl"
else
  echo "Note: Running $0 using F4DE_BASE ($F4DE_BASE) as base location" 
  specfile="${F4DE_BASE}/lib/data/$specfilename"
  avsssc="${F4DE_BASE}/bin/$avsssc_base"
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
