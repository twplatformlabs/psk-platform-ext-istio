#!/usr/bin/env bash
set -euo pipefail

cluster_role=$1
istio_base_version=$(jq -er .istio_base_version environments/$cluster_role.json)
base_revision=$(echo "${istio_base_version}" | tr '.' '-')
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

echo "Generate istio-ingressgateway Application definition at base version: $istio_base_version"

mkdir -p deploy-files/istio-ingressgateway

echo "generating ingressgateway application.yaml"
cat <<EOF > deploy-files/istio-ingressgateway/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-ingressgateway
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://istio-release.storage.googleapis.com/charts
      chart: gateway
      targetRevision: $istio_base_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/istio-ingressgateway/istio-ingressgateway-default-values.yaml
          - \$config/roles/$cluster_role/istio-ingressgateway/istio-ingressgateway-$cluster_role-values.yaml
    - repoURL: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
      targetRevision: HEAD
      ref: config
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-ingress
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 5m
EOF
cat deploy-files/istio-ingressgateway/application.yaml

echo "copying istio-ingressgateway environment values.yaml files"
cp -v deploy-templates/istio-ingressgateway-default-values.yaml deploy-files/istio-ingressgateway/istio-ingressgateway-default-values.yaml
cp -v deploy-templates/istio-ingressgateway-$cluster_role-values.yaml deploy-files/istio-ingressgateway/istio-ingressgateway-$cluster_role-values.yaml
