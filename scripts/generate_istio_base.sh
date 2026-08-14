#!/usr/bin/env bash
set -euo pipefail
source bash-functions.sh

A new version means base and cni are "on" that version so assume forward


1. If canary version is lower than release, must have rollback set


always specify the release=version, canary=version, delete=[versions]

- first, output the current list of istio versions running to the log for debug
  - kubectl get pods -n istio-system -l app=istiod --show-labels

- get list of all istio folders in the role in the configuration repo

- if istio-(release version) folder not there (hasnt been installed yet) then do revision install
- if istio-(canary version) folder not there (hasnt been installed yet) then do revision install

# revision install below


- set canary tag to canary version
- integration test canary
- set release to release version, if not blank

- loop on delete versions, if not matching release or canary then delete


cluster_role=$1

istio_chart_version=$(jq -er .istio_chart_version environments/$cluster_role.json)
# custom_chart_version=$(jq -er .custom_chart_version environments/$cluster_role.json)
# argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)

# perform trivy scan of chart with role configuration.
# ArgoCD Core will do the actual Helm install, this is just a pre-flight security review
# helm repo add istio https://istio-release.storage.googleapis.com/charts
# helm repo update

# pull the new version of istio to install
curl -L https://istio.io/downloadIstio | ISTIO_VERSION="$istio_chart_version" sh -



# trivyScan "istio/base" "base" "$istio_chart_version" "deploy-templates/istio-base-default-values.yaml"  just CRD

trivyScan "istio/cni" "cni" "$istio_chart_version" "deploy-templates/istio-cni-default-values.yaml"






# echo "Application resource and configuration files for crossplane"
# echo "crossplane chart version: $crossplane_chart_version"
# echo "custom aws resource chart version: $custom_chart_version"
# echo "creating deploy-files directory for all the files that will written to psk-platform-control-plane-configuration repository"
# mkdir deploy-files
# mkdir deploy-files/crossplane
# mkdir deploy-files/crossplane-aws

# # generate application.yaml for both Applications then stage the files for writing to the app-of-app config repo
# echo "generating application.yaml"
# cat <<EOF > deploy-files/crossplane/application.yaml
# ---
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: crossplane
#   namespace: $argocd_namespace
#   finalizers:
#     - resources-finalizer.argocd.argoproj.io
#   annotations:
#     argocd.argoproj.io/sync-wave: "0"
# spec:
#   project: psk-aws-control-plane-configuration

#   sources:
#     - repoURL: https://charts.crossplane.io/stable
#       chart: crossplane
#       targetRevision: $crossplane_chart_version
#       helm:
#         valueFiles:
#           - \$config/roles/$cluster_role/crossplane/default-values.yaml
#           - \$config/roles/$cluster_role/crossplane/$cluster_role-values.yaml
#     - repoURL: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
#       targetRevision: HEAD
#       ref: config
#   destination:
#     server: https://kubernetes.default.svc
#     namespace: crossplane-system
#   syncPolicy:
#     automated:
#       prune: true
#       selfHeal: true
#     syncOptions:
#       - ServerSideApply=true
#       - CreateNamespace=true
#     managedNamespaceMetadata:
#       labels:
#         app.kubernetes.io/managed-by: psk-platform-ext-crossplane
#         platform-vault: "true"
#     retry:
#       limit: 5
#       backoff:
#         duration: 30s
#         factor: 2
#         maxDuration: 5m
# EOF
# cat deploy-files/crossplane/application.yaml

# cat <<EOF > deploy-files/crossplane-aws/application.yaml
# ---
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: crossplane-aws
#   namespace: $argocd_namespace
#   finalizers:
#     - resources-finalizer.argocd.argoproj.io
#   annotations:
#     argocd.argoproj.io/sync-wave: "1"
# spec:
#   project: psk-aws-control-plane-configuration

#   sources:
#     - repoURL: https://github.com/twplatformlabs/psk-platform-ext-crossplane
#       path: chart/crossplane-aws
#       targetRevision: $custom_chart_version
#       helm:
#         valueFiles:
#           - \$config/roles/$cluster_role/crossplane-aws/aws-default-values.yaml
#           - \$config/roles/$cluster_role/crossplane-aws/aws-$cluster_role-values.yaml
#     - repoURL: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
#       targetRevision: HEAD
#       ref: config
#   destination:
#     server: https://kubernetes.default.svc
#     namespace: crossplane-system
#   syncPolicy:
#     automated:
#       prune: true
#       selfHeal: true
#     syncOptions:
#       - ServerSideApply=true
#       - SkipDryRunOnMissingResource=true
#     retry:
#       limit: 5
#       backoff:
#         duration: 30s
#         factor: 2
#         maxDuration: 5m
# EOF
# cat deploy-files/crossplane-aws/application.yaml

# echo "copying crossplane and custom aws values"
# cp -v deploy-templates/default-values.yaml deploy-files/crossplane/default-values.yaml
# cp -v deploy-templates/$cluster_role-values.yaml deploy-files/crossplane/$cluster_role-values.yaml
# cp -v deploy-templates/aws-default-values.yaml deploy-files/crossplane-aws/aws-default-values.yaml
# cp -v deploy-templates/aws-default-values.yaml deploy-files/crossplane-aws/aws-$cluster_role-values.yaml
