create schema api;
create schema types;
create schema data;
create role anon;
grant usage on schema api to anon;
grant usage on schema types to anon;

-- /service-info
create type types.service_type as (
  "group" varchar,
  "artifact" varchar,
  "version" varchar
);

create type types.service_organization as (
  "name" varchar,
  "url" varchar
);

create type types.service as (
  "id" varchar,
  "name" varchar,
  "type" types.service_type,
  "organization" types.service_organization,
  "version" varchar
);

-- /objects
create type types.drs_access_method_type as enum (
  's3',
  'gs',
  'ftp',
  'gsiftp',
  'globus',
  'htsget',
  'https',
  'file'
);


create type types.drs_access_url as (
  url varchar,
  headers json
);

create type types.drs_access_method as (
  access_id varchar,
  access_url types.drs_access_url,
  region varchar,
  type types.drs_access_method_type
);

create type types.drs_checksum_type as enum (
  'md5',
  'etag',
  'crc32c',
  'trunc512',
  'sha1',
  'sha256'
);
create type types.drs_checksum as (
  checksum varchar,
  type types.drs_checksum_type
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

-- data model
create or replace function data.drs_service_origin() returns varchar as $$
  select 'drs.lincs-dcic.org';
$$ language sql immutable;

create table data.drs_object (
  aliases varchar[],
  created_time timestamp not null default now(),
  description varchar,
  id varchar,
  mime_type varchar,
  name varchar,
  size varchar not null,
  updated_time timestamp,
  version varchar,
  primary key (id)
);

create table data.drs_object_access (
  id varchar,
  type varchar not null,
  access_id varchar not null,
  access_url varchar not null,
  region varchar,
  headers json,
  primary key (id, access_id),
  foreign key (id) references data.drs_object (id) on delete cascade
);

create table data.drs_object_checksum (
  id varchar,
  type varchar not null,
  checksum varchar not null,
  primary key (id, type),
  foreign key (id) references data.drs_object (id) on delete cascade
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

-- API

-- /service-info
create or replace function api.drs_service_info() returns types.service as $$
select
  'org.lincs-dcic.drs' as "id",
  'LINCS DRS' as "name",
  cast((
    'org.lincs-dcic',
    'drs',
    '1.0.0'
  ) as types.service_type) as "type",
  cast((
    'MaayanLab',
    'https://maayanlab.cloud'
  ) as types.service_organization) as "organization",
  '1.0.0' as "version"
$$ language sql immutable;
grant execute on function api.drs_service_info() to anon;

-- /objects/{object_id}
create or replace function api.drs_object(object_id varchar) returns setof data.drs_object_complete as $$
  select *
  from data.drs_object_complete
  where id = drs_object.object_id;
$$ language sql security definer;
grant execute on function api.drs_object(varchar) to anon;

-- /objects/{object_id}/access/{access_id}
create or replace function api.drs_object_access(object_id varchar, access_id varchar) returns setof types.drs_access_url as $$
  select
    a.access_url as url,
    coalesce(a.headers, '{}'::json) as headers
  from
    data.drs_object_access a
    where
      a.id = drs_object_access.object_id
      and a.access_id = drs_object_access.access_id
  ;
$$ language sql security definer;
grant execute on function api.drs_object_access(varchar, varchar) to anon;
