variable "bastion_tag" {
  default = "bastion"
  description = <<EOF
Tag that will be given to the bastion machine, and used to apply firewall
rules to it.
EOF
}

variable "bastion_region" {
  default = "europe-west1"

  description = <<EOF
Region for the bastion host. To keep your SSH session snappy, you may want
to place the bastion in a region that you have low latency to. If you are
unsure, you may want to run the CloudHarmony Network Test. For instance,
the following test checks your latency to all regions:

  http://cloudharmony.com/speedtest-latency-for-google:compute-limit-10

EOF
}

variable "bastion_zone" {
  description = "Zone to keep the bastion in; must belong to bastion_region."
  default = "europe-west1-d"
}

// IPs that you trust to connect to your bastion host.
variable "bastion_trusted_ips" {
  default = ["85.240.66.15/32"]
}

resource "google_compute_instance_template" "bastion" {
  description = "A group to ensure the bastion host remains up."

  name_prefix = "bastion"

  lifecycle {
    create_before_destroy = true
  }

  // This tag is used by a firewall rule to allow access to allow
  // access to the SSH port.
  tags = ["${var.bastion_tag}"]

  instance_description = "A bastion host accessible on SSH port from trusted IPs."
  region = "${var.bastion_region}"

  machine_type = "f1-micro"
  can_ip_forward = false

  // TODO(fred): not having this will cause this template to be force
  //             recreated every time (Terraform bug).
  automatic_restart = false

  scheduling {
    on_host_maintenance = "TERMINATE"
    preemptible = true
    automatic_restart = false
  }

  disk {
    source_image = "debian-cloud/debian-8-jessie-v20160803"
    auto_delete = true
    boot = true
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.backend.name}"
    access_config {}
  }
}

resource "google_compute_target_pool" "bastion" {
  name = "bastion"
  description = "Target pool for bastion hosts"
  region = "${var.bastion_region}"
}

resource "google_compute_instance_group_manager" "bastion" {
  name = "bastion"
  description = "Keeps a single bastion instance alive."

  base_instance_name = "bastion"
  instance_template = "${google_compute_instance_template.bastion.self_link}"
  update_strategy = "RESTART"

  target_pools = ["${google_compute_target_pool.bastion.self_link}"]
  target_size  = 1
  zone = "${var.bastion_zone}"

  named_port {
    name = "ssh"
    port = 22
  }
}

resource "google_compute_forwarding_rule" "default" {
  name = "bastion"
  target = "${google_compute_target_pool.bastion.self_link}"
  port_range = "22-22"
  ip_protocol = "TCP"
  region = "${google_compute_target_pool.bastion.region}"
}

resource "google_compute_firewall" "backend_bastion_allow_trusted_ips" {
  name = "${google_compute_network.backend.name}-allow-trusted-ips-to-bastion"
  description = "Allow bastion SSH access from trusted IPs."
  network = "${google_compute_network.backend.name}"

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  source_ranges = "${var.bastion_trusted_ips}"
  target_tags = ["${var.bastion_tag}"]
}

resource "google_compute_firewall" "allow_bastion_to_internal" {
  name = "${google_compute_network.backend.name}-allow-bastion-to-internal"
  description = "Allow bastion to access everything on the backend subnet."
  network = "${google_compute_network.backend.name}"

  allow {
    protocol = "tcp"
    ports = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["${google_compute_subnetwork.backend.ip_cidr_range}"]
}

output "bastion_ip" {
  value = "${google_compute_forwarding_rule.default.ip_address}"
}
