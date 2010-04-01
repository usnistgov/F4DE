package MtSQLite;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# M's tiny SQLite Functions
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "MtSQLite.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

use DBI;
use SQL::Abstract;

use MMisc;
use CSVHelper;

# No 'new', simply functions

##########

sub get_dbh {
  my ($dbfile) = @_;

  my $dbh = DBI->connect
    ("dbi:SQLite:dbname=$dbfile", "", "",
     { RaiseError => 1, PrintError => 0 , sqlite_unicode => 1, # just to be safe
       AutoCommit => 0, # speeds up things but we have to force commits
     }) or return("Can not connect to DB", undef);

  return("", $dbh);
}

#######

sub release_dbh {
  my ($dbh) = @_;

  # jut to be safe if there were any changes made to the DB
  # commit before disconnecting
  $dbh->commit();
  $dbh->disconnect();
}

#####

sub fix_entries {
  my @out = ();
  for (my $i = 0; $i < scalar @_; $i++) {
    my $v = $_[$i];
    $v =~ s%[^a-z0-9_]%_%ig;
    push @out, $v;
  }
  return(@out);
}

##########

sub insertCSV {
  my ($dbh, $csvfile, $tablename, @columnsname) = @_;

  return("No DB handler") 
    if (! defined $dbh);
  
  my $err = $dbh->errstr();
  return("Problem with DB handler: $err")
    if (! MMisc::is_blank($err));
  
  my $err = MMisc::check_file_r($csvfile);
  return("Problem with CSV file ($csvfile): $err", 0)
    if (! MMisc::is_blank($err));

  my $csvh = new CSVHelper();
  return("Problem obtaining a CSV handler", 0) if (! defined $csvh);
  return("Problem with CSV handler: " . $csvh->get_errormsg(), 0)
    if ($csvh->error());
  open CSV, "<$csvfile"
    or MMisc::error_quit("Problem with CSV file ($csvfile): $!", 0);

  my $line = <CSV>;
  my @csvheader = $csvh->csvline2array($line);
  return("Problem with CSV header extraction: " . $csvh->get_errormsg(), 0)
    if ($csvh->error());
  return("No header in CSV", 0)
    if (scalar @csvheader == 0);
  my @tmpa = MMisc::make_array_of_unique_values(\@csvheader);
  return("Header has multiple columns with the same name ? [".join(" | ", @csvheader)."]", 0)
    if (scalar @tmpa != scalar @csvheader);
  $csvh->set_number_of_columns(scalar @csvheader);

  @columnsname = &fix_entries(@csvheader)
    if (scalar @columnsname == 0);
  
  return("Not the same number of columns in file (" . scalar @csvheader . "[" . join(" | ", @csvheader) ."]) vs provided list (" . scalar @columnsname . "[" . join(" | ", @columnsname) ."])", 0)
    if (scalar @csvheader != scalar @columnsname);

  $dbh->do('begin');
  my $sql = SQL::Abstract->new;
  # process csv rows
  my $inserted = 0;
  while (my $line = <CSV>) {
    my %fieldvals = $csvh->csvline2hash($line, \@columnsname);
    return("Problem with CSV line extraction: " . $csvh->get_errormsg(), 0)
      if ($csvh->error());

    # SQL::Abstract sets up the DBI variables
    my ($stmt, @bind) = $sql->insert($tablename, \%fieldvals);
    
    # insert the row
    my $sth = $dbh->prepare($stmt);
    $inserted += $sth->execute(@bind);

    my $err = $sth->errstr();
    return("Problem whie CSV line insert (row: $inserted) [command: $stmt]: $err", 0)
      if (! MMisc::is_blank($err));

    my $err = $dbh->errstr();
    return("Problem whie CSV line insert (row: $inserted): $err", 0)
      if (! MMisc::is_blank($err));
  }

  # only commit here
  $dbh->commit();

  return("", $inserted);
}

##########

sub doOneCommand {
  my ($dbh, $cmd) = @_;

  return("No DB handler") 
    if (! defined $dbh);

  my $err = $dbh->errstr();
  return("Problem with DB handler: $err")
    if (! MMisc::is_blank($err));

  $dbh->do($cmd);
  my $err = $dbh->errstr();
  return("Problem with command processing: $err")
    if (! MMisc::is_blank($err));

  # safety first ... commit
  $dbh->commit();

  return("");
}

####################

sub _fixcmd {
  my ($cmd) = @_;

  my $tcmd = MMisc::clean_begend_spaces($cmd);
  $tcmd .= ";" if ($tcmd !~ m%\;$%);

  return($tcmd);
}

##

sub commandAdd {
  my ($rstr, $cmd) = @_;

  my $tcmd = &_fixcmd($cmd);

  $$rstr .= "/* New command */\n";
  $$rstr .= "$tcmd\n";
}

#####

sub sqliteCommands {
  my ($sqlitecmd, $dbfile, $cmdlist) = @_;

  my $tf = MMisc::get_tmpfilename();
  return("Problem obtaining a temporary file")
    if (MMisc::is_blank($tf));

  return("Problem writing command file ($tf)")
    if (! MMisc::writeTo($tf, "", "", "", $cmdlist));
  
#  print "* Generated temporary command file used for sqlite3 call: $tf\n";
  my $lf = "$tf.logfile";
  my ($ok, $otxt, $so, $se, $rc, $of) = 
    MMisc::write_syscall_smart_logfile($lf, "$sqlitecmd $dbfile < $tf");

#  print "* Log file for sqlite3 call: $of\n";
  return("There was a problem running the sqlite commands, see: $of")
    if ((! $ok) || ($rc != 0));

  return("", $of, $so, $se);
}

####################

sub get_command_sth {
  my ($dbh, $cmd) = @_;

  return("No DB handler") 
    if (! defined $dbh);

  my $err = $dbh->errstr();
  return("Problem with DB handler: $err")
    if (! MMisc::is_blank($err));

  my $sth = $dbh->prepare($cmd)
    or return("Could not prepare statement: " . $dbh->errstr, undef);
  
  return("", $sth);
}

#####

sub execute_sth {
  my ($sth, @parameters) = @_;

  return("No Statement handler") 
    if (! defined $sth);

  my $err = $sth->errstr();
  return("Problem with Statement handler: $err")
    if (! MMisc::is_blank($err));
 
  $sth->execute(@parameters)
    or return("Could not execute statement: " . $sth->errstr);

  return("");
}

#####

sub sth_fetchrow_array {
  my ($sth) = @_;

  return("No Statement handler") 
    if (! defined $sth);

  my $err = $sth->errstr();
  return("Problem with Statement handler: $err")
    if (! MMisc::is_blank($err));

  return("", $sth->fetchrow_array());
}

#####

sub sth_finish {
  my ($sth) = @_;

  return("No Statement handler") 
    if (! defined $sth);

  my $err = $sth->errstr();
  return("Problem with Statement handler: $err")
    if (! MMisc::is_blank($err));

  $sth->finish();

  return("");
}

#####

sub get_sth_error { return($_[0]->errstr); }

####################

sub error {
  my ($dbh) = @_;

  my $err = $dbh->errstr();
  return(MMisc::is_blank($err));
}

##

sub get_errormsg {
  return($_[0]->errstr());
}

############################################################
1;
