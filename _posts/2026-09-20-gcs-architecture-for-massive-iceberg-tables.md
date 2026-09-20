---
layout: post
title: "Best-in-Class Storage: Architecting Google Cloud Storage for Massive Iceberg Tables"
categories: [GCP, Cloud Storage, Apache Iceberg, BigQuery, Lakehouse]
excerpt: "At petabyte scale, the storage layer is the one part of your lakehouse you cannot re-architect on a Tuesday afternoon. This is a deep dive into the GCS decisions that actually move the needle for Apache Iceberg managed tables: why object naming still shapes your request-rate ceiling, what hierarchical namespace buys you, how to lay out buckets and prefixes, and where the real throughput ceiling sits."
image: assets/img/iceberg-logo-icon.png
---

Most lakehouse posts spend 90% of their words on the query engine and one paragraph on "put your files in a bucket." That ordering is backwards. You can swap Spark for Trino next quarter. You can migrate a catalog. But the bucket your multi-petabyte Iceberg table lives in carries three decisions that are made once, at creation time, and are effectively permanent: its **location**, its **namespace type**, and the **prefix topology** you commit your tables to.

Get those wrong and you will spend a year doing a copy-migration of a petabyte while your quarterly reports run on stale data.

This post is about getting them right. The focus is **Apache Iceberg managed tables in BigQuery** — Google's managed path, where BigQuery owns compaction, clustering, and garbage collection on your GCS bucket — but the request-rate and topology mechanics apply to any Iceberg-on-GCS deployment.

> A note on naming, because it changed recently: **as of April 20, 2026, BigLake is called Lakehouse**, and the BigLake metastore is now the **Lakehouse runtime catalog**. Separately, **Anywhere Cache was renamed Rapid Cache** in March 2026. Many doc URLs and the `gcloud` CLI still carry the old names. I'll use the current names and flag the old ones where the tooling hasn't caught up.

## The three irreversible decisions

Before any tuning, get these right:

| Decision | Reversible? | Cost of getting it wrong |
|---|---|---|
| Bucket location (region / dual / multi) | No — requires bucket relocation or full copy | Permanent egress bill on every read, or a PB-scale migration |
| Hierarchical namespace on/off | **No — create-time only** | 8x lower initial QPS ceiling, forever |
| Prefix topology (which table lives where) | Technically yes, practically no | Iceberg metadata holds absolute paths; moving a table means rewriting it |

Everything else in this post — caching, storage class, lifecycle, clustering — you can change next week. These three you cannot.

---

## Layer 1: The request-rate model

There's a comfortable assumption floating around that object naming stopped mattering years ago — that modern object storage auto-scales transparently and you can name your keys whatever reads nicely.

On Google Cloud Storage, that assumption will cost you. The [request rate and access distribution guidelines](https://docs.cloud.google.com/storage/docs/request-rate) are live, current documentation — the page was last updated days before I wrote this — and they are explicit that key naming drives how fast a bucket scales.

### How GCS actually scales

GCS maintains an index of object keys per bucket, and that index "is stored in lexicographical order and is updated whenever objects are written to or deleted from a bucket." When a narrow slice of that index gets hot — what the docs call hotspotting — Cloud Storage detects it and "automatically redistributes the load on the affected index range across multiple servers." A fresh bucket starts at:

- **~1,000 object write requests per second** (uploads, updates, deletes)
- **~5,000 object read requests per second**

Auto-scaling is not instant. Per the docs, Cloud Storage "typically takes **on the order of minutes** to detect and accordingly redistribute the load across more servers." And the ramp guidance is explicit:

> "you should start with a request rate below or near the thresholds and then gradually increase the rate **no faster than doubling the rate over a period of 20 minutes**."

### Why sequential names hurt

This is the part that matters for a lakehouse, because **lakehouse paths are almost always sequential**. Date-partitioned prefixes. Timestamp-based file names. Monotonic snapshot IDs. The docs are blunt about it:

> "Auto-scaling of an index range can be slowed when using sequential names, such as object keys based on a sequence of numbers or timestamp. This occurs because requests are constantly shifting to a new index range, making redistributing the load harder and less effective."

There's a second-order trap the docs call out too: adding randomness *after* a sequential common prefix only helps *within* that prefix. If your prefixes roll over hourly, "the write rate resets at the beginning of each hour." You re-pay the ramp tax every hour, forever.

The documented mitigation is to hash the front of the key — take the MD5 of the original object name and prepend the first 6 characters:

```
gs://my-bucket/2016-05-10-12-00-00/file1
        ↓
gs://my-bucket/2fa764-2016-05-10-12-00-00/file1
```

And on how many characters you actually need:

> "a 1-character prefix using a random hex value provides effective auto-scaling from the initial 5000/1000 reads/writes per second up to roughly **80000/16000 reads/writes per second**, because the prefix has 16 potential values."

One hex character. 16 values. 16x the ceiling. If you don't need more than ~80k reads/sec, a longer prefix buys you nothing — which is worth knowing, because every extra character you hash is a character of human-readable path you destroy.

### The catch for managed tables

Here's where it gets interesting for BigQuery-managed Iceberg tables: **you don't name the objects.** BigQuery does. It writes Parquet shards into `STORAGE_URI/data` and Iceberg metadata into `STORAGE_URI/metadata`, and Google doesn't publish the naming convention inside those folders.

So the prefix-hashing lever doesn't disappear — it **moves up a level**. What you control is the shape of the namespace *above* the table:

- The `storage_uri` you assign each table
- How many tables share a bucket
- Whether that bucket has a hierarchical namespace

If you run self-managed writers (Spark, Flink) alongside managed tables, the hashing guidance applies directly to *their* output paths. For managed tables, your job is to make sure BigQuery's index ranges aren't all landing in one lexicographic neighbourhood — which is a topology problem, not a naming problem.

---

## Layer 2: Hierarchical namespace — the 8x lever you get exactly one shot at

[Hierarchical namespace](https://docs.cloud.google.com/storage/docs/hns-overview) (HNS) turns folders into real metadata resources instead of name prefixes. For analytics workloads this is the single highest-leverage bucket setting, and it is **create-time only**.

**What you get:**

- **Up to 8x higher initial QPS** for reads and writes versus a flat bucket. Google states the multiple, not an absolute — "up to 8 times higher initial Queries per second (QPS) limits for reading and writing objects." Against the flat-bucket baseline of 5,000 reads / 1,000 writes per second, that implies a ceiling in the tens of thousands, but treat 8x as a documented maximum rather than a number you can budget against.
- **Atomic folder rename.** On a flat bucket, renaming a "folder" is a copy-and-delete of every object under it. On HNS it's a single metadata operation. For Hive-style staging patterns and any engine that writes-then-promotes, this is a category difference, not a percentage one.

**What it costs you:**

- Uniform bucket-level access is **required** (you want this anyway — it's the Iceberg best practice).
- **No Object Versioning.** The full unsupported list: Bucket Lock, bucket relocations with write downtime, cross-bucket replication, object holds, object-level ACLs, Object Retention Lock, and Object Versioning.
- Full-bucket listing gets *worse*, not better. Per the [HNS best-practices page](https://docs.cloud.google.com/storage/docs/hns-buckets-best-practices), "listing all objects for the entire bucket or with a prefix is resource-intensive as the operation must traverse each folder and subfolder." Scoped listing with a delimiter and specific prefix is the efficient path — which is exactly how Iceberg reads anyway, since manifests give it explicit file paths.
- A large number of empty folders degrades listing performance. Clean them up.

The Object Versioning restriction sounds alarming until you read the [Iceberg managed tables best practices](https://docs.cloud.google.com/biglake/docs/best-practices-biglake-iceberg-tables), which lists its own set as flatly **unsupported** for Iceberg managed tables: object ACLs, customer-supplied encryption keys, object versioning, object lock, bucket lock, and restoring soft-deleted objects with the BigQuery API or `bq` CLI. The two lists overlap heavily. HNS takes away several features you were already told not to use.

Creating one:

```bash
gcloud storage buckets create gs://acme-lakehouse-sales-us-central1 \
  --location=us-central1 \
  --enable-hierarchical-namespace \
  --uniform-bucket-level-access \
  --public-access-prevention \
  --default-storage-class=STANDARD \
  --soft-delete-duration=7d
```

If you're driving this from Spark via the Cloud Storage connector, enable the rename-folder path explicitly — it needs connector **2.2.23+** (2.x) or **3.0.1+** (3.x):

```
fs.gs.hierarchical.namespace.folders.enable=true
```

> One genuinely open question: Google documents neither compatibility nor incompatibility between HNS and Autoclass. HNS isn't in the Autoclass restrictions list, and Autoclass isn't in the HNS unsupported list. If your design depends on both, test it in a throwaway bucket before you commit a petabyte — don't take my word or anyone else's.

---

## Layer 3: Bucket topology

### Location: single-region, co-located, no exceptions

The Iceberg best-practices doc is unusually direct here:

> "Choose **single-region** Cloud Storage buckets that are co-located in the same region as your BigQuery dataset. This coordination improves performance and lowers costs by avoiding data transfer charges."

The reason multi-region is a trap for analytics isn't the storage price ($0.026 vs $0.020/GiB-month in the US — a 30% premium you might shrug at). It's that the [bucket locations](https://docs.cloud.google.com/storage/docs/locations) comparison marks multi-region with "outbound data transfer charges always apply when reading data," where dual-region gets "no outbound data transfer charges when reading data within either region." At petabyte scan volumes, that line item dwarfs the storage delta.

Dual-region is the defensible middle ground when you have a real regional-failover requirement. It replicates asynchronously, and "for buckets using default replication, the RPO for objects is 12 hours." **Turbo replication** is "designed to replicate 100% of newly written objects to the two regions that constitute a dual-region within the recovery point objective of 15 minutes" — and it holds that RPO regardless of object size. It costs $0.04/GiB replicated versus $0.02/GiB for default replication, and it is dual-region only.

| | Region | Dual-region | Multi-region |
|---|---|---|---|
| Standard price (US) | $0.020/GiB-mo | $0.022/GiB-mo | $0.026/GiB-mo |
| Egress on read from co-located compute | None | None | **Always charged** |
| Replication RPO | n/a (synchronous across AZs) | 12h default / 15min turbo | — |
| Availability SLA (Standard) | 99.9%\* | 99.95% | 99.95% |
| **Verdict for Iceberg** | **Default choice** | Only with a real DR mandate | Avoid |

\* Regional Standard is 99.5% in Mexico and Stockholm — check the [SLA](https://cloud.google.com/storage/sla) for your region rather than assuming 99.9%.

### How many buckets?

There's no documented maximum number of buckets per project, but there are rate limits that shape the answer: bucket create/delete runs at roughly **one request every two seconds per project**, and bucket metadata updates are capped at **one per second per bucket**. Neither matters for steady state; both matter if you're programmatically provisioning a bucket per table across thousands of tables.

Three topologies, and when each is right:

**1. Monolith — one bucket, all tables.**
Simple IAM story, single lifecycle config. Falls over on two limits: **1,500 IAM principals per bucket**, and a cap of **1,000 combined prefixes+suffixes across all lifecycle rules per bucket**. Also concentrates all index-range pressure in one keyspace. Fine below a few dozen tables; do not scale it.

**2. Bucket per data domain — the recommended default.**
One bucket per domain and region (`acme-lakehouse-sales-us-central1`, `acme-lakehouse-clickstream-us-central1`). Domains map cleanly to ownership, so bucket-level IAM does real work. Each domain gets its own request-rate keyspace, its own lifecycle policy, its own Rapid Cache decision. This is where I'd start for almost any organization.

**3. Bucket per table — for the extreme few.**
Only justified when a single table is so hot it genuinely needs its own auto-scaling keyspace, or when regulatory isolation demands it. The operational overhead of thousands of buckets is real. Reach for this per-table, not as a policy.

### Prefix layout inside the bucket

Two rules from the Iceberg docs are non-negotiable, and violating either is a data-loss path:

> "Only create new Iceberg managed tables in **empty prefixes**."
> "Use **unique URIs** for each Iceberg managed table."

The reason is stated even more bluntly elsewhere on the same page: "New files or objects added outside of BigQuery are not tracked by BigQuery. **Untracked files are deleted by background garbage collection processes.**" Point two tables at overlapping prefixes and one table's GC will eat the other's data files.

A layout that holds up, with a hash shard at the front so tables spread across index ranges instead of clustering under a sequential domain name:

```
gs://acme-lakehouse-sales-us-central1/
├── 3f/orders/              ← storage_uri for sales.orders
│   ├── data/               ← Parquet shards, written by BigQuery
│   └── metadata/           ← Iceberg snapshots, written by BigQuery
├── a1/order_items/         ← storage_uri for sales.order_items
│   ├── data/
│   └── metadata/
└── 7c/returns/
    ├── data/
    └── metadata/
```

The two-character shard is the first two hex characters of the MD5 of the table name — deterministic, reproducible from your Terraform, and enough to spread across 256 buckets of keyspace. Generate it once at table-creation time:

```bash
TABLE="sales.orders"
SHARD=$(printf '%s' "$TABLE" | md5sum | cut -c1-2)
STORAGE_URI="gs://acme-lakehouse-sales-us-central1/${SHARD}/${TABLE#*.}"
echo "$STORAGE_URI"
# gs://acme-lakehouse-sales-us-central1/3f/orders
```

Is this strictly necessary for managed tables? Honestly: for a few dozen tables, no. The index-range pressure won't be your bottleneck. But it costs one line of shell at provisioning time and it removes an entire class of problem you'd otherwise discover at 2 AM three years from now. Cheap insurance.

---

## Layer 4: The throughput ceiling nobody budgets for

Here is the number that ends more petabyte-scale projects than any query-tuning problem: the default quota for "maximum bandwidth for each region that has data egress from Cloud Storage to Google services" is **200 Gbps per region**. It is scoped by location, **not by bucket** — adding buckets does not add bandwidth. (For dual-region it's 200 Gbps for each region within the pair; for multi-region, per region.)

200 Gbps = **25 GB/s**. So:

- Scanning **1 PB** at the quota ceiling: **~11 hours**, assuming you get 100% of the quota and nothing else is reading.
- Scanning **100 TB**: ~67 minutes.

(Those are decimal PB and TB, to stay consistent with Gbps. GCS quotas and pricing are quoted in binary GiB/TiB/PiB, so if you redo this math in PiB the numbers stretch by about 12%.)

If your SLA says "the daily rollup finishes by 6 AM" and the daily rollup touches 300 TB, you are not going to tune your way there with better clustering. You're bandwidth-bound, and you need either a quota increase — requestable through the console or your account team — or a cache.

### Rapid Cache: buying throughput back

[Rapid Cache](https://docs.cloud.google.com/storage/docs/rapid/rapid-cache) (the feature formerly called Anywhere Cache) is an SSD-backed **zonal read cache** in front of your bucket, and it changes the math in two ways.

First, the ceiling: **up to 2.5 TB/s of throughput** — two orders of magnitude above the bucket quota. Second, and this is the part that's easy to miss: **cache reads draw on a separate bandwidth budget.** The docs are explicit:

> "The cache bandwidth limit is separate from your project's maximum bandwidth quota. Reading data from the cache counts towards the cache bandwidth limit until the limit is reached, at which point data reads begin counting towards the project's bandwidth quota. **Cache misses don't count towards the cache bandwidth limit.**"

That cache limit tops out at **20 Tbps per project, per zone**, starting at a 100 Gbps base and scaling by 20 Gbps per TiB of data stored in the cache. Note the last sentence: a cache miss hits your 200 Gbps bucket quota from the first byte, so a cold cache buys you nothing. Hit rate is the whole game.

How it works:

- One cache instance per bucket per zone; the cache must live in a zone within the bucket's location.
- Objects are cached in **2 MB chunks**. Objects larger than that cache only the requested byte ranges — which is a good fit for Parquet, where engines read footers and specific row groups rather than whole files.
- Default is cache-on-first-read. Ingest-on-write is optional, and since **August 21, 2026** supports **prefix-level filtering** via managed folders — which is how you cache only `.../data/` for your hot tables and skip everything else.
- **TTL defaults to 24 hours**, settable between 24 hours and 7 days.

```bash
gcloud storage buckets anywhere-caches create \
  gs://acme-lakehouse-sales-us-central1 us-central1-a \
  --ttl=48h
```

(Yes, the subcommand is still `anywhere-caches`. The CLI hasn't caught up to the rename.)

Admission policies — `ADMIT_ON_SECOND_MISS` keeps one-off scans from polluting the cache — are worth knowing about, but note that the flag is documented on **update**, not create, and currently only under `gcloud alpha`:

```bash
gcloud alpha storage buckets anywhere-caches update \
  acme-lakehouse-sales-us-central1/CACHE_ID \
  --admission-policy='ADMIT_ON_SECOND_MISS'
```

The economics force a discipline that's good for you anyway. In Iowa, Rapid Cache storage runs $0.0001233/GiB-hour — about **$0.09/GiB-month, roughly 4.5x Standard regional storage** — plus **$0.0032/GiB ingest** and **$0.0006/GiB transfer out**. And cached data still sits in the backing bucket, so the all-in cost of a cached GiB is closer to **5.5x** Standard. You cannot afford to cache a petabyte table. You *can* afford to cache the last 30 days of a partitioned table — which is where 90% of your queries live.

Two bonuses worth knowing: retrieval fees for Nearline/Coldline/Archive **don't apply** to cache reads, and a single cache can grow to **1 PiB** (raisable through your account team).

### gRPC and direct connectivity

For Compute Engine-based engines, [direct connectivity](https://docs.cloud.google.com/storage/docs/direct-connectivity) means requests "are routed directly to Cloud Storage, bypassing Google Front Ends (GFEs)." Google publishes no numbers for the gain — only "lower latency and connection overhead" — but the constraint is documented and sharp:

> "For analytics workloads on Google Cloud, gRPC improves Cloud Storage read performance **only when the Compute Engine instance and the Cloud Storage bucket are in the same region**."

Cross-region, expect nothing. Which is one more argument for co-location.

---

## Layer 5: The settings that quietly delete your table

### Lifecycle rules are a loaded gun pointed at Iceberg

This deserves its own warning. Object Lifecycle Management has no idea what Iceberg is. An age-based `Delete` rule on your `data/` prefix will cheerfully remove Parquet files that a **live snapshot still references**, and your table breaks on the next read.

**Do not use age-based lifecycle deletion on Iceberg data or metadata prefixes.** Snapshot expiry and orphan-file cleanup are Iceberg's job — and for managed tables, BigQuery does it for you: "after the expiration of the time travel window, data files are garbage collected." BigQuery's time-travel window is configurable from two to seven days. Worth knowing alongside that: Iceberg managed tables **don't support fail-safe windows**, so there is no extra 7-day cushion behind time travel the way there is for standard BigQuery tables.

Lifecycle also has operational sharp edges. Config changes "can take up to 24 hours to go into effect, and Object Lifecycle Management might still perform actions based on the old configuration during this time." Actions are asynchronous — "there can be a lag between when the conditions are satisfied and when the action is taken" — and you generally pay for storage during that lag, though at-rest charges are waived for objects meeting specific criteria (age-based delete rules, no holds). And a lifecycle `Delete` on a live object becomes a **soft delete retained for seven days** by default, so it doesn't stop the meter when you think it does.

### Soft delete: the recommendation inverts for Iceberg

The general GCS guidance for high-churn data is "store temporary objects in buckets that don't have soft delete enabled," because soft-deleted objects "continue to accrue storage charges until their retention period expires and they're permanently deleted."

Iceberg metadata is about as high-churn as data gets — every commit rewrites manifest lists and snapshot JSON. So you'd expect the advice to be "turn it off."

It isn't. The Iceberg best practices say:

> "Keep the default soft delete policy (7 day retention) to protect against accidental deletions."

The reasoning is that a corrupted or partially-deleted Iceberg table is a far more expensive incident than seven days of duplicate metadata storage. One caveat that comes with it, and it's a sharp one: restoring soft-deleted objects with the BigQuery API or `bq` CLI is on the **unsupported** list. The docs are blunt about where that leaves you — "There is no self-serve way to recover from this point. Contact support for data recovery assistance."

### Autoclass: the cost-control lever, with one detail that makes it work

The Iceberg best-practices page points at [Autoclass](https://docs.cloud.google.com/storage/docs/autoclass), though more permissively than you might expect: "To optimize data storage costs, you can enable Autoclass to automatically manage storage class transitions." Not a mandate — an option. But it's the right option for Iceberg, for a specific reason.

Manual tiering to Nearline means a 30-day minimum storage duration; delete or rewrite a file before that and "you are charged as if the object was stored for the minimum duration." For a table whose compaction constantly rewrites files, that's a bill you'd rather not discover. On an Autoclass bucket, retrieval fees and early-deletion charges are not charged — with one asterisk worth reading carefully: **"except as part of enablement charges."** Turning Autoclass on for a bucket that already holds cold data triggers a one-time enablement charge covering early-delete fees for objects below their minimum duration, retrieval fees for non-Standard objects, and a Class A operation per object. Enable it on an empty bucket and that charge is nothing. Enable it on a two-petabyte archive and it is not nothing.

The detail that makes Autoclass a good fit for Iceberg: **objects smaller than 128 KiB never transition** to colder classes, and they aren't counted toward the management fee. To the extent your Iceberg metadata files fall below that line, they stay in Standard for free while cold Parquet data ages down. Do check that assumption against your own tables rather than taking it on faith — manifest size scales with partition and file count, and Google publishes no size expectations for BigQuery-written Iceberg metadata.

Cost: **$0.0025 per 1,000 objects stored for 30 days**, excluding sub-128-KiB objects. The trade-off: a bucket cannot have both Autoclass and a lifecycle rule using a **`SetStorageClass` action or a `matchesStorageClass` condition**. Pick one tiering mechanism.

```bash
gcloud storage buckets update gs://acme-lakehouse-sales-us-central1 \
  --enable-autoclass \
  --autoclass-terminal-storage-class=ARCHIVE
```

### And the one that isn't free

Automatic table management on managed Iceberg tables — compaction, clustering, garbage collection, metadata refresh — is billed in **Data Compute Units at $0.12 per DCU-hour**, region-dependent. It's excellent value versus running your own maintenance jobs, but it's a line item, not a freebie. Budget for it.

---

## Putting it together

The full provisioning sequence, start to finish:

```bash
export PROJECT=acme-analytics
export REGION=us-central1
export BUCKET=acme-lakehouse-sales-${REGION}

# 1. The bucket — HNS and location are the decisions you can't undo
gcloud storage buckets create gs://${BUCKET} \
  --project=${PROJECT} \
  --location=${REGION} \
  --enable-hierarchical-namespace \
  --uniform-bucket-level-access \
  --public-access-prevention \
  --default-storage-class=STANDARD \
  --soft-delete-duration=7d

gcloud storage buckets update gs://${BUCKET} --enable-autoclass

# 2. A BigQuery connection, co-located with the bucket
bq mk --connection --location=${REGION} \
  --project_id=${PROJECT} \
  --connection_type=CLOUD_RESOURCE iceberg-conn

# 3. Grant the connection's service account access to the bucket.
#    Google documents TWO roles here — objectUser alone is not enough.
SA=$(bq show --format=prettyjson --connection \
  ${PROJECT}.${REGION}.iceberg-conn | jq -r .cloudResource.serviceAccountId)

for ROLE in roles/storage.objectUser roles/storage.legacyBucketReader; do
  gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --member="serviceAccount:${SA}" \
    --role="${ROLE}"
done
```

That second role is the one people miss. Granting only Storage Object User is the most common reason table creation fails with a permissions error that doesn't obviously point at the bucket.

Then the table itself. Table partitioning, multi-statement transactions, and the advanced runtime all went **GA for Apache Iceberg managed tables on July 13, 2026**:

```sql
CREATE TABLE `acme-analytics.sales.orders` (
  order_id      INT64,
  customer_id   INT64,
  order_ts      TIMESTAMP,
  region_code   STRING,
  total_amount  NUMERIC
)
PARTITION BY TIMESTAMP_TRUNC(order_ts, DAY)
CLUSTER BY region_code, customer_id
WITH CONNECTION `acme-analytics.us-central1.iceberg-conn`
OPTIONS (
  file_format  = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri  = 'gs://acme-lakehouse-sales-us-central1/3f/orders'
);
```

A few constraints to design around:

- `CLUSTER BY` takes **up to four columns**, and "they must be top-level, non-repeated columns." BigQuery scopes jobs to the right partitions "similar to Iceberg hidden partitioning."
- Partition columns are restricted to `DATE`, `DATETIME`, or `TIMESTAMP`, with hourly, daily, monthly, or yearly granularity. That rules out integer-range partitioning by implication; Iceberg's own `bucket` and `truncate` transforms aren't offered here either.
- **Partition evolution isn't supported.** Choose your granularity carefully — this is another one-way door.
- Column types are narrower than standard BigQuery: `BIGNUMERIC`, `INTERVAL`, `JSON`, `RANGE`, and `GEOGRAPHY` aren't supported. Check your schema before you port it.

Load data, and publish metadata for external engines:

```sql
LOAD DATA INTO `acme-analytics.sales.orders`
FROM FILES (
  uris   = ['gs://acme-staging-us-central1/orders/*.parquet'],
  format = 'PARQUET'
);
```

Two constraints on that load path: `LOAD DATA` and batch loading "only support appending data to existing" tables, and they "don't support schema updates." Plan your schema changes through DDL instead.

```bash
# Refresh the Iceberg V2 snapshot that Spark/Trino read
bq query --use_legacy_sql=false \
  --display_name='sales.orders metadata refresh' \
  --schedule='every 24 hours' \
  'EXPORT TABLE METADATA FROM sales.orders'
```

One freshness caveat for anyone building on the exported snapshot: "Iceberg metadata might not contain data that was streamed to BigQuery by the Storage Write API within the last 90 minutes." External engines reading the snapshot are not reading a real-time view of a streaming table.

For multi-engine access, point Spark at the Lakehouse runtime catalog's Iceberg REST endpoint with credential vending, so the engine receives short-lived, path-scoped GCS tokens instead of a long-lived key:

```
spark.sql.extensions = org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
spark.sql.catalog.lakehouse                        = org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.lakehouse.type                   = rest
spark.sql.catalog.lakehouse.uri                    = https://biglake.googleapis.com/iceberg/v1/restcatalog
spark.sql.catalog.lakehouse.warehouse              = gs://acme-lakehouse-sales-us-central1
spark.sql.catalog.lakehouse.rest.auth.type         = org.apache.iceberg.gcp.auth.GoogleAuthManager
spark.sql.catalog.lakehouse.io-impl                = org.apache.iceberg.gcp.gcs.GCSFileIO
spark.sql.catalog.lakehouse.header.x-goog-user-project          = acme-analytics
spark.sql.catalog.lakehouse.header.X-Iceberg-Access-Delegation  = vended-credentials
```

Three things that will bite you here:

- The `warehouse` value depends on your catalog type. A **single-bucket** catalog takes the `gs://BUCKET` form shown above; a **multi-bucket** catalog takes `bl://projects/PROJECT_ID/catalogs/CATALOG_ID` instead.
- `GoogleAuthManager` needs **Apache Iceberg 1.10 or later** — earlier releases don't have built-in support for Google's authorization flows.
- Two different service accounts need two different grants. The catalog's auto-provisioned service account needs **Storage Object User (`roles/storage.objectUser`)** on every associated bucket; your *engine's* service account needs **BigLake Editor (`roles/biglake.editor`)** for write-scoped vended credentials, or **BigLake Viewer (`roles/biglake.viewer`)** for read-only.

## The checklist

| Layer | Setting | Do this | Why |
|---|---|---|---|
| Namespace | Hierarchical namespace | **Enable at creation** | Up to 8x initial QPS; atomic folder rename; cannot be added later |
| Location | Bucket location | Single region, same as BQ dataset | Avoids per-read egress; enables gRPC direct connectivity |
| Topology | Bucket granularity | One per data domain per region | IAM boundaries; separate keyspaces; stays under the 1,500-principal cap |
| Topology | Table prefix | Unique, empty, hash-sharded | GC eats untracked files in shared prefixes |
| Access | UBLA + public access prevention | Enable both | Required for HNS; Iceberg best practice |
| Throughput | Egress quota | Budget against 200 Gbps (25 GB/s) per region | Scoped by region, not by bucket — buckets don't add bandwidth |
| Throughput | Rapid Cache | Cache hot partitions only | 2.5 TB/s on a separate bandwidth budget; misses fall back to the bucket quota |
| Cost | Autoclass | Enable **on an empty bucket** | Waives early-deletion fees, but enabling on existing cold data triggers a one-time charge |
| Safety | Soft delete | Keep the 7-day default | Iceberg guidance overrides the general high-churn advice |
| Safety | Lifecycle `Delete` rules | **Never on data/ or metadata/** | Lifecycle doesn't read manifests; BigQuery GC handles it |
| Safety | Object versioning, ACLs, CSEK, locks | Avoid all | Explicitly unsupported for Iceberg managed tables |

## Closing thought

The pattern across all five layers is the same: **the storage layer's failure modes are slow and expensive, and its decisions compound.** A badly-clustered table is a bad afternoon. A flat-namespace multi-region bucket holding two petabytes is a bad year.

The good news is that the list of things you genuinely cannot change later is short — three items — and the commands to get them right fit on one screen. Spend the hour on the bucket before you spend the quarter on the query.

If you're running Iceberg at scale on GCS and your experience diverges from any of this, I'd like to hear it — particularly on the HNS-plus-Autoclass question, which Google documents in neither direction.

## References

- [Request rate and access distribution guidelines](https://docs.cloud.google.com/storage/docs/request-rate)
- [Hierarchical namespace overview](https://docs.cloud.google.com/storage/docs/hns-overview) · [Best practices for HNS buckets](https://docs.cloud.google.com/storage/docs/hns-buckets-best-practices)
- [Best practices for Iceberg managed tables](https://docs.cloud.google.com/biglake/docs/best-practices-biglake-iceberg-tables)
- [Apache Iceberg managed tables in BigQuery](https://docs.cloud.google.com/bigquery/docs/biglake-iceberg-tables-in-bigquery)
- [Lakehouse introduction](https://docs.cloud.google.com/lakehouse/docs/introduction) · [Set up the Iceberg REST catalog endpoint](https://docs.cloud.google.com/lakehouse/docs/set-up-lakehouse-iceberg-rest-catalog) · [Credential vending](https://docs.cloud.google.com/lakehouse/docs/credential-vending)
- [Rapid Cache](https://docs.cloud.google.com/storage/docs/rapid/rapid-cache) · [Cloud Storage quotas and limits](https://docs.cloud.google.com/storage/quotas)
- [Autoclass](https://docs.cloud.google.com/storage/docs/autoclass) · [Soft delete](https://docs.cloud.google.com/storage/docs/soft-delete) · [Object Lifecycle Management](https://docs.cloud.google.com/storage/docs/lifecycle)
