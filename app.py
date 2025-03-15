from flask import Flask, request, jsonify
import asyncio
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError
import os
import logging
import socket

# Configure logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

async def extract_content(url, selector, timeout=30000, first_only=False, wait_options=None):
    """Visit the URL and extract content matching the selector using Playwright
    
    Args:
        url (str): The URL to visit
        selector (str): The CSS selector to extract
        timeout (int): Navigation timeout in milliseconds
        first_only (bool): If True, only return the first match
        wait_options (dict): Options for waiting for page to be ready:
            - load_state (str): 'networkidle', 'domcontentloaded', 'load' (default: 'networkidle')
            - wait_for_selector (str): Optional selector to wait for before extracting content
            - wait_time (int): Additional time to wait in milliseconds after page load
        
    Returns:
        list: List of dictionaries containing HTML and text content
    """
    # Default wait options
    if wait_options is None:
        wait_options = {}
    
    # Validate wait options
    load_state = wait_options.get('load_state', 'networkidle')
    # Make sure load_state is a valid value
    if load_state not in ('networkidle', 'domcontentloaded', 'load'):
        logger.warning(f"Invalid load_state '{load_state}', defaulting to 'networkidle'")
        load_state = 'networkidle'
        
    # Make sure wait_for_selector is a valid string selector or None
    wait_for_selector = wait_options.get('wait_for_selector', None)
    if wait_for_selector is not None:
        # Convert to string if it's a number
        if isinstance(wait_for_selector, (int, float)):
            logger.warning(f"wait_for_selector was a number ({wait_for_selector}), but should be a CSS selector string. Setting to None.")
            wait_for_selector = None
        elif not isinstance(wait_for_selector, str) or not wait_for_selector.strip():
            logger.warning(f"Invalid wait_for_selector, should be a non-empty string. Setting to None.")
            wait_for_selector = None
    
    # Make sure wait_time is a valid number
    wait_time = wait_options.get('wait_time', 0)
    if not isinstance(wait_time, (int, float)) or wait_time < 0:
        logger.warning(f"Invalid wait_time '{wait_time}', defaulting to 0")
        wait_time = 0
    
    logger.info(f"Extracting content from {url} with selector '{selector}', first_only={first_only}")
    logger.info(f"Wait options: load_state={load_state}, wait_for_selector={wait_for_selector}, wait_time={wait_time}ms")
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        try:
            page = await browser.new_page()
            
            # Configure navigation timeout
            page.set_default_navigation_timeout(timeout)
            
            try:
                # Navigate to the page and wait for initial load state
                response = await page.goto(url, wait_until=load_state)
                
                if not response:
                    return {"error": "Failed to get response from page"}
                
                status = response.status
                if status >= 400:
                    return {"error": f"Page returned status code {status}"}
                
                # If we need to wait for a specific element to appear
                if wait_for_selector:
                    try:
                        logger.info(f"Waiting for selector: {wait_for_selector}")
                        await page.wait_for_selector(wait_for_selector, timeout=timeout)
                    except PlaywrightTimeoutError:
                        return {"error": f"Timeout waiting for selector '{wait_for_selector}'"}
                    except Exception as e:
                        logger.error(f"Error waiting for selector '{wait_for_selector}': {str(e)}")
                        return {"error": f"Invalid selector '{wait_for_selector}': {str(e)}"}
                
                # If we need additional wait time for JavaScript
                if wait_time > 0:
                    logger.info(f"Waiting additional {wait_time}ms for JavaScript")
                    await page.wait_for_timeout(wait_time)
                
                # Check if selector exists
                try:
                    if not await page.query_selector(selector):
                        return {"error": f"Selector '{selector}' not found on page"}
                except Exception as e:
                    logger.error(f"Error with content selector '{selector}': {str(e)}")
                    return {"error": f"Invalid content selector '{selector}': {str(e)}"}
                
                results = []
                
                if first_only:
                    # Get only the first match (equivalent to querySelector)
                    element = await page.query_selector(selector)
                    if element:
                        html = await element.inner_html()
                        text = await element.text_content()
                        results.append({
                            "html": html,
                            "text": text
                        })
                else:
                    # Get all matches (equivalent to querySelectorAll)
                    elements = await page.query_selector_all(selector)
                    for element in elements:
                        html = await element.inner_html()
                        text = await element.text_content()
                        results.append({
                            "html": html,
                            "text": text
                        })
                
                return results
                
            except PlaywrightTimeoutError:
                logger.error(f"Timeout while loading {url}")
                return {"error": f"Timeout while loading {url}"}
            except Exception as e:
                logger.error(f"Error navigating to page: {str(e)}")
                return {"error": str(e)}
                
        finally:
            await browser.close()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint to verify the service is running"""
    return jsonify({"status": "ok"})

@app.route('/extract', methods=['POST'])
def handle_extract():
    data = request.json
    
    if not data or 'url' not in data or 'selector' not in data:
        return jsonify({"error": "Missing required fields: url and selector"}), 400
    
    url = data['url']
    selector = data['selector']
    
    # Get optional parameters
    timeout = data.get('timeout', 30) * 1000
    first_only = data.get('first_only', False)
    
    # Get wait options
    wait_options = {}
    if 'wait_for' in data:
        wait_options = data['wait_for']
        
        # Convert wait_time from seconds to milliseconds if provided
        if 'wait_time' in wait_options:
            try:
                wait_options['wait_time'] = float(wait_options['wait_time']) * 1000
            except (ValueError, TypeError):
                logger.warning(f"Invalid wait_time value: {wait_options['wait_time']}")
                wait_options['wait_time'] = 0
    
    try:
        # Run the async function using asyncio
        content = asyncio.run(extract_content(url, selector, timeout, first_only, wait_options))
        
        # Check for error in content
        if isinstance(content, dict) and 'error' in content:
            return jsonify(content), 500
            
        return jsonify({"results": content})
    except Exception as e:
        logger.exception("Error processing request")
        return jsonify({"error": str(e)}), 500

def is_running_in_docker():
    """Check if the application is running inside a Docker container"""
    # Method 1: Check for .dockerenv file
    if os.path.exists('/.dockerenv'):
        return True
    
    # Method 2: Check cgroup
    try:
        with open('/proc/1/cgroup', 'r') as f:
            return 'docker' in f.read()
    except:
        pass
    
    # Method 3: Check environment variable
    if os.environ.get('RUNNING_IN_DOCKER') == 'true':
        return True
    
    return False

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'False').lower() in ('true', '1', 't')
    
    # Determine if this is running in Docker or as a service
    is_docker = is_running_in_docker()
    is_service = os.environ.get('RUNNING_AS_SERVICE') == 'true'
    
    # Bind to all interfaces when in Docker, local interface when running as service
    host = '0.0.0.0' if is_docker else '127.0.0.1'
    
    logger.info(f"Starting server on {host}:{port}, debug={debug}, docker={is_docker}, service={is_service}")
    app.run(host=host, port=port, debug=debug) 