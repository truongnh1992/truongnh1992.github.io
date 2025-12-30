# GA4 View Counter Proxy Service

This is a serverless proxy service that fetches page view counts from Google Analytics 4 (GA4) and exposes them via a REST API. It's designed to be deployed on Google Cloud Run.

## Features

- Fetch page views for individual pages
- Batch fetch views for multiple pages
- CORS-enabled for use with static websites
- Secure: Uses Google Cloud IAM for authentication
- Scalable: Automatically scales with Cloud Run

## Prerequisites

- Google Cloud Project with billing enabled
- GA4 property set up and tracking your website
- `gcloud` CLI installed and configured
- GA4 Property ID (format: `123456789`)

## Setup Instructions

### 1. Find Your GA4 Property ID

1. Go to [Google Analytics](https://analytics.google.com/)
2. Click on **Admin** (gear icon at bottom left)
3. In the **Property** column, click **Property Settings**
4. Your Property ID is shown at the top (format: `123456789`)

### 2. Set Up Service Account Permissions

The Cloud Run service needs access to your GA4 data:

```bash
# Set your project ID
export GCP_PROJECT_ID="your-project-id"
export GA4_PROPERTY_ID="your-ga4-property-id"

# Get the Cloud Run service account
export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format="value(projectNumber)")
export SERVICE_ACCOUNT="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

echo "Service Account: $SERVICE_ACCOUNT"
```

Then, add this service account to GA4:

1. Go to [Google Analytics Admin](https://analytics.google.com/analytics/web/#/a{your-account}/admin)
2. In the **Property** column, click **Property Access Management**
3. Click the **+** button and select **Add users**
4. Add the service account email (from above)
5. Assign **Viewer** role
6. Click **Add**

### 3. Deploy to Cloud Run

```bash
# Navigate to the ga4-proxy directory
cd ga4-proxy

# Make the deploy script executable
chmod +x deploy.sh

# Deploy (replace with your actual values)
GCP_PROJECT_ID="your-project-id" \
GA4_PROPERTY_ID="your-property-id" \
GCP_REGION="us-central1" \
./deploy.sh
```

The deployment script will:
- Enable required GCP APIs
- Build the Docker container
- Deploy to Cloud Run
- Configure environment variables
- Output the service URL

### 4. Test the Deployment

```bash
# Get your service URL from the deployment output
export SERVICE_URL="https://ga4-view-counter-xxx.run.app"

# Test health endpoint
curl $SERVICE_URL/api/health

# Test view count for a single page
curl "$SERVICE_URL/api/views?path=/your-post.html"

# Test view counts for multiple pages
curl "$SERVICE_URL/api/views?paths=/post1.html,/post2.html"
```

### 5. Update Your Jekyll Site

After deployment, update the `API_URL` in your Jekyll site's JavaScript file:

```javascript
// In assets/js/ga4-analytics.js
const API_URL = 'https://your-service-url.run.app';
```

## API Endpoints

### GET /api/health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-12-30T10:00:00.000000"
}
```

### GET /api/views?path={page_path}

Get view count for a single page.

**Parameters:**
- `path`: The page path (e.g., `/my-post.html`)

**Response:**
```json
{
  "path": "/my-post.html",
  "views": 1234
}
```

### GET /api/views?paths={page_paths}

Get view counts for multiple pages.

**Parameters:**
- `paths`: Comma-separated list of page paths

**Response:**
```json
{
  "views": {
    "/post1.html": 1234,
    "/post2.html": 5678
  }
}
```

## Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export GA4_PROPERTY_ID="your-property-id"
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"

# Run locally
python main.py
```

The service will be available at http://localhost:8080

## Security Considerations

- The service is deployed as **public** (allow-unauthenticated) since it's serving read-only view counts
- No sensitive data is exposed - only aggregate page view numbers
- CORS is configured to only allow requests from your domain
- Consider implementing rate limiting for production use
- Consider implementing caching to reduce GA4 API calls

## Cost Optimization

Cloud Run free tier includes:
- 2 million requests per month
- 360,000 GB-seconds of memory
- 180,000 vCPU-seconds

For most personal blogs, this service will stay within the free tier.

To further optimize costs:
- Implement caching (Redis/Memorystore)
- Use Cloud CDN to cache responses
- Set appropriate `min-instances=0` to scale to zero when not in use

## Troubleshooting

### "Permission denied" errors

Make sure the Cloud Run service account has Viewer access to your GA4 property.

### CORS errors

Check that your domain is listed in the CORS configuration in `main.py`.

### "Property not found" errors

Verify your GA4_PROPERTY_ID is correct (just the numeric ID, without "properties/" prefix).

## License

MIT License - feel free to use and modify for your needs.

