#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e  # immediately exit if a command returns nonzero
set -u  # fail when referencing nonexistent variables
set -o pipefail  # fail the pipeline if any pipeline command fails

SERVICE_NAME=${1?"Usage: build.sh <service_name> <destination>"}
DESTINATION=${2?"Usage: build.sh <service_name> <destination>"}

(cd ${DIR}/.. && ./pants --config-override=pants.ci.ini bundle "services/io/enginoid/${SERVICE_NAME}")
cp -LR \
  "${DIR}/../dist/services.io.enginoid.${SERVICE_NAME}.${SERVICE_NAME}-bundle/"* \
  "${DESTINATION}/"

GIT_REVISION=$(git -C "${DIR}" rev-parse --verify HEAD)
echo $GIT_REVISION > "${DESTINATION}/version"
