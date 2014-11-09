# You should setup a PostgreSQL database containing the catalogue (a 
# SQL "table") of your sources. The supplied version of Query.pm needs
# the following columns:
#
# id,ra,dec_,scts058,scts28,scts052,bg_map058,bg_map28,bg_map052,nndist
#
# which contain: source id, ra, dec, counts in the 0.5-8, 2-8 and 0.5-2
# keV bands, background surface brightnesses in the same bands. Scts 
# and bg_map shuold be in the same units of the output from emldetect.
#

# Assuming you have such a database, you need first to define the
# haversine function (i.e., distance between two points on a sphere).
# Copy and paste the following lines in the psql prompt:

#---begin---
create or replace function public.haversine( ra1 double precision, dec1 double precision, ra2 double precision, dec2 double precision )
returns double precision as
$BODY$
select 2*asin(sqrt(
       (sin(radians(dec1-dec2)/2))^2
       +cos(radians(ra1))*cos(radians(ra2))*(sin(radians(ra1-ra2)/2))^2
       ))
as haversine;
$BODY$
	language sql immutable cost 100;
#---end---


# (NB the above version of haversine takes degrees as input, but gives
# radians as output).

# Then, two new columns must be created:  nndist real, nnxseq integer. Give
# the following commands at the psql prompt:


alter table _YOUR_CATALOGUE_TABLE_  add column nndist real;
alter table _YOUR_CATALOGUE_TABLE_  add column nnid integer;

create index catra  on _YOUR_CATALOGUE_TABLE_ ( ra );
create index catdec on _YOUR_CATALOGUE_TABLE_ ( dec_ );
create index catid  on _YOUR_CATALOGUE_TABLE_ ( id );



# Now, define the addnn() function, by copying and pasting the following
# lines in the psql prompt:

#---begin---
CREATE OR REPLACE FUNCTION addnn() returns void as $$
       declare
	  myid int;
       begin
          for myid in select id from _YOUR_CATALOGUE_TABLE_
	  loop
		update _YOUR_CATALOGUE_TABLE_ set nndist=dist, nnid=x2id
		from (
		       select haversine(x1.ra,x1.dec_,x2.ra,x2.dec_)/3.141592*180*60 as dist,
		              x2.id as x2id
		       from _YOUR_CATALOGUE_TABLE_ as x1
		       join _YOUR_CATALOGUE_TABLE_ as x2
		       on x1.id!=x2.id
		       where x1.id=myid
		       and x2.ra>x1.ra-1
		       and x2.ra<x1.ra+1
		       and x2.dec_>x1.dec_-1
		       and x2.dec_<x1.dec_+1
		       order by dist
		       limit 1
		) q
		where id=myid;
	   end loop;
	   return;
 	end
$$ language plpgsql;
#---end---

# finally, populate the new columns by running the following command at
# the psql prompt:

select addnn();
