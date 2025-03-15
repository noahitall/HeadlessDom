#!/bin/bash

# Exit on error
set -e

echo "Building HeadlessDom Installer..."

# Create a temporary directory for building
BUILD_DIR="$(pwd)/HeadlessDom-Build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Create the necessary directory structure
mkdir -p build/{scripts,payload}
mkdir -p build/payload/Applications/HeadlessDom
mkdir -p build/payload/Applications/HeadlessDom/logs
mkdir -p build/payload/Library/LaunchAgents
mkdir -p resources

# Copy app.py to the payload directory
cp "$(pwd)/../app.py" build/payload/Applications/HeadlessDom/

# Create requirements.txt in the payload directory
cat > build/payload/Applications/HeadlessDom/requirements.txt << 'EOF'
flask==2.0.1
werkzeug==2.0.1
playwright==1.37.0
EOF

# Create the LaunchAgent plist file
cat > build/payload/Library/LaunchAgents/com.headlessdom.service.plist << 'EOF'
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

# Create the control script
cat > build/payload/Applications/HeadlessDom/headlessdom << 'EOF'
#!/bin/bash

SERVICE_NAME="com.headlessdom.service"
PLIST_PATH="/Library/LaunchAgents/$SERVICE_NAME.plist"

case "$1" in
  start)
    launchctl load $PLIST_PATH
    echo "HeadlessDom service started"
    ;;
  stop)
    launchctl unload $PLIST_PATH
    echo "HeadlessDom service stopped"
    ;;
  restart)
    launchctl unload $PLIST_PATH
    sleep 2
    launchctl load $PLIST_PATH
    echo "HeadlessDom service restarted"
    ;;
  status)
    if launchctl list | grep $SERVICE_NAME > /dev/null; then
      echo "HeadlessDom service is running"
    else
      echo "HeadlessDom service is not running"
    fi
    ;;
  logs)
    echo "=== Standard Output ==="
    cat /Applications/HeadlessDom/logs/output.log
    echo ""
    echo "=== Error Log ==="
    cat /Applications/HeadlessDom/logs/error.log
    ;;
  test)
    curl http://localhost:5000/health
    ;;
  reinstall-browser)
    echo "Reinstalling Playwright browsers..."
    cd /Applications/HeadlessDom
    source venv/bin/activate
    PLAYWRIGHT_BROWSERS_PATH=/Applications/HeadlessDom/browsers python -m playwright install chromium
    echo "Browser installation complete"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs|test|reinstall-browser}"
    exit 1
esac
exit 0
EOF

chmod +x build/payload/Applications/HeadlessDom/headlessdom

# Create the uninstaller script
cat > build/payload/Applications/HeadlessDom/uninstall.sh << 'EOF'
#!/bin/bash

echo "Uninstalling HeadlessDom..."

# Stop the service if running
launchctl unload /Library/LaunchAgents/com.headlessdom.service.plist 2>/dev/null

# Remove the launchd plist
rm -f /Library/LaunchAgents/com.headlessdom.service.plist

# Remove the symbolic link
rm -f /usr/local/bin/headlessdom

# Remove the application files
rm -rf /Applications/HeadlessDom

echo "HeadlessDom has been uninstalled."
exit 0
EOF

chmod +x build/payload/Applications/HeadlessDom/uninstall.sh

# Create preinstall script
cat > build/scripts/preinstall << 'EOF'
#!/bin/bash

# Stop the service if it's already running
if launchctl list | grep com.headlessdom.service > /dev/null; then
    launchctl unload /Library/LaunchAgents/com.headlessdom.service.plist 2>/dev/null
fi

# Create logs directory
mkdir -p /Applications/HeadlessDom/logs

exit 0
EOF

# Create postinstall script
cat > build/scripts/postinstall << 'EOF'
#!/bin/bash

# Set up Python virtual environment
cd /Applications/HeadlessDom

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is not installed. Please install it and try again."
    exit 1
fi

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create a specific directory for Playwright browsers
mkdir -p /Applications/HeadlessDom/browsers

# Install Playwright browsers to the specific directory
PLAYWRIGHT_BROWSERS_PATH=/Applications/HeadlessDom/browsers python -m playwright install chromium

# Set permissions
chmod -R 755 /Applications/HeadlessDom
chown -R root:wheel /Applications/HeadlessDom
chmod 644 /Library/LaunchAgents/com.headlessdom.service.plist

# Create symbolic link to the control script
mkdir -p /usr/local/bin
ln -sf /Applications/HeadlessDom/headlessdom /usr/local/bin/headlessdom

# Ensure the launch agent is loaded for all users by using a global domain
echo "Loading LaunchAgent for HeadlessDom..."
launchctl load /Library/LaunchAgents/com.headlessdom.service.plist

# Verify the service is running
sleep 3
if ! launchctl list | grep com.headlessdom.service > /dev/null; then
    echo "WARNING: Service did not start automatically. Attempting to start manually..."
    launchctl load -w /Library/LaunchAgents/com.headlessdom.service.plist
    
    # Create a startup item that will run at next login to ensure the service is running
    cat > /Library/LaunchDaemons/com.headlessdom.startup.plist << 'STARTUP_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.headlessdom.startup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>launchctl load -w /Library/LaunchAgents/com.headlessdom.service.plist</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
STARTUP_EOF
    chmod 644 /Library/LaunchDaemons/com.headlessdom.startup.plist
    launchctl load /Library/LaunchDaemons/com.headlessdom.startup.plist
fi

echo "HeadlessDom has been installed and started."
echo "You can manage it using: headlessdom {start|stop|restart|status|logs|test|reinstall-browser}"

# Create a file to track installation
date > /Applications/HeadlessDom/installed_on.txt

exit 0
EOF

# Make the scripts executable
chmod +x build/scripts/preinstall
chmod +x build/scripts/postinstall

# Create installer resources
cat > resources/welcome.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Welcome</title>
</head>
<body>
    <h2>Welcome to the HeadlessDom Installer</h2>
    <p>This will install HeadlessDom v1.0 on your computer and set it up to run as a service on startup.</p>
    <p>HeadlessDom provides a headless web browser API for extracting content from websites based on CSS selectors.</p>
    <p>The API will be available on http://localhost:5000 after installation.</p>
    <p>It will bind only to localhost (127.0.0.1) for security, unlike the Docker version which can be configured to bind to all interfaces.</p>
</body>
</html>
EOF

# Create license file
cat > resources/license.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>License</title>
</head>
<body>
    <h2>MIT License</h2>
    <p>Copyright (c) 2023 HeadlessDom</p>
    <p>Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:</p>
    
    <p>The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.</p>
    
    <p>THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.</p>
</body>
</html>
EOF

# Create conclusion message
cat > resources/conclusion.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Installation Complete</title>
</head>
<body>
    <h2>Installation Complete</h2>
    <p>HeadlessDom has been successfully installed on your computer and started as a service.</p>
    <p>You can verify the service is running with: <code>headlessdom status</code></p>
    <p>The API is available at: <code>http://localhost:5000</code></p>
    <p>To test the API, try:</p>
    <pre>headlessdom test</pre>
    <p>Or:</p>
    <pre>curl http://localhost:5000/health</pre>
    <p>If you encounter browser installation issues, run:</p>
    <pre>sudo headlessdom reinstall-browser</pre>
    <p>If the service is not running after installation, restart your computer or run:</p>
    <pre>sudo headlessdom restart</pre>
    <p>To uninstall in the future, run:</p>
    <pre>sudo /Applications/HeadlessDom/uninstall.sh</pre>
</body>
</html>
EOF

# Create distribution XML
cat > distribution.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>HeadlessDom</title>
    <organization>HeadlessDom</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true" />
    <welcome file="welcome.html" mime-type="text/html" />
    <license file="license.html" mime-type="text/html" />
    <conclusion file="conclusion.html" mime-type="text/html" />
    <pkg-ref id="com.headlessdom.pkg" version="1.0" onConclusion="none">HeadlessDom-1.0.pkg</pkg-ref>
    <choices-outline>
        <line choice="default">
            <line choice="com.headlessdom.pkg"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.headlessdom.pkg" visible="false">
        <pkg-ref id="com.headlessdom.pkg"/>
    </choice>
</installer-gui-script>
EOF

# Build component package
pkgbuild --root build/payload \
         --scripts build/scripts \
         --identifier com.headlessdom.pkg \
         --version 1.0 \
         --install-location / \
         HeadlessDom-1.0.pkg

# Build the final distribution package
productbuild --distribution distribution.xml \
             --resources resources \
             --package-path . \
             HeadlessDom-Installer.pkg

echo "Installer package created: $BUILD_DIR/HeadlessDom-Installer.pkg"
echo "To install, run: open $BUILD_DIR/HeadlessDom-Installer.pkg" 