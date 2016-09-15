variable "concourse_tsa_host" {
    description = <<EOF
Address for the Concourse TSA load balanceer (concourse-web on Kubernetes).
This is used by the worker to connect to the main Concourse instances
that coordinate jobs.

If you're running Terraform for the first time and/or have not yet created the
manifests for Concourse on Kubernetes, feel free to specify an arbitrary value
for now (e.g. localhost).

When you've applied Terraform once and created the manifests for Concourse,
you should be able to obtain the load balancer IP with this command:

  kubectl get service concourse-web \
    --template='{{(index .status.loadBalancer.ingress 0).ip}}' \
    -o template

Setting this to a new value will force recreation of the instance group and
instance template. To persist this value, put it in the .tfvars file instead
of supplying it on every terraform run.

(This is a workaround until I can set up proper service discovery to avoid
this cumbersome manual step.)

EOF
}

variable "google_credentials" {}
variable "google_project" {}
variable "google_region" {}


module "gcp" {
    source = "./gcp"

    google_credentials = "${var.google_credentials}"
    google_project = "${var.google_project}"
    google_region = "${var.google_region}"

    concourse_tsa_host = "${var.concourse_tsa_host}"
}

output "bastion_ip" {
  value = "${module.gcp.bastion_ip}"
}

output "container_cluster_ip" {
  value = "${module.gcp.container_cluster_ip}"
}
