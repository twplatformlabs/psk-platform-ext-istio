#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

cluster_role=$1
istio_release_version=$(jq -er .istio_release_version environments/$cluster_role.json)
istio_staged_version=$(jq -er .istio_staged_version environments/$cluster_role.json)
release_revision=$(echo "${istio_release_version}" | tr '.' '-')
staged_revision=$(echo "${istio_staged_version}" | tr '.' '-')
echo "release_revision $release_revision"
echo "staged_revision $staged_revision"
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

mkdir -p deploy-files/istiod-release
mkdir -p deploy-files/istiod-staged

# helm repo add istio https://istio-release.storage.googleapis.com/charts
# helm repo update

# trivyscan
# the base deployment is just CRD
# CNI runs with elevated priviledges to perform routing controls

# helm template istio-base istio/istiod \
#      --namespace istio-system \
#      --version 1.29.3 \
#      --set revision=1-29-3 \
#      --values deploy-templates/istio-default-values.yaml > istiod.yaml



if [[ $istio_release_version != "none" ]]; then
  echo "generating release istiod application.yaml"
  cat <<EOF > deploy-files/istiod-release/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-release
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://istio-release.storage.googleapis.com/charts
      chart: istiod
      targetRevision: $istio_release_version
      helm:
        parameters:
          - name: revision
            value: $release_revision
        valueFiles:
          - \$config/roles/$cluster_role/istiod/istiod-default-values.yaml
          - \$config/roles/$cluster_role/istiod/istiod-$cluster_role-values.yaml
    - repoURL: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
      targetRevision: HEAD
      ref: config
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
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
else
  echo "# No release version specified" > deploy-files/istiod-release/application.yaml
fi
cat deploy-files/istiod-release/application.yaml

echo "generating staged istiod application.yaml"
cat <<EOF > deploy-files/istiod-staged/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-staged
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://istio-staged.storage.googleapis.com/charts
      chart: istiod
      targetRevision: $istio_staged_version
      helm:
        parameters:
          - name: revision
            value: $staged_revision
        valueFiles:
          - \$config/roles/$cluster_role/istiod/istiod-default-values.yaml
          - \$config/roles/$cluster_role/istiod/istiod-$cluster_role-values.yaml
    - repoURL: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
      targetRevision: HEAD
      ref: config
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
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
cat deploy-files/istiod-staged/application.yaml

echo "copying istiod env values files"
cp -v deploy-templates/istiod-default-values.yaml deploy-files/istiod-release/istiod-default-values.yaml
cp -v deploy-templates/istiod-$cluster_role-values.yaml deploy-files/istiod-release/istiod-$cluster_role-values.yaml
cp -v deploy-templates/istiod-default-values.yaml deploy-files/istiod-staged/istiod-default-values.yaml
cp -v deploy-templates/istiod-$cluster_role-values.yaml deploy-files/istiod-staged/istiod-$cluster_role-values.yaml
