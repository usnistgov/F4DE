package F4DE_TestCore;

use strict;
use MMisc;

my $magicmode = "makecheckfiles"; # And the magic word is ...
my $magicmode_comp = "makecompcheckfiles";
my @magicmodes = ($magicmode, $magicmode_comp);
my $mmc_add = $ENV{TEST_MMC_ADD} || "-comp";
my $dev = "F4DE_TestCore default error value";
my $lts = 10;                   # lines to show

####################

sub get_magicmode_key { return($magicmode); }
sub get_magicmode_comp_key { return($magicmode_comp); }

#####

sub _get_filec {
  my $f = shift @_;

  return($dev) if ((! -e $f) || (! -r $f));

  my $txt = MMisc::slurp_file($f);

  return($txt);
}

#####

sub make_syscall {
  my ($ofile, @command) = @_;

  my ($wrote, $otxt, $stdout, $stderr, $retcode) 
    = MMisc::write_syscall_logfile($ofile, @command);

  die("F4DE_TestCore Internal Error\n")
    if (! $wrote);
 
  my @toshow = MMisc::get_txt_last_Xlines($stdout, $lts);

  my $txt = &_get_filec($ofile);
  $retcode = 1 if ($txt eq $dev);

  return($retcode, $txt, @toshow);
}

##########

sub _is_magic {
  my ($mode) = @_;

  return(grep(m%^$mode$%, @magicmodes));
}

#####

sub _run_core {
  my ($cmd, $cmp2resfile, $mode, $erv) = 
    MMisc::iuav(\@_, "", "", "", 0);

  my $ofile = "";
  if (&_is_magic($mode)) {
    $ofile = $cmp2resfile;
    $ofile .= $mmc_add if ($mode eq $magicmode_comp);
  } else {
    $ofile = MMisc::get_tmpfilename();
  }

  my ($retcode, $run, @toshow) = &make_syscall($ofile, $cmd);

  my $tst = join("\n  ## ", @toshow);

  return(0, $ofile, $tst) if (($retcode >> 8) != $erv);
  # 'perldoc -f system': to get the actual exit value, shift right by eight

  return(1, $ofile, $tst) if (&_is_magic($mode));

  my $runfile = &_get_filec($ofile);
  my $resfile = &_get_filec($cmp2resfile);
  unlink($ofile);

  return(0) if (($runfile eq $dev) || ($resfile eq $dev));

  return(1, $ofile, $tst) if ($runfile eq $resfile);

  return(0, $ofile, $tst);
}

##########

sub print_name {
  my ($name, $comment) = @_;

  $name =~ s%(\d)% $1%;
  
  print ucfirst($name);

  print " $comment" if (! MMisc::is_blank($comment));
  
  print " : ";
}

#####

sub check_skip {
  my ($name) = @_;

  my $skipfile = ".skip_" . lc($name);

  return(1) if (-e $skipfile);

  if ($skipfile =~ s%[a-z]+$%%) {
    return(1) if (-e $skipfile);
  }

  return(0);
}

#####

sub run_simpletest {
  my ($testname, $subtype, $cmd, $cmp2resfile, $mode, $erv) = 
    MMisc::iuav(\@_, "", "", "", "", "", 0);

  &print_name($testname, $subtype);

  if ( (&check_skip($testname)) || (! &query_do_test($testname)) ) {
    print "Skipped\n";
    return(1);
  }

  my ($rv, $ofile, $toshow) = &_run_core($cmd, $cmp2resfile, $mode, $erv);

  if (&_is_magic($mode)) {
    print "makecheckfile ... ";
    if ($rv == 0) {
      print "##### failed ! ##### (see $ofile)\n";
      print "## Last $lts lines of stdout run:\n  ## $toshow\n";
      return(0);
    }
    print "ok [wrote: $ofile]\n";
    print "## Last $lts lines of stdout run:\n  ## $toshow\n";
    return(1);
  }

  if ($rv == 0) {
    print "failed\n";
    return(0);
  }

  print "OK\n";
  return(1);
}

####################

sub _split_fn {
  my $v = shift @_;
  
  my ($sf, $df) = split(m%\:%, $v);
  
  return($sf,$df);
}

#####

sub _get_sfdf_core {
  my ($v, $p) = @_;
  
  my ($sf, $df) = &_split_fn($v);
  return($dev) if ((MMisc::is_blank($sf)) || (MMisc::is_blank($df)));
  
  my @it = ($sf, $df);
  my $fc = &_get_filec($it[$p]);

  return($fc);
}

#####

sub _get_sfc {
  my ($v) = @_;
  return(&_get_sfdf_core($v, 0));
}

#####
  
sub _get_dfc {
  my ($v) = @_;
  return(&_get_sfdf_core($v, 1));
}

#####

sub _mcfgetf {
  my $mode = shift @_;
  my @vs = @_;
  
  foreach my $v (@vs) {
    my ($sf, $df) = &_split_fn($v);
    my $sfc = &_get_sfc($v);
    return(0) if ($sfc eq $dev);
    $df .= $mmc_add if ($mode eq $magicmode_comp);
    die("F4DE_TestCore Internal Error\n")
      if (! MMisc::writeTo($df, "", 0, 0, $sfc));
  }

  return(1);
}
 
#####

sub _cmp_sfc_dfc {
  my @vs = @_;

  foreach my $v (@vs) {
    my $sfc = &_get_sfc($v);
    return(0) if ($sfc eq $dev);

    my $dfc = &_get_dfc($v);
    return(0) if ($dfc eq $dev);
    
    return(0) if ($sfc ne $dfc);
  }

  return(1);
}

#####

sub run_complextest {
  my ($testname, $subtype, $cmd, $cmp2resfile, $mode, @sfiles) = @_;

  &print_name($testname, $subtype);

  if ( (&check_skip($testname)) || (! &query_do_test($testname)) ) {
    print "Skipped\n";
    return(1);
  }

  my ($rv, $ofile, $toshow) = &_run_core($cmd, $cmp2resfile, $mode);

  if (&_is_magic($mode)) {
    print "makecheckfile ... ";
    if (($rv == 0) || (! &_mcfgetf($mode, @sfiles))) {
      print "##### failed ! ##### (see $ofile)\n";
      print "## Last $lts lines of stdout run:\n  ## $toshow\n";
      return(0);
    }
    print "ok [wrote: $ofile]\n";
    print "## Last $lts lines of stdout run:\n  ## $toshow\n";
    return(1);
  }

  if ( ($rv == 0) || (! &_cmp_sfc_dfc(@sfiles)) ) {
    print "failed\n";
    return(0);
  }

  print "OK\n";
  return(1);
}

########################################

sub query_do_test {
  my ($testname) = @_;

  return(1) if (! defined $ENV{TEST_ONLY});

  my @todo = split(" ", $ENV{TEST_ONLY});

  # If no limit, simply do them all
  return(1) if (scalar @todo == 0);

  # only keep the number (and sub test name) part
  $testname =~ s%^\w+?(\d+)%$1%s;
  
  return(1) if (grep(m%^$testname$%, @todo)); # is it in the todo list ?

  # Remove the last alpha digits (test sub name)
  if ($testname =~ s%[a-z]+$%%) {
    return(1) if (grep(m%^$testname$%, @todo));
  }
  
  return(0);
}

########################################

1;
