
DROP TABLE IF EXISTS EventIDList;
CREATE TABLE EventIDList AS SELECT DISTINCT EventID FROM systemDB.System INNER JOIN metadataDB.TrialIndex WHERE System.TrialID==TrialIndex.TrialID;

DROP TABLE IF EXISTS subTrialID;
CREATE TABLE subTrialID AS SELECT TrialID FROM metadataDB.TrialIndex INNER JOIN EventIDList WHERE TrialIndex.EventID==EventIDList.EventID;

DROP TABLE IF EXISTS missingTrialID;
CREATE TABLE missingTrialID AS SELECT TrialID FROM subTrialID WHERE TrialID NOT IN ( SELECT TrialID FROM System );

DROP TABLE IF EXISTS unknownTrialID;
CREATE TABLE unknownTrialID AS SELECT TrialID FROM System WHERE TrialID NOT IN ( SELECT TrialID FROM subTrialID );

DROP TABLE IF EXISTS detectionTrialID;
CREATE TABLE detectionTrialID AS SELECT TrialID FROM detection WHERE TrialID NOT IN ( SELECT TrialID FROM System );

DROP TABLE IF EXISTS thresholdEventID;
CREATE TABLE thresholdEventID AS SELECT EventID FROM threshold WHERE EventID NOT IN ( SELECT EventID FROM EventIDList );
