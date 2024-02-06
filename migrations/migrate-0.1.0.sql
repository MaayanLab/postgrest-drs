-- if you were using 0.0.* you can migrate to 0.1.* with this SQL

drop function api.drs_object;
drop view data.drs_object_complete;
drop type types.drs_object;
drop type types.drs_access_method;

create type types.drs_access_method as (
  access_id varchar,
  access_url types.drs_access_url,
  region varchar,
  type types.drs_access_method_type
);

create type types.drs_object as (
  access_methods types.drs_access_method[],
  aliases varchar[],
  checksums types.drs_checksum[],
  created_time timestamp,
  description varchar,
  id varchar,
  mime_type varchar,
  name varchar,
  self_uri varchar,
  size varchar,
  updated_time timestamp,
  version varchar
);

create or replace view data.drs_object_complete as
select 
  (
    select coalesce(array_agg(cast((
      a.access_id,
      cast((
        a.access_url,
        a.headers
      ) as types.drs_access_url),
      a.region,
      a.type
    ) as types.drs_access_method)), '{}'::types.drs_access_method[])
    from data.drs_object_access a
    where o.id = a.id
  ) as access_methods,
  (
    select coalesce(array_agg(cast((c.checksum, c.type) as types.drs_checksum)), '{}'::types.drs_checksum[])
    from data.drs_object_checksum c
    where o.id = c.id
  ) as checksums,
  o.aliases,
  o.created_time,
  o.description,
  o.id,
  o.mime_type,
  o.name,
  ('drs://' || data.drs_service_origin() || '/' || o.id) as self_uri,
  o.size,
  o.updated_time,
  o.version
from
  data.drs_object o
;

create or replace function api.drs_object(object_id varchar) returns setof data.drs_object_complete as $$
  select *
  from data.drs_object_complete
  where id = drs_object.object_id;
$$ language sql security definer;
grant execute on function api.drs_object(varchar) to anon;
