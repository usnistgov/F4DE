INSERT OR ABORT INTO System ( TrialID, Score, Decision )
  SELECT detection.TrialID, Score, 'y' FROM detection;
