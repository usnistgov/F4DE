## MED11 profile settings and checks

{ # avoid injecting new variable into the main scope
  my %tmp_up = (
                'CostMiss=' => '1',
                'Ptarg=' => '0.5',
                'CostFA=' => '1',
               );
  foreach my $v (keys %tmp_up) {
    next if grep(m%^$v%, @usedmetparams);
    push @usedmetparams, $v . $tmp_up{$v};
  }
}
$taskName = 'MED'
  if (MMisc::is_blank($taskName));
$devadetname = 'EventID'
  if (MMisc::is_blank($devadetname));
$blockIDname = 'EventID'
  if (MMisc::is_blank($blockIDname));

## MED11 checks
MMisc::error_quit("When using \'MED11\' profile, \'dividedSys\' must be used")
  if (! defined $dividedSys);
MMisc::error_quit("For the \'MED11\' profile, two \'syscsv\' must be used")
  if (scalar @syscsvs != 2);

## 'dividedSys' Join SQL commands
$dividedSys = "$profiles_path/DEVAcli_dividedSys_MED11.sql"
  if (MMisc::is_blank($dividedSys));

# 'FilterCMDfile' SQL commands
$filtercmdfile = "$profiles_path/DEVAcli_filter-MED11.sql"
  if (MMisc::is_blank($fitercmdfile));

{ # avoid injecting new variable into the main scope
  my $err = MMisc::check_file_r($dividedSys);
  MMisc::error_quit("Problem with \'dividedSys\' SQL join file ($dividedSys) : $err")
      if (! MMisc::is_blank($err));
}

sub __constraints_placement__ {
  my ($errmsg, $ra, %__constraints) = @_;
  my @in = @$ra;
  my @out = ();
  foreach my $td (@in) {
    foreach my $ck (keys %__constraints) {
      if ($td =~ m%^([^\:]+?\:$ck)(\%.+)?$%) {
        $td = "$1\%" . $__constraints{$ck};
        delete $__constraints{$ck};
      }
    }
    push @out, $td;
  }
  MMisc::error_quit($errmsg . " : " . join(" ", keys %__constraints))
      if (scalar(keys %__constraints) > 0);
  return(@out);
}

{ # avoid injecting new variable into the main scope
  my %__constraints = ( 'detection' => 'Score:\'CHECK(Score>=0.0 AND Score <=1.0)\'' );
  @syscsvs = &__constraints_placement__
    ("Problem finding required \'--dividedSys\' table for \'MED11\' profile's column constraints",
     \@syscsvs, %__constraints);
}

{ # avoid injecting new variable into the main scope
  my %__constraints = ( 'TrialIndex' => 'TrialID:\'UNIQUE\'' );
  @csvlist = &__constraints_placement__
    ("Problem finding required Metadata table for \'MED11\' profile's column constraints",
     \@csvlist, %__constraints);
}

##########
# Config step mandatory checks
@Cfg_errorquit_divsys_checks = 
  ("During MED11 dividedSys System CSV configuration generation",
   '^newtable\:\s+detection$', "Issue finding one of the two expected table name (\'detection\')",
   '^newtable\:\s+threshold$', "Issue finding one of the two expected table name (\'threshold\')",
   # columns expected in detection
   '^column\:\s+TrialID\;', "Problem with \'TrialID\' column",
   '^column\:\s+Score\;REAL', "Problem with \'Score\' column (expected type: REAL)",
   '^\#\s+Primary\s+key\s+candidate\(s\)\:[\s\w_]*?\s+TrialID', "Problem with \'TrialID\' column (not a primary key ?)",
   # columns expected in threshold
   '^column\:\s+EventID\;', "Problem with \'EventID\' column",
   '^column\:\s+DetectionThreshold\;REAL', "Problem with \'DetectionThreshold\' column (expected type: REAL)",
   '^column\:\s+DetectionTPT\;', "Problem with \'DetectionTPT\' column",
   '^\#\s+Primary\s+key\s+candidate\(s\)\:[\s\w_]*?\s+EventID', "Problem with \'EventID\' column (not a primary key ?)",
);


########## END MED11 profile add-ons

