INSERT OR ABORT INTO ThresholdTable ( BlockID, Threshold) SELECT threshold.EventID, threshold.RankThreshold Threshold FROM systemDB.threshold;
