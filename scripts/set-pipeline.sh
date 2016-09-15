#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e  # immediately exit if a command returns nonzero
set -u  # fail when referencing nonexistent variables
set -o pipefail  # fail the pipeline if any pipeline command fails

NAME=${1?"Usage: set-pipeline.sh <name>"}

PIPELINE_PATH="${DIR}/../infrastructure/concourse/pipelines/${NAME}.yml"

if [[ ! -f "${PIPELINE_PATH}" ]]; then
  echo "Can't find the ${NAME} pipeline at ${PIPELINE_PATH}. Does it exist?"
  exit 1
fi

CONTAINER_REGISTRY_CONTINENT="$(cat ${DIR}/../config/gcr-continent)"
GCP_PROJECT_NAME="$(cat ${DIR}/../config/gcp-project-name)"
DOCKER_REGISTRY="${CONTAINER_REGISTRY_CONTINENT}.gcr.io/${GCP_PROJECT_NAME}"

fly --target "monorepo" set-pipeline \
  --pipeline "${NAME}" \
  --config "${DIR}/../infrastructure/concourse/pipelines/${NAME}.yml" \
  --var "private_key=$(cat ${DIR}/../../makesomecloud-secrets/concourse_pipeline/concourse_ci)" \
  --var "service_account_keyfile=$(cat ${DIR}/../../makesomecloud-secrets/concourse_worker/service-account-keyfile.json)" \
  --var "git_repository=$(cat ${DIR}/../config/git-repository)" \
  --var "container_registry_continent=" \
  --var "gcp_project_name=$(cat ${DIR}/../config/gcp-project-name)" \
  --var "pants_builder_docker_registry=${DOCKER_REGISTRY}/pants-builder" \
  --var "helloworld_service_container_registry=${DOCKER_REGISTRY}/helloworld"

