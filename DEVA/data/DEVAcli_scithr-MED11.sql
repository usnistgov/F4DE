INSERT OR ABORT INTO ThresholdTable ( BlockID, Threshold) SELECT threshold.EventID,threshold.DetectionThreshold FROM systemDB.threshold;
