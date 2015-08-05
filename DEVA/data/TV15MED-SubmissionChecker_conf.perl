$expid_count = 8;
@expid_tag  = ( 'MED15' ); # should only contain 1 entry
@expid_data = ( 'MED15DRYRUN', 'MED15EvalSub', 'MED15EvalFull' ); # <SEARCH> order is important
@expid_task = ( 'PS', 'AH', 'iAH' ); # <EVENTSET> order is important
@expid_traintype = ( '100Ex', '10Ex', '0Ex' ); # <EKTYPE> order is important
@expid_hardwaretype = ( 'SML', 'MED', 'LRG' ); # <SMGHW> order is important

@expected_dir_output = ( "output" );
$expected_csv_per_expid = 2;
@expected_csv_names = ( 'detection', 'threshold' );

$medtype_fullcount = 0;
$medtype_fullcount_perTask{$expid_data[0]}{$expid_task[0]} = 3;
$medtype_fullcount_perTask{$expid_data[0]}{$expid_task[1]} = -1; # not a valid case
$medtype_fullcount_perTask{$expid_data[0]}{$expid_task[2]} = -1; # not a valid case
$medtype_fullcount_perTask{$expid_data[1]}{$expid_task[0]} = 20;
$medtype_fullcount_perTask{$expid_data[1]}{$expid_task[1]} = 10;
$medtype_fullcount_perTask{$expid_data[1]}{$expid_task[2]} = 10;
$medtype_fullcount_perTask{$expid_data[2]}{$expid_task[0]} = 20;
$medtype_fullcount_perTask{$expid_data[2]}{$expid_task[1]} = 10;
$medtype_fullcount_perTask{$expid_data[2]}{$expid_task[2]} = 10;

$db_check_sql = "TV15MED-SubmissionChecker_conf-DBcheck.sql";

# Order is important: tablename, columnname [, columname ...]
@db_eventidlist = ("EventIDList", "EventID");
@db_missingTID  = ("missingTrialID", "TrialID");
@db_unknownTID  = ("unknownTrialID", "TrialID");
@db_detectionTID = ("detectionTrialID", "TrialID");
@db_thresholdEID = ("thresholdEventID", "EventID");
@db_checkSEARCHMDTPT = ("checkSEARCHMDTPT", "SEARCHMDTPT");
@db_checkRanksdup = ("dupRanks", "EventID", "Rank", "COUNT(*)");
