#!/usr/bin/env perl

use strict;

my $sd = "";
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $sd = dirname(abs_path($0));
}
use lib ("$sd/../../../common/lib", "$sd/../../lib");

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

my $usage = &set_usage();

my %opt = ();
my $sha = undef;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                                  h          s         #

GetOptions
  (
   \%opt,
   'help',
   'sha=s' => \$sha,
  ) or MMisc::error_quit("Unknown option\n\n$usage\n");
MMisc::ok_quit("\n$usage\n") if ($opt{'help'});


##########
$sd = dirname(abs_path($0));

my $tool = "$sd/GetVarValue.sh";
my $err = MMisc::check_file_x($tool);
MMisc::error_quit("Problem with file ($tool) : $err")
  if (! MMisc::is_blank($err));

my @tocheck = `ls $sd/*_SubmissionHelper.cfg`;
chomp @tocheck;

my $at = new AutoTable();
my $inc = 0;
foreach my $mcfg (@tocheck) {
  $err = MMisc::check_file_r($mcfg);
  MMisc::error_quit("Problem with file ($mcfg) : $err")
      if (! MMisc::is_blank($err));
  
  my $q = `env subhelp_dir=$sd $tool $mcfg lockdir`;
  chomp $q;

  &processdir($mcfg, $q);
}
print $at->renderTxtTable();

MMisc::ok_exit();

sub processdir {
  my ($cfg, $d) = @_;

  $cfg =~ s%^$sd/%%;
  my ($ev) = split(m%_%, $cfg);

  my @content = `ls $d/*.02-uploaded`;
  chomp @content;

  foreach my $is (@content) {
    my $rs = MMisc::slurp_file($is);
    $is =~ s%$d/%%;
    $is =~ s%\.02-uploaded$%%;
    if ((! defined $sha) || ((defined $sha) && (grep(m%$sha%, $is, $rs)))){
      $at->addData($ev, "Eval", $inc);
      $at->addData($is, "InternalSHA256", $inc);
      $at->addData($rs, "RemoteSHA256", $inc);
      $inc++;
    }
#    print "$ev | $is | $rs\n";
  }
}

########################################

sub set_usage {  
  my $tmp=<<EOF
$0 [--help] [--sha partofsha]

Where:
 --help       This help message
 --sha        part of SHA to look for

EOF
;

  return($tmp);
}
