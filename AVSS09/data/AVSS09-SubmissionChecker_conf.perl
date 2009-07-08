@expected_year = ( "2009" );
@expected_task = ( "MCSPT", "SCSPT", "CPSPT" );
@expected_data = ( "DEV09", "EVAL09" );
@expected_lang = ( "ENG" );
@expected_sysid_beg = ( "p-", "c-" );

@expected_dir_output = ( "output" );

%expected_ecf_files = 
  (
   "CPSPT" => 
   {
    "DEV09"  => "expt_2009_CPSPT_DEV09_ENG_NIST_1.xml",
    "DRYRUN09" => "expt_2009_CPSPT_DRYRUN09_ENG_NIST_1.xml",
    "EVAL09" => "expt_2009_CPSPT_EVAL09_ENG_NIST_1.xml",
   },
   "MCSPT" =>
   {
    "DEV09"  => "expt_2009_MCSPT_DEV09_ENG_NIST_1.xml",
    "DRYRUN09" => "expt_2009_MCSPT_DRYRUN_ENG_NIST_1.xml", # Not DRYRUN09 on purpose
    "EVAL09" => "expt_2009_MCSPT_EVAL09_ENG_NIST_1.xml",
   },
   "SCSPT" =>
   {
    "DEV09"  => "expt_2009_SCSPT_DEV09_ENG_NIST_1.xml",
    "DRYRUN09" => "expt_2009_SCSPT_DRYRUN09_ENG_NIST_1.xml",
    "EVAL09" => "expt_2009_SCSPT_EVAL09_ENG_NIST_1.xml",
   },
);
