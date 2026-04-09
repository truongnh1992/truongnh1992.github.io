---
layout: post
title: Running Gemma 4 on Cloud Run with NVIDIA RTX 6000 Pro GPU and vLLM
categories: [GCP, Gemma 4, Cloud Run]
excerpt: "Deploying a massive open model like Google's Gemma 4 used to require complex Kubernetes setups. Now, with Cloud Run's GPU support, you can launch it as a serverless, auto-scaling endpoint. This tutorial covers deploying the Gemma 4 31B Instruction-Tuned model on an NVIDIA RTX 6000 Pro GPU, combining vLLM for high throughput with Run:ai Model Streamer for ultra-fast cold starts."
image: assets/img/gemma4.png
---

## Introduction

Deploying a massive open model like Google's Gemma 4 used to require complex Kubernetes setups. Now, with Cloud Run's GPU support, you can launch it as a serverless, auto-scaling endpoint. This tutorial covers deploying the `Gemma 4 31B Instruction-Tuned` model on an **NVIDIA RTX 6000 Pro GPU**, combining **vLLM** for high throughput with **Run:ai Model Streamer** for ultra-fast cold starts.

By the end, you'll have an OpenAI-compatible API endpoint that auto-scales from zero to multiple instances based on demand.

![image](assets/img/gemma4.png)

## Architecture Overview

The deployment consists of four key components:

- **Cloud Run** — serves the model behind an HTTPS endpoint, auto-scales instances, and manages GPU allocation
- **vLLM** — high-performance inference engine with continuous batching, prefix caching, and chunked prefill
- **Cloud Storage** — stores model weights close to the compute region, eliminating repeated downloads from HuggingFace
- **Direct VPC Egress** — enables fast private network access from Cloud Run to Cloud Storage via Private Google Access, dramatically reducing model load time

The request flow is straightforward: client sends an OpenAI-compatible chat completion request to Cloud Run, which routes it to vLLM running on the GPU instance. vLLM handles batching, KV-cache management, and token generation.


## Prerequisites

- A Google Cloud project with billing enabled
- `gcloud` CLI installed and authenticated
- Access to the [Gemma 4 model on HuggingFace](https://huggingface.co/google/gemma-4-31B-it) (accept the license agreement)

## Step 1: Environment Setup

Define the variables that will be used throughout the deployment:

```bash
export MODEL_NAME="google/gemma-4-31B-it"
export SERVICE_NAME=gemma-rtx-vllm
export GOOGLE_CLOUD_PROJECT=<YOUR_PROJECT_ID>
export GOOGLE_CLOUD_REGION=asia-southeast1
export HF_TOKEN=""  # HuggingFace token if model is private

export SERVICE_ACCOUNT="vllm-service-sa"
export SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

export MODEL_CACHE_BUCKET="${GOOGLE_CLOUD_PROJECT}-${GOOGLE_CLOUD_REGION}-hf-model-cache"
export GCS_MODEL_LOCATION="gs://${MODEL_CACHE_BUCKET}/model-cache/${MODEL_NAME}"

export VPC_NETWORK="vllm-${GOOGLE_CLOUD_REGION}-net"
export VPC_SUBNET="vllm-${GOOGLE_CLOUD_REGION}-subnet"
export SUBNET_RANGE="10.8.0.0/26"

gcloud config set project $GOOGLE_CLOUD_PROJECT
gcloud config set run/region $GOOGLE_CLOUD_REGION
```

Enable the required APIs:

```bash
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com \
    compute.googleapis.com \
    vpcaccess.googleapis.com \
    storage.googleapis.com
```

## Step 2: Create a Dedicated Service Account

Running Cloud Run services with the Compute Engine default service account is a security anti-pattern. Create a dedicated service account with minimal permissions:

```bash
gcloud iam service-accounts create ${SERVICE_ACCOUNT} \
  --display-name "vLLM Service Account"
```

## Step 3: Cache Model Weights in Cloud Storage

Downloading 60+ GB of model weights from HuggingFace on every cold start would be unacceptably slow. Instead, cache the weights in a regional Cloud Storage bucket co-located with your Cloud Run service.

Create the bucket:

```bash
gcloud storage buckets create "gs://${MODEL_CACHE_BUCKET}" \
    --uniform-bucket-level-access \
    --public-access-prevention \
    --location "${GOOGLE_CLOUD_REGION}"
```

Grant the service account access to the bucket:

```bash
gcloud storage buckets add-iam-policy-binding "gs://${MODEL_CACHE_BUCKET}" \
    --member "serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role "roles/storage.admin"
```

Download and upload the model using Cloud Build (which provides enough disk space for the large model files):

```bash
gcloud builds submit --region="${GOOGLE_CLOUD_REGION}" --no-source \
    --substitutions="_MODEL_NAME=${MODEL_NAME},_HF_TOKEN=${HF_TOKEN},_GCS_MODEL_LOCATION=${GCS_MODEL_LOCATION}" \
    --config=/dev/stdin <<'EOF'
steps:
- name: 'gcr.io/google.com/cloudsdktool/google-cloud-cli:slim'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    set -e
    pip3 install --root-user-action=ignore --break-system-packages huggingface_hub[cli]
    echo "Downloading the model..."
    if [[ "$_HF_TOKEN" != "" ]]; then
      hf download "$_MODEL_NAME" --token $_HF_TOKEN --local-dir "./model-cache/$_MODEL_NAME"
    else
      hf download "$_MODEL_NAME" --local-dir "./model-cache/$_MODEL_NAME"
    fi
    echo "Uploading the model..."
    gcloud storage cp -r "./model-cache/$_MODEL_NAME" "$_GCS_MODEL_LOCATION"
options:
  machineType: 'E2_HIGHCPU_8'
  diskSizeGb: 500
EOF
```


## Step 4: Configure Direct VPC Egress

This is the key optimization for cold start performance. Direct VPC Egress with Private Google Access allows Cloud Run to download model weights from Cloud Storage over Google's internal network rather than the public internet.

Create a VPC network and subnet:

```bash
gcloud compute networks create "$VPC_NETWORK" \
    --subnet-mode=custom \
    --bgp-routing-mode=regional

gcloud compute networks subnets create "$VPC_SUBNET" \
    --network="$VPC_NETWORK" \
    --region="$GOOGLE_CLOUD_REGION" \
    --range="$SUBNET_RANGE" \
    --enable-private-ip-google-access
```

The `--enable-private-ip-google-access` flag is critical — it allows traffic to Google APIs (including Cloud Storage) without going through the public internet.

## Step 5: Deploy to Cloud Run

### Tuning Parameters

Before deploying, configure the inference and service parameters:

```bash
export MAX_MODEL_LEN=32767       # Reduced from 256K max to improve concurrency
export QUANTIZATION_TYPE="fp8"   # FP8 quantization for speed + lower memory
export KV_CACHE_DTYPE="fp8"      # FP8 KV-cache to save GPU memory
export GPU_MEM_UTIL="0.95"       # Use 95% of GPU memory
export TENSOR_PARALLEL_SIZE="1"  # Single GPU, no tensor parallelism
export MAX_NUM_SEQS=8            # Max concurrent requests per batch

export CLOUD_RUN_CPU_NUM=20
export CLOUD_RUN_MEMORY_GB=80
export CLOUD_RUN_MAX_INSTANCES=3
export CLOUD_RUN_CONCURRENCY=16
```

Key tuning considerations:

| Parameter | Effect | Trade-off |
|-----------|--------|-----------|
| `MAX_MODEL_LEN` | Maximum context window per request | Lower = more concurrent requests fit in GPU memory |
| `MAX_NUM_SEQS` | Requests batched together by vLLM | Higher throughput but increased per-request latency |
| `CLOUD_RUN_CONCURRENCY` | Requests routed to one instance | Should be >= `MAX_NUM_SEQS`; set ~2x for traffic spikes |
| `GPU_MEM_UTIL` | GPU memory allocated to vLLM | Higher = more KV-cache space, but risk of OOM |
| `QUANTIZATION_TYPE` | Model weight precision | FP8 halves memory vs BF16, minimal quality loss |

### Build the vLLM Command

```bash
CONTAINER_ARGS=(
    "vllm" "serve" "${GCS_MODEL_LOCATION}"
    "--served-model-name" "${MODEL_NAME}"
    "--enable-log-requests"
    "--enable-chunked-prefill"
    "--enable-prefix-caching"
    "--generation-config" "auto"
    "--enable-auto-tool-choice"
    "--tool-call-parser" "gemma4"
    "--reasoning-parser" "gemma4"
    "--dtype" "bfloat16"
    "--quantization" "${QUANTIZATION_TYPE}"
    "--kv-cache-dtype" "${KV_CACHE_DTYPE}"
    "--max-num-seqs" "${MAX_NUM_SEQS}"
    "--limit-mm-per-prompt" "'{\"image\":4,\"video\":2}'"
    "--gpu-memory-utilization" "${GPU_MEM_UTIL}"
    "--tensor-parallel-size" "${TENSOR_PARALLEL_SIZE}"
    "--load-format" "runai_streamer"
    "--port" "8080"
    "--host" "0.0.0.0"
)

if [[ "${MAX_MODEL_LEN}" != "" ]]; then
    CONTAINER_ARGS+=("--max-model-len" "${MAX_MODEL_LEN}")
fi

export CONTAINER_ARGS_STR="${CONTAINER_ARGS[*]}"
```

Notable flags:

- **`--load-format runai_streamer`** — Uses Run:ai Model Streamer to load weights in parallel from GCS, significantly reducing startup time compared to standard loading
- **`--enable-chunked-prefill`** — Allows long prompts to be processed in chunks alongside generation, improving latency for concurrent requests
- **`--enable-prefix-caching`** — Caches KV states for common prompt prefixes (e.g., system prompts), avoiding redundant computation
- **`--tool-call-parser gemma4`** / **`--reasoning-parser gemma4`** — Enables native tool calling and chain-of-thought reasoning support

### Deploy

```bash
gcloud beta run deploy "${SERVICE_NAME}" \
    --image="us-docker.pkg.dev/vertex-ai/vertex-vision-model-garden-dockers/pytorch-vllm-serve:gemma4" \
    --service-account "${SERVICE_ACCOUNT_EMAIL}" \
    --execution-environment gen2 \
    --no-allow-unauthenticated \
    --cpu="${CLOUD_RUN_CPU_NUM}" \
    --memory="${CLOUD_RUN_MEMORY_GB}Gi" \
    --gpu=1 \
    --gpu-type=nvidia-rtx-pro-6000 \
    --no-gpu-zonal-redundancy \
    --no-cpu-throttling \
    --max-instances ${CLOUD_RUN_MAX_INSTANCES} \
    --concurrency ${CLOUD_RUN_CONCURRENCY} \
    --network ${VPC_NETWORK} \
    --subnet ${VPC_SUBNET} \
    --vpc-egress all-traffic \
    --set-env-vars "MODEL_NAME=${MODEL_NAME}" \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT}" \
    --set-env-vars "GOOGLE_CLOUD_REGION=${GOOGLE_CLOUD_REGION}" \
    --startup-probe tcpSocket.port=8080,initialDelaySeconds=240,failureThreshold=1,timeoutSeconds=240,periodSeconds=240 \
    --command "bash" \
    --args="^;^-c;${CONTAINER_ARGS_STR}"
```

The startup probe is set to 240 seconds because loading a 31B parameter model — even with Run:ai Model Streamer and VPC Egress — takes a few minutes.

## Step 6: Test the Endpoint

Retrieve the service URL and send a test request:

```bash
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --format 'value(status.url)')

curl -s "$SERVICE_URL/v1/chat/completions" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
  "model": "'"${MODEL_NAME}"'",
  "messages": [
    {"role": "user", "content": "Why is the sky blue?"}
  ],
  "chat_template_kwargs": {
    "enable_thinking": true
  },
  "skip_special_tokens": false
}' | jq -r '.choices[0].message.content'
```

The `enable_thinking` flag activates Gemma 4's chain-of-thought reasoning, where the model shows its reasoning process before giving a final answer.

Since the service is deployed with `--no-allow-unauthenticated`, requests require a valid identity token. For service-to-service calls, use Workload Identity or a service account token instead of `gcloud auth print-identity-token`.


## Cost and Performance Considerations

**Cold starts**: The combination of GCS model caching + Direct VPC Egress + Run:ai Model Streamer brings cold start from potentially 10+ minutes (downloading from HuggingFace) down to a few minutes. Setting `--min-instances=1` eliminates cold starts entirely at the cost of continuous billing.

**Scaling**: With `max-instances=3` and `concurrency=16`, the service handles up to 48 concurrent requests. Each instance costs GPU time, so tune `max-instances` based on your traffic pattern.

**Quantization**: FP8 quantization roughly halves GPU memory usage compared to BF16 with minimal quality degradation for most tasks. This is what allows a 31B model to run on a single RTX 6000 Pro (48 GB VRAM).


## Cleanup

Remove all resources to avoid ongoing charges:

```bash
gcloud run services delete $SERVICE_NAME --quiet
gcloud iam service-accounts delete ${SERVICE_ACCOUNT_EMAIL} --quiet
gcloud storage rm --recursive gs://$MODEL_CACHE_BUCKET
gcloud compute networks subnets delete $VPC_SUBNET \
    --region "${GOOGLE_CLOUD_REGION}" --quiet
gcloud compute networks delete $VPC_NETWORK --quiet
```


## Summary

This deployment pattern — vLLM on Cloud Run with GPU, backed by GCS model caching and VPC Egress — gives you a production-grade inference endpoint with several advantages over VM-based or GKE deployments:

- **No cluster management** — Cloud Run handles scaling, networking, and TLS
- **Pay-per-use** — scale to zero when idle (if `min-instances=0`)
- **OpenAI-compatible API** — drop-in replacement for existing applications using the OpenAI SDK
- **Fast cold starts** — Run:ai Model Streamer + Direct VPC Egress minimize startup latency

For production workloads, consider adding IAM-based authentication, Cloud Armor for rate limiting, and monitoring via Cloud Logging and Cloud Trace.

