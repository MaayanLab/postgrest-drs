# Postgrest DRS

This is a DRS endpoint powered by postgrest -- that-is the drs id mappings go in a postgres database, postgrest serves that database as a REST API, and the files are accessible over GA4GH compatible endpoints.

In the future, it could be expanded to support more advanced queries over those objects, or a REST API for minting DRS ids.

## How it works
- postgres has `schema.sql`
- postgrest provides a REST API for accessing the functions in the postgres store
- nginx maps GA4GH calls to postgrest queries:
  - /ga4gh/drs/v1/service-info => /rpc/drs_service_info
  - /ga4gh/drs/v1/objects/{obj} => /rpc/drs_object?object_id={obj}
  - /ga4gh/drs/v1/objects/{obj}/access/{access} => /rpc/drs_object_access?object_id={obj}&access_id={access}
- runs both of these services (postgrest+nginx)

## Adding DRS Entries

```sql
insert into data.drs_object (id, created_time, size)
values ('mydrsid', now(), 0);

insert into data.drs_object_access (id, type, access_id, access_url, headers)
values ('mydrsid', 'https', 'primary', 'https://myurl', '{}'::json);
```
