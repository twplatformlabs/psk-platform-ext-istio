#!/usr/bin/env bash
set -euo pipefail

cluster_role=$1

custom_chart_version=$(jq -er .custom_chart_version environments/$cluster_role.json)
istio_release_version=$(jq -er .istio_release_version environments/$cluster_role.json)
istio_canary_version=$(jq -er .istio_canary_version environments/$cluster_role.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

echo "Dependency deployment for istio service mesh"
echo "role: $cluster_role"
echo "release version: $istio_release_version"
echo "canary version: $istio_canary_version"

echo "creating deploy-files directory for istio-dependencies files that will written to psk-platform-control-plane-configuration repository"
mkdir -p deploy-files
mkdir -p deploy-files/istio-dependencies

# generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
echo "generating istio-dependencies application.yaml"
cat <<EOF > deploy-files/istio-dependencies/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-dependencies
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://github.com/twplatformlabs/psk-platform-ext-istio
      path: chart/istio-dependencies
      targetRevision: $custom_chart_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/istio-dependencies/deps-default-values.yaml
          - \$config/roles/$cluster_role/istio-dependencies/deps-$cluster_role-values.yaml
    - repoURL: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
      targetRevision: HEAD
      ref: config
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
      - SkipDryRunOnMissingResource=true
    retry:
      limit: 5
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 5m
EOF
cat deploy-files/istio-dependencies/application.yaml

# echo "copying istio-dependency values"
cp -v deploy-templates/deps-default-values.yaml deploy-files/istios-dependencies/deps-default-values.yaml
cp -v deploy-templates/deps-$cluster_role-values.yaml deploy-files/istios-dependencies/deps-$cluster_role-values.yaml

