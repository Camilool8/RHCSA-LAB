#!/bin/bash
# Setup repository server

echo "=== Setting up Repository Server ==="

REPO_IP="192.168.55.47"
DVD_REPOS_AVAILABLE=false

# Step 1: Try to mount and use DVD/ISO first
echo "Checking for attached DVD/ISO..."
if [ -b "/dev/sr0" ] || [ -b "/dev/cdrom" ]; then
    mkdir -p /mnt/cdrom
    
    if mount /dev/sr0 /mnt/cdrom 2>/dev/null || mount /dev/cdrom /mnt/cdrom 2>/dev/null; then
        if [ -d "/mnt/cdrom/BaseOS" ] && [ -d "/mnt/cdrom/AppStream" ]; then
            echo "✓ DVD/ISO detected and mounted successfully!"
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
            echo "✓ Temporary DVD repos configured"
        fi
    fi
fi

# Step 2: Install required packages
if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    echo "Installing packages from DVD repos..."
    dnf install -y httpd createrepo_c --disablerepo="*" --enablerepo="DVD-*"
else
    echo "No DVD available, installing from box repos..."
    dnf install -y httpd createrepo_c
fi

# Step 3: Create HTTP repository directories
mkdir -p /var/www/html/repo/{BaseOS,AppStream}

# Step 4: Copy repos from DVD to HTTP location
if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    echo "Copying repositories from DVD to HTTP location..."
    echo "This may take 5-10 minutes..."
    
    cp -rv /mnt/cdrom/BaseOS/* /var/www/html/repo/BaseOS/
    cp -rv /mnt/cdrom/AppStream/* /var/www/html/repo/AppStream/
    
    echo "Creating repository metadata..."
    createrepo_c /var/www/html/repo/BaseOS
    createrepo_c /var/www/html/repo/AppStream
    
    echo "✓ Repositories copied successfully from DVD"
    
    # Clean up temporary DVD repos
    rm -f /etc/yum.repos.d/dvd-temp.repo
    umount /mnt/cdrom 2>/dev/null
else
    echo "WARNING: No DVD/ISO found!"
    createrepo_c /var/www/html/repo/BaseOS
    createrepo_c /var/www/html/repo/AppStream
fi

# IMPORTANT: Configure repo server to use its own HTTP repos
echo "Configuring repo server to use local HTTP repos..."
cat > /etc/yum.repos.d/local-http.repo <<EOF
[LocalBaseOS]
name=Local BaseOS
baseurl=http://127.0.0.1/repo/BaseOS/
enabled=1
gpgcheck=0

[LocalAppStream]
name=Local AppStream
baseurl=http://127.0.0.1/repo/AppStream/
enabled=1
gpgcheck=0
EOF

dnf clean all
echo "✓ Repo server configured to use local HTTP repos"

# Step 5: Configure httpd
cat > /etc/httpd/conf.d/repos.conf <<EOF
<Directory /var/www/html/repo>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
EOF

chown -R apache:apache /var/www/html/repo
chmod -R 755 /var/www/html/repo

firewall-cmd --permanent --add-service=http
firewall-cmd --reload

systemctl enable --now httpd

# Configure static IP
echo "Configuring static IP ${REPO_IP}/24..."
CONN_NAME=$(nmcli -t -f NAME,DEVICE con show | grep eth2 | cut -d: -f1)
if [ -z "$CONN_NAME" ]; then
    nmcli con add type ethernet ifname eth2 con-name eth2 ip4 ${REPO_IP}/24
else
    nmcli con mod "$CONN_NAME" ipv4.addresses ${REPO_IP}/24
    nmcli con mod "$CONN_NAME" ipv4.method manual
    nmcli con up "$CONN_NAME"
fi

sleep 2
echo ""
echo "=== Repository server setup complete ==="
curl -s http://127.0.0.1/repo/ > /dev/null && echo "✓ HTTP repo server is accessible!"
echo ""
echo "Repos available at:"
echo "  http://${REPO_IP}/repo/BaseOS/"
echo "  http://${REPO_IP}/repo/AppStream/"