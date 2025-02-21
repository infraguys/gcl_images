locals {
  cd_content = {
    "meta-data" = yamlencode({
      instance-id = "iid-local01"
    })
    "user-data" = join("\n", [
      "#cloud-config",
      yamlencode({
        ssh_authorized_keys = [
          data.sshkey.install.public_key
        ]
      })
    ])
  }
}

data "sshkey" "install" {
  name = "packer"
}

source "qemu" "ubuntu-24" {
  iso_url                   = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  iso_checksum              = "file:https://cloud-images.ubuntu.com/releases/24.04/release/SHA256SUMS"
  accelerator               = "kvm"
  boot_wait                 = "5s"
  boot_command              = ["<enter>"]
  cpus                      = 4
  memory                    = 4092
  disk_image                = true
  disk_size                 = "4000M"
  disk_interface            = "virtio-scsi"
  disk_cache                = "unsafe"
  disk_discard              = "unmap"
  disk_detect_zeroes        = "unmap"
  disk_compression          = true
  format                    = "raw"
  net_device                = "virtio-net"
  headless                  = true
  qemu_binary               = "qemu-system-x86_64"
  ssh_timeout               = "30s"
  ssh_username              = "ubuntu"
  ssh_clear_authorized_keys = true
  temporary_key_pair_name   = "packer"
  qemuargs                  = [["-serial", "stdio"]]
  # It's quite unstable to use shrink so uncomment it if you need it very much
  # qemu_img_args {
  #   resize  = ["--shrink"]
  # }
  output_directory          = var.output_directory
  vm_name                   = "${source.name}.raw"
  ssh_private_key_file      = data.sshkey.install.private_key_path
  cd_label                  = "cidata"
  cd_content                = local.cd_content
  shutdown_command        = <<EOF
set -ex

# Default network settings
cat << EOF1 | sudo tee /etc/netplan/90-genesis-net-base-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    alleths:
      match:
        name: en*
      dhcp4: true
EOF1

# Logs
sudo rm -fr /var/log/*

# Remove temporary keys
# Disable removing host keys temporarily
# sudo rm -f /etc/ssh/*host*key*

# Add developer keys
sudo mkdir -p /home/ubuntu/.ssh
[[ -f /tmp/__dev_keys ]] && sudo mv /tmp/__dev_keys /home/ubuntu/.ssh/authorized_keys

# Temporary solution only for development
echo 'ubuntu:ubuntu' | sudo chpasswd

# Tmp files
sudo rm -rf /tmp/* /var/tmp/*

# clear machine-id
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo touch /etc/machine-id
sudo touch /var/lib/dbus/machine-id

# Shell history
history -c

# Cloud-init clean
sudo cloud-init clean --log --seed

# Sync FS
sudo sync

# shutdown machine
sudo poweroff
EOF
}
