-- y Targ
INSERT OR ABORT INTO System ( TrialID, Score, Decision )
  SELECT detection.TrialID, Score, 'y' FROM detection INNER JOIN TrialIndex, threshold
    WHERE (detection.TrialID == TrialIndex.TrialID AND TrialIndex.EventID==threshold.EventID AND Score > threshold.DetectionThreshold);

-- n Targ
INSERT OR ABORT INTO System ( TrialID, Score, Decision )
  SELECT detection.TrialID, Score, 'n' FROM detection INNER JOIN TrialIndex, threshold
    WHERE (detection.TrialID == TrialIndex.TrialID AND TrialIndex.EventID==threshold.EventID AND Score <= threshold.DetectionThreshold);
