#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# TrecVid08 Big XML Files Validator Helper
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Big XML Files Validator Helper" is an experimental system.
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
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";

# Part of this tool
foreach my $pn ("TrecVid08ViperFile", "TrecVid08HelperFunctions", "xmllintHelper", "MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "TrecVid08 Big XML Files Validator ($versionkey)";

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

my $xmllint_env = "F4DE_XMLLINT";
my $mancmd = "perldoc -F $0";
my $spc = 200; # Fine tuned on BigTest (on my laptop)
# 50=11s 100=9.97s 150=9.5s 200=9.3s 250=9.3s 300=9.55s 500=10.3s
my $chunks = 16034;

my $mrgtool = "";
my $valtool = "";
$valtool = "$f4d/TV08ViperValidator.pl";
$mrgtool = "$f4d/../TV08MergeHelper/TV08MergeHelper.pl";

my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = "$f4d/../../data";
my $isgtf = 0; # a Ground Truth File is authorized not to have the Decision informations set
my $writedir = undef;
my $fps = undef;
my $verb = 1;
my $copyxmltoo = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:   C         M      T V      c  fgh    m   q s uvwx    #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'gtf'             => \$isgtf,
   'writedir=s'      => \$writedir,
   'fps=s'           => \$fps,
   'splitevery=i'    => \$spc,
   'quiet'           => sub { $verb = 0; },
   'chunks=i'        => \$chunks,
   'ViperValidator=s' => \$valtool,
   'MergerHelper=s'  => \$mrgtool,
   'Copy_xml_too'    => \$copyxmltoo,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::ok_quit("\n$usage\n") if (scalar @ARGV == 0);

MMisc::error_quit("\'writedir\' no specified, aborting")
  if (! defined $writedir);

MMisc::error_quit("\'fps\' no specified, aborting")
  if (! defined $fps);

MMisc::error_quit("\"chunks\" ($chunks) is to be 16Kb at minimum")
  if ($chunks < 16034);

MMisc::error_quit("\"splitevery\" ($spc) is to be 50 at minimum")
  if ($spc < 50);

my $err = MMisc::check_dir_w($writedir);
MMisc::error_quit("Problem with \'writedir\': $err")
  if (! MMisc::is_blank($err));

##########
# Main processing

my $ntodo = scalar @ARGV;
my $ndone = 0;
my $exp_xf = "";
while (my $file = shift @ARGV) {
  print "\n** $file\n";

  my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($file);
  &valerr($file, $err)
    if (! MMisc::is_blank($err));

  $exp_xf = MMisc::concat_dir_file_ext("", $fn, $ext);

  my $bdir = "$writedir/$fn.ValidatorHelper";
  `rm -rf $bdir`
    if (-d $bdir);

  my $stepc = 1;
  
  ##

  print $stepc++, ") XML schema validation of the file\n";

  my $xmldir = "$bdir/00-xmllint_validation";
  MMisc::error_quit("Problem creating directory [$xmldir]")
      if (! MMisc::make_dir($xmldir));

  my $xfile = "$xmldir/" . MMisc::concat_dir_file_ext("", $fn, $ext);
  my $err = &xmllint_file($file, $xfile);
  MMisc::error_quit("Problem during \'xmllint\' step: $err")
    if (! MMisc::is_blank($err));

  ##

  print $stepc++, ") Creating one XML file per $spc events\n";

  my $sfdir = "$bdir/01-Split_files";
  MMisc::error_quit("Problem creating directory [$sfdir]")
      if (! MMisc::make_dir($sfdir));

  my ($err, $tcount, @fl) = &prep_sub_files($sfdir, $xfile);
  if (! MMisc::is_blank($err)) {
    &valerr($file, $err);
    next;
  }
  print " - Created ", scalar @fl, " files [seen $tcount objects]\n";
  if (scalar @fl == 0) {
    print " !! No file created, could be one of two reasons: file contains no entry or file will not validate because it is not XML proper => Copying file to validate\n";
    my ($rc, $so, $se) = MMisc::do_system_call("rsync -a $xfile $sfdir/");
    MMisc::error_quit("Problem while copying [$file] to [$sfdir]")
      if ($rc != 0);
    my ($err, $d, $f, $e) = MMisc::split_dir_file_ext($file);
    MMisc::error_quit("Problem with file name [$file]: $err")
      if (! MMisc::is_blank($err));
    push @fl, MMisc::concat_dir_file_ext("", $f, $e);
  }

  ##

  my $vdir = "$bdir/02-Validation";
  MMisc::error_quit("Problem creating directory [$vdir]")
      if (! MMisc::make_dir($vdir));

  if (scalar @fl == 1) {
    print $stepc++, ") Only one file created, validating source file\n";
    $sfdir = $dir;
    @fl = ();
    push @fl, MMisc::concat_dir_file_ext("", $fn, $ext);
  } else {
    print $stepc++, ") Validating each file\n";
  }

  my ($err, @vfl) = &validate_sub_files($vdir, $sfdir, @fl);
  if (! MMisc::is_blank($err)) {
    &valerr($file, $err);
    next;
  }
  MMisc::error_quit("No Validated file ?")
    if (scalar @vfl == 0);
  print " - Validated ", scalar @vfl, " files\n"
    if (scalar @vfl > 1);

  ##

  my ($vf, $md_vf) = ("", "");
  my $mdir = "$bdir/03-Merging";
  if (scalar @vfl > 1) {
    print $stepc++, ") Merging files into output files\n";

    MMisc::error_quit("Problem creating directory [$mdir]")
      if (! MMisc::make_dir($mdir));
    
    (my $err, $vf, $md_vf) = &merge_val_files($file, $mdir, $vdir, @vfl);
    if (! MMisc::is_blank($err)) {
      &valerr($file, $err);
      next;
    }
    print " - Merged files\n";
  } else {
    print "* Skipping merging step for only 1 validated file *\n";
    $vf = MMisc::concat_dir_file_ext("", $fn, $ext);
    $md_vf = $vf . ".memdump";
    $mdir = $vdir;
  }

  ##

  my $addtxt = ($copyxmltoo) ? " (and rewritten XML file)" : "";
  if (scalar @vfl > 1) {
    print $stepc++, ") Copying merged MemDump file$addtxt\n";
  } else {
    print $stepc++, ") Copying validated MemDump file$addtxt\n";
  }

  my $fvf = "$mdir/$vf";
  my $xf = "$writedir/$exp_xf";
  &copy_file($fvf, $xf)
    if ($copyxmltoo);

  my $mfvf = "$mdir/$md_vf";
  my $mxf = $xf . ".memdump";
  &copy_file($mfvf, $mxf);

  print "Results:\n - $xf\n - $mxf\n";

  print $stepc++, ") Confirming number of event in MemDump\n";
  my ($ettxt, $et, $tot) = &load_check_number_of_events($mxf);
  print " - Found $tot total events among $et types: $ettxt\n";

  MMisc::eror_quit("Did not find the same number of total events in the output file ($tot) than in the split input files ($tcount)")
    if ($tcount != $tot);

  $ndone++;
}
print "All files processed (Done: $ndone | Total: $ntodo)\n\n";
MMisc::error_exit()
  if ($ndone != $ntodo);

MMisc::ok_exit();

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)) { 
    &valok($fname, "[ERROR] $_");
  }
}

####################

sub xmllint_file {
  my ($ifile, $ofile) = @_;

  my $dummy = new TrecVid08ViperFile();
  my @xsdfilesl = $dummy->get_required_xsd_files_list();

  my $xmllintobj = new xmllintHelper();
  $xmllintobj->set_xsdfilesl(@xsdfilesl);
  $xmllintobj->set_xsdpath($xsdpath);
  return("Problem with \'xsdpath\' [$xsdpath]: " . $xmllintobj->get_errormsg())
    if ($xmllintobj->error());
  $xmllintobj->set_xmllint($xmllint);
  return("Problem with \'xmllint\' [$xmllint]: " . $xmllintobj->get_errormsg())
    if ($xmllintobj->error());
  
  my $txt = $xmllintobj->run_xmllint($ifile);
  return("Problem running \'xmllint\': " . $xmllintobj->get_errormsg())
    if ($xmllintobj->error());
  
  my $ok = MMisc::writeTo($ofile, "", 1, 0, $txt);
  return("Problem writting to [$ofile]") if (! $ok);

  return("");
}

#####

sub prep_sub_files {
  my $odir = shift @_;
  my $file = shift @_;
  
  my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($file);
  return($err)
    if (! MMisc::is_blank($err));

  my $slurped = MMisc::slurp_file($file);
  if (! defined $slurped) {
    return("Problem loading file, skipping");
    next;
  }

  my $trailer = "";
  my $slurp = "";
  my $lchunks = $chunks;
  while ((MMisc::is_blank($trailer)) && (length($slurped) > 0)) {
    while ((length($slurped) > 0) && (length($slurp) < $lchunks)) {
      my $lslurp = substr($slurped, -$chunks, $chunks, "");
      # we can only clean the end spaces if we are not adding at the beginning
      # of an already filled "slurp"
      MMisc::clean_end_spaces(\$lslurp) if (MMisc::is_blank($slurp)); 
      $slurp = "$lslurp$slurp";
    }
    $trailer = $1 if ($slurp =~ s%(\<\/sourcefile\>.+)$%%s);
    $lchunks += $chunks;
  }
  return("Could not get file trailer") if (MMisc::is_blank($trailer));
  $slurped .= $slurp;

  my $header = "";
  my $slurp = "";
  my $lchunks = $chunks;
  while ((MMisc::is_blank($header)) && (length($slurped) > 0)) {
    while ((length($slurped) > 0) && (length($slurp) < $lchunks)) {
      my $lslurp = substr($slurped, 0, $chunks, "");
      # we can only clean the beg spaces if we are not adding at the end
      # of an already filled "slurp"
      MMisc::clean_beg_spaces(\$lslurp) if (MMisc::is_blank($slurp));
      $slurp .= $lslurp;
    }
    $header = $1 if ($slurp =~ s%^(.+?\<\/file\>)%%s);
    $lchunks += $chunks;
  }
  return("Could not get file header") if (MMisc::is_blank($header));

  # keep working with what is left in $slurp
  my $inc = 0;
  my $count = 0;
  my $txt = "\n";
  my @fl = ();
  my $doit = 1;
  my $tcount = 0;
  while ($doit) {
    my $al1o = ""; # At least 1 object / Empty previous at each loop
    my $e_al1o = 1;
    my $lchunks = $chunks;

    # Can we process from 
    if ($slurp =~ s%(\<object\s.+?\<\/object\>)%%s) {
      $al1o = $1;
      $e_al1o = 0; # not empty anymore
    }

    while (($e_al1o) && (length($slurped) > 0)) {      
      if ((length($slurp) < $lchunks) && (length($slurped) > 0)) {
        my $lslurp .= substr($slurped, 0, $chunks, "");
        $slurp .= $lslurp;
      }

      if ($slurp =~ s%(\<object\s.+?\<\/object\>)%%s) {
        $al1o = $1;
        $e_al1o = 0; # not empty anymore
        next;
      }

      $lchunks += $chunks;
    }

    if ((MMisc::is_blank($slurp)) && ($e_al1o)) {
      $doit = 0;
      next;
    }

    if ($e_al1o) {
      my $tf = "$odir/$fn.bad";
      MMisc::writeTo($tf, "", 0, 0, "[$slurp]");
      return("Could not find an \"object\" section, but file is not empty. See \"$tf\" for leftover content (content encapsulated within [])");
    }

    $txt .= "$al1o\n";
    $count++;

    if ($count >= $spc) {
      my $tf = MMisc::concat_dir_file_ext($odir, sprintf("${fn}_%06d", ++$inc), $ext);
      MMisc::writeTo($tf, "", $verb, 0, $header . $txt . $trailer);
      push @fl, $tf;
      $txt = "\n";
      $tcount += $count;
      $count = 0;
    }

  }

  if ($count > 0) {
    my $tf = MMisc::concat_dir_file_ext($odir, sprintf("${fn}_%06d", ++$inc), $ext);
    MMisc::writeTo($tf, "", $verb, 0, $header . $txt . $trailer);
    push @fl, $tf;
    $txt = "";
    $tcount += $count;
    $count = 0;
  }
    
  return("", $tcount, @fl);
}

####################

sub validate_sub_files {
  my ($odir, $sfdir, @fl) = @_;

  foreach my $file (@fl) {
    my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($file);
    return($err)
      if (! MMisc::is_blank($err));
    
    my $logfile = "$odir/$fn.log";

    my $cmd = $valtool;
    $cmd .= " -g" if ($isgtf);
    $cmd .= " -w $odir -W text ";
    $cmd .= MMisc::concat_dir_file_ext($sfdir, $fn, $ext);

    my ($rv, $tx, $so, $se, $retcode, $logfile)
      = MMisc::write_syscall_smart_logfile($logfile, $cmd);

    return("Problem validating file [$file] -- see: $logfile")
      if ($retcode != 0);
    &vprint("    -> Validated [$file]\n");
  }

  my @dl = MMisc::get_files_list($odir);
  my @vfl = grep(m%\.memdump$%, @dl);

  return("Found a different amount of output files (" . scalar @vfl . ") from the number of input file (" . scalar @fl . ")")
    if (scalar @vfl != scalar @fl);

  return("", @vfl);
}

####################

sub merge_val_files {
  my ($ffnb, $odir, $vdir, @fl) = @_;

  my ($err, $dir, $fn, $ext) = MMisc::split_dir_file_ext($ffnb);
  return($err)
    if (! MMisc::is_blank($err));

 
  my $vfl = "";
  foreach my $file (@fl) {
    $vfl .= "$vdir/$file ";
  }    
  
  my $logfile = "$odir/$fn.log";

  my $cmd = $mrgtool;
  $cmd .= " -g" if ($isgtf);
  $cmd .= " -w $odir -W text -k -f $fps -n ";
  $cmd .= $vfl;

  my ($rv, $tx, $so, $se, $retcode, $logfile)
    = MMisc::write_syscall_smart_logfile($logfile, $cmd);

  return("Problem Merging file -- see: $logfile")
    if ($retcode != 0);

  my @dl = MMisc::get_files_list($odir);
  my @mfl = sort grep(! m%\.log$%, @dl);

  return("Found different than two files in directory [$odir]: " . join(" ", @mfl))
    if (scalar @mfl != 2);;

  my $vf = shift @mfl;
  my $md_vf = shift @mfl;

  return("", $vf, $md_vf);
}

##########

sub vprint {
  return() if (! $verb);

  print @_;
}

##########

sub copy_file {
  my ($a, $b) = @_;

  my $err = MMisc::filecopy($a, $b);
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
}

##########

sub load_check_number_of_events {
  my ($fn) = @_;

  my ($retstatus, $object, $msg) = 
    TrecVid08HelperFunctions::load_ViperFile($isgtf, $fn, $fps, $xmllint, $xsdpath);

  MMisc::error_quit("Problem reloading MemDump file ($fn) : $msg")
    if (! $retstatus);

  my ($ettxt, $et, $tot) = $object->get_txt_and_number_of_events(2);
  MMisc::error_quit("Problem with reloaded ViperFile MemDump: " . $object->get_errormsg())
    if ($object->error());

  return($ettxt, $et, $tot);
}

########################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################ Manual

=pod

=head1 NAME

TV08_BigXML_ValidatorHelper - TrecVid08 Big XML Files Validator Helper

=head1 SYNOPSIS

B<TV08_BigXML_ValidatorHelper> S<[--help | --man | --version]>
  S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
  S<[B<--ViperValidator> I<location>] [B<--MergeHelper> I<location>]>
  S<[B<--gtf>] [B<--splitevery> I<value>] [B<--chunks> I<bytes>]>
  S<[B<--quiet>] [B<--Copy_xml_too>]>
  B<--fps> I<fps> B<--writedir> I<directory>
  I<viper_source_file.xml> [I<viper_source_file.xml> [I<...>]]

=head1 DESCRIPTION

B<TV08_BigXML_ValidatorHelper> performs a syntactic and semantic validation of the ViPER XML file(s) provided on the command line, then write a MemDump version of this file into the B<writedir> directory. It can I<validate> reference files (see B<--gtf>) as well as system files. It does so by splitting large files into plenty of small files, validating those files and merging the resulting files. It does not have all the options of S<TV08ViperValidator> as it is a helper tool designed to obtain a MemDump version of large XML files. Those MemDump files can then be used in other tools reducing considerably the load time (does not have to re-validate the XML file). 

=head1 PREREQUISITES

B<TV08_BigXML_ValidatorHelper> relies on some external software and files.

=over

=item B<SOFTWARE> 

I<xmllint> (part of I<libxml2>, see S<http://www.xmlsoft.org/>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<F4DE_XMLLINT> environment variable.

B<TV08ViperValidator> and B<TV08MergerHelper>, part of F4DE's TrecVid08 section are also needed as they are the core programs used. 

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

Once you have installed the software, extending your B<PATH> to include F4DE's B<bin> directory should be sufficient for the tools to find their components.

=back

=head1 GENERAL NOTES

B<TV08_BigXML_ValidatorHelper> expect that the files can be validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<TV08_BigXML_ValidatorHelper> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--Copy_xml_too>

Copy source XML file to B<writedir> directory in addition to generating the I<MemDump> file.

=item B<--chunks> I<value>

Read I<value> bytes of data at a time from the source file when generating the sub files used for validation.
This influence the speed of processing of the validation process.
Default value can be obtained using B<--help>. It is recommended to not go under this value.

=item B<--fps> I<fps>

Specify the default sample rate (in frames per second) of the ViPER files.

=item B<--gtf>

Specify that the file to validate is a Reference file (also known as a Ground Truth File)

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--MergeHelper> I<location>

Specify the location of the S<TV08MergeHelper> program (used by this helper).
Default location used can be obained using B<--help>.

=item B<--man>

Display this man page.

=item B<--quiet>

Do not print processing information (default is to be verbose).

=item B<--splitevery> I<value>

Split the source file every I<value> event observation seen.
This influence the total number of files created in the validation process.
Default value can be obtained using B<--help>

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).

=item B<--ViperValidator> I<location>

Specify the location of the S<TV08ViperValidator> program (used by this helper).
Default location used can be obained using B<--help>.

=item B<--version>

Display B<TV08_BigXML_ValidatorHelper> version information.

=item B<--writedir> [I<directory>]

Once validation has been completed for a given file, B<TV08_BigXML_ValidatorHelper> will write the MemDump representation of this file to this directory.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<F4DE_XMLLINT> environment variable.

=back

=head1 USAGE


=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut

########################################

sub set_usage {
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--xmllint location] [--TrecVid08xsd location] [--ViperValidator location] [--MergerHelper location] [--gtf] [--splitevery value] [--chunks bytes] [--quiet] [--Copy_xml_too] --fps fps --writedir directory viper_source_file.xml [viper_source_file.xml [...]]

Will perform a semantic validation of the ViPER XML file(s) provided.

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable
  --TrecVid08xsd  Path where the XSD files can be found
  --ViperValidator    Location of the TV08ViperValidator tool
  --MergeHelper   Location of the TV08MergeHelper tool
  --gtf           Specify that the file to validate is a Ground Truth File
  --splitevery    Split \'viper_source_file.xml\' every \'value\' events observations (default: $spc)
  --chunks        Specify the size in \'bytes\' of the chunks of the input file being processed at a time (to generate the split version) (default: $chunks)
  --quiet         Print as little information as possible during run
  --Copy_xml_too  By default, only write MemDump to \'writedir\' directory, copy XML file too
  --writedir      Once processed in memory, print a new XML MemDump of file in this directory. Also use this directory to put all steps
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)

Note:
- Program will ignore the <config> section of the XML file.
- Program will discard any xml comment(s).
- By default will try to use:
$valtool
$mrgtool
EOF
    ;

    return $tmp;
}
