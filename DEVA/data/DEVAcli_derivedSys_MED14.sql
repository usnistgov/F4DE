-- y Targ
INSERT OR ABORT INTO System ( TrialID, Score, Rank, Decision)
  SELECT detection.TrialID, Score, Rank, 'y' FROM detection INNER JOIN TrialIndex, threshold
    WHERE (detection.TrialID == TrialIndex.TrialID AND TrialIndex.EventID==threshold.EventID AND Rank < threshold.RankThreshold);

-- n Targ
INSERT OR ABORT INTO System ( TrialID, Score, Rank, Decision )
  SELECT detection.TrialID, Score, Rank, 'n' FROM detection INNER JOIN TrialIndex, threshold
    WHERE (detection.TrialID == TrialIndex.TrialID AND TrialIndex.EventID==threshold.EventID AND Rank >= threshold.RankThreshold);
