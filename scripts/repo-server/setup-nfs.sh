#!/bin/bash
# Setup NFS server

echo "=== Setting up NFS Server ==="

dnf install -y nfs-utils

mkdir -p /export/{it_files,dba_files,home}
mkdir -p /export/home/{manny,moe,jack,marcia,jan,cindy}

for user in manny moe jack marcia jan cindy; do 
    cp /etc/skel/.b* /export/home/$user 2>/dev/null || true
done

chown -R 1010:1010 /export/home/manny
chown -R 1011:1011 /export/home/moe
chown -R 1012:1012 /export/home/jack
chown -R 1013:1013 /export/home/marcia
chown -R 1014:1014 /export/home/jan
chown -R 1015:1015 /export/home/cindy

if [ -f /tmp/exports ]; then
    mv /tmp/exports /etc/exports
else
    cat > /etc/exports <<EOF
/export/home         192.168.55.0/24(rw,sync,no_root_squash)
/export/it_files     192.168.55.0/24(rw,sync,no_root_squash)
/export/dba_files    192.168.55.0/24(rw,sync,no_root_squash)
EOF
fi

firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload

systemctl enable --now nfs-server
exportfs -ra

echo "=== NFS server setup complete ==="