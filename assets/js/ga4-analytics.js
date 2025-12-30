/**
 * GA4 Analytics View Counter
 * Fetches and displays page view counts from GA4 via Cloud Run proxy
 */

// Configuration - Update this with your Cloud Run service URL
const API_URL = 'https://ga4-view-counter-oze7nwnjba-as.a.run.app'; // e.g., 'https://ga4-view-counter-xxx.run.app'

// Cache for view counts (to avoid redundant API calls)
const viewCountCache = new Map();
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

/**
 * Format view count with K, M suffixes for large numbers
 */
function formatViewCount(count) {
  if (count === 0) return '0';
  if (count < 1000) return count.toString();
  if (count < 1000000) return (count / 1000).toFixed(1).replace(/\.0$/, '') + 'K';
  return (count / 1000000).toFixed(1).replace(/\.0$/, '') + 'M';
}

/**
 * Get cached view count if available and not expired
 */
function getCachedViewCount(path) {
  const cached = viewCountCache.get(path);
  if (cached && (Date.now() - cached.timestamp < CACHE_DURATION)) {
    return cached.count;
  }
  return null;
}

/**
 * Set view count in cache
 */
function setCachedViewCount(path, count) {
  viewCountCache.set(path, {
    count: count,
    timestamp: Date.now()
  });
}

/**
 * Fetch view count for a single page
 */
async function fetchSingleViewCount(pagePath) {
  try {
    // Check cache first
    const cached = getCachedViewCount(pagePath);
    if (cached !== null) {
      return cached;
    }

    // Fetch from API
    const response = await fetch(`${API_URL}/api/views?path=${encodeURIComponent(pagePath)}`);
    if (!response.ok) {
      console.warn(`Failed to fetch view count for ${pagePath}: ${response.status}`);
      return 0;
    }

    const data = await response.json();
    const count = data.views || 0;
    
    // Cache the result
    setCachedViewCount(pagePath, count);
    
    return count;
  } catch (error) {
    console.error(`Error fetching view count for ${pagePath}:`, error);
    return 0;
  }
}

/**
 * Fetch view counts for multiple pages (batch)
 */
async function fetchMultipleViewCounts(pagePaths) {
  try {
    // Separate cached and uncached paths
    const uncachedPaths = [];
    const results = {};

    for (const path of pagePaths) {
      const cached = getCachedViewCount(path);
      if (cached !== null) {
        results[path] = cached;
      } else {
        uncachedPaths.push(path);
      }
    }

    // If all paths are cached, return immediately
    if (uncachedPaths.length === 0) {
      return results;
    }

    // Fetch uncached paths
    const pathsParam = uncachedPaths.join(',');
    const response = await fetch(`${API_URL}/api/views?paths=${encodeURIComponent(pathsParam)}`);
    
    if (!response.ok) {
      console.warn(`Failed to fetch view counts: ${response.status}`);
      // Return cached results with zeros for uncached
      uncachedPaths.forEach(path => results[path] = 0);
      return results;
    }

    const data = await response.json();
    const views = data.views || {};
    
    // Merge with cached results and update cache
    for (const [path, count] of Object.entries(views)) {
      results[path] = count;
      setCachedViewCount(path, count);
    }

    // Fill in zeros for any missing paths
    uncachedPaths.forEach(path => {
      if (!(path in results)) {
        results[path] = 0;
        setCachedViewCount(path, 0);
      }
    });

    return results;
  } catch (error) {
    console.error('Error fetching view counts:', error);
    // Return zeros for all paths
    const results = {};
    pagePaths.forEach(path => results[path] = 0);
    return results;
  }
}

/**
 * Update view count display for a single element
 */
function updateViewCountElement(element, count) {
  const formattedCount = formatViewCount(count);
  element.innerHTML = `<i class="icon-eye"></i> ${formattedCount} views`;
  element.setAttribute('title', `${count.toLocaleString()} views`);
  element.classList.add('loaded');
}

/**
 * Display view count for current page (single post view)
 */
async function displayCurrentPageViews() {
  // Skip if API URL is not configured
  if (!API_URL || API_URL === 'YOUR_CLOUD_RUN_SERVICE_URL') {
    console.warn('GA4 Analytics API URL not configured');
    return;
  }

  const viewCountElement = document.getElementById('ga4-view-count');
  if (!viewCountElement) return;

  // Get the current page path
  const pagePath = window.location.pathname;
  
  // Show loading state
  viewCountElement.classList.add('loading');
  
  // Fetch and display view count
  const count = await fetchSingleViewCount(pagePath);
  updateViewCountElement(viewCountElement, count);
  viewCountElement.classList.remove('loading');
}

/**
 * Display view counts for all posts on home page
 */
async function displayAllPostViews() {
  // Skip if API URL is not configured
  if (!API_URL || API_URL === 'YOUR_CLOUD_RUN_SERVICE_URL') {
    console.warn('GA4 Analytics API URL not configured');
    return;
  }

  const viewCountElements = document.querySelectorAll('.ga4-view-count');
  if (viewCountElements.length === 0) return;

  // Collect all page paths
  const pagePaths = Array.from(viewCountElements).map(el => el.dataset.pagePath);
  
  // Show loading state
  viewCountElements.forEach(el => el.classList.add('loading'));

  // Fetch all view counts in batch
  const viewCounts = await fetchMultipleViewCounts(pagePaths);

  // Update each element
  viewCountElements.forEach(element => {
    const pagePath = element.dataset.pagePath;
    const count = viewCounts[pagePath] || 0;
    updateViewCountElement(element, count);
    element.classList.remove('loading');
  });
}

/**
 * Initialize view counter based on page type
 */
function initGA4ViewCounter() {
  // Check if we're on a single post page
  const singlePostElement = document.getElementById('ga4-view-count');
  if (singlePostElement) {
    displayCurrentPageViews();
  }

  // Check if we're on the home page with multiple posts
  const multiplePostElements = document.querySelectorAll('.ga4-view-count');
  if (multiplePostElements.length > 0) {
    displayAllPostViews();
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initGA4ViewCounter);
} else {
  initGA4ViewCounter();
}

// Export functions for potential manual use
window.GA4ViewCounter = {
  fetchSingleViewCount,
  fetchMultipleViewCounts,
  displayCurrentPageViews,
  displayAllPostViews,
  refresh: initGA4ViewCounter
};

