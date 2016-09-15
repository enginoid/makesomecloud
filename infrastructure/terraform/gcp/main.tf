variable "google_credentials" {}
variable "google_project" {}
variable "google_region" {}

variable "secrets_directory" {
  description = "Path to secrets from terraform directory."
  default = "../../../makesomecloud-secrets"
}

variable "config_dir" {
  default = "../../config"
}

provider "google" {
  // When these are left blank, Terraform should be able to pick
  // up the configuration from an active `gcloud` installation
  // for a given project.
  credentials = "${var.google_credentials}"
  project = "${var.google_project}"
  region = "${var.google_region}"
}

