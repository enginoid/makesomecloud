#!/bin/bash -x

# Prerequisites:
#  - set instance metadata attributes:
#    - concourse-version (e.g. "2.1.0")
#    - tsa-host (e.g. "10.23.51.12")

function get_metadata_value() {
  local key_name=${1?"missing key argument in get_metadata_value"}
  echo "$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${key_name}" \
      -H Metadata-Flavor:Google)"
}

function install_concourse() {
  local version=${1?"missing version in install_concourse"}
  local destination=${2?"missing destination in install_concourse"}

  wget -O "${destination}" "https://github.com/concourse/concourse/releases/download/v${version}/concourse_linux_amd64"
  chmod 0755 "${destination}"
  return
}

function download_secrets() {
  local secrets_src=${1?"missing secrets_src in download_secrets"}
  local secrets_dst=${2?"missing secrets_dst in download_secrets"}

  if [[ ! -d "${secrets_dst}" ]]; then
    mkdir -p "${secrets_dst}"
  fi
  mkdir "${secrets_dst}"
  chmod 0600 "${secrets_dst}"
  gsutil cp -r "${secrets_src}/*" "${secrets_dst}"
  return
}

function create_service_env() {
  local env_file=${1?"missing env_file in create_service_env"}
  local tsa_host=${2?"missing tsa_host in create_service_env"}
  local secrets_path=${3?"missing secrets_path in create_service_env"}

    cat <<EOF > ${env_file}
CONCOURSE_WORK_DIR=/opt/concourse/worker
CONCOURSE_TSA_HOST=${tsa_host}
CONCOURSE_TSA_PORT=2222
CONCOURSE_TSA_PUBLIC_KEY=${secrets_path}/tsa-host-public-key
CONCOURSE_TSA_WORKER_PRIVATE_KEY=${secrets_path}/worker-private-key
EOF

  return
}

function create_service() {
  local env_file=${1?"missing env_file in create_service"}
  local bin_path=${2?"missing bin_path in create_service"}
  local service_name=${3?"missing service_name in create_service"}

  local service_path="/etc/systemd/system/${service_name}.service"

  cat <<EOF > ${service_path}
[Unit]
Description=Run a concourse worker.

[Service]
EnvironmentFile=${env_file}
ExecStart=${bin_path} worker
EOF

  chmod 0644 "${service_path}"
  return
}

function main() {
  CONCOURSE_SERVICE_NAME="concourse_worker"
  CONCOURSE_SECRETS_GS_DIR="$(get_metadata_value 'instance-data-gs-path')"
  CONCOURSE_SECRETS_DIR="/etc/secrets"
  CONCOURSE_BIN_FILE="/usr/local/bin/concourse"
  CONCOURSE_ENV_FILE="/etc/concourse.env"
  SERVICE_NAME="concourse_worker"

  install_concourse "$(get_metadata_value 'concourse-version')" "${CONCOURSE_BIN_FILE}" &
  download_secrets "${CONCOURSE_SECRETS_GS_DIR}" "${CONCOURSE_SECRETS_DIR}" &
  create_service_env "${CONCOURSE_ENV_FILE}" "$(get_metadata_value concourse-tsa-host)" "${CONCOURSE_SECRETS_DIR}" &
  create_service "${CONCOURSE_ENV_FILE}" "${CONCOURSE_BIN_FILE}" "${CONCOURSE_SERVICE_NAME}" &
  wait
  systemctl daemon-reload
  systemctl start ${CONCOURSE_SERVICE_NAME}.service
}

main "$@"

