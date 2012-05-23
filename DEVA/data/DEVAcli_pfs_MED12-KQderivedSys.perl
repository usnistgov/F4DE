# DEVA_cli MED12 Profile add for required checks

$VAR1 = 
  [
   'During MED12 derivedSys System CSV configuration generation',
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
   '^column\:\s+EAGTP\;', "Problem with \'EAGTP\' column",
   '^\#\s+Primary\s+key\s+candidate\(s\)\:[\s\w_]*?\s+EventID', "Problem with \'EventID\' column (not a primary key ?)"
  ];
