# Headless DOM Content Extractor

A web scraping API that extracts content from websites based on CSS selectors. Available as both a Docker container and a native macOS service.

## Overview

This tool runs a web server that accepts HTTP POST requests with a URL and CSS selector, 
visits the webpage using Playwright (a headless browser automation tool), 
and returns the content matching the selector.

## Installation Options

You can run HeadlessDom in two ways:

1. **Docker Container** - Run as an isolated container (cross-platform)
2. **Native macOS Service** - Install directly on macOS to run as a system service

### Option 1: Docker Installation

Build the Docker image:

```bash
docker build -t headless-dom .
```

For a more secure version that runs as a non-root user:

```bash
docker build -t headless-dom-secure -f Dockerfile-secure .
```

Run the container securely:

```bash
docker run -p 127.0.0.1:5000:5000 headless-dom
```

### Option 2: Native macOS Installation

For macOS users who prefer not to use Docker, you can install HeadlessDom as a native service that starts automatically at system boot.

#### Building the Installer

Follow these steps to build the installer package:

1. Make sure the required build tools are installed:
   ```bash
   # Check if the required tools are available
   which pkgbuild productbuild
   ```
   If the tools are not found, install the Command Line Tools:
   ```bash
   xcode-select --install
   ```

2. Run the build script:
   ```bash
   chmod +x build_installer.sh
   ./build_installer.sh
   ```

3. The script will create the installer at `HeadlessDom-Build/HeadlessDom-Installer.pkg`

#### Installation Process

1. Double-click the `HeadlessDom-Installer.pkg` file
2. Follow the on-screen instructions
3. Enter your administrator password when prompted
4. The installer will:
   - Create the HeadlessDom directories in `/Applications/HeadlessDom/`
   - Set up a Python virtual environment
   - Install required dependencies
   - Install Playwright and the Chromium browser to a dedicated path
   - Configure the service to start automatically
   - Verify that the service has started successfully

5. After installation completes, verify the service is running:
   ```bash
   headlessdom status
   headlessdom test
   ```

#### Managing the macOS Service

The installer adds a command-line tool for managing the service:

```bash
# Check status
headlessdom status

# Stop the service
headlessdom stop

# Start the service
headlessdom restart

# View logs
headlessdom logs

# Test the service
headlessdom test
# or
curl http://localhost:5000/health

# Reinstall Playwright browser if needed
sudo headlessdom reinstall-browser
```

To uninstall:
```bash
sudo /Applications/HeadlessDom/uninstall.sh
```

## Usage

### Environment Variables

You can customize the behavior using environment variables:

- `PORT`: Change the port the server listens on (default: 5000)
- `DEBUG`: Enable debug mode (default: false)
- `RUNNING_AS_SERVICE`: Set by the macOS installer to configure service-specific behavior

Example with Docker:

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
3. The native macOS service automatically binds only to localhost for security

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

- Available as both a Docker container and native macOS service
- Extracts both HTML and text content from matched elements
- Handles multiple matching elements
- Supports querySelector-like behavior (first match only option)
- Built on Playwright for reliable web scraping
- Configurable timeouts for slow-loading pages
- Advanced options for JavaScript-heavy applications
- Detailed error messages for debugging
- Secure configurations

## Troubleshooting

### General Issues

If you encounter any issues:

1. Check that the URL is accessible
2. Verify that your CSS selector is valid
3. Try increasing the timeout for slow-loading websites
4. For JavaScript-heavy pages, use the wait_for options:
   - Set `wait_for_selector` to an element that appears when your content is loaded
   - Or set `wait_time` to allow sufficient time for JavaScript execution
5. Some websites may block automated browsers or require additional handling for JavaScript rendering

### Docker-Specific Troubleshooting

Check the container logs for more detailed error information:
```bash
docker logs <container_id>
```

If you can't connect to the service with curl, make sure you're using the correct port and hostname (localhost).

### macOS Native Service Troubleshooting

#### Browser Installation Issues

If you see errors like "Executable doesn't exist" or "Playwright was just installed or updated":

```bash
# Reinstall the browser in the correct location
sudo headlessdom reinstall-browser

# Then restart the service
headlessdom restart
```

This command ensures the browser is installed in the custom browser path that the service is configured to use (`/Applications/HeadlessDom/browsers`).

#### Service Not Starting

If the service isn't starting automatically:

```bash
# Check if the plist file exists
ls -la /Library/LaunchAgents/com.headlessdom.service.plist

# Try manually loading the service
sudo launchctl load -w /Library/LaunchAgents/com.headlessdom.service.plist

# Check for errors
sudo launchctl list | grep headlessdom
```

#### Installation Failures

Check the installation logs:
```bash
sudo cat /var/log/install.log | grep HeadlessDom
```

If you see security warnings, you may need to:
- Go to System Preferences > Security & Privacy
- Click "Allow" for the blocked installer
- Or run: `sudo spctl --master-disable` to temporarily disable Gatekeeper

#### File Permission Issues

If you have trouble with file permissions:

```bash
sudo chmod -R 755 /Applications/HeadlessDom
sudo chown -R root:wheel /Applications/HeadlessDom
```

## Advanced: How the macOS Service Works

### System Architecture

The installer sets up a Python-based web service that:

1. Runs as a LaunchAgent at system startup
2. Uses a dedicated browser installation path (`/Applications/HeadlessDom/browsers`)
3. Binds only to localhost (127.0.0.1) for security
4. Logs to `/Applications/HeadlessDom/logs/`

### Launch Agent and Daemon Configuration

HeadlessDom uses two mechanisms to ensure reliable startup:

1. **Primary LaunchAgent**: Installed in `/Library/LaunchAgents/` with:
   - `RunAtLoad` set to `true` - makes the service start at boot
   - `KeepAlive` set to `true` - restarts the service if it terminates unexpectedly

2. **Fallback LaunchDaemon**: Created only if the primary service fails to start, located at `/Library/LaunchDaemons/`:
   - Acts as a backup to ensure the service loads even if the initial loading fails
   - Runs with system-level privileges to avoid permission issues

### Browser Installation

HeadlessDom is configured to:

1. Install browsers in a dedicated directory: `/Applications/HeadlessDom/browsers`
2. Use the `PLAYWRIGHT_BROWSERS_PATH` environment variable to point to this directory
3. Run as the root user for system-wide accessibility

This approach prevents permission issues that can occur when the service looks for browsers in user-specific cache directories.

## License

MIT 