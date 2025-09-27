# RHCSA Lab Automation

Automated RHCSA 9 practice lab with 3 servers using Vagrant + VirtualBox.

## Prerequisites

**Required Software:**
- VirtualBox 7.0+ ([Download](https://www.virtualbox.org/wiki/Downloads))
- Vagrant 2.4+ ([Download](https://www.vagrantup.com/downloads))

**System Requirements:**
- RAM: 6GB available (8GB+ recommended)
- Disk: 50GB free space
- CPU: Virtualization enabled (VT-x/AMD-V)

**Optional:**
- RHEL 9.x / Rocky 9 / AlmaLinux 9 ISO

## Quick Start

### 1. Setup Repository

```bash
git clone <your-repo-url>
cd rhcsa-lab
mkdir -p disks iso scripts/common scripts/repo-server scripts/server1 scripts/server2 files
```

### 2. Add ISO (Optional but Recommended)

```bash
# Place your ISO in iso/ folder
cp /path/to/rhel-9.0-x86_64-dvd.iso iso/

# Vagrant will auto-detect and attach it to all VMs
```

### 3. Deploy Lab

```bash
vagrant up
```

This takes 15-20 minutes on first run.

### 4. Access VMs

**SSH with password (recommended for lab):**
```bash
ssh redhat@192.168.55.47    # repo server (after network configured)
ssh redhat@192.168.55.71    # server1 (after Task #2)
ssh redhat@192.168.55.72    # server2 (after Task #2)
# Password: redhat
```

**Or use Vagrant SSH:**
```bash
vagrant ssh repo
vagrant ssh server1
vagrant ssh server2
```

**VNC for server2 (GRUB recovery):**
```bash
# Connect to: vnc://192.168.55.72:5901
# Password: password
```

## Lab Architecture

### Network Setup

Each VM has 3 network adapters:

| Adapter | Type | Purpose | Configuration |
|---------|------|---------|---------------|
| eth0 | NAT | Internet access | Auto (Vagrant default) |
| eth1 | Bridged | Host communication | Auto |
| eth2 | Host-Only (192.168.55.x) | Lab internal network | **Manual (Task #2)** |

### VM Specifications

**Repo Server (192.168.55.47):**
- 2 CPU, 1GB RAM, 32GB disk
- HTTP repos (BaseOS + AppStream)
- NFS server
- Containerfile hosting
- Network configured and working

**Server1 (192.168.55.71):**
- 2 CPU, 2GB RAM, 32GB disk
- httpd installed but broken (port 85 + SELinux)
- NO repos configured (Task #6)
- NO network on eth2 (Task #2)

**Server2 (192.168.55.72):**
- 2 CPU, 2GB RAM, 1x 32GB + 2x 16GB disks
- GNOME Desktop + VNC on port 5901
- Boot broken (network.target)
- Root password randomized
- NO repos configured (Task #7)
- NO network on eth2 (Task #2)

### User Accounts

**All VMs have:**
- User: `redhat` / Password: `redhat` (sudo access)
- User: `root` / Password: `password`

**Server2 only:**
- Root password has been randomized (Task #1: reset it)

## Lab Services

### Repo Server (192.168.55.47)

**HTTP Repositories:**
```
http://192.168.55.47/repo/BaseOS/
http://192.168.55.47/repo/AppStream/
```

**NFS Exports:**
```
/export/home         # User home directories (autofs practice)
/export/it_files     # IT files share
/export/dba_files    # DBA files share
```

**Containerfile:**
```
http://192.168.55.47/containers/Containerfile
```

## Configuration

Edit `config.yaml` to customize:

```yaml
network:
  subnet: "192.168.55"           # Change lab subnet
  
vms:
  repo_server:
    ip: "192.168.55.47"          # Change IPs
    memory: 1024                  # Change RAM (MB)
    cpus: 2                       # Change CPU count
```

## Practice Workflow

### Initial Setup (One Time)

```bash
# Deploy lab
vagrant up

# Take snapshots for easy reset
VBoxManage snapshot rhcsa-repo-server take "clean"
VBoxManage snapshot rhcsa-server1 take "clean"
VBoxManage snapshot rhcsa-server2 take "clean"
```

### Daily Practice

```bash
# Start lab
vagrant up

# Connect via VNC to server2 for boot recovery (Task #1)
# Use VNC client to connect to 192.168.55.72:5901

# SSH to servers (after completing Task #2 network config)
ssh redhat@192.168.55.71
ssh redhat@192.168.55.72

# Practice tasks...

# Suspend or halt when done
vagrant suspend    # Quick pause
vagrant halt       # Full shutdown
```

### Reset Lab

```bash
# Restore snapshots (fastest)
VBoxManage snapshot rhcsa-server1 restore "clean"
VBoxManage snapshot rhcsa-server2 restore "clean"
vagrant up server1 server2

# Or full rebuild
vagrant destroy server1 server2 -f
vagrant up server1 server2
```

## Practice Tasks

Based on RHCSA exam objectives, your lab supports:

**Boot & System (Server2):**
- [ ] Task #1: Break into server2, reset root password, fix boot target

**Network (Both Servers):**
- [ ] Task #2: Configure network interfaces (192.168.55.71 & .72)
- [ ] Task #3: Enable network services at boot
- [ ] Task #4: Enable SSH root access
- [ ] Task #5: Enable key-based SSH auth

**Repos (Both Servers):**
- [ ] Task #6: Configure repos on server1
- [ ] Task #7: Copy repos to server2

**Web Server (Server1):**
- [ ] Task #27: Fix httpd (port + SELinux + firewall)

**NFS & AutoFS (Both Servers):**
- [ ] Task #8: Configure autofs for home directories
- [ ] Task #22-23: Mount NFS shares persistently

**Users & Permissions:**
- [ ] Task #11-13: Create users and groups
- [ ] Task #14-16: Configure sudo privileges

**Storage (Server2):**
- [ ] Task #32-39: LVM, VDO, swap partitions

**Containers (Server1, user cindy):**
- [ ] Task #42: Build container image from Containerfile
- [ ] Task #43: Deploy container as systemd service

## Common Commands

```bash
# VM management
vagrant status           # Check VM status
vagrant up               # Start all VMs
vagrant up repo          # Start specific VM
vagrant halt             # Stop all VMs
vagrant suspend          # Pause VMs
vagrant resume           # Resume paused VMs
vagrant destroy -f       # Delete VMs
vagrant reload           # Restart VMs
vagrant ssh repo         # SSH into VM

# Snapshots (VirtualBox)
VBoxManage snapshot rhcsa-server1 take "snapshot-name"
VBoxManage snapshot rhcsa-server1 restore "snapshot-name"
VBoxManage snapshot rhcsa-server1 list
```

## Troubleshooting

### Cannot SSH with password

```bash
# SSH into VM via vagrant
vagrant ssh server1

# Verify SSH config
sudo grep PasswordAuthentication /etc/ssh/sshd_config

# Should show: PasswordAuthentication yes
# If not, fix it:
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### VMs can't communicate

```bash
# On each server, check network (after Task #2)
ip addr show eth2
ping 192.168.55.47

# On repo server
firewall-cmd --list-services
systemctl status httpd
```

### No repos available on server1/server2

This is expected. They have NO repos configured by design. Configure them as Task #6 and Task #7.

### ISO not detected

```bash
# Check if ISO is in iso/ folder
ls -lh iso/*.iso

# Should show your ISO file
# If not, add it and run:
vagrant reload --provision
```

### VNC not working

```bash
vagrant ssh server2
sudo systemctl status vncserver@:1
sudo firewall-cmd --list-ports | grep 5901
```

## File Structure

```
rhcsa-lab/
├── Vagrantfile                 # Main Vagrant config
├── config.yaml                 # Lab settings (CUSTOMIZE THIS)
├── README.md                   # This file
├── disks/                      # VM disk files (auto-created)
├── iso/                        # Place ISO here
│   └── README.md
├── scripts/
│   ├── common/
│   │   ├── base-setup.sh       # Base system setup
│   │   └── create-redhat-user.sh  # Create redhat user
│   ├── repo-server/
│   │   ├── setup-repos.sh      # HTTP repository setup
│   │   ├── setup-nfs.sh        # NFS server setup
│   │   └── setup-containerfile.sh
│   ├── server1/
│   │   └── break-httpd.sh      # Break httpd for practice
│   └── server2/
│       └── break-boot.sh       # Break boot + install GUI
└── files/
    ├── Containerfile           # Container definition
    └── exports                 # NFS exports config
```

## Additional Resources

- [RHCSA 9 Exam Objectives](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [VirtualBox Manual](https://www.virtualbox.org/manual/)

## License

MIT License - Free to use and modify for RHCSA preparation.