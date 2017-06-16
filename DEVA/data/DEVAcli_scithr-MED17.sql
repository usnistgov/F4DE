INSERT OR ABORT INTO ThresholdTable ( BlockID ) SELECT threshold.EventID FROM systemDB.threshold;
