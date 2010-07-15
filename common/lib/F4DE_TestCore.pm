package F4DE_TestCore;

use strict;
use MMisc;

my $env_mmcadd = "F4DE_TEST_MMC_ADD";
my $env_testonly = "F4DE_TEST_ONLY";
my $env_testoptions = "F4DE_TEST_OPTIONS";

my $magicmode = "makecheckfiles"; # And the magic word is ...
my $magicmode_comp = "makecompcheckfiles";
my @magicmodes = ($magicmode, $magicmode_comp);

my $mmc_add = $ENV{$env_mmcadd} || "-comp";

my $dev = "F4DE_TestCore default error value";
my $lts = 10;                   # lines to show

my @testoptions_list = ( "elapsedtime" );
my $processed_testoptions = 0;
my $show_elapsed = 0;

####################

sub get_magicmode_key { return($magicmode); }
sub get_magicmode_comp_key { return($magicmode_comp); }

##########

sub get_mmcadd_env { return($env_mmcadd); }
sub get_testonly_env { return($env_testonly); }
sub get_testoptions_env { return($env_testoptions); }

#####

sub set_mmcadd_env {
  my $val = shift @_;

  MMisc::error_quit("Can not set \"$env_mmcadd\" to an empty value")
      if (MMisc::is_blank($val));

  $env_mmcadd = $val;
}

#####

sub set_testonly_env {
  my $val = shift @_;

  MMisc::error_quit("Can not set \"$env_testonly\" to an empty value")
      if (MMisc::is_blank($val));

  $env_testonly = $val;
}

#####

sub set_testoptions_env {
  my $val = shift @_;

  MMisc::error_quit("Can not set \"$env_testoptions\" to an empty value")
      if (MMisc::is_blank($val));

  $env_testoptions = $val;
}

#####

sub show_authorized_test_options { return(join(" ", @testoptions_list)); }

##########

sub is_elapsedtime_on {
  &check_testoptions_env();
  return(1) if ($show_elapsed);

  return(0);
}

#####

sub get_currenttime { return(MMisc::get_currenttime()); }

#####

sub get_elapsedtime { return(MMisc::get_elapsedtime(shift @_)); }

##########

sub check_testoptions_env {
  return() if (! exists $ENV{$env_testoptions});
  return() if ($processed_testoptions);

  my $v = $ENV{$env_testoptions};

  my $t = $testoptions_list[0];
  $show_elapsed = 1 if ($v =~ s%$t%%i);

  MMisc::error_quit("Unknown options(s)  (" . MMisc::clean_begend_spaces($v) . ") for \"$env_testoptions\", authorized options: " . &show_authorized_test_options())
      if (! MMisc::is_blank($v));

  $processed_testoptions = 1;
}

###############

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

  MMisc::error_quit("F4DE_TestCore Internal Error\n")
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

  my $t0 = &get_currenttime();
  my ($retcode, $run, @toshow) = &make_syscall($ofile, $cmd);
  my $elapsed = &get_elapsedtime($t0);

  my $tst = join("\n  ## ", @toshow);

  return(0, $ofile, $tst, $elapsed) if ($retcode != $erv);

  return(1, $ofile, $tst, $elapsed) if (&_is_magic($mode));

  my $runfile = &_get_filec($ofile);
  my $resfile = &_get_filec($cmp2resfile);
  unlink($ofile);

  return(0, "", "", $elapsed) if (($runfile eq $dev) || ($resfile eq $dev));

  return(1, $ofile, $tst, $elapsed) if ($runfile eq $resfile);

  return(0, $ofile, $tst, $elapsed);
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

sub check_files {
  my ($testname, $subtype, $warn_msg, @lstests) = @_;
  
  for (my $i = 0; $i < scalar @lstests; $i++) {
    my $lsa = $lstests[$i];
    next if (MMisc::ls_ok($lsa));

    &print_name($testname, $subtype);
    print "Skipped [" . 
      ((MMisc::is_blank($warn_msg)) ? "not all files present" : $warn_msg ) 
        ."]\n";
    return(0);
  }

  return(1);
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

  &check_testoptions_env();

  my ($rv, $ofile, $toshow, $elapsed) = &_run_core($cmd, $cmp2resfile, $mode, $erv);

  my $add = "";
  $add .= " [Elapsed: $elapsed seconds]" if ($show_elapsed);

  if (&_is_magic($mode)) {
    print "makecheckfile ... ";
    if ($rv == 0) {
      print "##### failed ! ##### (see $ofile)$add\n";
      print "## Last $lts lines of stdout run:\n  ## $toshow\n";
      return(0);
    }
    print "ok [wrote: $ofile]$add\n";
    print "## Last $lts lines of stdout run:\n  ## $toshow\n";
    return(1);
  }

  if ($rv == 0) {
    print "failed$add\n";
    return(0);
  }

  print "OK$add\n";
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
  
  for (my $i = 0; $i < scalar @vs; $i++) {
    my $v = $vs[$i];
    my ($sf, $df) = &_split_fn($v);
    my $sfc = &_get_sfc($v);
    return(0) if ($sfc eq $dev);
    $df .= $mmc_add if ($mode eq $magicmode_comp);
    MMisc::error_quit("F4DE_TestCore Internal Error\n")
        if (! MMisc::writeTo($df, "", 0, 0, $sfc));
  }

  return(1);
}
 
#####

sub _cmp_sfc_dfc {
  my @vs = @_;

  for (my $i = 0; $i < scalar @vs; $i++) {
    my $v = $vs[$i];
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

  &check_testoptions_env();

  my ($rv, $ofile, $toshow, $elapsed) = &_run_core($cmd, $cmp2resfile, $mode);

  my $add = "";
  $add .= " [Elapsed: $elapsed seconds]" if ($show_elapsed);

  if (&_is_magic($mode)) {
    print "makecheckfile ... ";
    if (($rv == 0) || (! &_mcfgetf($mode, @sfiles))) {
      print "##### failed ! ##### (see $ofile)$add\n";
      print "## Last $lts lines of stdout run:\n  ## $toshow\n";
      return(0);
    }
    print "ok [wrote: $ofile]$add\n";
    print "## Last $lts lines of stdout run:\n  ## $toshow\n";
    return(1);
  }

  if ( ($rv == 0) || (! &_cmp_sfc_dfc(@sfiles)) ) {
    print "failed$add\n";
    return(0);
  }

  print "OK$add\n";
  return(1);
}

########################################

sub query_do_test {
  my ($testname) = @_;

  return(1) if (! defined $ENV{$env_testonly});

  my @todo = split(" ", $ENV{$env_testonly});

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
