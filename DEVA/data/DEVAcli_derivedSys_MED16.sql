INSERT OR ABORT INTO System ( TrialID, Rank)
  SELECT TrialID, Rank FROM detection;
