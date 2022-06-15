# Postgrest DRS

This is a DRS endpoint powered by postgrest -- that-is the drs id mappings go in a postgres database, postgrest serves that database as a REST API, and the files are accessible over GA4GH compatible endpoints.

Future:
- DRS bundles
- PostgREST facilitated DRS insertion

## How it works
- postgres has `schema.sql`
- postgrest provides a REST API for accessing the functions in the postgres store
- nginx maps GA4GH calls to postgrest queries:
  - /ga4gh/drs/v1/service-info => /rpc/drs_service_info
  - /ga4gh/drs/v1/objects/{obj} => /rpc/drs_object?object_id={obj}
  - /ga4gh/drs/v1/objects/{obj}/access/{access} => /rpc/drs_object_access?object_id={obj}&access_id={access}
- supervisor runs both of these services (postgrest+nginx)

## Adding DRS Entries

```sql
-- register a drs object
insert into data.drs_object (id, size)
values ('mydrsid', 0);
insert into data.drs_object_access (id, type, access_id, access_url, headers)
values ('mydrsid', 'https', 'primary', 'https://myurl', '{}'::json);
insert into data.drs_object_checksum (id, type, checksum)
values ('mydrsid', 'etag', '12345');

-- review object info provided on /ga4gh/drs/v1/objects/*
select *
from data.drs_object_complete;
```

## Staging from file store

Assuming you want to expose, for example, an S3 bucket, you can quickly generate all relevant entires for the DRS endpoint.

```python
import os
import csv
import s3fs
import pathlib
import psycopg2
import contextlib
import tempfile

@contextlib.contextmanager
def with_many(**contexts):
  yields = {
    k: context.__enter__()
    for k, context in contexts.items()
  }
  try:
    yield yields
  except:
    for context in reversed(contexts.values()):
      context.__exit__(*sys.exc_info())
  else:
    for context in reversed(contexts.values()):
      context.__exit__(None, None, None)

# get files from s3
bucket = 'your-bucket'
fs = s3fs.S3FileSystem(anon=True)
files = [f for f in fs.ls(bucket, detail=True) if f['type'] == 'file']

# connect to database
conn = psycopg2.connect(os.environ.get('DB_URL', 'user=postgres host=localhost port=5432'))
cur = conn.cursor()

# database import schema
tables = OrderedDict([
  ('drs_object', ('id', 'created_time', 'size')),
  ('drs_object_checksums': ('id', 'type', 'checksum')),
  ('drs_object_access': ('id', 'type', 'access_id', 'access_url')),
])
# prepare temporary directory for work
with tempfile.TemporaryDirectory() as tmp:
  tmp = Path(tmp)
  # prepare file for each table
  with with_many(**{
    tbl: (tmp/(tbl+'.tsv')).open('w')
    for tbl in tables
  }) as table_fps:
    # prepare tsv writers for each table
    table_writers = {
      tbl: csv.DictWriter(table_fps[tbl], cols, delimiter='\t')
      for tbl, cols in tables.items()
    }
    # walk through files and write entries
    for r in files:
      id = r['ETag'].strip('"')
      table_writers['drs_object'].writerow({
        'id': id,
        'created_time': r['LastModified'].isoformat(),
        'size': r['size'],
      })
      table_writers['drs_object_checksums'].writerow({
        'id': id, 'type': 'etag', 'checksum': r['ETag'].strip('"')
      })
      table_writers['drs_object_access'].writerow({
        'id': id, 'access_id': 'http', 'type': 'http',
        'access_url': f"https://{bucket}.s3.amazonaws.com/{r['name'][len(bucket)+1:]}"
      })
      table_writers['drs_object_access_methods'].writerow({
        'id': id, 'access_id': 's3', 'type': 's3',
        'access_url': f"s3://{r['name']}",
      })
  # load table files into database
  for table, cols in tables.items():
    with (tmp/(table+'.tsv')).open('r') as fr:
      cur.copy_from(fr, table, columns=cols, sep='\t')
  conn.commit()

```
