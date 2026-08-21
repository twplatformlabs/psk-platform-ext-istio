#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_name=$1
cluster_role=$2
istio_base_version=$(jq -er .istio_base_version environments/$cluster_role.json)
istio_release_version=$(jq -er .istio_release_version environments/$cluster_role.json)
istio_staged_version=$(jq -er .istio_staged_version environments/$cluster_role.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)
base_revision=$(echo "${istio_base_version}" | tr '.' '-')
release_revision=$(echo "${istio_release_version}" | tr '.' '-')
staged_revision=$(echo "${istio_staged_version}" | tr '.' '-')

echo "smoke test $cluster_name for istio $cluster_role configuration"
echo "BASE_REV: $base_revision"
echo "RELEASE_REV: $release_revision"
echo "STAGED_REV: $staged_revision"

# confirm new configuration has been synced
validate_argocore_helm_app_resource "$argocd_namespace" "istio-dependencies" "HEAD"
validate_argocore_helm_app_resource "$argocd_namespace" "istio-base" "$istio_base_version"
validate_argocore_helm_app_resource "$argocd_namespace" "istio-cni" "$istio_base_version"
validate_argocore_helm_app_resource "$argocd_namespace" "istio-revision-base" "HEAD"

if [[ "$release_revision" != "none" ]]; then
  validate_argocore_helm_app_resource "$argocd_namespace" "istiod-release" "$istio_release_version"
  validate_argocore_helm_app_resource "$argocd_namespace" "istio-revision-release" "HEAD"
else
  echo "skipping release revision as not deployed"
fi

if [[ "$staged_revision" != "none" ]]; then
  validate_argocore_helm_app_resource "$argocd_namespace" "istiod-staged" "$istio_staged_version"
  validate_argocore_helm_app_resource "$argocd_namespace" "istio-revision-staged" "HEAD"
else
  echo "skipping stage revision as not deployed"
fi

validate_argocore_helm_app_resource "$argocd_namespace" "istio-ingressgateway" "$istio_base_version"

# run basic smoketest for istio health
BASE=$base_revision RELEASE=$release_revision STAGED=$staged_revision bats test/istio-deployment-checks.bats
