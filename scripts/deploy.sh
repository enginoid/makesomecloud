#!/bin/bash

set -e  # immediately exit if a command returns nonzero
set -u  # fail when referencing nonexistent variables
set -o pipefail  # fail the pipeline if any pipeline command fails

SERVICE_NAME=${1?"Usage: deploy.sh <service_name> <tag>"}
TAG=${2?"Usage: deploy.sh <service_name> <tag>"}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="${DIR}/.."

KUBECTL="${PROJECT_ROOT}/scripts/kubectl.sh"

if [[ ! -d "dist" ]]; then
  mkdir "dist"
fi

SERVICE_ARTIFACT="dist/service.yaml"
CONTAINER_REGISTRY_CONTINENT=$(cat "${PROJECT_ROOT}/config/gcr-continent")
GCP_PROJECT_NAME=$(cat "${PROJECT_ROOT}/config/gcp-project-name")
DOCKER_REGISTRY="${CONTAINER_REGISTRY_CONTINENT}.gcr.io/${GCP_PROJECT_NAME}"

# TODO(fred): these are obviously fragile; sed is not supposed to interpolate templates!
cp "services/io/enginoid/${SERVICE_NAME}/service.yaml.tpl" "${SERVICE_ARTIFACT}"
sed -ie "s|{{ GITHASH }}|${TAG}|g" "${SERVICE_ARTIFACT}"
sed -ie "s|{{ DOCKER_REGISTRY }}|${DOCKER_REGISTRY}|g" "${SERVICE_ARTIFACT}"

# TODO(fred): this is not robust against multiple matches. stop using bash for this; prefer go here.
# TODO(fred): check should be safer. the script should avoid making assumptions about the selector, use selector in current YAML.
current_service_name=$(${KUBECTL} get rc --selector "name=${SERVICE_NAME}" -o template --template '{{ range .items }}{{.metadata.name}}{{end}}')
new_service_name="${SERVICE_NAME}-${TAG}"

"${KUBECTL}" apply -f "${PROJECT_ROOT}/${SERVICE_ARTIFACT}"

rm "${SERVICE_ARTIFACT}"
