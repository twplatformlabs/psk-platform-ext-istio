#!/usr/bin/env bats

# ------------------------------------- istio-dependencies
@test "default-mtls namespace exists" {
  run bash -c "kubectl get ns"
  [[ "${output}" =~ "default-mtls " ]]
}

@test "default-mtls namespace has correct labels" {
  run bash -c "kubectl get ns default-mtls --show-labels"
  [[ ! "${output}" =~ "platform-vault=true" ]]
  [[ ! "${output}" =~ "managed-by=psk-platform-ext-istio" ]]
  [[ ! "${output}" =~ "istio.io/rev: release" ]]
}

@test "default-mtls-canary namespace exists" {
  run bash -c "kubectl get ns"
  [[ "${output}" =~ "default-mtls-canary" ]]
}

@test "default-mtls-canary namespace has correct labels" {
  run bash -c "kubectl get ns default-mtls-canary --show-labels"
  [[ ! "${output}" =~ "platform-vault=true" ]]
  [[ ! "${output}" =~ "managed-by=psk-platform-ext-istio" ]]
  [[ ! "${output}" =~ "istio.io/rev: canary" ]]
}

