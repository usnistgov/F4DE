-- y Targ
INSERT OR ABORT INTO System ( TrialID, Score, Decision ) 
  SELECT detection.TrialID, Score, 'y' FROM detection INNER JOIN metadata, threshold
    WHERE (detection.TrialID == metadata.TrialID AND metadata.Block==threshold.EventID AND Score > threshold.DetectionThreshold);

-- n Targ
INSERT OR ABORT INTO System ( TrialID, Score, Decision ) 
  SELECT detection.TrialID, Score, 'n' FROM detection INNER JOIN metadata, threshold
    WHERE (detection.TrialID == metadata.TrialID AND metadata.Block==threshold.EventID AND Score <= threshold.DetectionThreshold);
