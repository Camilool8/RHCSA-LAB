# ISO Directory - Automatic Detection

## How It Works

The Vagrantfile automatically detects and attaches any `.iso` file in this directory to all VMs during `vagrant up`.

## Setup Instructions

### Place your ISO here

```bash
# RHEL 9
cp ~/Downloads/rhel-9.0-x86_64-dvd.iso iso/

# Rocky Linux 9
wget https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9-latest-x86_64-dvd.iso -P iso/

# AlmaLinux 9
wget https://repo.almalinux.org/almalinux/9/isos/x86_64/AlmaLinux-9-latest-x86_64-dvd.iso -P iso/
```

### Deploy lab

```bash
vagrant up
```

The ISO is automatically attached to all VMs.

## What Happens Automatically

1. **Detection**: Vagrantfile scans this folder for `.iso` files
2. **Attachment**: ISO attached to IDE Controller on all VMs
3. **Mounting**: Scripts automatically mount DVD at `/mnt/cdrom`
4. **Installation**: All packages installed from DVD repos first
5. **Repo Creation**: Repo server copies DVD content to HTTP repos

## Without ISO

If this folder is empty, the lab uses box repos as fallback. It still works but won't have actual RHEL packages.

## File Naming

Any name ending in `.iso` works:
- `rhel-9.0-x86_64-dvd.iso`
- `Rocky-9-latest-x86_64-dvd.iso`
- `AlmaLinux-9.4-x86_64-dvd.iso`

Only the first `.iso` file found will be used.