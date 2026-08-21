#!/usr/bin/env bash
set -euo pipefail

cluster_role=$1
istio_base_version=$(jq -er .istio_base_version environments/$cluster_role.json)
base_revision=$(echo "${istio_base_version}" | tr '.' '-')
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

echo "Generate Istio base and cni Application definition at base version: $istio_base_version"

mkdir -p deploy-files/istio-base
mkdir -p deploy-files/istio-cni
mkdir -p deploy-files/istio-revision-base

# to generate a similar template for analysis
# helm template istio-base istio/base \
#      --namespace istio-system \
#      --version 1.29.3 \
#      --set defaultRevision=default \
#      --set validationFailurePolicy=Fail \
#      --set pilot.cni.enabled=true \
#      --values deploy-templates/istio-base-default-values.yaml > base.yaml

# helm template istio-cni istio/cni \
#      --namespace istio-system \
#      --version 1.29.3 \
#      --values deploy-templates/istio-cni-default-values.yaml

echo "generating base application.yaml"
cat <<EOF > deploy-files/istio-base/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-base
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://istio-release.storage.googleapis.com/charts
      chart: base
      targetRevision: $istio_base_version
      helm:
        parameters:
          - name: defaultRevision
            value: $base_revision
          - name: validationFailurePolicy
            value: Fail
          - name: pilot.cni.enabled
            value: "true"
        valueFiles:
          - \$config/roles/$cluster_role/istio-base/istio-base-default-values.yaml
          - \$config/roles/$cluster_role/istio-base/istio-base-$cluster_role-values.yaml
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
  ignoreDifferences:
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      name: istiod-default-validator
      managedFieldsManagers:
        - pilot-discovery
EOF
cat deploy-files/istio-base/application.yaml

echo "generating cni application.yaml"
cat <<EOF > deploy-files/istio-cni/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-cni
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://istio-release.storage.googleapis.com/charts
      chart: cni
      targetRevision: $istio_base_version
      helm:
        valueFiles:
          - \$config/roles/$cluster_role/istio-cni/istio-cni-default-values.yaml
          - \$config/roles/$cluster_role/istio-cni/istio-cni-$cluster_role-values.yaml
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
cat deploy-files/istio-cni/application.yaml

echo "generating staged revision tag application.yaml"
cat <<EOF > deploy-files/istiod-revision-base/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-revision-base
  namespace: $argocd_namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: psk-aws-control-plane-configuration

  sources:
    - repoURL: https://github.com/twplatformlabs/psk-platform-ext-istio
      path: charts/istio-revision-base
      targetRevision: HEAD
      helm:
        parameters:
          - name: version
            value: $istio_base_version
          - name: revision
            value: $base_revision
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
cat deploy-files/istiod-revision-base/application.yaml


echo "copying istio base and cni environment values.yaml files"
cp -v deploy-templates/istio-base-default-values.yaml deploy-files/istio-base/istio-base-default-values.yaml
cp -v deploy-templates/istio-base-$cluster_role-values.yaml deploy-files/istio-base/istio-base-$cluster_role-values.yaml
cp -v deploy-templates/istio-cni-default-values.yaml deploy-files/istio-cni/istio-cni-default-values.yaml
cp -v deploy-templates/istio-cni-$cluster_role-values.yaml deploy-files/istio-cni/istio-cni-$cluster_role-values.yaml