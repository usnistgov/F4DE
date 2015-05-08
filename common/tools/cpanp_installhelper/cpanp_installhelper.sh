#!/bin/bash
#
# $Id$
#

usage()
{
cat <<EOF
Usage: $0 Some::Module

The tool will check if a perl package is installed and if it is not, will install it, following dependencies.

Please not it will check for the perl version that is first available in your path

PREREQUISITE: The tool require the \'cpanp\' tool to be installed and configured.

EOF
}

if  [ $# != 1 ]; then
  usage
  exit 1
fi

package=$1

tool_dir=`perl -e 'use Cwd "abs_path"; use File::Basename "dirname";  $dir = dirname(abs_path($ARGV[0])); print $dir' $0`

installed=`perl -I$tool_dir/../../lib -e 'use MMisc;if (MMisc::check_package($ARGV[0])) { print "present" } else { print "missing" };' $package`

# Already installed just exit
if [ "A$installed" == "Apresent" ]; then
  exit 0
fi
# Not installed, try to install (we will check exit status of the cpanp command)
cpanp -i $package
