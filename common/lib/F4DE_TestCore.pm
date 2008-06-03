package TV08TestCore;

use MMisc;

my $magicmode = "makecheckfiles"; # And the magic word is ...

#####

sub make_syscall {
  my ($ofile, @command) = @_;

  my ($retcode, $stdout, $stderr) = MMisc::do_system_call(@command);

  open OFILE, ">$ofile"
    or die("TV08TestCore Internal Error: Could not create output file ($ofile) : $!\n");
  print OFILE "STDOUT:\n$stdout\n\nSTDERR:\n$stderr\n";
  close OFILE;

  my $txt = MMisc::slurp_file($ofile);
  return($retcode, $txt);
}

##########

sub run_simpletest {
  my ($testname, $cmd, $cmp2resfile, $mode) = @_;

  print "$testname: ";

  my $ofile;
  if ($mode eq $magicmode) {
    $ofile = $cmp2resfile;
  } else {
    $ofile = MMisc::get_tmpfilename();
  }

  my ($retcode, $run) = &make_syscall($ofile, $cmd);

  if ($mode eq $magicmode) {
    print "makecheckfile ... ";
    if ($retcode != 0) {
      print "##### failed ! ##### (see $ofile)\n";
      return(0);
    }
    print "ok [wrote: $ofile]\n";
    return(1);
  }

  if ($retcode != 0) {
    print " failed\n";
    return(0);
  }

  my $runfile = MMisc::slurp_file($ofile);
  my $resfile = MMisc::slurp_file($cmp2resfile);
  unlink($ofile);

  if ($runfile eq $resfile) {
    print "OK\n";
    # Erase the temporary file
    return(1);
  }
  
  print "failed\n";
  return(0);
}

########################################

1;
