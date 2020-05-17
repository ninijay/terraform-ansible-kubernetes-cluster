locals {
  kube_version = "1.18.0"
  masternodes = 1
  workernodes = 2
  subnet_node_prefix = "172.16.1"
  domain = "k8s.local"
  initialUser = "zanidd"
  initialPW = "zanidd"
}

provider libvirt {
  uri = "qemu:///system"
}

resource libvirt_pool local {
  name = "k8cluster"
  type = "dir"
  path = "${path.cwd}/volume_pool"
}

resource libvirt_volume ubuntu1804_cloud {
  name   = "ubuntu18.04.qcow2"
  pool   = libvirt_pool.local.name
  source = "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource libvirt_volume ubuntu1804_resized {
  name           = "ubuntu-volume-${count.index}"
  base_volume_id = libvirt_volume.ubuntu1804_cloud.id
  pool           = libvirt_pool.local.name
  size           = 30949672960
  count          = local.masternodes + local.workernodes
}

data template_file public_key {
  template = file("/home/zanidd/.ssh/id_rsa.pub")
}

data template_file envvars {
  template = file("${path.module}/envvars.tmpl")
  vars = {
    kube_version = local.kube_version
  }
}

resource local_file envvars {
  content  = data.template_file.envvars.rendered
  filename = "${path.module}/envvars.env"
}

data template_file master_user_data {
  count = local.masternodes
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    public_key = data.template_file.public_key.rendered
    hostname = "kube-master"
    kube_version = local.kube_version
    user = local.initialUser
    pw = local.initialPW
  }
}

data template_file worker_user_data {
  count = local.workernodes
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    public_key = data.template_file.public_key.rendered
    hostname = "kube-node${count.index}"
    kube_version = local.kube_version
    user = local.initialUser
    pw = local.initialPW
  }
}

data "template_file" "master_network_config" {
  template = file("${path.module}/network_config.cfg")
  count = local.masternodes
  vars = {
    ip = "${local.subnet_node_prefix}.1${count.index+1}"
    gateway = "${local.subnet_node_prefix}.1"
  }
}

data "template_file" "worker_network_config" {
  template = file("${path.module}/network_config.cfg")
  count = local.workernodes
  vars = {
    ip = "${local.subnet_node_prefix}.2${count.index+1}"
    gateway = "${local.subnet_node_prefix}.1"
  }
}

resource libvirt_cloudinit_disk masternodes {
  count = local.masternodes
  name = "cloudinit_master_resized_${count.index}.iso"
  pool = libvirt_pool.local.name
  user_data = data.template_file.master_user_data[count.index].rendered
  network_config = data.template_file.master_network_config[count.index].rendered
}

resource libvirt_cloudinit_disk workernodes {
  count = local.workernodes
  name = "cloudinit_worker_resized_${count.index}.iso"
  pool = libvirt_pool.local.name
  user_data = data.template_file.worker_user_data[count.index].rendered
  network_config = data.template_file.worker_network_config[count.index].rendered
}

resource libvirt_network kube_node_network {
  name      = "kube_nodes"
  mode      = "nat"
  domain    = local.domain
  autostart = true
  addresses = ["${local.subnet_node_prefix}.0/24"]
  dns {
    enabled = true
  }
}

# resource libvirt_network kube_ext_network {
#   name      = "kube_ext"
#   mode      = "nat"
#   bridge    = "vbr1ext"
#   domain    = "ext.k8s.local"
#   autostart = true
#   addresses = ["${local.subnet_ext_prefix}.0/24"]
#   # dns {
#   #   enabled = false
#   # }
#   dhcp {
#     enabled = true
#   }
# }

resource libvirt_domain k8s_masters {
  count = local.masternodes
  name   = "kube-master"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.masternodes[count.index].id

  network_interface {
    network_id     = libvirt_network.kube_node_network.id
    hostname       = "kube-master"
    addresses      = ["${local.subnet_node_prefix}.1${count.index+1}"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu1804_resized[count.index].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource libvirt_domain k8s_workers {
  count = local.workernodes
  name   = "kube-node${count.index}"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.workernodes[count.index].id

  network_interface {
    network_id     = libvirt_network.kube_node_network.id
    hostname       = "kube-node${count.index}"
    addresses      = ["${local.subnet_node_prefix}.2${count.index + 1}"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu1804_resized[local.masternodes+count.index].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}