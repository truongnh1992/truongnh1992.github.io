---
layout: post
title: Centralized multiple GCP Projects logs
excerpt: "This article will show you how to accomplish log-file unification with access control using GCP’s Cloud Logging service."
tags: GCP DevOps SRE
image: /assets/img/centralized-gcp-logs.png
comments: false
---


Assume that all of your company workloads are running on Google Cloud. There are many GCP projects across your organization.
It's very inconvenient when team members want to check logs of applications on different projects. Fortunately, Google Cloud allows us to ship all the logs from different projects into one place.

<img src="/assets/img/centralized-gcp-logs.png">

{:.image-caption}
Architecture

### Filter logs at the organization level with a sink
We can use an aggregated sink to combine and route logs from the GCP projects in an organization or folder.
The filtered logs from our GCP projects and send to one of the following destinations:
- **Cloud Storage**: JSON files are stored in Cloud Storage buckets.
- **Pub/Sub**: JSON files stored in Cloud Storage buckets.
- **BigQuerry**: Tables created in BigQuery datasets.
- **Cloud Logging buckets**

This article will show you how to ship all the logs from all GCP projects in Org to a `Log bucket` in a specific project.

### IAM Requirements

To create a log sink, make sure that you have one of the following IAM roles:
  * **Owner** (`roles/owner`)
  * **Logging Admin** (`roles/logging.admin`)
  * **Logs Configuration Writer** (`roles/logging.configWriter`)

#### Step 1: Choose the log dedicated project

The common log bucket can be one of the projects in your organization.

For example, let's create a log bucket on the project with project-id: `$YOUR_PROJECT_ID`

```
gcloud logging buckets create --location=global --retention-days=7 --project=$YOUR_PROJECT_ID specific-log
```

Result:

<img src="/assets/img/specific-log.png">

#### Step 2: Create an aggregated sink

You can create an aggregated sink by running the following command:

```
gcloud logging sinks create sink-specific-logs --organization=$ORGANIZATION_ID --include-children \
logging.googleapis.com/projects/logging.googleapis.com/projects/$YOUR_PROJECT_ID/locations/global/buckets/specific-log
```

#### Check the log entries

Go to the Cloud Logging console and click `REFINE SCOPE`

<img src="/assets/img/refinescope.png">

Then, select the `Scope by storage` and select the only `specific-log` log bucket created in **Step 1**.

<img src="/assets/img/scopebystorage.png">

Now, you can choose the project you want to check logs on the left pane.

<img src="/assets/img/centralizedlogs.png">

> **Note from Google Cloud docs**: It is possible to be charged for ingesting the same log entry multiple times. For example, if your sinks route a log entry to three log buckets, ingesting that log entry's counts towards your ingestion allotment three times.

To avoid paying multiple times for log ingestion, you can disable the `_Default` log sink on GCP Projects.

***That's all. Thanks for reading!***