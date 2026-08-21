#!/usr/bin/env bash
set -euo pipefail

cluster_role=$1
istio_release_version=$(jq -er .istio_release_version environments/$cluster_role.json)
istio_staged_version=$(jq -er .istio_staged_version environments/$cluster_role.json)
release_revision=$(echo "${istio_release_version}" | tr '.' '-')
staged_revision=$(echo "${istio_staged_version}" | tr '.' '-')
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

echo "Generate release revision Application definition at release version: $istio_release_version"
echo "Generate Istiod staged revision Application definition at staged version: $istio_staged_version"

mkdir -p deploy-files/istiod-revision-release
mkdir -p deploy-files/istiod-revision-staged

if [[ $istio_release_version != "none" ]]; then
  echo "generating release revision tag application.yaml"
  cat <<EOF > deploy-files/istiod-revision-release/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-revision-release
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "6"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://github.com/twplatformlabs/psk-platform-ext-istio
      path: charts/istio-revision-release
      targetRevision: HEAD
      helm:
        parameters:
          - name: version
            value: $istio_release_version
          - name: revision
            value: $release_revision
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
else
  echo "Skipping release version on initial install"
  echo "# No release version specified" > deploy-files/istiod-revision-release/application.yaml
fi
cat deploy-files/istiod-revision-release/application.yaml

echo "generating staged revision tag application.yaml"
cat <<EOF > deploy-files/istiod-revision-staged/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-revision-staged
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "6"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://github.com/twplatformlabs/psk-platform-ext-istio
      path: charts/istio-revision-staged
      targetRevision: HEAD
      helm:
        parameters:
          - name: version
            value: $istio_staged_version
          - name: revision
            value: $staged_revision
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
cat deploy-files/istiod-revision-staged/application.yaml
