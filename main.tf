# main.tf

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.84.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Configure the Proxmox provider to get the list of LXCs
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}

# --- Data Sources ---

# Get all LXCs
data "proxmox_virtual_environment_containers" "all_lxcs_on_node" {
  node_name = var.proxmox_node_name
}

# --- Local Variables for Processing ---

locals {
  # vmid => name for running containers
  running_lxcs = {
    for vm in data.proxmox_virtual_environment_containers.all_lxcs_on_node.containers :
    tostring(vm.vm_id) => vm.name if vm.status == "running"
  }

  # newline-delimited "vmid name" pairs for the script
  lxc_pairs = join(
    "\n",
    [for id, name in local.running_lxcs : "${id} ${name}"]
  )
}

resource "null_resource" "always_run" {
  triggers = { timestamp = timestamp() }
}

resource "null_resource" "lxc_batch_updater" {
  # Re-run whenever the list of running LXCs changes or on each apply
  triggers = {
    lxcs_hash = sha1(local.lxc_pairs)
    ts        = null_resource.always_run.triggers.timestamp
  }

  connection {
    type        = "ssh"
    host        = var.proxmox_ssh_host
    user        = var.proxmox_ssh_user
    private_key = file(var.proxmox_ssh_private_key_path)
  }

  # Upload a script that runs updates in parallel on the Proxmox host
  provisioner "file" {
    content     = <<-EOT
      #!/usr/bin/env bash
      set -euo pipefail

      MAXP="$${MAX_PARALLEL}"

      update_one() {
        vmid="$1"
        name="$2"

        echo "--- Running update on LXC $${vmid} ($${name}) ---"
        # Make sure printf creates an executable shim
        pct exec "$${vmid}" -- bash -lc \
          "cp /usr/bin/whiptail /usr/bin/whiptail.old &&
           printf '#!/bin/sh\\necho 2\\n' > /usr/bin/whiptail &&
           chmod +x /usr/bin/whiptail &&
           echo '--- Performing update ---' &&
           update > /var/log/lxc-update.log 2>&1 ||
           true
           cp /usr/bin/whiptail.old /usr/bin/whiptail &&
           echo '--- Restored whiptail ---'"

        echo "--- Finished update for LXC $${vmid} ($${name}) ---"
      }

      export -f update_one

      # Feed "vmid name" pairs and run with limited parallelism via xargs
      # Requires xargs with -P support (common on GNU/BSD)
      xargs -P "$${MAXP}" -n 2 bash -c 'update_one "$1" "$2"' _ <<'LIST'
      ${local.lxc_pairs}
      LIST
    EOT
    destination = "/tmp/lxc_update.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/lxc_update.sh",
      "MAX_PARALLEL=${var.max_parallel} /tmp/lxc_update.sh",
      "rm -f /tmp/lxc_update.sh"
    ]
  }
}
