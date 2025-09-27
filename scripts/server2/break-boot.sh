#!/bin/bash
# Break boot process and setup GUI for VNC access

echo "=== Setting up server2 with GUI and broken boot ==="

DVD_REPOS_AVAILABLE=false

echo "Checking for attached DVD/ISO..."
if [ -b "/dev/sr0" ] || [ -b "/dev/cdrom" ]; then
    mkdir -p /mnt/cdrom
    
    if mount /dev/sr0 /mnt/cdrom 2>/dev/null || mount /dev/cdrom /mnt/cdrom 2>/dev/null; then
        if [ -d "/mnt/cdrom/BaseOS" ] && [ -d "/mnt/cdrom/AppStream" ]; then
            echo "✓ DVD/ISO detected, using DVD repos for GUI installation"
            DVD_REPOS_AVAILABLE=true
            
            cat > /etc/yum.repos.d/dvd-temp.repo <<EOF
[DVD-BaseOS]
name=DVD BaseOS
baseurl=file:///mnt/cdrom/BaseOS
enabled=1
gpgcheck=0

[DVD-AppStream]
name=DVD AppStream
baseurl=file:///mnt/cdrom/AppStream
enabled=1
gpgcheck=0
EOF
        fi
    fi
fi

echo "Installing GNOME Desktop and VNC server..."
echo "This will take 5-10 minutes..."

GUI_INSTALLED=false

if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    # Try multiple installation methods
    echo "Attempting: dnf groupinstall 'Server with GUI'..."
    if dnf groupinstall -y "Server with GUI" --allowerasing --disablerepo="*" --enablerepo="DVD-*"; then
        GUI_INSTALLED=true
    else
        echo "Failed. Attempting: dnf install @^graphical-server-environment..."
        if dnf install -y @^graphical-server-environment --allowerasing --disablerepo="*" --enablerepo="DVD-*"; then
            GUI_INSTALLED=true
        else
            echo "Failed. Attempting: dnf install GNOME packages directly..."
            if dnf install -y gnome-shell gnome-terminal nautilus gdm gnome-session --allowerasing --disablerepo="*" --enablerepo="DVD-*"; then
                GUI_INSTALLED=true
            fi
        fi
    fi
    
    dnf install -y tigervnc-server --disablerepo="*" --enablerepo="DVD-*"
else
    # Use regular repos
    echo "Attempting: dnf groupinstall 'Server with GUI'..."
    if dnf groupinstall -y "Server with GUI" --allowerasing; then
        GUI_INSTALLED=true
    else
        echo "Failed. Attempting: dnf install @^graphical-server-environment..."
        if dnf install -y @^graphical-server-environment --allowerasing; then
            GUI_INSTALLED=true
        else
            echo "Failed. Attempting: dnf install GNOME packages directly..."
            if dnf install -y gnome-shell gnome-terminal nautilus gdm gnome-session --allowerasing; then
                GUI_INSTALLED=true
            fi
        fi
    fi
    
    dnf install -y tigervnc-server
fi

# Verify GUI installation
if rpm -q gnome-shell &> /dev/null || rpm -q gnome-desktop3 &> /dev/null; then
    echo "✓ GUI packages installed successfully"
    GUI_INSTALLED=true
else
    echo "✗ WARNING: GUI installation may have failed - gnome-shell not found"
    GUI_INSTALLED=false
fi

if [ "$GUI_INSTALLED" = true ]; then
    systemctl set-default graphical.target
else
    echo "⚠ Skipping graphical.target - GUI not properly installed"
fi

mkdir -p /root/.vnc
cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/gnome-session
EOF
chmod +x /root/.vnc/xstartup

echo "password" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

cat > /etc/systemd/system/vncserver@.service <<'EOF'
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=simple
User=root
PAMName=login
PIDFile=/root/.vnc/%H%i.pid
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver %i -geometry 1280x1024 -depth 24
ExecStop=/usr/bin/vncserver -kill %i

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vncserver@:1.service

echo "Installing noVNC for browser-based VNC access..."
WEBSOCKIFY_PATH=""

if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    dnf install -y novnc python3-websockify --disablerepo="*" --enablerepo="DVD-*"
    
    # Check if installation succeeded - refresh PATH first
    hash -r 2>/dev/null
    if command -v websockify &> /dev/null; then
        WEBSOCKIFY_PATH=$(which websockify)
        echo "✓ noVNC installed from DVD at $WEBSOCKIFY_PATH"
    fi
else
    dnf install -y novnc python3-websockify
    
    # Check if installation succeeded - refresh PATH first
    hash -r 2>/dev/null
    if command -v websockify &> /dev/null; then
        WEBSOCKIFY_PATH=$(which websockify)
        echo "✓ noVNC installed from repos at $WEBSOCKIFY_PATH"
    fi
fi

# Fallback: Install via pip if dnf failed
if [ -z "$WEBSOCKIFY_PATH" ]; then
    echo "⚠ Package installation failed, falling back to pip installation..."
    
    # Install pip if not present
    if [ "$DVD_REPOS_AVAILABLE" = true ]; then
        dnf install -y python3-pip --disablerepo="*" --enablerepo="DVD-*" || \
        dnf install -y python3 --disablerepo="*" --enablerepo="DVD-*"
    else
        dnf install -y python3-pip || dnf install -y python3
    fi
    
    # Install websockify via pip
    pip3 install websockify || python3 -m pip install websockify
    
    # Refresh PATH and find websockify location
    hash -r 2>/dev/null
    export PATH="/usr/local/bin:$PATH"
    
    if command -v websockify &> /dev/null; then
        WEBSOCKIFY_PATH=$(which websockify)
        echo "✓ websockify installed via pip at $WEBSOCKIFY_PATH"
    elif [ -f "/usr/local/bin/websockify" ]; then
        WEBSOCKIFY_PATH="/usr/local/bin/websockify"
        echo "✓ websockify found at $WEBSOCKIFY_PATH"
    else
        echo "✗ ERROR: Failed to install websockify"
        WEBSOCKIFY_PATH="/usr/local/bin/websockify"  # Best guess
    fi
fi

# Check for noVNC web files
NOVNC_WEB_PATH=""
if [ -d "/usr/share/novnc" ]; then
    NOVNC_WEB_PATH="/usr/share/novnc/"
    echo "✓ noVNC web files found at $NOVNC_WEB_PATH"
else
    echo "⚠ noVNC web files not found, downloading from GitHub..."
    cd /usr/share
    if [ "$DVD_REPOS_AVAILABLE" = true ]; then
        dnf install -y git --disablerepo="*" --enablerepo="DVD-*"
    else
        dnf install -y git
    fi
    
    git clone https://github.com/novnc/noVNC.git novnc
    
    if [ -d "/usr/share/novnc" ]; then
        NOVNC_WEB_PATH="/usr/share/novnc/"
        echo "✓ noVNC web files downloaded"
    else
        echo "⚠ Could not download noVNC, web interface may not work"
        NOVNC_WEB_PATH="/usr/share/novnc/"
    fi
fi

cat > /etc/systemd/system/novnc.service <<EOF
[Unit]
Description=noVNC websocket proxy
After=vncserver@:1.service network.target

[Service]
Type=simple
ExecStart=${WEBSOCKIFY_PATH} --web=${NOVNC_WEB_PATH} 6080 localhost:5901
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable novnc.service

# Start services only if GUI was successfully installed
if [ "$GUI_INSTALLED" = true ]; then
    systemctl start vncserver@:1.service
    systemctl start novnc.service
    echo "✓ VNC services started"
else
    echo "⚠ Skipping VNC service startup - GUI not installed"
fi

if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    umount /mnt/cdrom 2>/dev/null
fi

firewall-cmd --permanent --add-service=vnc-server 2>/dev/null
firewall-cmd --permanent --add-port=5901/tcp 2>/dev/null
firewall-cmd --permanent --add-port=6080/tcp 2>/dev/null
firewall-cmd --reload 2>/dev/null

echo "✓ VNC and noVNC services configured"

NEW_ROOT_PASSWORD=$(openssl rand -base64 16)
echo "root:${NEW_ROOT_PASSWORD}" | chpasswd
echo "INFO: Root password randomized"

# echo "Breaking boot configuration..."
# systemctl set-default network.target

echo "Removing all repository configurations..."
rm -rf /etc/yum.repos.d/*
dnf clean all

echo "Disabling network configuration on eth2..."
CONN_NAME=$(nmcli -t -f NAME,DEVICE con show | grep eth2 | cut -d: -f1)
if [ -n "$CONN_NAME" ]; then
    nmcli con down "$CONN_NAME" 2>/dev/null || true
    nmcli con del "$CONN_NAME" 2>/dev/null || true
fi

ifconfig

echo ""
echo "=== server2 setup complete ==="
echo ""
echo "Installation Status:"
if [ "$GUI_INSTALLED" = true ]; then
    echo "  ✓ GNOME Desktop installed"
else
    echo "  ✗ GNOME Desktop NOT installed"
fi
echo "  ✓ VNC server on port 5901"
echo "  ✓ noVNC browser access on port 6080"
echo "  ✗ Root password RANDOMIZED"
echo "  Note: Boot breaking (network.target) is DISABLED for testing"
echo "  ✗ NO repos (Task #7)"
echo "  ✗ NO network on eth2 (Task #2)"
echo ""
echo "websockify location: $WEBSOCKIFY_PATH"
echo "noVNC web path: $NOVNC_WEB_PATH"
echo ""