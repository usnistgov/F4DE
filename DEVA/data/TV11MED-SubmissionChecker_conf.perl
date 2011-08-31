@expid_tag  = ( 'MED11' );
@expid_data = ( 'DRYRUN', 'DEVT', 'MED11TEST' ); # order is important
@expid_MEDtype = ( 'MEDFull', 'MEDPart' ); # order is important
@expid_EAG = ( 'AutoEAG', 'SemiAutoEAG' );
@expid_sysid_beg = ( "p-", "c-" );

@expected_dir_output = ( "output" );
$expected_csv_per_expid = 2;
@expected_csv_names = ( 'detection', 'threshold' );
$medtype_fullcount = 10;

$pc_check = 1;

$db_check_sql = "TV11MED-SubmissionChecker_conf-DBcheck.sql";

# Order is important: tablename, columnname [, columname ...]
@db_eventidlist = ("EventIDList", "EventID");
@db_missingTID  = ("missingTrialID", "TrialID");
@db_unknownTID  = ("unknownTrialID", "TrialID");
@db_detectionTID = ("detectionTrialID", "TrialID");
@db_thresholdEID = ("thresholdEventID", "EventID");

$max_expid = 4;
$max_expid_error = 0;
