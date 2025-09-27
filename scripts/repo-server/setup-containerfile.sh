#!/bin/bash
# Setup Containerfile hosting

echo "=== Setting up Containerfile hosting ==="

mkdir -p /var/www/html/containers

if [ -f /tmp/Containerfile ]; then
    mv /tmp/Containerfile /var/www/html/containers/Containerfile
else
    cat > /var/www/html/containers/Containerfile <<'EOF'
FROM registry.access.redhat.com/ubi9/ubi:latest
RUN dnf -y install httpd; dnf clean all; systemctl enable httpd;
RUN echo "Successful Web Server Test" | tee /var/www/html/index.html
RUN mkdir /etc/systemd/system/httpd.service.d/; echo -e '[Service]\nRestart=always' | tee /etc/systemd/system/httpd.service.d/httpd.conf
EXPOSE 80
CMD [ "/sbin/init" ]
EOF
fi

chown apache:apache /var/www/html/containers/Containerfile
chmod 644 /var/www/html/containers/Containerfile

echo "=== Containerfile available at: http://192.168.55.47/containers/Containerfile ==="