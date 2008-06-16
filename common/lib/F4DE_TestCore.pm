package TV08TestCore;

use strict;
use MMisc;

my $magicmode = "makecheckfiles"; # And the magic word is ...
my $dev = "TV08TestCore default error value";
my $lts = 10;                   # lines to show

#####

sub get_txt_last_Xlines {
  my ($txt, $X) = @_;

  my @toshowa;
  my @a = split(m%\n%, $txt);
  my $e = scalar @a;
  my $b = (($e - $X) > 0) ? ($e - $X) : 0;
  foreach (my $i = $b; $i < $e; $i++) {
    push @toshowa, $a[$i];
  }

  return(@toshowa);
}

##########

sub _get_filec {
  my $f = shift @_;

  return($dev) if ((! -e $f) || (! -r $f));

  my $txt = MMisc::slurp_file($f);

  return($txt);
}

#####

sub make_syscall {
  my ($ofile, @command) = @_;

  my ($retcode, $stdout, $stderr) = MMisc::do_system_call(@command);

  my $otxt = "[[COMMANDLINE]] " . join(" ", @command) . "\n"
    . "[[RETURN CODE]] $retcode\n"
      . "[[STDOUT]]\n$stdout\n\n"
        . "[[STDERR]]\n$stderr\n";

  die("TV08TestCore Internal Error\n")
    if (! MMisc::writeTo($ofile, "", 0, 0, $otxt));
 
  my @toshow = &get_txt_last_Xlines($stdout, $lts);

  my $txt = &_get_filec($ofile);
  $retcode = 1 if ($txt eq $dev);

  return($retcode, $txt, @toshow);
}

##########

sub _run_core {
  my ($testname, $cmd, $cmp2resfile, $mode) = @_;

  my $ofile;
  if ($mode eq $magicmode) {
    $ofile = $cmp2resfile;
  } else {
    $ofile = MMisc::get_tmpfilename();
  }

  my ($retcode, $run, @toshow) = &make_syscall($ofile, $cmd);

  my $tst = join("\n  ## ", @toshow);

  return(0, $ofile, $tst) if ($retcode != 0);

  return(1, $ofile, $tst) if ($mode eq $magicmode);

  my $runfile = &_get_filec($ofile);
  my $resfile = &_get_filec($cmp2resfile);
  unlink($ofile);

  return(0) if (($runfile eq $dev) || ($resfile eq $dev));

  return(1, $ofile, $tst) if ($runfile eq $resfile);

  return(0, $ofile, $tst);
}

##########
  
sub run_simpletest {
  my ($testname, $cmd, $cmp2resfile, $mode) = @_;

  print "$testname: ";

  my ($rv, $ofile, $toshow) = &_run_core(@_);

  if ($mode eq $magicmode) {
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
    print " failed\n";
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
  my @vs = @_;
  
  foreach my $v (@vs) {
    my ($sf, $df) = &_split_fn($v);
    my $sfc = &_get_sfc($v);
    return(0) if ($sfc eq $dev);
    die("TV08TestCore Internal Error\n")
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
  my ($testname, $cmd, $cmp2resfile, $mode, @sfiles) = @_;

  print "$testname: ";

  my ($rv, $ofile, $toshow) = &_run_core(@_);

  if ($mode eq $magicmode) {
    print "makecheckfile ... ";
    if (($rv == 0) || (! &_mcfgetf(@sfiles))) {
      print "##### failed ! ##### (see $ofile)\n";
      print "## Last $lts lines of stdout run:\n  ## $toshow\n";
      return(0);
    }
    print "ok [wrote: $ofile]\n";
    print "## Last $lts lines of stdout run:\n  ## $toshow\n";
    return(1);
  }

  if (($rv == 0) || (! &_cmp_sfc_dfc(@sfiles))) {
    print " failed\n";
    return(0);
  }

  print "OK\n";
  return(1);
}

########################################

1;
