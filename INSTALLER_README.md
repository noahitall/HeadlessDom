# HeadlessDom Installer for macOS

This package installs HeadlessDom as a native macOS service that runs on startup, without requiring Docker.

## Building the Installer

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

## Installation

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

### Automatic Startup on Installation

The installer has been enhanced to ensure HeadlessDom starts automatically:

1. The service is configured as a LaunchAgent to start at system boot
2. During installation, the service is loaded immediately 
3. A verification step checks if the service started correctly
4. If the service fails to start, a fallback LaunchDaemon is created to ensure it loads on the next restart

If you need to restart the service manually after installation:
```bash
sudo headlessdom restart
```

## Troubleshooting Installation

If installation fails or the service doesn't start:

1. Check the installation logs:
   ```bash
   sudo cat /var/log/install.log | grep HeadlessDom
   ```

2. Ensure Python 3 is properly installed:
   ```bash
   python3 --version
   ```

3. If you see security warnings, you may need to:
   - Go to System Preferences > Security & Privacy
   - Click "Allow" for the blocked installer
   - Or run: `sudo spctl --master-disable` to temporarily disable Gatekeeper

4. If the service isn't running after installation:
   ```bash
   # Check the status
   headlessdom status
   
   # View any error logs
   headlessdom logs
   
   # Restart the service
   sudo headlessdom restart
   ```

5. In rare cases, a system restart may be needed for the service to start correctly

## Managing the Service

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

## Common Errors and Solutions

### Browser Installation Issues

If you see errors like "Executable doesn't exist" or "Playwright was just installed or updated":

```bash
# Reinstall the browser in the correct location
sudo headlessdom reinstall-browser

# Then restart the service
headlessdom restart
```

This command ensures the browser is installed in the custom browser path that the service is configured to use (`/Applications/HeadlessDom/browsers`).

### LaunchAgent Not Loading

If the service isn't starting automatically:

```bash
# Check if the plist file exists
ls -la /Library/LaunchAgents/com.headlessdom.service.plist

# Try manually loading the service
sudo launchctl load -w /Library/LaunchAgents/com.headlessdom.service.plist

# Check for errors
sudo launchctl list | grep headlessdom
```

### File Permission Issues

If you have trouble with file permissions:

```bash
sudo chmod -R 755 /Applications/HeadlessDom
sudo chown -R root:wheel /Applications/HeadlessDom
```

## Manual Installation (Without Installer)

If you prefer to install manually:

1. Clone the repository and set up the directories:
   ```bash
   sudo mkdir -p /Applications/HeadlessDom/logs
   sudo cp app.py /Applications/HeadlessDom/
   ```

2. Create the requirements file:
   ```bash
   echo "flask==2.0.1
   werkzeug==2.0.1
   playwright==1.37.0" | sudo tee /Applications/HeadlessDom/requirements.txt
   ```

3. Set up the Python environment:
   ```bash
   cd /Applications/HeadlessDom
   sudo python3 -m venv venv
   sudo bash -c "source venv/bin/activate && pip install -r requirements.txt"
   ```

4. Install Playwright browsers:
   ```bash
   sudo mkdir -p /Applications/HeadlessDom/browsers
   sudo bash -c "cd /Applications/HeadlessDom && source venv/bin/activate && PLAYWRIGHT_BROWSERS_PATH=/Applications/HeadlessDom/browsers python -m playwright install chromium"
   ```

5. Create the LaunchAgent:
   ```bash
   sudo bash -c 'cat > /Library/LaunchAgents/com.headlessdom.service.plist' << 'EOF'
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>com.headlessdom.service</string>
       <key>ProgramArguments</key>
       <array>
           <string>/Applications/HeadlessDom/venv/bin/python</string>
           <string>/Applications/HeadlessDom/app.py</string>
       </array>
       <key>EnvironmentVariables</key>
       <dict>
           <key>PORT</key>
           <string>5000</string>
           <key>RUNNING_AS_SERVICE</key>
           <string>true</string>
           <key>PLAYWRIGHT_BROWSERS_PATH</key>
           <string>/Applications/HeadlessDom/browsers</string>
       </dict>
       <key>RunAtLoad</key>
       <true/>
       <key>KeepAlive</key>
       <true/>
       <key>StandardErrorPath</key>
       <string>/Applications/HeadlessDom/logs/error.log</string>
       <key>StandardOutPath</key>
       <string>/Applications/HeadlessDom/logs/output.log</string>
       <key>WorkingDirectory</key>
       <string>/Applications/HeadlessDom</string>
   </dict>
   </plist>
   EOF
   ```

6. Load the service:
   ```bash
   sudo launchctl load -w /Library/LaunchAgents/com.headlessdom.service.plist
   ```

## Uninstalling

To uninstall HeadlessDom:

```bash
sudo /Applications/HeadlessDom/uninstall.sh
```

Or manually:

```bash
sudo launchctl unload /Library/LaunchAgents/com.headlessdom.service.plist
sudo rm -f /Library/LaunchAgents/com.headlessdom.service.plist
sudo rm -rf /Applications/HeadlessDom
sudo rm -f /usr/local/bin/headlessdom
# Also remove the backup startup daemon if it exists
sudo launchctl unload /Library/LaunchDaemons/com.headlessdom.startup.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.headlessdom.startup.plist
```

## Advanced: How It Works

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

## API Usage

Once installed, you can use the API exactly as you would with the Docker version:

```bash
# Check health
curl http://localhost:5000/health

# Extract content
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","selector":"h1"}'
``` 