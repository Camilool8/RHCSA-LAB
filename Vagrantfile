# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# Load configuration
config_file = File.join(File.dirname(__FILE__), 'config.yaml')
settings = YAML.load_file(config_file)

NETWORK_BASE = settings['network']['subnet']
BRIDGE_ADAPTER = settings['network']['bridge_adapter']

# Auto-detect RHEL/Rocky/Alma ISO in iso/ folder
ISO_PATH = Dir.glob("iso/*.iso").first

Vagrant.configure("2") do |config|
  
  # Disable automatic box updates
  config.vm.box_check_update = false
  
  # Common VirtualBox configuration
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.linked_clone = true
  end

  #############################################
  # REPO SERVER
  #############################################
  config.vm.define "repo" do |repo|
    repo.vm.box = settings['box']['name']
    repo.vm.hostname = settings['vms']['repo_server']['hostname']
    
    # Network Configuration
    repo.vm.network "public_network", 
      bridge: BRIDGE_ADAPTER,
      auto_config: false
    
    repo.vm.network "private_network", 
      ip: settings['vms']['repo_server']['ip'],
      netmask: settings['network']['netmask']
    
    repo.vm.provider "virtualbox" do |vb|
      vb.name = "rhcsa-repo-server"
      vb.memory = settings['vms']['repo_server']['memory']
      vb.cpus = settings['vms']['repo_server']['cpus']
      
      # Auto-attach ISO if present
      if ISO_PATH
        puts "Found ISO: #{ISO_PATH}"
        puts "Attaching ISO to repo server..."
        vb.customize ['storageattach', :id, 
                      '--storagectl', 'IDE Controller', 
                      '--port', 0, 
                      '--device', 0, 
                      '--type', 'dvddrive', 
                      '--medium', File.absolute_path(ISO_PATH)]
      end
    end
    
    # Provisioning
    repo.vm.provision "shell", path: "scripts/common/base-setup.sh"
    repo.vm.provision "shell", path: "scripts/common/create-redhat-user.sh"
    repo.vm.provision "shell", path: "scripts/repo-server/setup-repos.sh"
    repo.vm.provision "shell", path: "scripts/repo-server/setup-nfs.sh"
    repo.vm.provision "shell", path: "scripts/repo-server/setup-containerfile.sh"
    
    repo.vm.provision "file", source: "files/Containerfile", 
                       destination: "/tmp/Containerfile"
    repo.vm.provision "file", source: "files/exports", 
                       destination: "/tmp/exports"
  end

  #############################################
  # SERVER 1
  #############################################
  config.vm.define "server1" do |server1|
    server1.vm.box = settings['box']['name']
    server1.vm.hostname = settings['vms']['server1']['hostname']
    
    server1.vm.network "public_network", 
      bridge: BRIDGE_ADAPTER,
      auto_config: false
    
    server1.vm.network "private_network", 
      ip: settings['vms']['server1']['ip'],
      netmask: settings['network']['netmask'],
      auto_config: false
    
    server1.vm.provider "virtualbox" do |vb|
      vb.name = "rhcsa-server1"
      vb.memory = settings['vms']['server1']['memory']
      vb.cpus = settings['vms']['server1']['cpus']
      
      if ISO_PATH
        vb.customize ['storageattach', :id, 
                      '--storagectl', 'IDE Controller', 
                      '--port', 0, 
                      '--device', 0, 
                      '--type', 'dvddrive', 
                      '--medium', File.absolute_path(ISO_PATH)]
      end
    end
    
    server1.vm.provision "shell", path: "scripts/common/base-setup.sh"
    server1.vm.provision "shell", path: "scripts/common/create-redhat-user.sh"
    server1.vm.provision "shell", path: "scripts/server1/break-httpd.sh"
  end

  #############################################
  # SERVER 2
  #############################################
  config.vm.define "server2" do |server2|
    server2.vm.box = settings['box']['name']
    server2.vm.hostname = settings['vms']['server2']['hostname']
    
    server2.vm.network "public_network", 
      bridge: BRIDGE_ADAPTER,
      auto_config: false
    
    server2.vm.network "private_network", 
      ip: settings['vms']['server2']['ip'],
      netmask: settings['network']['netmask'],
      auto_config: false
    
    server2.vm.provider "virtualbox" do |vb|
      vb.name = "rhcsa-server2"
      vb.memory = settings['vms']['server2']['memory']
      vb.cpus = settings['vms']['server2']['cpus']
      
      if ISO_PATH
        vb.customize ['storageattach', :id, 
                      '--storagectl', 'IDE Controller', 
                      '--port', 0, 
                      '--device', 0, 
                      '--type', 'dvddrive', 
                      '--medium', File.absolute_path(ISO_PATH)]
      end
      
      # Additional disks for storage tasks
      settings['vms']['server2']['additional_disks'].each_with_index do |disk, idx|
        disk_file = "./disks/server2-disk#{idx + 1}.vdi"
        unless File.exist?(disk_file)
          vb.customize ['createhd', '--filename', disk_file, 
                        '--size', disk['size'].to_i * 1024]
          vb.customize ['storageattach', :id, 
                        '--storagectl', 'SATA Controller', 
                        '--port', idx + 1, 
                        '--device', 0, 
                        '--type', 'hdd', 
                        '--medium', disk_file]
        end
      end
    end
    
    server2.vm.provision "shell", path: "scripts/common/base-setup.sh"
    server2.vm.provision "shell", path: "scripts/common/create-redhat-user.sh"
    server2.vm.provision "shell", path: "scripts/server2/break-boot.sh"
  end

end