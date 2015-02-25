# meridian2-for-pgrouting
Building a pgRouting network from Ordnance Survey's Meridian2 dataset.

Get the data
------------

Download the Meridian2 shapefiles for the UK from https://www.ordnancesurvey.co.uk/opendatadownload/products.html

Merge the roads
---------------

+ unzip the downloaded Meridian2 data
+ using QGIS you can merge all the roads layers to make one layer.
+ Vector Menu > Data Management > Merge Shapefiles To One
+ Choose all roads layers
+ create merged layer
+ Add the new layer to QGIS 

Load to the database
--------------------

+ Use the DB Manager in QGIS to load the data to PostGIS.  This takes a wee while as there are 1.25 million roads features.
+ Optionally create schema: **os_m2** (or use public)
+ Create table: **m2_roads**
+ Set primary key field: **gid**
+ Set geometry field: **geometry**
+ Set target SRID: **27700**
+ Check the box to create single part features rather than multipart.
+ Check box to create spatial index.

Create a network table
----------------------

Add some fields that pgRouting needs

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

Build the indices on the *source* and *target* fields to speed things up		
		
	CREATE INDEX strat_rds_source_idx ON os_m2.m2_roads USING btree(source);
	CREATE INDEX strat_rds_target_idx ON os_m2.m2_roads USING btree(target);

Populate the network table
--------------------------

Calculate coordinates for start and end points of lines	
	
	UPDATE os_m2.m2_roads SET 
		x1 = st_x(st_startpoint(geometry)),
		y1 = st_y(st_startpoint(geometry)),
		x2 = st_x(st_endpoint(geometry)),
		y2 = st_y(st_endpoint(geometry));

Update the length fields with length of the links			
			
	UPDATE os_m2.m2_roads SET
		cost_len = ST_Length(geometry),
		rcost_len = ST_Length(geometry);

Set some average speeds used to calculate travel time.  Adjust as required.		
		
	UPDATE os_m2.m2_roads SET speed_km =
		CASE WHEN number LIKE 'M%' THEN 60
		WHEN number LIKE 'A%' THEN 50
		WHEN number LIKE 'B%' THEN 40
		ELSE 30 END;

Calculate the travel time for each link			
		
	UPDATE os_m2.m2_roads SET
		cost_time = cost_len/1000.0/speed_km::numeric*3600.0,
		rcost_time = cost_len/1000.0/speed_km::numeric*3600.0; 

Update the statistics on the table and clear out the cruft		
		
	VACUUM ANALYZE VERBOSE os_m2.m2_roads;

Build the topology
------------------

Build your network (took 45 min on my quad core processor)
	
	SELECT pgr_createtopology('os_m2.m2_roads',0.001,'geometry','gid','source','target');

Analyse the network
-------------------

Analyse your network for errors (took another 45 min).  You may get some complaints about the geometry being MULTILINESTRING rather than LINESTRING.	
	
	SELECT pgr_analyzegraph('os_m2.m2_roads',0.001,'geometry','gid','source','target');
	
Get lost
--------

Use the pgRouting Layer plugin in QGIS to load your network table and do some routing.
