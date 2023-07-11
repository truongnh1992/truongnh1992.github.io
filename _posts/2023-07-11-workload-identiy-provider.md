---
layout: post
title: Workload Identity Federation for Github Provider
excerpt: "Assume we want to deploy a CloudRun service to a GCP project from GitHub Action. GitHub needs to be authorized with GCP. We can generate the JSON key of a service account (that has sufficient IAM roles) and store it in the Github Repo as Secrets. Then we use this Service Account key to call GCP APIs. ⇒ It’s hazardous (in case that key is leaked)."
tags: GCP DevOps SRE
image: /assets/img/wif.png
comments: false
---

Assume we want to deploy a CloudRun service to a GCP project from GitHub Action. GitHub needs to be authorized with GCP.
We can generate the JSON key of a service account (that has sufficient IAM roles) and store it in the Github Repo as Secrets.
Then we use this Service Account key to call GCP APIs. => It’s hazardous (in case that key is leaked).

But fortunately, GCP has a safer way to implement the same thing using `Workload Identity Federation`.

<img src="/assets/img/wif.png">
_Workload Identity Federation workflow_

### 1. Create a Workload Identity Pool
A *Workload Identity Pool* is used to manage external identities outside the GCP environment. The following command will create a new pool named: `github-wif-pool`
```bash
gcloud iam workload-identity-pools create github-wif-pool \
--location="global" --project=PROJECT-ID
```


### 2. Create a Workload Identity Pool Provider
A *Workload Identity Pool Provider* describes the relationship between Google Cloud and an external Identity Provider (IdP). In this article, the IdP is GitHub OIDC Provider.
GCP IAM uses a token of the GitHub OIDC provider to authorize the permission on GCP resources.
```
gcloud iam workload-identity-pools providers create-oidc githubwif \
--location="global" --workload-identity-pool="github-wif-pool" \
--issuer-uri="https://token.actions.githubusercontent.com" \
--attribute-mapping="attribute.actor=assertion.actor,google.subject=assertion.sub,attribute.repository=assertion.repository" \
--project=PROJECT-ID
```

### 3. Service Account and IAMs
For example, we'll use this service account `SA-NAME@PROJECT-ID.iam.gserviceaccount.com` with sufficient permission to deploy a CloudRun service. `Workload Identiy Provider` impersonates the service account.

We need to grant the role `roles/iam.workloadIdentityUser` to the above service account.

If we only allow IAM to authen the request coming from a specific Github repository `your-github-username/your-repo`
```
gcloud iam service-accounts add-iam-policy-binding SA-NAME@PROJECT-ID.iam.gserviceaccount.com \
--project=PROJECT-ID \
--role="roles/iam.workloadIdentityUser" \
--member="principalSet://iam.googleapis.com/projects/PROJECT-NUMBER/locations/global/workloadIdentityPools/github-wif-pool/attribute.repository/your-github-username/your-repo"
```

### 4. Step Google Auth on GitHub Action workflow file
Now, we can enable keyless authentication from GitHub Actions to GCP resources by defining this step in the workflow file.

```yaml
- name: Google Auth
  id: auth
  uses: 'google-github-actions/auth@v1'
  with:
    token_format: 'access_token'
    workload_identity_provider: 'projects/PROJECT-NUMBER/locations/global/workloadIdentityPools/github-wif-pool/providers/githubwif'
    service_account: 'SA-NAME@PROJECT-ID.iam.gserviceaccount.com'
```

***That's all. Thanks for reading!***