# Headless DOM Content Extractor

A containerized web scraping API that extracts content from websites based on CSS selectors.

## Overview

This Docker container runs a web server that accepts HTTP POST requests with a URL and CSS selector, 
visits the webpage using Playwright (a headless browser automation tool), 
and returns the content matching the selector.

## Usage

### Build the Docker Image

```bash
docker build -t headless-dom .
```

For a more secure version that runs as a non-root user:

```bash
docker build -t headless-dom-secure -f Dockerfile-secure .
```

### Run the Container Securely

```bash
docker run -p 127.0.0.1:5000:5000 headless-dom
```

This is the recommended way to run the container:
- The Flask app inside the container binds to all interfaces (0.0.0.0)
- But Docker only exposes the port on localhost (127.0.0.1)
- This ensures the service is only accessible from your local machine

You can change the port:

```bash
docker run -p 127.0.0.1:8080:5000 headless-dom
```

### Environment Variables

You can customize the behavior using environment variables:

- `PORT`: Change the port the server listens on inside the container (default: 5000)
- `DEBUG`: Enable debug mode (default: false)

Example:

```bash
# Change port and enable debug mode
docker run -p 127.0.0.1:8080:8080 -e PORT=8080 -e DEBUG=true headless-dom
```

### Security Considerations

For maximum security:

1. Always use `-p 127.0.0.1:5000:5000` instead of `-p 5000:5000` to expose the port only on localhost
2. Use the secure Dockerfile that runs as a non-root user:
   ```bash
   docker run -p 127.0.0.1:5000:5000 headless-dom-secure
   ```
3. See SECURITY.md for additional security recommendations

### API Endpoints

#### Health Check

- **URL**: `/health`
- **Method**: `GET`
- **Response**: `{"status": "ok"}`

You can verify the service is running with:

```bash
curl http://localhost:5000/health
```

#### Content Extraction

- **URL**: `/extract`
- **Method**: `POST`
- **Content-Type**: `application/json`
- **Request Body**:
  ```json
  {
    "url": "https://example.com",
    "selector": "h3",
    "timeout": 30,
    "first_only": false,
    "wait_for": {
      "load_state": "networkidle",
      "wait_for_selector": ".content-loaded",
      "wait_time": 5
    }
  }
  ```

#### Parameters:

- `url` (required): The website URL to visit
- `selector` (required): CSS selector to extract (e.g., "h1", ".class-name", "#id", etc.)
- `timeout` (optional): Maximum time in seconds to wait for page load (default: 30)
- `first_only` (optional): If true, only returns the first matching element (default: false)
- `wait_for` (optional): Options for handling JavaScript-heavy pages:
  - `load_state` (optional): Page load state to wait for - 'networkidle', 'domcontentloaded', or 'load' (default: 'networkidle')
  - `wait_for_selector` (optional): Additional selector to wait for before extracting content
  - `wait_time` (optional): Additional time in seconds to wait after page load

> **Important**: Always use proper CSS selector strings for the `selector` and `wait_for_selector` parameters. 
> Don't use numbers or empty strings as selectors.
> For example, use `"#element-id"`, `".classname"`, or `"div > p"` instead of `15` or `""`.

### Handling JavaScript-Heavy Pages

For pages with complex JavaScript that take time to load fully:

1. **Method 1**: Wait for a specific indicator element to appear
   ```json
   "wait_for": {
     "wait_for_selector": "#app-loaded"
   }
   ```
   This will wait until an element matching the selector appears on the page, which is ideal when your app displays a specific element when it's fully loaded.

2. **Method 2**: Wait for a specific amount of time
   ```json
   "wait_for": {
     "wait_time": 15
   }
   ```
   This will wait for an additional 15 seconds after the initial page load, which is useful for apps with known load times.

3. **Method 3**: Change the load state criterion
   ```json
   "wait_for": {
     "load_state": "load"
   }
   ```
   You can choose between 'domcontentloaded' (faster but before all resources loaded), 'load' (when page load event fires), or 'networkidle' (when network has been idle for 500ms).

4. **Method 4**: Combine approaches
   ```json
   "wait_for": {
     "load_state": "load",
     "wait_for_selector": ".dashboard-ready",
     "wait_time": 2
   }
   ```
   This will wait for the load event, then wait for the .dashboard-ready element, and finally wait an additional 2 seconds.

### CSS Selector Examples

The `selector` parameter accepts standard CSS selectors:

```javascript
// Get all h1 elements
"selector": "h1"

// Get the first div with class 'content'
"selector": "div.content", "first_only": true

// Get all links inside the navigation
"selector": "nav a"

// Get elements with specific attributes
"selector": "[data-testid='product-card']"

// Combine multiple selectors for complex targeting
"selector": "article.blog-post > h2, main .headline"

// Get the first element matching specific child elements
"selector": ".products li:first-child", "first_only": true

// Target by ID
"selector": "#main-content"
```

### Example Requests

Using curl to get all H1 elements:

```bash
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","selector":"h1"}'
```

Using curl to get only the first matching element:

```bash
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","selector":"h1","first_only":true}'
```

Using curl with a more complex selector and timeout:

```bash
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","selector":"article .title, main h2","timeout":45}'
```

Using curl with JavaScript-heavy page options:

```bash
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://spa-example.com","selector":".dashboard-data","wait_for":{"wait_for_selector":".app-loaded","wait_time":5}}'
```

Using curl with a long wait time for JavaScript-heavy pages:

```bash
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://spa-example.com","selector":".dashboard-data","wait_for":{"wait_time":15}}'
```

### Common Errors and Fixes

1. **"Error while parsing selector"** - Make sure you're using a valid CSS selector string, not a number or empty string:
   ```
   // Incorrect:
   "wait_for": {"wait_for_selector": 15}
   
   // Correct:
   "wait_for": {"wait_for_selector": "#element-with-id"}
   ```

2. **"Timeout waiting for selector"** - The element never appeared on the page within the timeout period. Try a different selector or increase the timeout.

3. **"Selector not found on page"** - Your target content selector doesn't match any elements. Check that the selector is correct and the page has loaded properly.

### Example Response

When getting all matching elements (default):

```json
{
  "results": [
    {
      "html": "Example Domain",
      "text": "Example Domain"
    },
    {
      "html": "Another Heading",
      "text": "Another Heading"
    }
  ]
}
```

When getting only the first match (`first_only: true`):

```json
{
  "results": [
    {
      "html": "Example Domain",
      "text": "Example Domain"
    }
  ]
}
```

### Error Response

If an error occurs, the API will return a JSON object with an error message:

```json
{
  "error": "Selector 'h5' not found on page"
}
```

## Features

- Containerized solution for easy deployment
- Extracts both HTML and text content from matched elements
- Handles multiple matching elements
- Supports querySelector-like behavior (first match only option)
- Built on Playwright for reliable web scraping
- Configurable timeouts for slow-loading pages
- Advanced options for JavaScript-heavy applications
- Detailed error messages for debugging
- Secure Docker configuration

## Troubleshooting

If you encounter any issues:

1. Check that the URL is accessible
2. Verify that your CSS selector is valid
3. Try increasing the timeout for slow-loading websites
4. For JavaScript-heavy pages, use the wait_for options:
   - Set `wait_for_selector` to an element that appears when your content is loaded
   - Or set `wait_time` to allow sufficient time for JavaScript execution
5. Some websites may block automated browsers or require additional handling for JavaScript rendering
6. Check the container logs for more detailed error information:
   ```bash
   docker logs <container_id>
   ```
7. If you can't connect to the service with curl, make sure you're using the correct port and hostname (localhost)

### Playwright Browser Issues

If you see errors like "Executable doesn't exist" or browser installation messages:

1. Rebuild the Docker image from scratch to ensure a clean installation:
   ```bash
   docker build --no-cache -t headless-dom-secure -f Dockerfile-secure .
   ```

2. Test that Playwright can access the browser inside the container:
   ```bash
   docker run --rm headless-dom-secure python -c "from playwright.sync_api import sync_playwright; print('Browser works!') if sync_playwright().start().chromium.launch() else print('Browser failed')"
   ```

3. For the secure container, make sure the browser is installed as the non-root user, which is handled by the Dockerfile-secure.

## License

MIT 