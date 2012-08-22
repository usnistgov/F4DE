#!/usr/bin/env perl

# bench
# bench.pl
# Authors: Jerome Ajot, Jon Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# KWSEval is an experimental system.  
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
# Version

# $Id$
my $version = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "bench Version: $version";

##########
# Check we have every module (perl wise)

my ($f4b, @f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  $f4b = "F4DE_BASE";
  push @f4bv, (exists $ENV{$f4b}) 
    ? ($ENV{$f4b} . "/lib") 
      : ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long", "Data::Dumper", "Time::HiRes qw( gettimeofday tv_interval )") {
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

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

##########
my $IterUBench = 30;
my $IterAsclite = 30;
my $IterFFmpeg = 5;
my $reiter = 3;

#my $KWSEval_dir_path = "../../src";
#my $KWSEval_testfile_dir_path = "../../test_suite";
#my $command_to_run = "perl -I$KWSEval_dir_path $KWSEval_dir_path/KWSEval.pl -e $KWSEval_testfile_dir_path/test2.ecf.xml -r $KWSEval_testfile_dir_path/test2.rttm -s $KWSEval_testfile_dir_path/test2.stdlist.xml -t $KWSEval_testfile_dir_path/test2.kwlist.xml -A 1>/dev/null 2>/dev/null";

my $ascliteRunCommand = "/tmp/asclite -o sgml stdout -f 0 -noisg -F -D -overlap-limit 3 -r /tmp/rt04s.040420.mdm.overlap.stm.filt stm -h /tmp/rt04s.040810.mdm.overlap.ctm.filt ctm >> /dev/null";

my $ffmpegRunCommand = "/tmp/ffmpeg -i /tmp/20050412-1303-final.mpg -vtag DIVX -y -f avi -vcodec mpeg4 -b 1000 -aspect 16:9 -s 960x544 -r ntsc -g 300 -t 250 -me full -mbd 2 -qmin 2 -qmax 31 -trell -hq -an -benchmark /tmp/out.avi &> /dev/null";

my $ubench = "ubench";
my $ubench_options = "";

my $nbench = "nbench";

my $ubenchOpt = undef;
my $ubenchRun = 0;
my $nbenchRun = 0;
my $acliteOpt = undef;
my $ascliteRun = 0;
my $FFmpegOpt = undef;
my $FFmpegRun = 0;

my $multicore = 0;

GetOptions
(
	'ubench:i'  => \$ubenchOpt,
	'nbench'    => \$nbenchRun,
	'asclite:i' => \$acliteOpt,
	'ffmpeg:i'  => \$FFmpegOpt,
	'multicore' => \$multicore,
) or MMisc::error_quit("Unknown option(s)");

my $incpu = 1;
my $ifcpu = 1000;
my $ios = "Linux";
my $imem = 1;

if(defined($ubenchOpt))
{
	$ubenchRun = 1;
	$IterUBench = $ubenchOpt if($ubenchOpt > 0);
}

if(defined($acliteOpt))
{
	$ascliteRun = 1;
	$IterAsclite = $acliteOpt if($acliteOpt > 0);
}

if(defined($FFmpegOpt))
{
	$FFmpegRun = 1;
	$IterFFmpeg = $FFmpegOpt if($FFmpegOpt > 0);
}

sub tim
{
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	return sprintf("[%02d:%02d:%02d]", $hour, $minute, $second);
}

sub info_ncpu
{
	if($ios =~ /linux|cygwin/i)
	{
		system("grep -e '^processor' /proc/cpuinfo | wc -l > /tmp/KWSEval.ncpu");
	}
	else
	{
		system("sysctl hw.ncpu | sed 's/hw.ncpu.\\s*//' > /tmp/KWSEval.ncpu");
	}
	
	open(NCPU, "/tmp/KWSEval.ncpu") or MMisc::error_quit("cannot open 'ncpu'");
	my $ncpu = 0;
	
	while(<NCPU>)
	{
		chomp;
		$ncpu = $_;
	}
	
	close(NCPU);
	unlink("/tmp/KWSEval.ncpu");
	$ncpu =~ s/\s+//;
	return $ncpu;
}

sub info_fcpu
{
	if($ios =~ /linux|cygwin/i)
	{
		system("grep 'cpu MHz' /proc/cpuinfo | sed 's/\\s*//g' | sed 's/cpuMHz://g' | awk '{print \$1*1000000}'> /tmp/KWSEval.fcpu");
	}
	else
	{
		system("sysctl hw.cpufrequency | sed 's/hw.cpufrequency.\\s*//' > /tmp/KWSEval.fcpu");
	}
	
	open(FCPU, "/tmp/KWSEval.fcpu") or MMisc::error_quit("cannot open 'fcpu'");
	my $fcpu = 0;
	
	while(<FCPU>)
	{
		chomp;
		$fcpu = $_;
	}
	
	close(FCPU);
	unlink("/tmp/KWSEval.fcpu");
	$fcpu =~ s/\s+//;
	return sprintf("%.1f", $fcpu/1000000);
}


sub info_mem
{
	if($ios =~ /linux|cygwin/i)
	{
		system("cat /proc/meminfo | grep MemTotal | sed 's/MemTotal.\\s*//' | sed 's/\\s*kB//' | awk '{print \$1*1024}' > /tmp/KWSEval.mem");
	}
	else
	{
		system("sysctl hw.memsize | sed 's/hw.memsize.\\s*//' > /tmp/KWSEval.mem");
	}
	
	open(MEM, "/tmp/KWSEval.mem") or MMisc::error_quit("cannot open 'mem'");
	my $mem = 0;
	
	while(<MEM>)
	{
		chomp;
		$mem = $_;
	}
	
	close(MEM);
	unlink("/tmp/KWSEval.mem");
	return sprintf("%.1f", $mem/1024/1024);
}

sub info_os
{
	system("uname > /tmp/KWSEval.uname");
	open(UNAME, "/tmp/KWSEval.uname") or MMisc::error_quit("cannot open 'uname'");
	my $os = "Linux";
	
	while(<UNAME>)
	{
		chomp;
		$os = $_;
	}
	
	close(UNAME);
	unlink("/tmp/KWSEval.uname");
	return $os;
}

sub check_exec
{
	my ($execname) = @_;
	my $tmp = "";
	
	return "./$execname" if (-x "./$execname");
	
	system("$execname -h &> /tmp/KWSEval.where");
	open(WHERE, "/tmp/KWSEval.where") or MMisc::error_quit("cannot open where-file for '$execname' location");
	while(<WHERE>) { chomp; $tmp = $_; }
	close(WHERE);
	return "$execname" if($tmp !~ /command not found/i);
	
	print STDERR "'$execname' need to be on the current directory or in your PATH!\n";
	exit;
}

sub run_ubench
{
	my $t0 = [gettimeofday()];
	system("$ubench $ubench_options > /tmp/KWSEval.ubench.out 2> /dev/null");
	my $elapsed = tv_interval ($t0, [gettimeofday()]);
	open(UBENCH, "/tmp/KWSEval.ubench.out") or MMisc::error_quit("cannot open result file for 'ubench'");
	
	my $AVG = 0;
	my $CPU = 0;
	my $MEM = 0;
	
	while(<UBENCH>)
	{
		chomp;
		my $line = $_;
		
		if($line =~ /AVG/)
		{
			my @tmp = split(/\s+/, $line);
			$AVG = $tmp[2 + ($ubench_options ne "")];
		}
		
		if($line =~ /CPU/)
		{
			my @tmp = split(/\s+/, $line);
			$CPU = $tmp[2 + ($ubench_options ne "")];
		}
		
		if($line =~ /MEM/)
		{
			my @tmp = split(/\s+/, $line);
			$MEM = $tmp[2 + ($ubench_options ne "")];
		}
	}
	
	close(UBENCH);
	unlink("/tmp/KWSEval.ubench.out");
	return ($CPU, $MEM, $AVG, $elapsed);
}

sub ubenchmark
{
	my $currtime = tim();
	print STDERR "$currtime Starting Benchmark (ubench)...\n";
	
	my %statsbench = ();
	
	foreach my $type ("CPU", "MEM", "AVG")
	{
		foreach my $res ("min", "max", "mean", "rel2stderr", "stddev")
		{
			$statsbench{$type}{$res} = 0;
		}
	}
	
	my $mode = "multi";
	
	if($multicore == 0)
	{
		$ubench_options = "-s";
		$mode = "single";
	}
	
	my $localreiter = $reiter;

	for(my $i=0; $i<$IterUBench; $i++)
	{
		my $iternum = $i+1;
		my $tim = tim();
		print STDERR "$tim Benchmark ($mode) iteration #$iternum/$IterUBench... ";
		my @bench_results = run_ubench();
		my $CPU = $bench_results[0];
		my $MEM = $bench_results[1];
		my $AVG = $bench_results[2];
		
		if( ($CPU !=0) && ($MEM != 0) && ($AVG != 0) )
		{
			$statsbench{CPU}{min} = $CPU if( ($i == 0) || ($CPU < $statsbench{CPU}{min}) );
			$statsbench{CPU}{max} = $CPU if( ($i == 0) || ($CPU > $statsbench{CPU}{max}) );
			$statsbench{CPU}{mean} += $CPU;
			$statsbench{CPU}{stddev} += $CPU * $CPU;
			
			$statsbench{MEM}{min} = $MEM if( ($i == 0) || ($MEM < $statsbench{MEM}{min}) );
			$statsbench{MEM}{max} = $MEM if( ($i == 0) || ($MEM > $statsbench{MEM}{max}) );
			$statsbench{MEM}{mean} += $MEM;
			$statsbench{MEM}{stddev} += $MEM * $MEM;
			
			$statsbench{AVG}{min} = $AVG if( ($i == 0) || ($AVG < $statsbench{AVG}{min}) );
			$statsbench{AVG}{max} = $AVG if( ($i == 0) || ($AVG > $statsbench{AVG}{max}) );
			$statsbench{AVG}{mean} += $AVG;
			$statsbench{AVG}{stddev} += $AVG * $AVG;
			
			my $tmpmean = sprintf("%.8f", $statsbench{AVG}{mean}/($i+1) );
			my $tmpstdev = sprintf("%.8f", sqrt( ($statsbench{AVG}{stddev}/($i+1)) - ($tmpmean*$tmpmean) ) );
			my $tempstderr = sprintf("%.2f%%", 200*$tmpstdev/($tmpmean*sqrt($i+1)) );
			print STDERR "Relative 2SE: $tempstderr\n";
			
			$localreiter = $reiter;
		}
		else
		{
			print STDERR "ERROR: cpu:$CPU mem:$MEM!";
			$localreiter--;
			$i--;
			
			if($localreiter <= 0)
			{
				$localreiter = $reiter;
				$IterUBench--;
				print STDERR " Re-iterations exceeded!";
			}
			
			print STDERR "\n";
		}
	}
	
	foreach my $type ("CPU", "MEM", "AVG")
	{
		my $tmpmean = sprintf("%.8f", $statsbench{$type}{mean}/$IterUBench);
		$statsbench{$type}{mean} = sprintf("%.1f", $tmpmean);
		my $tmpstdev = sprintf("%.8f", sqrt( ($statsbench{$type}{stddev}/$IterUBench) - ($tmpmean * $tmpmean) ));
		$statsbench{$type}{stddev} = sprintf("%.1f", $tmpstdev);
		$statsbench{$type}{rel2stderr} = sprintf("%.8f", 2*$tmpstdev/($tmpmean*sqrt($IterUBench)));
	}
	
	my $legend = "typebench";
	
	foreach my $type ("CPU", "MEM", "AVG")
	{
		foreach my $res ("mean", "stddev", "rel2stderr", "min", "max")
		{
			$legend .= ",$type" . "_$res";
		}
	}
	
	print "$legend\n";
	
	my $out = "s";
	$out = "m" if($multicore);
	
	foreach my $type ("CPU", "MEM", "AVG")
	{
		foreach my $res ("mean", "stddev", "rel2stderr", "min", "max")
		{
			$out .= ",$statsbench{$type}{$res}";
		}
	}
	
	print "$out\n";
	$currtime = tim();
	print STDERR "$currtime Benchmark ended (ubench).\n";
}

sub nbenchmark
{
	my $currtime = tim();
	print STDERR "$currtime Starting Benchmark (nbench)...\n";
	
	# create the config file
	open(CONFIG, ">CONFIG.NBENCH") or MMisc::error_quit("cannot open config file for nbench");
	print CONFIG "ALLSTATS=F\n";
	print CONFIG "CUSTOMRUN=T\n";
	print CONFIG "OUTFILE=NBENCH.DATA\n";
	print CONFIG "DONUMSORT=T\n";
	print CONFIG "DOSTRINGSORT=T\n";
	print CONFIG "DOBITFIELD=T\n";
	print CONFIG "DOEMF=T\n";
	print CONFIG "DOFOUR=T\n";
	print CONFIG "DOASSIGN=T\n";
	print CONFIG "DOIDEA=T\n";
	print CONFIG "DOHUFF=T\n";
	print CONFIG "DONNET=F\n";
	print CONFIG "DOLU=T\n";
	close(CONFIG);
	
	system("$nbench -cCONFIG.NBENCH >> /dev/null ");
	unlink("CONFIG.NBENCH");
	
	open(NBENCHDATA, "NBENCH.DATA") or MMisc::error_quit("cannot open data file from nbench");
	
	my %nbenchdata;
	
	while(<NBENCHDATA>)
	{
		chomp;
		$nbenchdata{NUMSORT} = $1 if($_ =~ /^NUMERIC SORT.* (\d+\.\d+)$/);
		$nbenchdata{STRINGSORT} = $1 if($_ =~ /^STRING SORT.* (\d+\.\d+)$/);
		$nbenchdata{BITFIELD} = $1 if($_ =~ /^BITFIELD.* (\d+\.\d+)$/);
		$nbenchdata{EMF} = $1 if($_ =~ /^FP EMULATION.* (\d+\.\d+)$/);
		$nbenchdata{FOUR} = $1 if($_ =~ /^FOURIER.* (\d+\.\d+)$/);
		$nbenchdata{ASSIGN} = $1 if($_ =~ /^ASSIGNMENT.* (\d+\.\d+)$/);
		$nbenchdata{IDEA} = $1 if($_ =~ /^IDEA.* (\d+\.\d+)$/);
		$nbenchdata{HUFF} = $1 if($_ =~ /^HUFFMAN.* (\d+\.\d+)$/);
		$nbenchdata{LU} = $1 if($_ =~ /^LU DECOMPOSITION.* (\d+\.\d+)$/);
	}
	
	close(NBENCHDATA);
	unlink("NBENCH.DATA");
	
	my $sum = 0;
	my $prod = 1;
	
	foreach my $test (keys %nbenchdata)
	{
		$sum += $nbenchdata{$test};
		$prod *= $nbenchdata{$test};
	}
	
	my $mean = sprintf("%.2f", $sum/(keys %nbenchdata));
	my $geomean = sprintf("%.2f", $prod**(1/(keys %nbenchdata)));
	$sum = sprintf("%.2f", $sum);
	$prod = sprintf("%.2f", $prod);
	
	foreach my $test (keys %nbenchdata) { print "$test,"; }
	print "SUM,PROD,MEAN,GEOMEAN\n";
	foreach my $test (keys %nbenchdata) { print "$nbenchdata{$test},"; }
	print "$sum,$prod,$mean,$geomean\n";
	
	$currtime = tim();
	print STDERR "$currtime Benchmark ended (nbench).\n";
}

sub run
{
	my ($command_to_run) = @_;
	my $t0 = [gettimeofday()];
	system("$command_to_run");
	my $elapsed = tv_interval ($t0, [gettimeofday()]);
	return $elapsed;
}

sub run_exec
{
	my ($runcmd, $niter) = @_;
	my %TimesExec;
	
	foreach my $res ("min", "max", "mean", "rel2stderr", "stddev")
	{
		$TimesExec{$res} = 0;
	}
	
	for(my $i=0; $i<$niter; $i++)
	{
		my $iternum = $i+1;
		my $tim = tim();
		print STDERR "$tim Exec iteration #$iternum/$niter... ";
		my $outtime = run("$runcmd");

		$TimesExec{min} = $outtime if( ($i == 0) || ($outtime < $TimesExec{min}) );
		$TimesExec{max} = $outtime if( ($i == 0) || ($outtime > $TimesExec{max}) );
		$TimesExec{mean} += $outtime;
		$TimesExec{stddev} += $outtime * $outtime;
		
		my $tmpmean = sprintf("%.8f", $TimesExec{mean}/($i+1) );
		my $tmpstdev = sprintf("%.8f", sqrt( ($TimesExec{stddev}/($i+1)) - ($tmpmean*$tmpmean) ) );
		my $tempstderr = sprintf("%.2f%%", 200*$tmpstdev/($tmpmean*sqrt($i+1)) );
		print STDERR "Relative 2SE: $tempstderr\n";
	}
	
	my $tmpmean = sprintf("%.8f", $TimesExec{mean}/$niter);
	$TimesExec{mean} = sprintf("%.6f", $tmpmean);
	my $tmpstdev = sprintf("%.8f", sqrt( ($TimesExec{stddev}/$niter) - ($tmpmean * $tmpmean) ));
	$TimesExec{stddev} = sprintf("%.6f", $tmpstdev);
	$TimesExec{rel2stderr} = sprintf("%.8f", 2*$tmpstdev/($tmpmean*sqrt($niter)));
	
	my $legend = "exec";
	
	foreach my $res ("mean", "stddev", "rel2stderr", "min", "max")
	{
		$legend .= ",time" . "_$res";
	}
	
	print "$legend\n";
	
	my $out = "s";
	$out = "m" if($multicore);
	
	foreach my $res ("mean", "stddev", "rel2stderr", "min", "max")
	{
		$out .= ",$TimesExec{$res}";
	}
	
	print "$out\n";
}

# System Information
$ios = info_os();
$incpu = info_ncpu();
$ifcpu = info_fcpu();
$imem = info_mem();

print STDERR "OS:     $ios\n";
print STDERR "CPU(s): $incpu x $ifcpu MHz\n";
print STDERR "MEM:    $imem MB\n";

# Run The benchmark
if($ubenchRun)
{
	$ubench = check_exec($ubench);
	ubenchmark();
}

if($nbenchRun)
{
	$nbench = check_exec($nbench);
	nbenchmark();
}

run_exec($ascliteRunCommand, $IterAsclite) if($ascliteRun);
run_exec($ffmpegRunCommand, $IterFFmpeg) if($FFmpegRun);

MMisc::ok_exit();
