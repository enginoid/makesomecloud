#!/bin/bash
#
# Connect to the kubernetes endpoint through the bastion host.

# TODO(fred): use ephemereal ports to avoid conflicts (e.g. kubectl proxy in one tab, kubectl get in other)
# TODO(fred): do something better here than --insecure-skip-tls-verify
# TODO(fred): use a stricter check for gcloud commands; handle multiple results
# TODO(fred): don't hang forever if the SSH exits abnormally
# TOOD(fred): stop waiting for the port and fail after some N tries
# TODO(fred): make nc silent when it catches a port

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e  # fail when referencing nonexistent variables
set -u  # fail when referencing nonexistent variables
set -o pipefail  # fail the pipeline if any pipeline command fails

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

require_bin() {
  if [[ -z $(which $1) ]]; then
    err "The $1 utility is required for this script, but is missing. Have you installed it?"
    exit 1
  fi
}

E_BASTION_NOT_FOUND=1
E_CLUSTER_NOT_FOUND=2
E_BASTION_UNREACHABLE=3

require_bin "ssh"
require_bin "gcloud"
require_bin "nc"
require_bin "kubectl"

BASTION_IP=$(gcloud compute forwarding-rules list --filter="name=bastion" --format=config | grep IPAddress | awk '{print $3}' &)
KUBERNETES_ENDPOINT=$(gcloud container clusters list --filter="name=backend" --format=config | grep endpoint | awk '{print $3}' &)
wait

if [[ -z "${BASTION_IP}" ]]; then
  err "Could not determine bastion IP -- forwarding rule with name 'bastion' not found."
  exit "${E_BASTION_NOT_FOUND}"
fi

if [[ -z "${E_CLUSTER_NOT_FOUND}" ]]; then
  err "Could not find container cluster -- cluster with name 'backend' not found."
  exit "{E_CLUSTER_NOT_FOUND}"
fi

# Check whether we can reach the bastion on port 22. This is to improve
# the developer experience around bastion unreachability, rather than just
# hanging and timing out without indication of whether the bastion or
# kubernetes is unreachable.
NC_RETURN="$(nc -z -G2 -w2 "${BASTION_IP}" "22" || echo $?)"  # echo to avoid triggering -e exit
if [[ "${NC_RETURN}" -ne 0 ]]; then
  USER_IP=$(curl -s https://api.ipify.org &)
  ALLOWED_IPS=$(gcloud compute firewall-rules describe backend-allow-trusted-ips-to-bastion --format='value(sourceRanges)' &)
  wait
  err "Failed to connect to the bastion host at ${BASTION_IP}."
  err "The firewall rule for external access to the bastion might not contain your current IP address."
  err "  Your IP address is: ${USER_IP}"
  err "  Authorized ranges are: ${ALLOWED_IPS}"
  err "If your IP is missing from the authorized ranges, add '${USER_IP}/32' to 'bastion_trusted_ips' in terraform.tfvars and apply."
  exit "${E_BASTION_UNREACHABLE}"
fi

# Forward the remote port of the Kubernetes master to a local port that
# we can use as the destination port in the `kubectl` command.
ssh "enginoid@${BASTION_IP}" -L "8443:${KUBERNETES_ENDPOINT}:443" -N &

# Ensure that we kill the SSH process on regular exit as well as keyboard
# interrupts or crashes.
trap 'kill -9 $!' 0

# The SSH connection takes a little bit; wait until port is available.
while ! ( nc -z localhost 8443 ); do sleep 0.1; done
kubectl -s https://localhost:8443 --insecure-skip-tls-verify "$@"
