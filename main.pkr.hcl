packer {
  required_plugins {
	qemu = {
		version = "~> 1"
		source  = "github.com/hashicorp/qemu"
	}
	parallels = {
		version = ">= 1.1.5"
		source  = "github.com/parallels/parallels"
	}
	vmware = {
		version = "~> 1"
		source = "github.com/hashicorp/vmware"
	}
  }
}

///////////////////////////////////////////

variable "iso_url"				{ type = string }
variable "iso_hash"				{ type = string }

variable "issuer_tag"			{
	type = string
	default = "X"
}
variable "verifier_tag"			{
	type = string
	default = "X"
}

variable "user_pass"			{ type = string }

variable "hypervisor"			{ type = string }

///////////////////////////////////////////
///////////////////////////////////////////
///////////////////////////////////////////

// https://developer.hashicorp.com/packer/integrations/Parallels/parallels/latest/components/builder/iso
source "parallels-iso" "eID" {
	iso_url           = var.iso_url
	iso_checksum      = var.iso_hash

	// Some people get an error when compacting the disk (?)
	// Also, according to the documentation, plain disks perform better
	disk_type = "plain"
	skip_compaction = true

	parallels_tools_flavor = "lin-arm"

	cpus = 6 	// My laptop has 12 cores
	memory = 18432 // 18 GB of RAM. My laptop has 36 GB

	guest_os_type = "debian"
	parallels_tools_mode = "upload"
	parallels_tools_guest_path = "/tmp/parallels_guest.iso"
	prlctl = [
		// Set the network in bridged mode to allow other hosts in the network (i.e., the Wallet app) to interact with the services
//		[ "set", "{{.Name}}", "--device-set", "net0", "--type", "bridged"] // Temporarily removed because my adapter seems to have problems with IPv6... 🙄 (see https://lists.debian.org/debian-boot/2025/03/msg00012.html )
	]

	vm_name = "eID_testlab"

	ssh_username = "lab-user"
	ssh_password = var.user_pass
	ssh_timeout = "10m"

	shutdown_command = "echo ${var.user_pass} | sudo -S /sbin/shutdown -h now" // shit ain't working :(

	// https://developer.hashicorp.com/packer/guides/automatic-operating-system-installs/preseed_ubuntu
	// Mounting an additional CD drives the Debian installer crazy, so I opted for pulling all provisioning files
	// from the HTTP server as well (exposed to the provisioners as PACKER_HTTP_ADDR: https://github.com/hashicorp/packer/pull/4409 )
	http_directory = "http_files"
	boot_command = [
		"c", // Go into Grub shell
		"root=(cd0,msdos1) <enter>", // Mount cd0p1 (the boot partition) on the root
		"linux /install.a64/vmlinuz",
		" auto-install/enable=true",
		" debconf/priority=critical",
		" preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <enter>",
		"initrd /install.a64/initrd.gz <enter>",
		"boot <enter>"
	]
	boot_wait = "1s" // In my tests it boots quite fast
}


source "vmware-iso" "eID" {
	iso_url           = var.iso_url
	iso_checksum      = var.iso_hash

	network_adapter_type = "vmxnet3"

	communicator = "ssh"
	ssh_username = "lab-user"
	ssh_password = var.user_pass
	ssh_timeout = "20m"

	cpus = 2	// 2 vCPUs spread on 2 sockets
	cores = 2
	memory = 8192 // 8 GB of RAM

//	disk_adapter_type = "ide" // The installer doesn't seem to detect the drive otherwise
	disk_type_id = 0 // "Growable virtual disk contained in a single file (monolithic sparse)."

	// https://github.com/vmware/open-vm-tools/blob/master/open-vm-tools/lib/include/guest_os_tables.h#L369
	guest_os_type = "debian13-64"
	vhv_enabled = true

	tools_mode = "upload"
	tools_upload_flavor = "linux"
	tools_upload_path = "/tmp/vmware_tools.iso"

	shutdown_command = "echo ${var.user_pass} | sudo -S /sbin/shutdown -h now"

	vm_name = "eID_testlab"

	// https://developer.hashicorp.com/packer/guides/automatic-operating-system-installs/preseed_ubuntu
	// Mounting an additional CD drives the Debian installer crazy, so I opted for pulling all provisioning files
	// from the HTTP server as well (exposed to the provisioners as PACKER_HTTP_ADDR: https://github.com/hashicorp/packer/pull/4409 )
	http_directory = "http_files"
	boot_command = [
		"<esc><wait>", // Go into the Debian bootloader shell. Apparently the x64 version has no Grub (?)
		"/install.amd/vmlinuz",
		" initrd=/install.amd/initrd.gz",
		" auto-install/enable=true",
		" debconf/priority=critical",
		" preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <enter>",
	]
	boot_wait = "5s" // In my tests it boots quite fast. 1s  was too fast, though...
}

// https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu
source "qemu" "eID" {
	iso_url           = var.iso_url
	iso_checksum      = var.iso_hash

	accelerator = "kvm"
	cpu_model = "host" // Pass through the host CPU so nested virtualization works (like vhv_enabled for vmware)

	cpus = 2
	memory = 8192 // 8 GB of RAM

	format = "qcow2"
	disk_size = "40G"
	// virtio-scsi shows up as /dev/sda in the guest, which is what grub-installer/bootdev in the preseed expects
	disk_interface = "virtio-scsi"
	net_device = "virtio-net"

	communicator = "ssh"
	ssh_username = "lab-user"
	ssh_password = var.user_pass
	ssh_timeout = "20m"

	shutdown_command = "echo ${var.user_pass} | sudo -S /sbin/shutdown -h now"

	vm_name = "eID_testlab.qcow2"

	http_directory = "http_files"
	boot_command = [
		"<esc><wait>", // Same BIOS/isolinux boot prompt as the vmware build
		"/install.amd/vmlinuz",
		" initrd=/install.amd/initrd.gz",
		" auto-install/enable=true",
		" debconf/priority=critical",
		" preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <enter>",
	]
	boot_wait = "5s"
}

locals {
	// The qemu builder is just called "qemu", not "qemu-iso"
	source_name = var.hypervisor == "qemu" ? "qemu" : "${var.hypervisor}-iso"
}

build {
	sources = ["source.${local.source_name}.eID"]

	// https://developer.hashicorp.com/packer/docs/provisioners/shell
	provisioner "shell" {
		script = "init_provisioning.sh"
		env = {
			"ELEVATE_PASS": var.user_pass
		}
		timeout = "20m"
	}

	provisioner "shell" {
		script = "http_files/provisioning/issuer/setup.sh"
		env = {
			"ELEVATE_PASS": var.user_pass,
			"GIT_TAG": var.issuer_tag,
		}
		timeout = "5m"
	}

	provisioner "shell" {
		script = "http_files/provisioning/verifier/setup.sh"
		env = {
			"ELEVATE_PASS": var.user_pass,
			"GIT_TAG": var.verifier_tag,
		}
		timeout = "5m"
	}

	provisioner "shell" {
		script = "http_files/provisioning/bind9/setup.sh"
		env = {
			"ELEVATE_PASS": var.user_pass // password for `sudo`
		}
		timeout = "5m"
	}

	provisioner "shell" {
		script = "post_provisioning.sh"
		env = {
			"USER_PASS": var.user_pass
		}
	}
}

