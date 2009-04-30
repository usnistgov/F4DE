#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# AVSS09 Scorer
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "AVSS09 Submission Checker" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "AVSS09 Scorer Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $avpl, $avplv, $clearpl, $clearplv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = (defined $ENV{$f4b}) ? $ENV{$f4b} . "/lib": "/lib";
  $avpl = "AVSS09_PERL_LIB";
  $avplv = $ENV{$avpl} || "../../lib";
  $clearpl = "CLEAR_PERL_LIB";
  $clearplv = $ENV{$clearpl} || "../../../CLEAR07/lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($avplv, $clearplv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $avpl, $clearpl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
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

my $xmllint_env = "CLEAR_XMLLINT";
my $xsdpath_env = "CLEAR_XSDPATH";
my $mancmd = "perldoc -F $0";
my $frameTol = 0;
my $valtool_bt = "AVSS09ViperValidator";
my $scrtool_bt = "CLEARDTScorer";
my @ok_md = ("gzip", "text"); # Default is gzip / order is important
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../../CLEAR07/data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../../CLEAR07/data"));
my $gtfs = 0;
my $verb = 1;
my $valtool = "";
my $scrtool = "";
my $destdir = "";

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:   C               S  V         f          q    vwx   #

my %opt = ();
my @leftover = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'quiet'           => sub {$verb = 0},
   'writedir=s'      => \$destdir,
   'xmllint=s'       => \$xmllint,
   'CLEARxsd=s'      => \$xsdpath,
   'gtf'             => sub {$gtfs++; @leftover = @ARGV},
   'frameTol=i'      => \$frameTol,
   'Validator=s'     => \$valtool,
   'Scorer=s'        => \$scrtool,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("No \'writedir\' given, aborting\n\n$usage\n")
  if (MMisc::is_blank($destdir));

# Val tool
if (MMisc::is_blank($valtool)) {
  my @ok_tools = ();
  if (defined $ENV{$f4b}) {
    push @ok_tools, $ENV{$f4b} . "/bin/$valtool_bt";
  }
  push @ok_tools, "./$valtool_bt";
  push @ok_tools, "./$valtool_bt.pl";
  push @ok_tools, "../$valtool_bt/$valtool_bt.pl";
  foreach my $t (@ok_tools) {
    next if (! MMisc::is_blank($valtool));
    next if (! MMisc::is_file_x($t));
    $valtool = $t;
  }
}
MMisc::error_quit("No \'$valtool_bt\' provided/found\n\n$usage\n")
  if (MMisc::is_blank($valtool));
my $err = MMisc::check_file_x($valtool);
MMisc::error_quit("Problem with \'$valtool_bt\' [$valtool]: $err\n\n$usage\n")
  if (! MMisc::is_blank($err));

# Scr tool
if (MMisc::is_blank($scrtool)) {
  my @ok_tools = ();
  if (defined $ENV{$f4b}) {
    push @ok_tools, $ENV{$f4b} . "/bin/$scrtool_bt";
  }
  push @ok_tools, "./$scrtool_bt";
  push @ok_tools, "./$scrtool_bt.pl";
  push @ok_tools, "../../../CLEAR07/tools/$scrtool_bt/$scrtool_bt.pl";
  foreach my $t (@ok_tools) {
    next if (! MMisc::is_blank($scrtool));
    next if (! MMisc::is_file_x($t));
    $scrtool = $t;
  }
}
MMisc::error_quit("No \'$scrtool_bt\' provided/found\n\n$usage\n")
  if (MMisc::is_blank($scrtool));
my $err = MMisc::check_file_x($scrtool);
MMisc::error_quit("Problem with \'$scrtool_bt\' [$scrtool]: $err\n\n$usage\n")
  if (! MMisc::is_blank($err));

MMisc::error_quit("Only one \'gtf\' separator allowed per command line, aborting\n\n$usage\n")
  if ($gtfs > 1);

my ($rref, $rsys) = &get_sys_ref_filelist(\@leftover, @ARGV);
my @ref = @{$rref};
my @sys = @{$rsys};
MMisc::error_quit("No SYS file(s) provided, can not perform scoring\n\n$usage\n")
  if (scalar @sys == 0);
MMisc::error_quit("No REF file(s) provided, can not perform scoring\n\n$usage\n")
  if (scalar @ref == 0);
MMisc::error_quit("Unequal number of REF and SYS files, can not perform scoring\n\n$usage\n")
  if (scalar @ref != scalar @sys);


my $svfmd = "VFmemdump";
my $sssmd = "SSmemdump";
########## Main processing
my $stepc = 1;

#####
print "\n\n***** STEP ", $stepc++, ": Validation\n";
## Create the needed directory
my $err = MMisc::check_dir_w($destdir);
MMisc::error_quit("Can not write in \'writedir\' ($destdir): $err")
  if (! MMisc::is_blank($err));
my $val_dir = "01-Validation";
my $td = "$destdir/$val_dir";
MMisc::error_quit("Could not create Validation directory ($td)")
  if (! MMisc::make_dir($td));

my (%sys_hash) = &load_preprocessing(0, "$td/01-SYS", @sys);
my (%ref_hash) = &load_preprocessing(1, "$td/00-GTF", @ref);

#####
print "\n\n***** STEP ", $stepc++, ": Scoring\n";
## Create the needed directories
my $scr_dir = "02-Scoring";
my $td = "$destdir/$scr_dir";
MMisc::error_quit("Could not create scoring directory ($td)")
  if (! MMisc::make_dir($td));

my @sysscrf = keys %{$sys_hash{$sssmd}};
my @refscrf = keys %{$ref_hash{$sssmd}};
my ($scores, $logfile) = &do_scoring($td, \@sysscrf, \@refscrf);

print "\n\n**** Scoring results:\n-- Beg ----------\n$scores\n-- End ----------\n";
print "For more details, see: $logfile\n";

MMisc::ok_quit("\n\n***** Done *****\n");

########## END
########################################

sub load_preprocessing {
  my ($isgtf, $ddir, @filelist) = @_;

  print "** Validating and Generating ", ($isgtf) ? "GTF" : "SYS", " Sequence MemDump\n";

  my %all = ();
  while (my $tmp = shift @filelist) {
    print "- Working on ",  ($isgtf) ? "GTF" : "SYS", " file: $tmp\n";

    my $err = MMisc::check_file_r($tmp);
    MMisc::error_quit("Problem with file ($tmp): $err")
        if (! MMisc::is_blank($err));

    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($tmp);
    MMisc::error_quit("Problem spliting filename ($tmp): $err")
        if (! MMisc::is_blank($err));

    my $td = "$ddir/$file";
    MMisc::error_quit("Output directory already exists ($td)")
        if (-d $td);
    MMisc::error_quit("Problem creating output directory ($td)")
        if (! MMisc::make_dir($td));

    my $logfile = "$td/$file.log";

    my $command = $valtool;
    $command .= " --gtf" if ($isgtf);
    $command .= " --xmllint $xmllint" if ($opt{'xmllint'});
    $command .= " --CLEARxsd $xsdpath" if ($opt{'xsdpath'});
    $command .= " --frameTol $frameTol" if ($opt{'frameTol'});
    $command .= " --write $td --WriteMemDump gzip";
    $command .= " \"$tmp\"";

    my ($ok, $otxt, $stdout, $stderr, $retcode, $ofile) = 
      MMisc::write_syscall_smart_logfile($logfile, $command);

    MMisc::error_quit("Problem during validation:\n" . $stderr . "\nFor details, see $ofile\n")
        if ($retcode != 0);

    my $file = "$td/$file.$ext";
    my $err = MMisc::check_file_r($file);
    MMisc::error_quit("Can not find output ViperFile [$file]")
        if (! MMisc::is_blank($err));

    my $vfmd = "$file.$svfmd";
    my $err = MMisc::check_file_r($vfmd);
    MMisc::error_quit("Can not find ViperFile MemDump file [$vfmd]")
        if (! MMisc::is_blank($err));
    $all{$svfmd}{$vfmd} = $tmp;

    my $ssmd = "$file.$sssmd";
    my $err = MMisc::check_file_r($ssmd);
    MMisc::error_quit("Can not find Sequence MemDump file [$ssmd]")
        if (! MMisc::is_blank($err));
    $all{$sssmd}{$ssmd} = $tmp;
  }

  return(%all);
}

##########

sub do_scoring {
  my ($td, $rsysf, $rgtff) = @_;

  my $logfile = "$td/scoring.log";
  
  my $cmd = "";
  if (! defined $ENV{$f4b}) { 
    $cmd .= "perl ";
    foreach my $j ("../../../CLEAR07/lib", "../../../common/lib") {
      my $i = MMisc::get_file_full_path($j);
      $cmd .= " -I$i" if (MMisc::is_dir_r($i));
    }
    $cmd .= " ";
  }

  $cmd .= $scrtool;
  $cmd .= " --xmllint $xmllint" if ($opt{'xmllint'});
  $cmd .= " --CLEARxsd $xsdpath" if (($opt{'xsdpath'}) || (! defined $ENV{$f4b}));
  $cmd .= " --frameTol $frameTol" if ($opt{'frameTol'});
  $cmd .= " --Domain SV";
  $cmd .= " --Eval Area";

  my @command = ();
  push @command, $cmd;
  push @command, @$rsysf;
  push @command, "--gtf";
  push @command, @$rgtff;

  my ($ok, $otxt, $stdout, $stderr, $retcode, $ofile) = 
    MMisc::write_syscall_smart_logfile($logfile, @command);

  MMisc::error_quit("Problem during scoring:\n" . $stderr . "\nFor details, see $ofile\n")
      if ($retcode != 0);

  return($stdout, $ofile);
}

##########

sub get_sys_ref_filelist {
  my $rlo = shift @_;
  my @args = @_;

  my @lo = @{$rlo};

  @args = reverse @args;
  @lo = reverse @lo;

  my @ref = ();
  my @sys = ();
  while (my $l = shift @lo) {
    if ($l eq $args[0]) {
      push @ref, $l;
      shift @args;
    }
  }
  @ref = reverse @ref;
  @sys = reverse @args;

  return(\@ref, \@sys);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

############################################################ Manual

=pod

=head1 NAME

AVSS09Scorer - AVSS09 ViPER XML System to Reference Scoring Tool

=head1 SYNOPSIS

B<AVSS09Scorer> S<[ B<--help> | B<--man> | B<--version> ]>
  S<[B<--xmllint> I<location>] [B<--CLEARxsd> I<location>]>
  S<B<--writedir> directory [B<--frameTol> I<framenbr>]>
  S<[B<--Validator> I<tool>] [B<--Scorer> I<tool>]>
  S<I<sys_file.xml> [I<...>] B<--gtf> I<ref_file.xml> [I<...>]>
  
=head1 DESCRIPTION

B<AVSS09Scorer> is a wrapper tool for the I<AVSS09ViperValidator> and I<CLEARDTScorer> tools.
The first one performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line.
The second perform the actual scoring on the I<Scoring Sequence memory representation> of the I<system> and I<reference> XML files.

=head1 PREREQUISITES

B<AVSS09scorer>'s tools relies on some external software and files, most of which associated with the B<CLEAR> section of B<F4DE>.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<CLEAR_XMLLINT> environment variable.

=item B<FILES>

The syntactic validation requires some XML schema files (see the B<CLEARDTScorer> help section for file list).
It is possible to specify their location using the B<--xsdpath> option or the B<CLEAR_XSDPATH> environment variable.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

B<AVSS09scorer>'s tools relies on some internal and external Perl libraries to function.

Simply running both the B<AVSS09ViperValidator> and B<CLEARDTScorer> script should provide you with the list of missing libraries. 
The following environment variables should be set in order for Perl to use the B<F4DE> libraries:

=over

=item B<F4DE_BASE>

The main variable once you have installed the software, it should be sufficient to run this program.

=item B<F4DE_PERL_LIB>

Allows you to specify a different directory for the B<F4DE> libraries.

=item B<AVSS09_PERL_LIB>

Allows you to specify a different directory for the B<AVSS09> libraries.

=item B<CLEAR_PERL_LIB>

Allows you to specify a different directory for the B<CLEAR> libraries.

=back

=back

=head1 GENERAL NOTES

B<AVSS09ViperValidator> expects that the files can be validated using 'xmllint' against the B<CLEAR> XSD file(s) (see B<--help> for files list).

B<AVSS09ViperValidator> will use the core validation of the B<CLEAR> code and add some specialized checks associated with the B<AVSS09> evaluation.

The B<CLEARDTScorer> will load I<Scoring Sequence memory represenations> generated by the validation process.

=head1 OPTIONS

=over

=item B<--CLEARxsd> I<location>

Specify the default location of the required XSD files.
Can also be set using the B<CLEAR_XSDPATH> environment variable.

=item B<--frameTol> I<framenbr>

The frame tolerance allowed for attributes to be outside of the object framespan

=item B<--gtf>

Specify that the files past this marker are reference files.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--man>

Display this man page.

=item B<--Scorer> I<tool>

Specify the full path location of the B<CLEARDTScorer> program

=item B<--Validator> I<tool>

Specify the full path location of the B<AVSS09ViperValidator> program

=item B<--version>

Display B<AVSS09ViperValidator> version information.

=item B<--writedir> I<directory>

Specify the I<directory> in which all files required for the validation and scoring process will be generated.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<CLEAR_XMLLINT> environment variable.

=back

=head1 USAGE

=item B<AVSS09Scorer --xmllint /local/bin/xmllint --TrecVid08xsd /local/F4DE-CVS/data --writedir /tmp --frameTol 5 sys_test1.xml sys_test2.xml --gtf ref_test1.xml ref_test2.xml>

Using the I<xmllint> executable located at I</local/bin/xmllint>, with the required XSD files found in the I</local/F4DE/data> directory, putting all generated files in I</tmp>, and using a frame tolerance of 5 frames, it will use:

=over

=item B<AVSS09ViperValidator> to validate the I<system> files I<sys_test1.xml> and I<sys_test2.xml> as well as the I<reference> files I<ref_test1.xml> and I<ref_test2.xml>.
The validator will also generate a I<Scoring Sequence memory represenation> of all those files.

=item B<CLEARDTScorer> to perform scoring on the I<Scoring Sequence memory represenation> files present.

=back

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=cut

########################################

sub set_usage {
  my $wmd = join(" ", @ok_md);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --man | --version] [--xmllint location] [--CLEARxsd location] --writedir directory [--frameTol framenbr] [--Validator tool] [--Scorer tool] sys_file.xml [sys_file.xml [...]] --gtf ref_file.xml [ref_file.xml [...]]

Will call the AVSS09 Validation and CLEAR Scorer tools on the XML file(s) provided (System vs Reference)

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --CLEARxsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --frameTol      The frame tolerance allowed for attributes to be outside of the object framespan (default: $frameTol)
  --writedir      Directory in which validation and scoring will be performed
  --Validator     Specify the full path location of the $valtool_bt tool (if not in your path)
  --Scorer        Specify the full path location of the $scrtool_bt tool (if not in your path)

Note:
- This prerequisite that the file can be been validated using 'xmllint' against the 'CLEAR.xsd' file
- Program will ignore the <config> section of the XML file.
- Program will disard any xml comment(s).
- 'CLEARxsd' files are the same as needed by CLEARDTViperValidator
EOF
;

  return $tmp;
}
