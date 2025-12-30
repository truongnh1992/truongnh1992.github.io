#!/bin/bash

# GA4 View Counter - Test Script
# Quick script to test your deployed service

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== GA4 View Counter Test Script ===${NC}\n"

# Check if SERVICE_URL is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage:${NC} ./test.sh <service-url>"
    echo "Example: ./test.sh https://ga4-view-counter-abc123.run.app"
    echo ""
    echo "To get your service URL:"
    echo "  gcloud run services describe ga4-view-counter --region=us-central1 --format='value(status.url)'"
    exit 1
fi

SERVICE_URL=$1

echo -e "${GREEN}Testing service:${NC} $SERVICE_URL\n"

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
echo "GET $SERVICE_URL/api/health"
response=$(curl -s "$SERVICE_URL/api/health")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Success${NC}"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
else
    echo -e "${RED}✗ Failed${NC}"
fi
echo ""

# Test 2: Single Page View Count
echo -e "${YELLOW}Test 2: Single Page View Count${NC}"
echo "GET $SERVICE_URL/api/views?path=/production-ready-ai-agent-with-google-adk-and-mcp-on-cloud-run.html"
response=$(curl -s "$SERVICE_URL/api/views?path=/production-ready-ai-agent-with-google-adk-and-mcp-on-cloud-run.html")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Success${NC}"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
else
    echo -e "${RED}✗ Failed${NC}"
fi
echo ""

# Test 3: Multiple Pages View Count
echo -e "${YELLOW}Test 3: Multiple Pages View Count${NC}"
echo "GET $SERVICE_URL/api/views?paths=/cloudrun-gemini.html,/cloudrun-aistudio.html"
response=$(curl -s "$SERVICE_URL/api/views?paths=/cloudrun-gemini.html,/cloudrun-aistudio.html")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Success${NC}"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
else
    echo -e "${RED}✗ Failed${NC}"
fi
echo ""

# Test 4: CORS Check
echo -e "${YELLOW}Test 4: CORS Headers${NC}"
echo "Checking CORS headers..."
cors_header=$(curl -s -I -H "Origin: https://truongnh1992.github.io" "$SERVICE_URL/api/health" | grep -i "access-control-allow-origin" || echo "")
if [ -n "$cors_header" ]; then
    echo -e "${GREEN}✓ CORS headers present${NC}"
    echo "$cors_header"
else
    echo -e "${RED}✗ CORS headers missing${NC}"
    echo "Warning: This might cause issues when calling from your website"
fi
echo ""

# Summary
echo -e "${GREEN}=== Test Complete ===${NC}\n"
echo "Next steps:"
echo "1. If all tests passed, update assets/js/ga4-analytics.js with:"
echo "   const API_URL = '$SERVICE_URL';"
echo ""
echo "2. Test locally:"
echo "   bundle exec jekyll serve"
echo ""
echo "3. Deploy:"
echo "   git add . && git commit -m 'Add GA4 view counter' && git push"

