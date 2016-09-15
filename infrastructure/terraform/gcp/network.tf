variable "backend_network_name" {
  default = "backend"
}

variable "backend_subnetwork_cidr_range" {
  default = "10.240.0.0/20"
}

resource "google_compute_network" "backend" {
  name = "${var.backend_network_name}"
}

resource "google_compute_subnetwork" "backend" {
  name = "${google_compute_network.backend.name}"
  network = "${google_compute_network.backend.self_link}"
  region = "${var.google_region}"
  ip_cidr_range = "${var.backend_subnetwork_cidr_range}"
}
