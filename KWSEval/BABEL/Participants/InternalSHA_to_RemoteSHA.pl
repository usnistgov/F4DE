#!/usr/bin/env perl
#
# $Id$
#

use strict;

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../../common/lib", "$f4d/../../lib");
}
use lib (@f4bv);

########### Check we have every module (perl wise)
sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. ";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "AutoTable") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

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

##########
# Options processing

my @out_ok = ('text', 'csv', 'html');

my $usage = &set_usage();

my %opt = ();
my $search = undef;
my $out = undef;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                                  h      o   s         #

GetOptions
  (
   \%opt,
   'help',
   'search=s' => \$search,
   'out=s' => \$out,
  ) or MMisc::error_quit("Unknown option\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});


##########
my $tool = "$f4d/GetVarValue.sh";
my $err = MMisc::check_file_x($tool);
MMisc::error_quit("Problem with file ($tool) : $err")
  if (! MMisc::is_blank($err));

my $out_ext = undef;
if (defined $out) {
  ($out_ext) = ($out =~ m%\.([^\.]+)$%);
  $out_ext = lc($out_ext);
  MMisc::error_quit("Unknown \'out\' mode ($out_ext), authorized: " . join(" ", @out_ok))
      if (! grep(m%^$out_ext$%, @out_ok));
}

my @tocheck = `ls $f4d/*_SubmissionHelper.cfg`;
chomp @tocheck;

my $at = new AutoTable();
my $inc = 0;
foreach my $mcfg (@tocheck) {
  $err = MMisc::check_file_r($mcfg);
  MMisc::error_quit("Problem with file ($mcfg) : $err")
      if (! MMisc::is_blank($err));
  
  my $q = `env subhelp_dir=$f4d $tool $mcfg lockdir`;
  chomp $q;

  &processdir($mcfg, $q);
}
print $at->renderTxtTable();
if (defined $out_ext) {
  MMisc::writeTo($out, "", 1, 0, $at->renderTxtTable())
      if ($out_ext eq $out_ok[0]);
  MMisc::writeTo($out, "", 1, 0, $at->renderCSV())
      if ($out_ext eq $out_ok[1]);
  MMisc::writeTo($out, "", 1, 0, $at->renderHTMLTable())
      if ($out_ext eq $out_ok[2]);
}
MMisc::ok_exit();

sub processdir {
  my ($cfg, $d) = @_;

  $cfg =~ s%^$f4d/%%;
  my ($ev) = split(m%_%, $cfg);

  my @content = `ls $d/*.02-uploaded`;
  chomp @content;

  foreach my $is (@content) {
    my $tf = $is;
    $tf =~ s%\.02-uploaded$%.01-validated%;
    my $rs = MMisc::slurp_file($is);
    $is =~ s%$d/%%;
    $is =~ s%\.02-uploaded$%%;
    my $if = MMisc::slurp_file($tf);
    if ((! defined $search) || ((defined $search) && (grep(m%$search%, $is, $rs, $if)))){
      $at->addData($ev, "Eval", $inc);
      $at->addData($is, "InternalSHA256", $inc);
      $at->addData($rs, "RemoteSHA256", $inc);
      $at->addData($if, "SubmissionFile", $inc);
      $inc++;
    }
#    print "$ev | $is | $rs\n";
  }
}

########################################

sub set_usage {  
  my $lot = join(" ", @out_ok);

  my $tmp=<<EOF
$0 [--help] [--search TextToMatch] [--out file]

Where:
 --help       This help message
 --search     Part of string to look for
 --out        Write output to a file. Type is file is determinde by extension, can be one of: $lot
EOF
;

  return($tmp);
}
