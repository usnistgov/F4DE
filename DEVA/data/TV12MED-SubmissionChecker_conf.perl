$expid_count = 9;
@expid_tag  = ( 'MED12' ); # should only contain 1 entry
@expid_data = ( 'MED12DRYRUN', 'MED12TEST' ); # order is important
@expid_task = ( 'PS', 'AH' ); # order is important
@expid_MEDtype = ( 'MEDFull', 'MEDPart' ); # order is important
@expid_traintype = ( 'EKFull', 'EK10Ex' ); # order is important
@expid_EAG = ( 'AutoEAG', 'SemiAutoEAG' );
@expid_sysid_beg = ( "p-", "c-" ); # order is important

@expected_dir_output = ( "output" );
$expected_csv_per_expid = 2;
@expected_csv_names = ( 'detection', 'threshold' );
$medtype_fullcount = 0;
$medtype_fullcount_perTask{$expid_task[0]} = 20;
$medtype_fullcount_perTask{$expid_task[1]} = 5;

$pc_check = 1;

$db_check_sql = "TV12MED-SubmissionChecker_conf-DBcheck.sql";

# Order is important: tablename, columnname [, columname ...]
@db_eventidlist = ("EventIDList", "EventID");
@db_missingTID  = ("missingTrialID", "TrialID");
@db_unknownTID  = ("unknownTrialID", "TrialID");
@db_detectionTID = ("detectionTrialID", "TrialID");
@db_thresholdEID = ("thresholdEventID", "EventID");

$max_expid = 4;
$max_expid_error = 0;
