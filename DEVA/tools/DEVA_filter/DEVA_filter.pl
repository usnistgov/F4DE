#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# DEVA Filter
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "DEVA_filter" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }

  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "MtSQLite") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "DEVA Filter ($versionkey)";

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Options processing

# Default values for variables
#
my $mdDBfile = "";
my $mdDBname = "metadataDB";
#
my $refDBfile = "";
my $refDBname = "referenceDB";
#
my $sysDBfile = "";
my $sysDBname = "systemDB";
#
my $tablename = "resultsTable";
my $TrialIDcolumn = "TrialID";
my $BlockIDcolumn = "BlockID";
#
my $filtercmd = "";
my $filtercmdfile = "";
my $blockIDname = $BlockIDcolumn;

my @addDBs = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:  B   F                    a    f h    m    rs  v      #

my $usage = &set_usage();

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'metadataDBfile=s'  => \$mdDBfile,
   'referenceDBfile=s' => \$refDBfile,
   'systemDBfile=s'    => \$sysDBfile,
   'filterCMD=s'       => \$filtercmd,
   'FilterCMDfile=s'   => \$filtercmdfile,
   'additionalDB=s'    => \@addDBs,
   'BlockIDname=s'     => \$blockIDname,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("No resultsDBfile information provided\n\n$usage") 
  if (scalar @ARGV != 1);

MMisc::error_quit("Both \'filterCMD\' and \'FilterCMDfile\' can not be used at the same time")
  if ((! MMisc::is_blank($filtercmd)) && (! MMisc::is_blank($filtercmdfile)));
MMisc::error_quit("One of \'filterCMD\' or \'filterCMDfile\' must be specified")
  if ((MMisc::is_blank($filtercmd)) && (MMisc::is_blank($filtercmdfile)));

if (! MMisc::is_blank($filtercmdfile)) {
  my $err = MMisc::check_file_r($filtercmdfile);
  MMisc::error_quit("Problem with \'FilterCMDfile\' file ($filtercmdfile): $err")
    if (! MMisc::is_blank($err));
}

MMisc::error_quit("The empty value is not authorized for \'BlockIDName\'")
  if (MMisc::is_blank($blockIDname));

my ($dbfile) = @ARGV;

my ($err, $sqlitecmd) = MtSQLite::get_sqlitecmd();
MMisc::error_quit($err)
  if (MMisc::is_blank($sqlitecmd));

my $cmdlines = "";
my @attachedDBs = ("temp"); # forbid use of this one already

&attach_dbfile_as($mdDBfile, $mdDBname, \$cmdlines, \@attachedDBs)
  if (! MMisc::is_blank($mdDBfile));


# Attach the REF and SYS databases
&attach_dbfile_as($refDBfile, $refDBname, \$cmdlines, \@attachedDBs);
&attach_dbfile_as($sysDBfile, $sysDBname, \$cmdlines, \@attachedDBs);

# Attach additional DBs
for (my $i = 0; $i < scalar @addDBs; $i++) {
  my $v = $addDBs[$i];
  my ($file, $name, @rest) = split(m%\:%, $v);
  MMisc::error_quit("Too many values for \'additionalDB\', expected \'file:name\' got more ($v)")
    if (scalar @rest > 0);
  MMisc::error_quit("Missing arguments for \'additionalDB\', expected \'file:name\' (got: $v)")
    if ((MMisc::is_blank($name)) || (MMisc::is_blank($file)));
  &attach_dbfile_as($file, $name, \$cmdlines, \@attachedDBs);
}

# Create the Result table
MtSQLite::commandAdd(\$cmdlines, "DROP TABLE IF EXISTS $tablename");
#MtSQLite::commandAdd(\$cmdlines, "CREATE TABLE $tablename ( $TrialIDcolumn INTEGER PRIMARY KEY )");
# was removed: we need to copy the type of the column instead of forcing it to INTEGER
MtSQLite::commandAdd(\$cmdlines, "CREATE TABLE $tablename AS SELECT $TrialIDcolumn FROM $refDBname.reference WHERE $TrialIDcolumn=\"not a value found here\"");

# Add a new column for the BlockID (string type)
MtSQLite::commandAdd(\$cmdlines, "ALTER TABLE $tablename ADD COLUMN $BlockIDcolumn STRING DEFAULT \'$blockIDname\';");

$filtercmd = MMisc::slurp_file($filtercmdfile)
  if (! MMisc::is_blank($filtercmdfile));

MMisc::error_quit("Empty SQL command ? ($filtercmd)")
  if (MMisc::is_blank($filtercmd));

MtSQLite::commandAdd(\$cmdlines, $filtercmd);

my ($err, $log, $stdout, $stderr) = 
  MtSQLite::sqliteCommands($sqlitecmd, $dbfile, $cmdlines);
MMisc::error_quit($err) if (! MMisc::is_blank($err));

&confirm_table($dbfile);

MMisc::ok_quit("Done");

####################

sub attach_dbfile_as {
  my ($dbfile, $dbname, $rcmd, $rdbl) = @_;

  my $err = MMisc::check_file_r($dbfile);
  MMisc::error_quit("Problem with \'$dbname\' DB file ($dbfile): $err")
    if (! MMisc::is_blank($err));
  my ($fname) = MtSQLite::fix_entries($dbname);
  MMisc::error_quit("Database name \$dbname\' is not properly formatted to use with SQLite (ok form: $fname)")
    if ($fname ne $dbname);
  MMisc::error_quit("Database name ($dbname) is unauthorized or already loaded")
    if (grep(m%^$dbname$%i, @$rdbl));

  MtSQLite::commandAdd($rcmd, "ATTACH DATABASE \"$dbfile\" AS $dbname;");
  push @$rdbl, $dbname;
}

##########

sub confirm_table {
  my ($dbfile) = @_;
  
  my ($err, $tidc) = MtSQLite::select_helper__count_rows($dbfile, $tablename, "", $TrialIDcolumn, $BlockIDcolumn);
  MMisc::error_quit($err) if (! MMisc::is_blank($err));

  MMisc::error_quit("No entry in table, this DB will not be scorable")
    if ($tidc == 0);

  print "* Confirmed that Found $tablename.$TrialIDcolumn contains data (${tidc}x datum)\n";
}

########## 

sub set_usage {  
  my $tmp=<<EOF
$versionid

$0 [--help | --version] --referenceDBfile file --systemDBfile file [--metadataDBfile file] [--additionalDB file:name [--additionalDB file:name [...]]] [--filterCMD \"SQLite COMMAND;\" | --FilterCMDfile SQLite_commands_file] [--BlockIDname name] resultsDBfile 

Will apply provided "INSERT / SELECT" filter from provided databases and will generate in the results database a new table named \'$tablename\' that only contain the \'$TrialIDcolumn\' and \'$BlockIDcolumn\' that will be given to the scoring interface.

Note that filter must be written in the form of a "INSERT ... SELECT" statement such as:

INSERT OR ABORT INTO ResultsTable ( TrialID ) SELECT System.TrialID FROM System INNER JOIN Reference WHERE System.TrialID==Reference.TrialID;

NOTE: if the \"BlockID\" column is not \'SELECT\'-ed as part of the filter, the literal \"$BlockIDcolumn\" will be added (unless overriden by the \"--BlockIDname\" option)

Where:
  --help     This help message
  --version  Version information
  --referenceDBfile  The Reference SQLite file (loaded as '$refDBname', contains the 'Reference' table, whose columns are: TrialID, Targ)
  --systemDBfile     The System SQLite file (loaded as '$sysDBname', contains the 'System' table, whose columns are: TrialID, Decision, Score)
  --metadataDBfile   The metadata SQLite file (loaded as '$mdDBname')
  --additionalDB     Load an additional SQLite database 'file' as 'name'
  --filterCMD        Set of SQLite commands
  --FilterCMDfile    File containing set of SQLite commands
  --BlockIDname      Specify the \"$BlockIDcolumn\" value used if the column is not \'SELECT\'-ed 


EOF
;

  return($tmp);
}

