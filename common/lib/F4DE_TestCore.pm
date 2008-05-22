package TV08TestCore;

use File::Temp qw / tempfile /;

############################################################

sub check_package {
  my ($package) = @_;
  unless (eval "use $package; 1")
  {
    return(0);
  }
  return(1);
}

##########

sub _get_env_val {
  my $envv = shift @_;
  my $default = shift @_;

  my $var = $default;

  $var = $ENV{$envv} if (exists $ENV{$envv});

  return($var);
}

##########

sub is_blank {
  my $txt = shift @_;
  return(($txt =~ m%^\s*$%));
}

############################################################

my $magicmode = "makecheckfiles"; # And the magic word is ...

#####

sub _get_tmpfilename {
  my (undef, $name) = tempfile( OPEN => 0 );

  return($name);
}

#####

sub _slurp_file {
  my ($fname, $type) = @_;

  open FILE, "<$fname"
    or die("Internal error: Can not open $type file to slurp ($fname): $!\n");
  my @all = <FILE>;
  close FILE;

  my $tmp = join("", @all);
  chomp $tmp;

  return($tmp);
}

#####

sub _do_system_call {
  my @args = @_;
  
  my $cmdline = join(" ", @args);

  my $retcode = -1;
  # Get temporary filenames (created by the command line call)
  my $stdoutfile = &_get_tmpfilename();
  my $stderrfile = &_get_tmpfilename();

  open (CMD, "$cmdline 1> $stdoutfile 2> $stderrfile |");
  close CMD;
  $retcode = $?;

  # Get the content of those temporary files
  my $stdout = &_slurp_file($stdoutfile, "stdout storage");
  my $stderr = &_slurp_file($stderrfile, "stderr storage");

  # Erase the temporary files
  unlink($stdoutfile);
  unlink($stderrfile);

  return($retcode, $stdout, $stderr);
}

##########

sub make_syscall {
  my ($ofile, @command) = @_;

  my ($retcode, $stdout, $stderr) = &_do_system_call(@command);

  open OFILE, ">$ofile"
    or die("Could not create output file ($ofile) : $!\n");
  print OFILE "STDOUT:\n$stdout\n\nSTDERR:\n$stderr\n";
  close OFILE;

  my $txt = &_slurp_file($ofile, "output");
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
    $ofile = &_get_tmpfilename();
  }

  my ($retcode, $run) = &make_syscall($ofile, $cmd);

  if ($mode eq $magicmode) {
    print "makecheckfile ... ";
    if ($retcode != 0) {
      print "failed ! (see $ofile)\n";
      return(0);
    }
    print "ok\n";
    return(1);
  }

  if ($retcode != 0) {
    print " failed\n";
    return(0);
  }

  my $runfile = &_slurp_file($ofile, "RUN");
  my $resfile = &_slurp_file($cmp2resfile, "RESULT");
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
