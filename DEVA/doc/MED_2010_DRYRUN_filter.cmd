SELECT system.TrialID,DRYRUN_TrialIndex.Event FROM DRYRUN_TrialIndex INNER JOIN system WHERE system.TrialID==DRYRUN_TrialIndex.TrialID;
