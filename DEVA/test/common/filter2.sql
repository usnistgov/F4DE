INSERT OR ABORT INTO ResultsTable ( TrialID ) SELECT system.TrialID FROM system INNER JOIN md WHERE system.TrialID=md.TrialID AND Decision>"1.2" AND color="blue";

