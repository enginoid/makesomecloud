# resource "google_storage_bucket_acl" "container_registry" {
#   bucket = "${trimspace(file("${var.config_dir}/container-registry-continent"))}.artifacts.make-some-cloud.appspot.com"
#
#   role_entity = [
#     "READER:user-concourse@${var.google_project}.iam.gserviceaccount.com",
#     "WRITER:user-concourse@${var.google_project}.iam.gserviceaccount.com",
#   ]
# }
