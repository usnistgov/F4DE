INSERT OR ABORT INTO ResultsTable ( TrialID, BlockID ) SELECT system.TrialID,TrialIndex.EventID FROM TrialIndex INNER JOIN system WHERE system.TrialID==TrialIndex.TrialID;
