$expid_count = 7;
@expid_tag  = ( 'MED14' ); # should only contain 1 entry
@expid_sys = ( 'noPRF', 'PRF' ); # order is important
@expid_data = ( 'MED14DRYRUN', 'MED14Sub', 'MED14Full' ); # <SEARCH> order is important
@expid_task = ( 'PS', 'AH' ); # <EVENTSET> order is important
@expid_traintype = ( '100Ex', '10Ex', '0Ex', 'SQ' ); # <EKTYPE> order is important

@expected_dir_output = ( "output" );
$expected_csv_per_expid = 2;
@expected_csv_names = ( 'detection', 'threshold' );

$medtype_fullcount = 0;
$medtype_fullcount_perTask{$expid_data[0]}{$expid_task[0]} = 3;
$medtype_fullcount_perTask{$expid_data[0]}{$expid_task[1]} = -1; # not a valid case
$medtype_fullcount_perTask{$expid_data[1]}{$expid_task[0]} = 20;
$medtype_fullcount_perTask{$expid_data[1]}{$expid_task[1]} = 20;
$medtype_fullcount_perTask{$expid_data[2]}{$expid_task[0]} = 20;
$medtype_fullcount_perTask{$expid_data[2]}{$expid_task[1]} = 20;

$db_check_sql = "TV13MED-SubmissionChecker_conf-DBcheck.sql";

# Order is important: tablename, columnname [, columname ...]
@db_eventidlist = ("EventIDList", "EventID");
@db_missingTID  = ("missingTrialID", "TrialID");
@db_unknownTID  = ("unknownTrialID", "TrialID");
@db_detectionTID = ("detectionTrialID", "TrialID");
@db_thresholdEID = ("thresholdEventID", "EventID");
@db_checkSEARCHMDTPT = ("checkSEARCHMDTPT", "SEARCHMDTPT");

# ## MER
# $mer_subcheck = MMisc::get_file_actual_dir($0) . "/MER-SubmissionChecker.sh";

# # MED13DRYRUN / FullSys / PS / 100Ex
# $mer_ok_expid{$expid_data[0]}{$expid_sys[0]}{$expid_task[0]}{$expid_traintype[0]} = 1; 
# # PROGSub / FullSys / PS / 100Ex
# $mer_ok_expid{$expid_data[1]}{$expid_sys[0]}{$expid_task[0]}{$expid_traintype[0]} = 1; 
# # PROGAll / FullSys / PS / 100Ex
# $mer_ok_expid{$expid_data[2]}{$expid_sys[0]}{$expid_task[0]}{$expid_traintype[0]} = 1; 
