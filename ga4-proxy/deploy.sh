#!/bin/bash

# GA4 View Counter Proxy - Deployment Script
# This script deploys the service to Google Cloud Run

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID}"
REGION="${GCP_REGION:-asia-southeast1}"
SERVICE_NAME="ga4-view-counter"
GA4_PROPERTY_ID="${GA4_PROPERTY_ID}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check required environment variables
if [ -z "$PROJECT_ID" ]; then
    print_error "GCP_PROJECT_ID environment variable is not set"
    echo "Usage: GCP_PROJECT_ID=your-project GA4_PROPERTY_ID=your-property-id ./deploy.sh"
    exit 1
fi

if [ -z "$GA4_PROPERTY_ID" ]; then
    print_error "GA4_PROPERTY_ID environment variable is not set"
    echo "Usage: GCP_PROJECT_ID=your-project GA4_PROPERTY_ID=your-property-id ./deploy.sh"
    exit 1
fi

print_info "Starting deployment to Google Cloud Run..."
print_info "Project: $PROJECT_ID"
print_info "Region: $REGION"
print_info "Service: $SERVICE_NAME"

# Set the project
print_info "Setting GCP project..."
gcloud config set project "$PROJECT_ID"

# Enable required APIs
print_info "Enabling required APIs..."
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable analyticsdata.googleapis.com

# Build and deploy to Cloud Run
print_info "Building and deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
    --source . \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-env-vars "GA4_PROPERTY_ID=$GA4_PROPERTY_ID" \
    --memory 512Mi \
    --cpu 1 \
    --timeout 60 \
    --max-instances 10 \
    --min-instances 0

# Get the service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --platform managed \
    --region "$REGION" \
    --format 'value(status.url)')

print_info "Deployment completed successfully!"
print_info "Service URL: $SERVICE_URL"
echo ""
print_info "Test the service:"
echo "  curl $SERVICE_URL/api/health"
echo ""
print_info "Next steps:"
echo "  1. Update your Jekyll site's ga4-analytics.js file"
echo "  2. Set the API_URL to: $SERVICE_URL"
echo "  3. Rebuild and deploy your Jekyll site"

