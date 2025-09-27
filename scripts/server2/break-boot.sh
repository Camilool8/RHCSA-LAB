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

if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    dnf groupinstall -y "Server with GUI" --disablerepo="*" --enablerepo="DVD-*" 2>/dev/null || \
    dnf install -y @gnome-desktop --disablerepo="*" --enablerepo="DVD-*" 2>/dev/null
    
    dnf install -y tigervnc-server --disablerepo="*" --enablerepo="DVD-*" 2>/dev/null
    
    echo "✓ GUI installed from DVD"
else
    dnf groupinstall -y "Server with GUI" --skip-broken 2>/dev/null || \
    dnf install -y @gnome-desktop 2>/dev/null
    
    dnf install -y tigervnc-server 2>/dev/null
fi

systemctl set-default graphical.target

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
if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    dnf install -y novnc python3-websockify --disablerepo="*" --enablerepo="DVD-*" 2>/dev/null
    echo "✓ noVNC installed from DVD"
else
    dnf install -y novnc python3-websockify 2>/dev/null
    echo "✓ noVNC installation attempted"
fi

cat > /etc/systemd/system/novnc.service <<'EOF'
[Unit]
Description=noVNC websocket proxy
After=vncserver@:1.service network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 6080 localhost:5901
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable novnc.service

if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    umount /mnt/cdrom 2>/dev/null
fi

firewall-cmd --permanent --add-service=vnc-server
firewall-cmd --permanent --add-port=5901/tcp
firewall-cmd --permanent --add-port=6080/tcp
firewall-cmd --reload

echo "✓ VNC and noVNC services configured"


NEW_ROOT_PASSWORD=$(openssl rand -base64 16)
echo "root:${NEW_ROOT_PASSWORD}" | chpasswd
echo "INFO: Root password randomized"

echo "Breaking boot configuration..."
systemctl set-default network.target

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
echo "Status:"
echo "  ✓ GNOME Desktop + VNC on port 5901"
echo "  ✓ noVNC browser access on port 6080"
echo "  ✗ Root password RANDOMIZED"
echo "  ✗ Boot broken (network.target)"
echo "  ✗ NO repos (Task #7)"
echo "  ✗ NO network on eth2 (Task #2)"
echo ""