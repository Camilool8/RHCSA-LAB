#!/bin/bash
# Create redhat user with sudo privileges and enable password SSH authentication

echo "=== Creating redhat user with admin privileges ==="

# Create redhat user with password "redhat"
if ! id redhat &>/dev/null; then
    useradd -m -s /bin/bash redhat
    echo "redhat:redhat" | chpasswd
    echo "✓ User 'redhat' created with password 'redhat'"
else
    echo "✓ User 'redhat' already exists"
fi

# Add redhat to wheel group for sudo access
usermod -aG wheel redhat
echo "✓ User 'redhat' added to wheel group (sudo privileges)"

# Enable password authentication in SSH
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Ensure PasswordAuthentication is enabled (add if not present)
if ! grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi

# Enable root login with password (for lab purposes only)
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set root password to "password" for lab convenience
echo "root:password" | chpasswd
echo "✓ Root password set to 'password'"

# Restart SSH service
systemctl restart sshd
echo "✓ SSH service restarted with password authentication enabled"

echo ""
echo "=== SSH Access Configuration Complete ==="
echo ""
echo "You can now SSH using:"
echo "  ssh redhat@<ip-address>     (password: redhat)"
echo "  ssh root@<ip-address>        (password: password)"
echo ""
echo "User 'redhat' has full sudo privileges"