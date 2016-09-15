#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e  # immediately exit if a command returns nonzero
set -u  # fail when referencing nonexistent variables
set -o pipefail  # fail the pipeline if any pipeline command fails

MONOREPO_PATH=${1?"Usage: bundle-docker.sh <MONOREPO_PATH> <DESTINATION>"}
DESTINATION=${2?"Usage: bundle-docker.sh <MONOREPO_PATH> <DESTINATION>"}

cp -r "${DIR}/Dockerfile" "${DESTINATION}"
cp -r "${MONOREPO_PATH}" "${DESTINATION}"
