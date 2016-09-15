variable "concourse_tsa_host" { }

variable "concourse_worker_zone" {
  default = "europe-west1-d"
}

variable "concourse_worker_machine_type" {
  default = "n1-standard-2"
}

variable "concourse_worker_preemptible" {
  default = true
}

resource "google_compute_instance_template" "concourse_worker" {
  tags = ["concourse-worker"]
  region = "${var.google_region}"

  instance_description = "Runs Concourse CI jobs."
  machine_type = "${var.concourse_worker_machine_type}"

  name_prefix = "concourse-worker"

  lifecycle {
    create_before_destroy = true
  }

  # TODO(fred): deprecated, but causes recreate every time if not set
  automatic_restart = false

  scheduling {
    on_host_maintenance = "TERMINATE"
    preemptible = "${var.concourse_worker_preemptible}"
    automatic_restart = false
  }

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-1604-lts"
    disk_type = "pd-ssd"
    disk_size_gb = "50"
    auto_delete = true
    boot = true
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.backend.name}"
    access_config {}
  }

  service_account {
    email = "concourse@${var.google_project}.iam.gserviceaccount.com"
    scopes = ["storage-ro"]
  }

  metadata {
    concourse-version = "2.1.0"
    concourse-tsa-host = "${var.concourse_tsa_host}"
    startup-script-url = "gs://${google_storage_bucket.concourse_worker.name}/scripts/startup.sh"
    instance-data-gs-path = "gs://${google_storage_bucket.concourse_worker.name}/data"
  }
}

resource "google_compute_instance_group_manager" "concourse_worker" {
  name = "concourse-worker"

  depends_on = ["google_compute_instance_template.concourse_worker"]

  base_instance_name = "concourse-worker"
  instance_template = "${google_compute_instance_template.concourse_worker.self_link}"
  update_strategy = "RESTART"

  zone = "${var.concourse_worker_zone}"
}

resource "google_compute_autoscaler" "concourse_worker" {

  depends_on = ["google_compute_instance_group_manager.concourse_worker"]

  name = "concourse-worker"
  zone = "${var.concourse_worker_zone}"
  target = "${google_compute_instance_group_manager.concourse_worker.self_link}"

  autoscaling_policy = {
    max_replicas    = 64
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

resource "google_storage_bucket" "concourse_worker" {
  name = "${var.google_project}-concourse-worker"
  location = "EU"
  force_destroy = true
}

resource "google_storage_bucket_acl" "concourse_worker" {
  bucket = "${google_storage_bucket.concourse_worker.name}"

  role_entity = ["READER:user-concourse@${var.google_project}.iam.gserviceaccount.com"]
}

resource "google_storage_bucket_object" "concourse_startup_script" {
  name = "scripts/startup.sh"
  bucket = "${google_storage_bucket.concourse_worker.name}"
  source = "${path.root}/../instances/concourse_worker/startup.sh"
}

resource "google_storage_object_acl" "concourse_startup_script" {
  bucket = "${google_storage_bucket.concourse_worker.name}"
  object = "${google_storage_bucket_object.concourse_startup_script.name}"
  role_entity = ["READER:user-concourse@${var.google_project}.iam.gserviceaccount.com"]
}

resource "google_storage_bucket_object" "concourse_tsa_host_public_key" {
  name = "data/tsa-host-public-key"
  bucket = "${google_storage_bucket.concourse_worker.name}"
  source = "${var.secrets_directory}/concourse_worker/tsa-host-public-key"
}

resource "google_storage_object_acl" "concourse_tsa_host_public_key" {
  bucket = "${google_storage_bucket.concourse_worker.name}"
  object = "${google_storage_bucket_object.concourse_tsa_host_public_key.name}"
  role_entity = ["READER:user-concourse@${var.google_project}.iam.gserviceaccount.com"]
}

resource "google_storage_bucket_object" "concourse_worker_private_key" {
  name  = "data/worker-private-key"
  bucket = "${google_storage_bucket.concourse_worker.name}"
  source = "${var.secrets_directory}/concourse_worker/worker-private-key"
}

resource "google_storage_object_acl" "concourse_worker_private_key" {
  bucket = "${google_storage_bucket.concourse_worker.name}"
  object = "${google_storage_bucket_object.concourse_worker_private_key.name}"
  role_entity = ["READER:user-concourse@${var.google_project}.iam.gserviceaccount.com"]
}
