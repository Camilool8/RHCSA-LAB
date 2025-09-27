#!/bin/bash
# Base setup for all servers

echo "=== Base System Setup ==="

# Ensure we have basic tools
dnf install -y vim wget curl net-tools bind-utils 2>/dev/null || echo "Some packages may already be installed"

# Configure firewall
systemctl enable --now firewalld

# Set SELinux to permissive (will be re-enabled for practice)
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

echo "=== Base setup complete ==="