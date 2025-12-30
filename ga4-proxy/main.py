"""
GA4 View Counter Proxy Service
A Cloud Run service that fetches page view counts from Google Analytics 4
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import (
    RunReportRequest,
    Dimension,
    Metric,
    DateRange,
)
from datetime import datetime, timedelta
import os
import logging

app = Flask(__name__)

# Configure CORS to allow requests from your GitHub Pages site
CORS(app, resources={
    r"/api/*": {
        "origins": [
            "https://truongnh1992.github.io",
            "https://truongnh-gde.dev",      # Custom domain
            "https://www.truongnh-gde.dev",  # Custom domain with www
            "http://localhost:4000",          # For local testing
            "http://127.0.0.1:4000"
        ]
    }
})

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# GA4 Property ID
GA4_PROPERTY_ID = os.environ.get('GA4_PROPERTY_ID', '')

def get_page_views(page_path):
    """
    Fetch page views for a specific page path from GA4
    
    Args:
        page_path: The URL path of the page (e.g., '/my-post.html')
    
    Returns:
        int: Number of page views
    """
    try:
        # Initialize the client (uses Application Default Credentials)
        client = BetaAnalyticsDataClient()
        
        # Try multiple path variations to handle different GA4 tracking formats
        paths_to_try = [
            page_path,                          # Original path
            page_path.rstrip('/'),              # Without trailing slash
            page_path.replace('.html', ''),     # Without .html extension
            page_path.replace('.html', '') + '/', # Without .html but with trailing slash
        ]
        
        # Remove duplicates while preserving order
        paths_to_try = list(dict.fromkeys(paths_to_try))
        
        for path in paths_to_try:
            # Create the request
            request = RunReportRequest(
                property=f"properties/{GA4_PROPERTY_ID}",
                dimensions=[Dimension(name="pagePath")],
                metrics=[Metric(name="screenPageViews")],
                date_ranges=[DateRange(start_date="2018-01-01", end_date="today")],
                dimension_filter={
                    "filter": {
                        "field_name": "pagePath",
                        "string_filter": {
                            "match_type": "EXACT",
                            "value": path
                        }
                    }
                }
            )
            
            # Execute the request
            response = client.run_report(request)
            
            # Extract the view count
            if response.row_count > 0:
                views = int(response.rows[0].metric_values[0].value)
                if views > 0:
                    logger.info(f"Found {views} views for {page_path} using path format: {path}")
                    return views
        
        logger.info(f"No views found for {page_path} (tried {len(paths_to_try)} path variations)")
        return 0
        
    except Exception as e:
        logger.error(f"Error fetching GA4 data for {page_path}: {str(e)}")
        return 0

def get_multiple_page_views(page_paths):
    """
    Fetch page views for multiple page paths from GA4
    
    Args:
        page_paths: List of URL paths
    
    Returns:
        dict: Dictionary mapping page paths to view counts
    """
    try:
        client = BetaAnalyticsDataClient()
        
        # Create the request for all pages
        request = RunReportRequest(
            property=f"properties/{GA4_PROPERTY_ID}",
            dimensions=[Dimension(name="pagePath")],
            metrics=[Metric(name="screenPageViews")],
            date_ranges=[DateRange(start_date="2018-01-01", end_date="today")],
        )
        
        response = client.run_report(request)
        
        # Build a dictionary of ALL page views from GA4
        ga4_views = {}
        for row in response.rows:
            path = row.dimension_values[0].value
            views = int(row.metric_values[0].value)
            ga4_views[path] = views
        
        # Match requested paths with GA4 data using different variations
        views_dict = {}
        for requested_path in page_paths:
            # Generate all possible variations of this path
            variations = [
                requested_path,                          # Original
                requested_path.rstrip('/'),              # Without trailing slash
                requested_path.replace('.html', ''),     # Without .html
                requested_path.replace('.html', '') + '/', # Without .html, with slash
                requested_path + '/' if not requested_path.endswith('/') else requested_path[:-1], # Toggle trailing slash
            ]
            
            # Remove duplicates while preserving order
            variations = list(dict.fromkeys(variations))
            
            # Try to find a match in GA4 data
            found = False
            for variation in variations:
                if variation in ga4_views and ga4_views[variation] > 0:
                    views_dict[requested_path] = ga4_views[variation]
                    logger.info(f"Matched {requested_path} to GA4 path {variation} ({ga4_views[variation]} views)")
                    found = True
                    break
            
            if not found:
                views_dict[requested_path] = 0
        
        return views_dict
        
    except Exception as e:
        logger.error(f"Error fetching GA4 data for multiple pages: {str(e)}")
        return {path: 0 for path in page_paths}

@app.route('/api/views', methods=['GET'])
def get_views():
    """
    API endpoint to get page views for one or more pages
    
    Query params:
        - path: Single page path (e.g., /my-post.html)
        - paths: Comma-separated list of page paths
    
    Returns:
        JSON with view counts
    """
    single_path = request.args.get('path')
    multiple_paths = request.args.get('paths')
    
    if single_path:
        views = get_page_views(single_path)
        return jsonify({
            'path': single_path,
            'views': views
        })
    
    elif multiple_paths:
        paths_list = [p.strip() for p in multiple_paths.split(',')]
        views_dict = get_multiple_page_views(paths_list)
        return jsonify({
            'views': views_dict
        })
    
    else:
        return jsonify({
            'error': 'Please provide either "path" or "paths" parameter'
        }), 400

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/')
def index():
    """Root endpoint"""
    return jsonify({
        'service': 'GA4 View Counter Proxy',
        'version': '1.0.0',
        'endpoints': {
            'health': '/api/health',
            'views': '/api/views?path=/your-post.html',
            'multiple': '/api/views?paths=/post1.html,/post2.html'
        }
    })

if __name__ == '__main__':
    # This is used when running locally
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)

