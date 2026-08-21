#!/usr/bin/env bats

# ------------------------------------- istio-dependencies
@test "default-mtls namespace exists" {
  run bash -c "kubectl get ns"
  [[ "${output}" =~ "default-mtls" ]]
}

@test "default-mtls namespace has correct labels" {
  run bash -c "kubectl get ns default-mtls --show-labels"
  [[ "${output}" =~ "platform-vault=true" ]]
  [[ "${output}" =~ "istio.io/rev=release" ]]
}

@test "default-mtls-staged namespace exists" {
  run bash -c "kubectl get ns"
  [[ "${output}" =~ "default-mtls-staged" ]]
}

@test "default-mtls-staged namespace has correct labels" {
  run bash -c "kubectl get ns default-mtls-staged --show-labels"
  [[ "${output}" =~ "platform-vault=true" ]]
  [[ "${output}" =~ "istio.io/rev=staged" ]]
}

# ------------------------------------- istio base components
@test "istio CRDs deployed" {
  run bash -c "kubectl get crd | grep istio"
  [[ "${output}" =~ "authorizationpolicies.security.istio.io" ]]
  [[ "${output}" =~ "destinationrules.networking.istio.io" ]]
  [[ "${output}" =~ "envoyfilters.networking.istio.io" ]]
  [[ "${output}" =~ "gateways.networking.istio.io" ]]
  [[ "${output}" =~ "peerauthentications.security.istio.io" ]]
  [[ "${output}" =~ "proxyconfigs.networking.istio.io" ]]
  [[ "${output}" =~ "requestauthentications.security.istio.io" ]]
  [[ "${output}" =~ "serviceentries.networking.istio.io" ]]
  [[ "${output}" =~ "sidecars.networking.istio.io" ]]
  [[ "${output}" =~ "telemetries.telemetry.istio.io" ]]
  [[ "${output}" =~ "virtualservices.networking.istio.io" ]]
  [[ "${output}" =~ "wasmplugins.extensions.istio.io" ]]
  [[ "${output}" =~ "workloadentries.networking.istio.io" ]]
  [[ "${output}" =~ "workloadgroups.networking.istio.io" ]]
}

@test "cni daemonset running" {
  run bash -c "kubectl -n istio-system rollout status daemonset/istio-cni-node"
  [[ "${output}" =~ "successfully rolled out" ]]
}

  # ------------------------------------- istiod

  # ------------------------------------- istio-ingressgateway

  # ------------------------------------- revision tags