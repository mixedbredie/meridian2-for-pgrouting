-- SQL to build network
-- Adjust road speeds as required
-- Run VACUUM ANALYZE after all the changes to the table

-- Add come columns needed for pgRouting
ALTER TABLE os_m2.m2_roads
	ADD COLUMN source integer,
	ADD COLUMN target integer,
	ADD COLUMN speed_km integer,
	ADD COLUMN cost_len double precision,
	ADD COLUMN rcost_len double precision,
	ADD COLUMN cost_time double precision,
	ADD COLUMN rcost_time double precision,
	ADD COLUMN x1 double precision,
	ADD COLUMN y1 double precision,
	ADD COLUMN x2 double precision,
	ADD COLUMN y2 double precision,
	ADD COLUMN to_cost double precision,
	ADD COLUMN rule text,
	ADD COLUMN isolated integer;

-- To make pgRouting fast
CREATE INDEX strat_rds_source_idx ON os_m2.m2_roads USING btree(source);
CREATE INDEX strat_rds_target_idx ON os_m2.m2_roads USING btree(target);

-- Calculate coordinates of link endpoints
UPDATE os_m2.m2_roads SET 
	x1 = st_x(st_startpoint(geometry)),
		y1 = st_y(st_startpoint(geometry)),
		x2 = st_x(st_endpoint(geometry)),
		y2 = st_y(st_endpoint(geometry));

-- Calculate distance cost
UPDATE os_m2.m2_roads SET
	cost_len = ST_Length(geometry),
	rcost_len = ST_Length(geometry);

-- Set average road speed for time costs
UPDATE os_m2.m2_roads SET speed_km =
	CASE WHEN number LIKE 'M%' THEN 60
	WHEN number LIKE 'A%' THEN 50
	WHEN number LIKE 'B%' THEN 40
	ELSE 30 END;

-- Calculate time costs
UPDATE os_m2.m2_roads SET
	cost_time = cost_len/1000.0/speed_km::numeric*3600.0,
	rcost_time = cost_len/1000.0/speed_km::numeric*3600.0;

-- Build your network
SELECT pgr_createtopology('os_m2.m2_roads',0.001,'geometry','gid','source','target');

-- Check your network for errors
SELECT pgr_analyzegraph('os_m2.m2_roads',0.001,'geometry','gid','source','target');

-- Clean out the cruft and update stats
--VACUUM ANALYZE VERBOSE os_m2.m2_roads;
