# GA4 View Counter Setup Guide

This guide will help you set up and display Google Analytics 4 (GA4) page view counts on your Jekyll blog.

## 🎯 Overview

The solution consists of:
1. **Cloud Run Service**: A serverless proxy that securely fetches data from GA4
2. **JavaScript Client**: Frontend code that displays view counts
3. **Jekyll Integration**: Layout updates to show view counts on posts

## 📋 Prerequisites

Before you begin, ensure you have:

- ✅ Google Cloud Project with billing enabled
- ✅ GA4 property already tracking your website (G-3BVZ3G2PM7)
- ✅ `gcloud` CLI installed ([Install Guide](https://cloud.google.com/sdk/docs/install))
- ✅ Basic knowledge of terminal/command line

## 🚀 Quick Start

### Step 1: Find Your GA4 Property ID

1. Go to [Google Analytics](https://analytics.google.com/)
2. Click **Admin** (⚙️ icon at bottom left)
3. In the **Property** column, click **Property Settings**
4. Find your **Property ID** (numeric, e.g., `123456789`)

💡 **Note**: This is different from your Measurement ID (G-3BVZ3G2PM7)

### Step 2: Deploy the Cloud Run Service

```bash
# Navigate to the ga4-proxy directory
cd ga4-proxy

# Make the deploy script executable
chmod +x deploy.sh

# Set your environment variables and deploy
GCP_PROJECT_ID="your-gcp-project-id" \
GA4_PROPERTY_ID="your-property-id" \
GCP_REGION="us-central1" \
./deploy.sh
```

**Example:**
```bash
GCP_PROJECT_ID="my-blog-project" \
GA4_PROPERTY_ID="123456789" \
GCP_REGION="us-central1" \
./deploy.sh
```

The script will:
- ✅ Enable required GCP APIs
- ✅ Build and deploy the Docker container
- ✅ Configure environment variables
- ✅ Output your service URL

**Save the service URL** - you'll need it in the next step!

### Step 3: Configure GA4 Access

The Cloud Run service needs permission to read your GA4 data:

1. Get your service account email (from deployment output):
   ```
   Service Account: 123456789-compute@developer.gserviceaccount.com
   ```

2. Add it to GA4:
   - Go to [Google Analytics Admin](https://analytics.google.com/)
   - Select your property
   - Click **Property Access Management**
   - Click the **+** button → **Add users**
   - Paste the service account email
   - Assign **Viewer** role
   - Click **Add**

### Step 4: Update Your Jekyll Site

Edit `assets/js/ga4-analytics.js` and replace the API URL:

```javascript
// Change this line:
const API_URL = 'YOUR_CLOUD_RUN_SERVICE_URL';

// To your actual Cloud Run URL:
const API_URL = 'https://ga4-view-counter-abc123.run.app';
```

### Step 5: Test Locally

```bash
# Build and serve your Jekyll site locally
bundle exec jekyll serve

# Open in browser
open http://localhost:4000
```

You should see view counts appearing next to each post!

### Step 6: Deploy to GitHub Pages

```bash
# Commit and push your changes
git add .
git commit -m "Add GA4 view counter feature"
git push origin main
```

GitHub Pages will automatically rebuild your site with the new features.

## 🧪 Testing

### Test the Cloud Run Service

```bash
# Set your service URL
export SERVICE_URL="https://ga4-view-counter-abc123.run.app"

# Test health endpoint
curl $SERVICE_URL/api/health

# Test a single page view count
curl "$SERVICE_URL/api/views?path=/your-post.html"

# Test multiple pages
curl "$SERVICE_URL/api/views?paths=/post1.html,/post2.html"
```

Expected response:
```json
{
  "path": "/your-post.html",
  "views": 1234
}
```

### Test in Browser Console

Open your blog in a browser and check the console:

```javascript
// Fetch view count for current page
await GA4ViewCounter.fetchSingleViewCount(window.location.pathname)

// Refresh all view counts
GA4ViewCounter.refresh()
```

## 🎨 Customization

### Change View Count Style

Edit `_includes/head.html` to customize the CSS:

```css
/* View counter styles */
.post-views {
  /* Your custom styles here */
}
```

### Change View Count Format

Edit `assets/js/ga4-analytics.js`:

```javascript
function formatViewCount(count) {
  // Customize formatting
  if (count < 1000) return count.toString();
  if (count < 1000000) return (count / 1000).toFixed(1) + 'K';
  return (count / 1000000).toFixed(1) + 'M';
}
```

### Hide View Counts

To temporarily disable view counts without removing code:

**Option 1**: Set API_URL to empty string in `ga4-analytics.js`:
```javascript
const API_URL = '';
```

**Option 2**: Comment out the script include in `_layouts/default.html`:
```html
<!-- <script src="{{ "/assets/js/ga4-analytics.js" | relative_url }}"></script> -->
```

## 🔒 Security & Privacy

### Security Features
- ✅ Service uses Google Cloud IAM for authentication
- ✅ No API keys exposed to client-side code
- ✅ CORS configured to only allow your domain
- ✅ Read-only access to analytics data
- ✅ No personal/sensitive data exposed

### Privacy Considerations
- View counts are **aggregate numbers only**
- No user-specific data is collected by this service
- Complies with GDPR as it doesn't process personal data
- GA4's own tracking still requires cookie consent per your jurisdiction

## 💰 Cost Estimates

### Cloud Run Pricing

**Free Tier (monthly):**
- 2 million requests
- 360,000 GB-seconds of memory
- 180,000 vCPU-seconds

**Estimated Usage for Personal Blog:**
- ~1,000 page views/day = ~30,000 API calls/month
- Well within free tier! 🎉

**If you exceed free tier:**
- $0.40 per million requests
- ~$0.01-0.05/month for most personal blogs

### GA4 API

- Free: 200,000 queries per day
- Your usage: ~1,000-5,000 per day
- Cost: **$0** 🎉

## 🐛 Troubleshooting

### View Counts Show "0 views" or Don't Load

**Check 1**: Verify API URL is correct
```javascript
// In ga4-analytics.js
console.log(API_URL); // Should output your Cloud Run URL
```

**Check 2**: Check browser console for errors
- Open DevTools (F12)
- Look for CORS or network errors

**Check 3**: Verify Cloud Run service is working
```bash
curl https://your-service.run.app/api/health
```

**Check 4**: Verify GA4 permissions
- Service account must have Viewer access in GA4

### CORS Errors

If you see CORS errors in the browser console:

1. Update `ga4-proxy/main.py` with your actual domain:
```python
CORS(app, resources={
    r"/api/*": {
        "origins": [
            "https://truongnh1992.github.io",
            "https://www.yoursite.com"  # Add your custom domain
        ]
    }
})
```

2. Redeploy the service:
```bash
cd ga4-proxy
./deploy.sh
```

### Slow Loading

If view counts take too long to load:

1. **Enable caching** (already implemented - caches for 5 minutes)
2. **Reduce timeout** in `ga4-analytics.js`:
```javascript
const CACHE_DURATION = 10 * 60 * 1000; // Change to 10 minutes
```

### Permission Errors

If you see "Permission denied" in Cloud Run logs:

1. Verify the service account has GA4 access
2. Wait 5-10 minutes for permissions to propagate
3. Check property ID is correct (numeric only, no "properties/" prefix)

## 📊 Monitoring

### View Cloud Run Logs

```bash
# View recent logs
gcloud run services logs read ga4-view-counter \
  --region=us-central1 \
  --limit=50
```

### Monitor in Google Cloud Console

1. Go to [Cloud Run Console](https://console.cloud.google.com/run)
2. Click on `ga4-view-counter`
3. View **Metrics** tab for:
   - Request count
   - Request latency
   - Error rate

## 🔄 Updating

### Update the Cloud Run Service

```bash
cd ga4-proxy

# Make changes to main.py
# Then redeploy
./deploy.sh
```

### Update the Frontend

```bash
# Edit assets/js/ga4-analytics.js or layouts
# Commit and push
git add .
git commit -m "Update view counter"
git push
```

## 🎓 Advanced Configuration

### Add Rate Limiting

Edit `ga4-proxy/main.py`:

```python
from flask_limiter import Limiter

limiter = Limiter(
    app,
    key_func=lambda: request.remote_addr,
    default_limits=["100 per hour"]
)

@app.route('/api/views', methods=['GET'])
@limiter.limit("50 per minute")
def get_views():
    # ... existing code
```

### Add Redis Caching

To reduce GA4 API calls, add Redis caching:

1. Create a Memorystore (Redis) instance
2. Update `main.py` to cache results
3. Set cache TTL to 1 hour

### Custom Domain

To use a custom domain for the API:

1. Set up Cloud Run domain mapping
2. Update `API_URL` in `ga4-analytics.js`
3. Update CORS settings in `main.py`

## 📚 Additional Resources

- [Google Analytics Data API Documentation](https://developers.google.com/analytics/devguides/reporting/data/v1)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Jekyll Documentation](https://jekyllrb.com/docs/)

## 🆘 Getting Help

If you run into issues:

1. Check the [troubleshooting section](#-troubleshooting)
2. View Cloud Run logs for errors
3. Test the API directly with curl
4. Check browser console for JavaScript errors

## 🎉 Success!

Once everything is working, you should see:
- View counts on all post listings (home page)
- View count on individual post pages
- Smooth loading animation
- ⚡ Fast loading with caching

Enjoy your new GA4 view counter! 🚀

