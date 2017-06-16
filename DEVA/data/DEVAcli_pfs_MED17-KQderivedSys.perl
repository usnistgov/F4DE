# DEVA_cli MED15 Profile add for required checks

$VAR1 = 
  [
   'During MED15 derivedSys System CSV configuration generation',
   '^newtable\:\s+detection$', "Issue finding one of the two expected table name (\'detection\')",
   '^newtable\:\s+threshold$', "Issue finding one of the two expected table name (\'threshold\')",
   # columns expected in detection
   '^column\:\s+TrialID\;', "Problem with \'TrialID\' column",
   '^column\:\s+Rank\;INT', "Problem with \'Rank\' column (expected type: INT)",
   '^\#\s+Primary\s+key\s+candidate\(s\)\:[\s\w_]*?\s+TrialID', "Problem with \'TrialID\' column (not a primary key ?)",
   # columns expected in threshold
   '^column\:\s+EventID\;', "Problem with \'EventID\' column",
   '^column\:\s+DetectionTPT\;', "Problem with \'DetectionTPT\' column",
   '^column\:\s+SEARCHMDTPT\;', "Problem with \'SEARCHMDTPT\' column",
   '^\#\s+Primary\s+key\s+candidate\(s\)\:[\s\w_]*?\s+EventID', "Problem with \'EventID\' column (not a primary key ?)"
  ];
