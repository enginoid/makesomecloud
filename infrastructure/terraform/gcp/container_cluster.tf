variable "container_cluster_name" {
  default = "backend"
}

variable "container_cluster_zone" {
  default = "europe-west1-d"
}

variable "container_cluster_initial_node_count" {
  default = 3
}

variable "container_cluster_machine_type" {
  default = "n1-standard-1"
}

resource "google_container_cluster" "backend" {
  // TODO: add Terraform support for multi-zone clusters (GA)
  // TODO: add Terraform support for cluster autoscaler (in beta)
  // TODO: maybe just move this and use vault for proper credential storage

  name = "${var.container_cluster_name}"
  zone = "${var.container_cluster_zone}"
  initial_node_count = "${var.container_cluster_initial_node_count}"
  network = "${google_compute_network.backend.name}"
  subnetwork = "${google_compute_subnetwork.backend.name}"

  master_auth {
    username = "${trimspace(file("${var.secrets_directory}/container_cluster/username"))}"
    password = "${trimspace(file("${var.secrets_directory}/container_cluster/password"))}"
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]
  }
}

output "container_cluster_ip" {
  value = "${google_container_cluster.backend.endpoint}"
}
