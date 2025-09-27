#!/bin/bash
# Break httpd for practice tasks on server1

echo "=== Setting up broken httpd on server1 ==="

DVD_REPOS_AVAILABLE=false

echo "Checking for attached DVD/ISO..."
if [ -b "/dev/sr0" ] || [ -b "/dev/cdrom" ]; then
    mkdir -p /mnt/cdrom
    
    if mount /dev/sr0 /mnt/cdrom 2>/dev/null || mount /dev/cdrom /mnt/cdrom 2>/dev/null; then
        if [ -d "/mnt/cdrom/BaseOS" ] && [ -d "/mnt/cdrom/AppStream" ]; then
            echo "✓ DVD/ISO detected, using DVD repos for httpd installation"
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

echo "Installing httpd..."
if [ "$DVD_REPOS_AVAILABLE" = true ]; then
    dnf install -y httpd --disablerepo="*" --enablerepo="DVD-*"
    umount /mnt/cdrom 2>/dev/null
    echo "✓ httpd installed from DVD"
else
    dnf install -y httpd
fi

echo "Breaking httpd configuration..."
sed -i 's/^Listen 80/Listen 85/' /etc/httpd/conf/httpd.conf

echo "Creating test web files..."
echo "RHCSA is Awesome" > /var/www/html/file1
cal > /var/www/html/file2
echo "This file is totally messed up" > /var/www/html/file3

echo "Breaking SELinux context on file3..."
chcon -t default_t /var/www/html/file3 2>/dev/null || true

systemctl enable httpd
systemctl start httpd 2>/dev/null || echo "httpd failed to start (expected)"

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
echo "=== server1 setup complete ==="
echo ""
echo "Status:"
echo "  ✓ httpd installed but broken (port 85 + SELinux issues)"
echo "  ✓ Web files created"
echo "  ✗ NO repository configurations (Task #6)"
echo "  ✗ NO network on eth2 (Task #2)"