#!/usr/bin/env bats

# ------------------------------------- istio-dependencies
@test "default-mtls namespace exists" {
  run bash -c "kubectl get ns"
  [[ "${output}" =~ "default-mtls " ]]
}

@test "default-mtls namespace has correct labels" {
  run bash -c "kubectl get ns default-mtls --show-labels"
  [[ "${output}" =~ "platform-vault=true" ]]
  [[ "${output}" =~ "managed-by=psk-platform-ext-istio" ]]
  [[ "${output}" =~ "istio.io/rev=release" ]]
}

@test "default-mtls-staged namespace exists" {
  run bash -c "kubectl get ns"
  [[ "${output}" =~ "default-mtls-staged" ]]
}

@test "default-mtls-staged namespace has correct labels" {
  run bash -c "kubectl get ns default-mtls-staged --show-labels"
  [[ "${output}" =~ "platform-vault=true" ]]
  [[ "${output}" =~ "managed-by=psk-platform-ext-istio" ]]
  [[ "${output}" =~ "istio.io/rev=staged" ]]
}

