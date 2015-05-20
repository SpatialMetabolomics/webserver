DROP TABLE IF EXISTS formula_dbs;
CREATE TABLE formula_dbs (
	db_id		int,
	db			text
);
INSERT INTO formula_dbs VALUES (0, 'HMDB');

DROP TABLE IF EXISTS formulas;
CREATE TABLE formulas (
	db_id	int,
	id		text,
	sf_id 	int,
	name	text,
	sf 		text
);
\COPY formulas FROM '/home/snikolenko/soft/ims/webserver/newformulas.csv' WITH delimiter ';' quote '@' csv;

DROP TABLE IF EXISTS agg_formulas;
CREATE TABLE agg_formulas (
	-- id 			serial not null,
	id 			int,
	sf 			text,
	db_ids 		int[],
	subst_ids 	text[],
	names 		text[]
);
\COPY agg_formulas FROM '/home/snikolenko/soft/ims/webserver/agg_formulas.csv';
-- INSERT INTO agg_formulas (sf, db_ids, subst_ids, names) 
-- 	SELECT sf,array_agg(db_id) as db_ids,array_agg(id) as subst_ids,array_agg(name) as names
-- 	FROM formulas
-- 	GROUP BY sf
-- ;
CREATE INDEX ind_agg_formulas_1 ON agg_formulas (sf);

DROP TABLE IF EXISTS datasets;
CREATE TABLE datasets (
	dataset_id	int,
	dataset		text,
	filename	text,
	nrows		int,
	ncols		int
);
INSERT INTO datasets VALUES (0, 'test', '/media/data/ims/testdataset.txt', 51, 49);
INSERT INTO datasets VALUES (1, 'Ctrl3s2', '/media/data/ims/Ctrl3s2_SpheroidsCtrl_DHBSub_IMS.txt', 51, 49);
INSERT INTO datasets VALUES (2, 'Rat_brain', '/media/data/ims/Rat_brain_1M_50um_centroids_IMS.txt', 51, 49);
-- INSERT INTO datasets VALUES (0, 'test', '/home/snikolenko/soft/ims/data/testdataset.txt', 51, 49);
-- INSERT INTO datasets VALUES (1, 'Ctrl3s2', '/home/snikolenko/soft/ims/data/Ctrl3s2_SpheroidsCtrl_DHBSub_IMS.txt', 51, 49);
-- INSERT INTO datasets VALUES (2, 'Rat_brain', '/home/snikolenko/soft/ims/data/Rat_brain_1M_50um_centroids_IMS.txt', 51, 49);

DROP TABLE IF EXISTS coordinates;
CREATE TABLE coordinates (
	dataset_id 	int,
	index 		int,
	x 			int,
	y 			int
);
\COPY coordinates FROM '/home/snikolenko/soft/ims/data/Ctrl3s2_SpheroidsCtrl_DHBSub_IMS.coords.txt' WITH delimiter ';' quote '@' csv;
CREATE INDEX ind_coordinates_1 ON coordinates (dataset_id, index);
CREATE INDEX ind_coordinates_2 ON coordinates (dataset_id);
CREATE INDEX ind_coordinates_3 ON coordinates (index);

DROP TABLE IF EXISTS job_types;
CREATE TABLE job_types (
	type 		int,
	description	text
);
INSERT INTO job_types VALUES (0, 'Extracting m/z values');
INSERT INTO job_types VALUES (1, 'Full dataset m/z image extraction');

DROP TABLE IF EXISTS jobs;
CREATE TABLE jobs (
	id 			int,
	type		int,
	formula_id	int,
	dataset_id	int,
	done		boolean,
	status		text,
	tasks_done	int,
	tasks_total	int,
	start       timestamp,
	finish      timestamp
);
CREATE INDEX ind_jobs_1 ON jobs (id);
-- \COPY jobs FROM '/home/snikolenko/soft/ims/pySIN/frontend/jobs.csv' WITH delimiter ';' quote '@' csv;

DROP TABLE IF EXISTS job_result_data;
CREATE TABLE job_result_data (
	job_id			int,
	param			int,
	adduct 			int,
	peak			int,
	spectrum		int,
	value real
);
CREATE INDEX ind_job_result_data_1 ON job_result_data (job_id);
-- CREATE INDEX ind_job_result_data_2 ON job_result_data (job_id, param);
-- CREATE INDEX ind_job_result_data_3 ON job_result_data (job_id, param, peak);
-- CREATE INDEX ind_job_result_data_4 ON job_result_data (job_id, param, adduct);
CREATE INDEX ind_job_result_data_5 ON job_result_data (job_id, param, peak, adduct);


DROP TABLE IF EXISTS job_result_stats;
CREATE TABLE job_result_stats (
	job_id			int,
	formula_id		int,
	adduct 			int,
	param			int,
	stats 			json
);
CREATE INDEX ind_job_result_stats_1 ON job_result_stats (job_id);
CREATE INDEX ind_job_result_stats_2 ON job_result_stats (job_id, formula_id);

DROP TABLE IF EXISTS mz_peaks;
CREATE TABLE mz_peaks (
	sf_id			int,
	adduct			int,
	peaks			real[],
	ints			real[]
);
\COPY mz_peaks FROM '/home/snikolenko/soft/ims/webserver/mzpeaks.csv' WITH delimiter ';' csv;
CREATE INDEX ind_mz_peaks_1 ON mz_peaks(sf_id, adduct);
CREATE INDEX ind_mz_peaks_2 ON mz_peaks(sf_id);

-- SELECT f.id,name,sf,peaks,ints,array_agg(d.dataset_id) as dataset_ids,array_agg(dataset) as datasets,array_agg(stats) as stats FROM formulas f JOIN mz_peaks p ON f.id=p.formula_id LEFT JOIN job_result_stats s ON f.id=s.formula_id LEFT JOIN jobs j ON s.job_id=j.id LEFT JOIN datasets d ON j.dataset_id=d.dataset_id WHERE f.id='10705' GROUP BY f.id,name,sf,peaks,ints;



-- explain analyze SELECT s.job_id,s.formula_id,peak,array_agg(x) as x,array_agg(y) as y,array_agg(value) as val
--     FROM job_result_stats s 
--             JOIN job_result_data d ON s.job_id=d.job_id 
--     		JOIN jobs j ON d.job_id=j.id 
-- 			JOIN coordinates c ON j.dataset_id=c.dataset_id AND spectrum=c.index
--     WHERE d.job_id=5 AND s.formula_id='13676' AND d.param=13676
--     GROUP BY s.job_id,s.formula_id,peak;
