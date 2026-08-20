#!/usr/bin/env bash
set -euo pipefail

cluster_role=$1
istio_revision=$2

#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1
istio_base_version=$(jq -er .istio_base_version environments/$cluster_role.json)
base_revision=$(echo "${istio_base_version}" | tr '.' '-')
echo "base_revision $base_revision"
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

mkdir -p deploy-files/istio-dependencies
mkdir -p deploy-files/istio-base
mkdir -p deploy-files/istio-cni
mkdir -p deploy-files/istio-staged
mkdir -p deploy-files/istio-release