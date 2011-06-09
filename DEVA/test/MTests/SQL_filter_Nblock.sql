INSERT OR ABORT INTO ResultsTable ( TrialID,BlockID ) SELECT system.TrialID,metadata.Block FROM system INNER JOIN metadata WHERE system.TrialID=metadata.TrialID

