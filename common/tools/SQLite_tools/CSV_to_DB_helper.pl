#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# CSV to SQLite Helper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CSV_to_DB_helper" is an experimental system.
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
my $versionid = "CSV to SQLite Helper ($versionkey)";

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

my $mancmd = "perldoc -F $0";

my ($sqlite_cfg_helper, $sqlite_tables_creator, $sqlite_load_csv)=
  ( "SQLite_cfg_helper", "SQLite_tables_creator", "SQLite_load_csv" ); 
my $mdDBb    = "csvDB";

my $usage = &set_usage();

my ($err, $sqlitecmd) = MtSQLite::get_sqlitecmd();
MMisc::error_quit($err)
  if (MMisc::is_blank($sqlitecmd));

my $outdir = "";

my $doCfg = 1;
my $createDBs = 1;

my $wmdCFfile  = '';
my $wmdDBfile  = '';

my $quickConfig = undef;
my $nullmode = 0;

my $debug = 0;
my $sp_md_constr  = undef;


my %opt = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   CD        MN       V      cd   h    m o q    v      #

GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'outdir=s'      => \$outdir,
   'configSkip'    => sub {$doCfg = 0},
   'CreateDBSkip'  => sub {$createDBs = 0},
   'MDBfile|DBfile=s'      => \$wmdDBfile, # to keep old option available
   'Vcfg=s'        => \$wmdCFfile,
   'quickConfig:i' => sub {$quickConfig = (defined $_[1]) ? $_[1] : 0;},
   'NULLfields'    => sub {$nullmode = 1;},
   'defaultName=s' => \$mdDBb,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("Nothing to do since \'configSkip\' and '\CreateDBSkip\' are both selected, aborting")
  if ((! $doCfg) && (! $createDBs));

my @csvlist = @ARGV;

my $err = MMisc::check_dir_w($outdir);
MMisc::error_quit("Problem with output directory ($outdir): $err\n$usage\n")
  if (! MMisc::is_blank($err));

my $logdir = "$outdir/_logs";
MMisc::error_quit("Could not create log dir ($logdir)")
  if (! MMisc::make_dir($logdir));

my $mdDBbase = "$outdir/$mdDBb";
my $mdDBcfg  = (MMisc::is_blank($wmdCFfile)) ? "$mdDBbase.cfg" : $wmdCFfile;
my $mdDBfile = (MMisc::is_blank($wmdDBfile)) ? "$mdDBbase.db" : $wmdDBfile;


if ($doCfg) {
  print "***** Generating config files\n";
  my $done = 0;
      
  if (scalar @csvlist > 0) {
    print "** In progress\n";
    my $tmp = &do_cfgfile
      ($mdDBcfg, 1, "$logdir/CfgGen_${mdDBb}.log", 
       "-c ${mdDBbase}_columninfo.txt -t ${mdDBbase}_tableinfo.txt", 
       @csvlist);
    $done++;
    print " -> $mdDBcfg\n";
  } else {
    MMisc::error_quit("No CVS file list given, no DB file will be generated");
  }


  print "-> $done config file generated\n";
}

if ($createDBs) {
  print "***** Creating initial DataBases (if not already present)\n";
  my $done = 0;
  
  if (MMisc::does_file_exist($mdDBcfg)) {
    print "** In progress\n";
    &db_create($mdDBcfg, 1, $mdDBfile, "$logdir/DBgen_${mdDBb}.log");
    $done++;
    print " -> $mdDBfile\n";
  } else {
    MMisc::error_quit("Could not find configuration file ($mdDBcfg) ?");
  }

  
  print "-> $done DB file generated\n";
}

MMisc::ok_quit("Done");

########################################

sub do_cfgfile {
  my ($cfgfile, $nullok, $log, $cmdadd, @csvfl) = @_;

  my $tool = &path_tool($sqlite_cfg_helper, "$f4d/../../../common/tools/SQLite_tools");

  if (defined $quickConfig) {
    $cmdadd .= " -q";
    $cmdadd .= " $quickConfig" if ($quickConfig > 0);
  }

  $cmdadd .= " -N" if (($nullok) && ($nullmode));

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, $cmdadd, @csvfl);

  MMisc::error_quit("Problem writing config file ($cfgfile)")
    if (! MMisc::writeTo($cfgfile, "", 0, 0, $so));

  return($so);
}

##########

sub db_create {
  my ($cfgfile, $nullok, $dbfile, $log) = @_;

  if (MMisc::does_file_exist($dbfile)) {
    print " -> DB file already exists, not overwriting it\n";
    return();
  }

  my $err = MMisc::check_file_r($cfgfile);
  MMisc::error_quit("Problem with config file ($cfgfile): $err")
    if (! MMisc::is_blank($err));

  my $tool = &path_tool($sqlite_tables_creator, "$f4d/../../../common/tools/SQLite_tools");
  my $tool2 = &path_tool($sqlite_load_csv, "$f4d/../../../common/tools/SQLite_tools");

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    &run_tool($log, $tool, 
              "-l" . (MMisc::is_blank($tool2) ? "" : " -L $tool2") 
              . (($nullok && $nullmode) ? " -N" : "")
              . " $dbfile $cfgfile");
}

##########

sub path_tool {
  my ($toolb, $relpath) = @_;
  my $tool = "$f4d/${toolb}.pl";
  &check_tool($tool, $toolb);
  return($tool);
}

#####

sub check_tool {
  my ($tool, $toolb) = @_;
  if (MMisc::is_blank($tool)) { # last chance, is it in PATH ?
    $tool = MMisc::cmd_which($toolb);
  }

  MMisc::error_quit("No location found for tool ($toolb)")
    if (MMisc::is_blank($tool));

  my $err = MMisc::check_file_x($tool);
  MMisc::error_quit("Problem with tool ($tool): $err")
    if (! MMisc::is_blank($err));
}

#####

sub run_tool {
  my ($lf, $tool, @cmds) = @_;

  $lf = MMisc::get_tmpfile() if (MMisc::is_blank($lf));

  my ($ok, $otxt, $so, $se, $rc, $of) = 
    MMisc::write_syscall_smart_logfile($lf, $tool, @cmds); 
  if ((! $ok) || ($rc != 0)) {
    my $lfc = MMisc::slurp_file($of);
    MMisc::error_quit("There was a problem running the tool ($tool) command\n  Run log (located at: $of) content: $lfc\n\n");
  }

  return($ok, $otxt, $so, $se, $rc, $of);
}


#####

sub extend_file_location {
  my ($rf, $t, @pt) = @_;

  return if (MMisc::is_blank($$rf));
  return if (MMisc::does_file_exist($$rf));

  foreach my $p (@pt) {
    my $v = "$p/$$rf";
    if (MMisc::does_file_exist($v)) {
      $$rf = $v;
      return();
    }
  }

  MMisc::error_quit("Could not find \'$t\' file ($$rf) in any of the expected paths: " . join(" ", @pt));
}

##

sub __constraints_placement {
  my ($t, $ra, %__constraints) = @_;
  my @in = @$ra;
  my @out = ();
  foreach my $td (@in) {
    foreach my $ck (keys %__constraints) {
      if ($td =~ m%^([^\:]+?\:$ck)(\%.+)?$%) {
        $td = "$1\%" . $__constraints{$ck};
        delete $__constraints{$ck};
      }
    }
    push @out, $td;
  }
  MMisc::error_quit("Problem with \'$t\', could not find/apply following rules : " . join(" ", keys %__constraints))
      if (scalar(keys %__constraints) > 0);
  return(@out);
}

##

sub apply_constraints {
  my ($fn, $ra, $t, @pf) = @_;

  return(@$ra) if (MMisc::is_blank($fn));
  &extend_file_location(\$fn, $t, @pf);
  my $tmp = MMisc::load_memory_object($fn);
  MMisc::error_quit("Problem with \'$t\' configuration file'ss data ($fn)")
    if (! defined $tmp);
  MMisc::error_quit("Problem with \'$t\' configuration file's data ($fn) : not a hash ?")
    if (ref($tmp) ne 'HASH');

  return(&__constraints_placement($t, $ra, %$tmp));
}

############################################################ Manual

=pod

=head1 NAME

CSV_to_DB_helper - Comma Separated Values files to SQLite tables helper

=head1 SYNOPSIS

B<CSV_to_DB_helper> 
  S<[B<--help> | B<--man> | B<--version>]>
  S<B<--outdir> I<dir>>
  S<[B<--configSkip>] [B<--CreateDBSkip>]>
  S<[B<--quickConfig> [I<linecount>]] [B<--NULLfields>]>
  S<[B<--Vcfg> I<file>]>
  S<[B<--MDBfile> I<file>]>
  S<[I<csvfile>[I<:tablename>][I<%columnname:constraint>[...]] [I<csvfile>[...] [...]]]>


=head1 DESCRIPTION

B<CSV_to_DB_helper> is a wrapper script for reading a set of comma
separated value (CSV) input data files and providing corresponding SQLite database tables. 

The wrapper performs two steps to complete its process.
The USAGE section describes the process with an example.

=over  

=item Step 1: Scheme configuration generation

Required arguments:
 S<B<--outdir> I<dir>>

Optional arguments:
 S<[B<--quickConfig> [I<linecount>]]>
 S<[B<--NULLfields>]>
 S<[B<--Vcfg> I<file>]>
 S<[I<csvfile>[...] [I<csvfile>[...] [...]]]>

Bypass step:
 S<[B<--configSkip>]>

=item Step 2: SQL table creation and populating

Required arguments:
 S<B<--outdir> I<dir>>

Optional arguments:
 S<[B<--NULLfields>]>
 S<[B<--Vcfg> I<file>]>
 S<[B<--MDBfile> I<file>]>

Bypass step: 
 S<[B<--CreateDBSkip>]>

=back


=head1 INPUT FILES

=head2 CSV files

To generate the multiple tables for the SQLite database, we rely on I<Comma Separated Values> (CSV) to contain the data to be processed.
The CSV file names will be used as SQL table name, and must have as a first row the column headers that will be used as the SQL table column names.
To avoid issues in processing the data, it is recommended that each column content be quoted and comma separated. For example, a table whose SQL table name is expected to be "Employee" will be represented as the "Employee.csv" file and contain a first row: S<"ID","FirstName","LastName"> and an exemplar entry could be: S<"1","John","Doe">

The program leave the content of the database free for most content. 

Examples of CSV files can be found in the F4DE source in:
 F<DEVA/common/test/common/ref.csv>
 F<DEVA/common/test/common/sys.csv>
 F<DEVA/common/test/common/md.csv>

When possible (and detailed in the usage), an extended command line definition for CSV files can be specified and allow to define more details for the file' content:

S<[I<csvfile>[I<:tablename>][I<%columnname:constraint>[...]]>

Here in addition to specify the CSV file name, the default SQL table name can be overridden by I<tablename>.
Also in the definition, SQLite I<Constraints> can be applied to given columns within the table.
For example: S<expid.detection.csv:detection%Score:'CHECK(ScoreE<gt>=0.0 AND Score E<lt>=1.0)'%EventID:UNIQUE>
specifies that for the S<expid.detection.csv> CSV file, force its SQLite table name to S<detection> (the default would be have been to use S<expid_detection> following the I<entry remaining rule> defined in the next section) and will enforce that values within its S<Score> column can only be added if they are between 0 and 1. Also, the table's S<EventID> must be I<unique>.

=head2 Configuration files

Configuration files are generated by Step 1.

A configuration file structure specify a corresponding I<SQLite> S<CREATE TABLE> but is human readable and composed of simple one line definitions:

=over

=item S<newtable: tablename>

Starts the definition of a new table and specify the table name as I<tablename> (must be the first line for each new table definition). Note that this step tries to infer the I<tablename> from the I<csvfile>'s I<filename>.

=item S<csvfile: location>

Specify the full path I<location> of the CSV file to load. If I<location> is of the form S<path/filename.suffix>, the default --unless it is overridden by the user or for specific tables (such as I<Reference> and I<System>)-- is to use I<filename> as the I<tablename>.

An I<entry renaming rule> apply to all I<tablename> and I<columnUsedName> so that any character other than S<a> to S<z>, S<A> to S<Z>, S<0> to S<9> and S<_> are replaced by S<_>. In addition, if a I<location> has multiple I<suffix> entries, only the last one if removed.
Therefore, f I<location> if of the form S<filename.suffix1.suffix>, the default corresponding I<tablename> would be S<filename_suffix1>.

Note that the I<path> is the exact same as specified on the command line for the corresponding CSV file (if the specified CSV file is S<../test.csv>, the I<location> will be S<../test.csv> too) it is therefore important to run the tools from the same location when creating the configuration file and its database creation.

=item S<column: columnUsedName;columnType:columnConstraint>

Specify a column seen in the CSV file, each column seen has to be detailed this way and the order in the configuration file as to match to column order in the CSV file. If a CSV file has I<X> columns, the configuration file must have I<X> S<column:> definitions.

S<column*:> specify that the column is the table's primary key. A given table can only have one primary key.

S<columnUsedName> specify the column name as it can be accessed from its I<tablename> within I<SQLite>. If a column has a name to which the I<entry renaming rule> applies, S<column:> gets redefined as S<column: columnName=columnUsedName;columnType>, where S<columnName> is the original column name. For example if the original column name is
 S<name.has;to:fixed> (of I<TEXT> S<columnType>)
, the S<column:> definition will read
 S<column: name.has;to:fixed=name_has_to_fixed;TEXT>

S<columnType> is one of S<INT>, S<REAL> or S<TEXT>.

S<columnConstraint> is optional and specify a SQLite constraint (S<CHECK>, S<UNIQUE>, ...).
Warning: S<PRIMARY KEY> should not be used as a column constraint, as it is defined using the S<column*:> syntax.

=back

Examples of configuration files can be found in the F4DE source in:
 F<DEVA/common/test/common/ref1.cfg>
 F<DEVA/common/test/common/sys2.cfg>
 F<DEVA/common/test/common/md2.cfg>
 F<DEVA/common/test/common/mix2.cfg>

=head1 PREREQUISITES

B<CSV_to_DB_helper> relies on some external software and files.

=over

=item B<SOFTWARE> 

I<sqlite3> (S<http://www.sqlite.org/>) is required (at least version 3.6.12) to perform all the SQL work.

=item B<GLOBAL ENVIRONMENT VARIABLE>

Once you have installed the software, extending your B<PATH> environment variable to include F4DE's B</bin> directory should be sufficient for the tools to find their components.

=back

=head1 OPTIONS

=over

=item B<--CreateDBSkip>

Skip the database and tables generation.

This step uses the files created in the configuration generation step and generate multiple SQLite databases containing the tables specified in their respective configuration files.

Files created during this step would be S<outdir/referenceDB.sql>, S<outdir/systemDB.sql> and S<outdir/metadataDB.sql>

=item B<--configSkip>

Skip the generation of the configuration files required for the generation of the database tables.

This process read each CSV file, determine the tables name, columns names and types and write them in S<outdir/metadataDB.cfg>.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--MDBfile> I<file>

Specify the location of the database file to generate.

=item B<--man>

Display this man page.

=item B<--NULLfields>

Empty columns will be inserted as the NULL value to allow proper JOIN (the default is to insert them as the empty value of the defined type, ie '' for TEXTs). This behavior only apply to metadata CSV files.

=item B<--outdir> I<dir>

Specify the directory in which all files relevant to this call to B<DEVA_cli> will be placed (or looked for).

=item B<--quickConfig> [I<linecount>]

Specify the number of lines to be read in Step 1 to decide on file content for config helper step (without quickConfig, process all lines)

=item B<--Vcfg> I<file>

Specify the metadata configuration file

=item B<--version>

Display the B<DEVA_cli> version information.

=back

=head1 USAGE

B<CSV_to_DB_helper --outdir outdir md.csv>

This will process the two steps expected of the command line interface:

=over

=item Step 1 (uses B<SQLite_cfg_helper>)

Will use I<md.csv> as the one CSV file (multiple CSV can be used, we only use one in this example).

From those files, the first step will generate the database creation configuration files by loading each rows and columns in the CSV to determine their SQLite type, and determine if the column header name has to be adapted to avoid characters not recognized by SQLite. 

Please note that it is the user's responsibility to provide properly formatted CSV files with the expected columns.

This process will create the I<outdir/csvDB.cfg> files. Note that the location of the CSV files is embedded within the config file. 

This step also create I<outdir/csvDB_columninfo.txt> and I<outdir/csvDB_tableinfo.txt>, which contain details on the relationship between columns and tables that will compose the database. 

=item Step 2 (uses B<SQLite_tables_creator>)

The next step will use those configuration files to create SQLite database files containing as many tables as CSV files (here only one) are added to <outdir/csvDB.db> loaded from the CSV file list provided (here only I<md.csv>).

=back

=back

=head1 Notes

=over

=item Logdirs

A I<outdir/_logs> is created and populated by each step, so that files starting with I<CfgGen_> and I<DBgen_> are generated respectively during Step 1 and 2.

In case a file of the expected name is already present, a tag consisting of S<-YYYYMMDD-HHMMSS> (year, month, day, hour, minute, seconds) will be added to the newly created log file.

=back

=head1 RELATED TOOLS

The script will work with the following tools (lookup their help page for more details):

=over

=item B<SQLite_cfg_helper> 

=item B<SQLite_tables_creator> (and B<SQLite_load_csv>)

=head1 NFS NOTE

When running teh tool on an NFS located database file (some files generated in the S<--outdir> for example), performance loss might happen, this is due to the I<journal> file for SQLite that is stored to the same directory as the original database file and write all the data to be committed to the main database when a SQLite transaction is complete. For optimal speed, it is recommended to try to avoid using NFS located database file in favor a copy on the local disk. 

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

##########

sub set_usage {

  my $tmp=<<EOF
$versionid

$0 [--help | --man | --version] --outdir dir [--defaultName name] [--configSkip] [--Vcfg file] [--quickConfig [linecount]] [--CreateDBSkip] [--NULLfields] [--DBfile file] [csvfile[:tablename][\%columnname:constraint[...]] [csvfile[...] [...]]] 

Wrapper designed to help using one or muliptle CSV files and insert them as tables in a SQLite DB file 
Arguments left on the command line are csvfile used to create the metadataDB

NOTE: will create _logs directory in outdir

Where:
  --help          This help message
  --version       Version information
  --outdir        Specify the directory where are all the steps are being processed
  --defaultName   The default base name for files created under \'outdir\' (default: $mdDBb)
  --configSkip    Bypass csv config helper step
  --Vcfg          Specify the configuration file location
  --quickConfig   Specify the number of lines to be read in Step 1 to decide on file content for config helper step (wihtout quickConfig, process all lines) (*1) (default: 'outdir'/'defaultName'.cfg)
  --CreateDBSkip  Bypasss Databases creation step
  --NULLfields    Empty columns will be inserted as the NULL value (the default is to insert them as the empty value of the defined type, ie '' for TEXTs). This behavior only apply to metadata CSV files.
  --DBfile        Specify the SQLite output database file location (default: 'outdir'/'defaultName'.db)

*1: default number of lines if no value is set can be obtained from \"$sqlite_cfg_helper\" 's help

WARNING: There can be only one 'PRIMARY KEY' per table, which is an autoincremental integer for tables. If you want to insure that all data are unique in a column, use a 'UNIQUE' constraint.

EOF
;

  return($tmp);
}

