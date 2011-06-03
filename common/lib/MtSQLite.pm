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

use MMisc;
use CSVHelper;

# No 'new', simply functions

##########
my $sqlitecmdb = "sqlite3";
my $sqlitecmd = "";
my $sqliteminv = "3.6.12";

sub set_sqlitecmd {
  $sqlitecmd = $_[0];
  return(&__check_sqlite());
}

##
sub get_sqlitecmd { 
  return("", $sqlitecmd)
    if (! MMisc::is_blank($sqlitecmd));

  $sqlitecmd = MMisc::cmd_which($sqlitecmdb);
  my ($err, $v) = &__check_sqlite();
  return($err, $sqlitecmd, $v);
}

##
sub __check_sqlite {
  return("No SQLite command location information")
    if (MMisc::is_blank($sqlitecmd));

  my $cmd = "$sqlitecmd --version";
  my ($rc, $so, $se) = MMisc::do_system_call($cmd);
  return("Problem obtaining SQLite ($sqlitecmd) version [using: $cmd]")
    if ($rc != 0);
  chomp($so);

  my ($err, $bv) = MMisc::get_version_comp($sqliteminv, 4, 1000);
  return("Problem obtaining default version number") 
    if (! MMisc::is_blank($err));
  my ($err, $cv) = MMisc::get_version_comp($so, 4, 1000);
  return("Problem obtaining comparable version number") 
    if (! MMisc::is_blank($err));
  
  return("Version of SQLite ($so) [at: $sqlitecmd] is not at least minimum required version ($sqliteminv)")
    if ($cv < $bv);

  return("", $so);
}

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
  # arg 0 : dbh

  # jut to be safe if there were any changes made to the DB
  # commit before disconnecting
  $_[0]->commit();
  $_[0]->disconnect();
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

sub get_column_names {
  my ($dbh, $table) = @_;

  my $sth = $dbh->prepare("SELECT * FROM $table LIMIT 1") 
    or return("Problem obtaining column names : " . $dbh->errstr());
  $sth->execute();

  my $fields = $sth->{NUM_OF_FIELDS};

  my @colsname = ();
  for (my $i = 0; $i < $fields; $i++ ) {
    push @colsname, $sth->{NAME}->[$i];
  }

  $sth->finish();

  return("", @colsname);
}

#####

sub insertCSV {
  my ($dbh, $csvfile, $tablename, @columnsname) = @_;
  return(&insertCSV($$dbh, $csvfile, $tablename, 0, @columnsname));
}

##

sub insertCSV_NULLfields {
  my ($dbh, $csvfile, $tablename, @columnsname) = @_;
  return(&insertCSV($$dbh, $csvfile, $tablename, 1, @columnsname));
}  

##

sub insertCSV_handler {
  my ($dbh, $csvfile, $tablename, $nullmode, @columnsname) = @_;

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
    or return("Problem with CSV file ($csvfile): $!", 0);

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

  # Check columns match
  my ($err, @itcn) = &get_column_names($dbh, $tablename);
  return($err, 0) if (! MMisc::is_blank($err));
  
  return("More columns in CSV (" . scalar @columnsname . "[" . join(" | ", @columnsname) ."]) than table ($tablename) list (" . scalar @itcn . "[" . join(" | ", @itcn) ."])", 0)
    if (scalar @itcn < scalar @columnsname);

  my ($err, %match) = MMisc::get_array1posinarray2(\@columnsname, \@itcn);
  return($err) if (! MMisc::is_blank($err));

  # process csv rows
  my $inserted = 0;
  my $ac = "(" . join(",", @columnsname) . ")";
  my $qm = "(";
  for (my $i = 0; $i < scalar @columnsname - 1; $i++) { $qm .= "?,"; }
  $qm .= "?)";
  my $sth = $dbh->prepare("INSERT INTO $tablename $ac VALUES $qm");

  while (my $line = <CSV>) {
    my @fields = $csvh->csvline2array($line);
    return("Problem with CSV line extraction: " . $csvh->get_errormsg(), 0)
      if ($csvh->error());

    if ($nullmode) {
      for (my $i = 0; $i < scalar @fields; $i++) {
        $fields[$i] = undef if ($fields[$i] eq '');
      }
    }

    $inserted += $sth->execute(@fields)
      or return("Problem trying to execute SQL statement: " . $dbh->errstr(), 0);

    my $err = $sth->errstr();
    return("Problem during CSV line insert (row: $inserted): $err", 0)
      if (! MMisc::is_blank($err));

    my $err = $dbh->errstr();
    return("Problem during CSV line insert (row: $inserted): $err", 0)
      if (! MMisc::is_blank($err));
  }

  # only commit here
  $dbh->commit();

  return("", $inserted);
}

#####

sub dumpCSV {
  my ($dbh, $table, $csvfile) = @_;

  return("No DB handler") 
    if (! defined $dbh);
  
  my $err = $dbh->errstr();
  return("Problem with DB handler: $err")
    if (! MMisc::is_blank($err));
  
  my $csvh = new CSVHelper();
  return("Problem obtaining a CSV handler", 0) if (! defined $csvh);
  return("Problem with CSV handler: " . $csvh->get_errormsg(), 0)
    if ($csvh->error());

  open CSV, ">$csvfile"
    or return("Problem with CSV file ($csvfile): $!", 0);

  # Header
  my ($err, @colsname) = &get_column_names($dbh, $table);
  return($err, 0) if (! MMisc::is_blank($err));

  $csvh->set_number_of_columns(scalar @colsname);
  return("Problem with CSV handler: " . $csvh->get_errormsg(), 0)
    if ($csvh->error());
  
  my $text = $csvh->array2csvline(@colsname);
  return("Problem with CSV handler: " . $csvh->get_errormsg(), 0)
    if ($csvh->error());

  print CSV "$text\n";

  ## Data
  my $sth = $dbh->prepare("SELECT * FROM $table") 
    or return("Problem obtaining column names : " . $dbh->errstr());
  $sth->execute();

  my $inc = 0;
  my $doit = 1;
  while ($doit) {
    my @data = $sth->fetchrow_array();
    if (scalar @data == 0) {
      $doit = 0;
      next;
    }

    my $text = $csvh->array2csvline(@data);
    return("Problem with CSV handler: " . $csvh->get_errormsg(), 0)
      if ($csvh->error());
    print CSV "$text\n";
    
    $inc++;
#    print "\r $inc     ";
  }
  close CSV;
  my $err = $sth->errstr();
  return("Problem with Statement handler: $err")
    if (! MMisc::is_blank($err));
  $sth->finish();
  my $err = $dbh->errstr();
  return("DB handler: $err")
    if (! MMisc::is_blank($err));
  
  return("", $inc);
}

##########

sub doOneCommand {
  my ($dbh, $cmd) = @_;

  return("No DB handler") 
    if (! defined $dbh);

  my $err = $dbh->errstr();
  return("Problem with DB handler: $err")
    if (! MMisc::is_blank($err));

#  print "[$cmd]\n";
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
  # arg 0 : cmd
  my $tcmd = MMisc::clean_begend_spaces($_[0]);
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
  
#  print "* Generated temporary command file used for $sqlitecmdb call: $tf\n";
  my $lf = "$tf.logfile";
  my ($ok, $otxt, $so, $se, $rc, $of) = 
    MMisc::write_syscall_smart_logfile($lf, "$sqlitecmd $dbfile < $tf");

#  print "* Log file for $sqlitecmdb call: $of\n";
  if ((! $ok) || ($rc != 0)) {
    my $logc = MMisc::slurp_file($of);
    return
      ("There was a problem running the sqlite commands\n"
       . "----- The run/error log (located: $of) is:\n$logc\n\n"
       . "----- The command runs (located: $tf) were:\n$cmdlist\n"
      );
  }

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
    or return("Could not prepare statement: " . $dbh->errstr(), undef);
  
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
    or return("Could not execute statement: " . $sth->errstr());

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

########################################

sub select_helper__count_rows {
  my ($dbfile, $tablename, $subselect, @columns) = @_;
  return(&__select_helper($dbfile, undef, undef, $tablename, $subselect, @columns));
}

##

sub select_helper__to_hash {
  my ($dbfile, $rh, $tablename, $subselect, @columns) = @_;
  return(&__select_helper($dbfile, $rh, undef, $tablename, $subselect, @columns));
}

##

sub select_helper__to_array {
  my ($dbfile, $ra, $tablename, $subselect, @columns) = @_;
  return(&__select_helper($dbfile, undef, $ra, $tablename, $subselect, @columns));
}

##

sub __select_helper {
  my ($dbfile, $rh, $ra, $tablename, $subselect, @columns) = @_;
  
  my ($err, $dbh) = &get_dbh($dbfile);
  return($err)
    if (! MMisc::is_blank($err));

  my $cmd = "SELECT " . join(",", @columns) . " FROM $tablename"
    . ((! MMisc::is_blank($subselect)) ? " $subselect" : "");

  my ($err, $sth) = &get_command_sth($dbh, $cmd);
  return("Problem doing a SELECT on \'$tablename\': $err")
   if (! MMisc::is_blank($err));

  my $err = &execute_sth($sth);
  return("Problem processing SELECT on \'$tablename\': $err")
    if (! MMisc::is_blank($err));

  my $tidc = 0;
  my $doit = 1;
  while ($doit) {
    my ($err, @data) = &sth_fetchrow_array($sth);
    return("Problem obtaining row (#" . 1 + $tidc . "): $err")
      if (! MMisc::is_blank($err));
    if (scalar @data == 0) {
      $doit = 0;
      next;
    }

    if (defined $rh) {
      my $mk = $data[0]; # _must be_ a primary key
      for (my $i = 1; $i < scalar @columns; $i++) {
        my $c = $columns[$i];
        my $v = $data[$i];
        return("In DB ($dbfile)'s table ($tablename), $mk / $c = $v was already found and its previous value was different : " . $$rh{$mk}{$c})
            if ((MMisc::safe_exists($rh, $mk, $c)) && ($$rh{$mk}{$c} ne $v));
        $$rh{$mk}{$c} = $v;
#      print "# $mk / $c / $v\n";
      }
    }

    if (defined $ra) {
      push @$ra, [ @data ];
    }

    $tidc++;
  }

  my $err = &sth_finish($sth);
  return("Problem while completing statement: $err")
    if (! MMisc::is_blank($err));

  &release_dbh($dbh);

  return("", $tidc);
}

########################################


sub get_sth_error { return($_[0]->errstr()); }

sub get_errormsg { return($_[0]->errstr()); }

############################################################
1;
