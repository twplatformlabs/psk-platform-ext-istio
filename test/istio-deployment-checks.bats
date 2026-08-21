#!/usr/bin/env bats

setup() {
  if [[ -z "${BASE}" ]]; then
    echo "ERROR: BASE environment variable is not set"
    exit 1
  fi
  if [[ -z "${RELEASE}" ]]; then
    echo "ERROR: RELEASE environment variable is not set"
    exit 1
  fi
  if [[ -z "${STAGED}" ]]; then
    echo "ERROR: STAGED environment variable is not set"
    exit 1
  fi
  if [[ ${BASE} == "none" ]]; then
    echo "ERROR: BASE can not equal none"
  fi
  if [[ ${RELEASE} == "none" ]]; then
    RELEASE=$BASE
    SKIP_RELEASE_TAG_CHECK=true
  fi
  if [[ ${STAGED} == "none" ]]; then
    STAGED=BASE
    SKIP_STAGED_TAG_CHECK=true
  fi
  echo "BASE $BASE"
  echo "RELEASE $RELEASE"
  echo "SKIP_RELEASE_TAG_CHECK $SKIP_RELEASE_TAG_CHECK"
  echo "SKIP_STAGED_TAG_CHECK $SKIP_STAGED_TAG_CHECK"
  echo "STAGED $STAGED"
}

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
@test "Rev: base istiod running" {
  run bash -c "kubectl -n istio-system rollout status deployment/istiod-${BASE}"
  [[ "${output}" =~ "successfully rolled out" ]]
}

@test "Rev: release istiod running" {
  run bash -c "kubectl -n istio-system rollout status deployment/istiod-${RELEASE}"
  [[ "${output}" =~ "successfully rolled out" ]]
}

@test "Rev: staged istiod running" {
  run bash -c "kubectl -n istio-system rollout status deployment/istiod-${STAGED}"
  [[ "${output}" =~ "successfully rolled out" ]]
}

# ------------------------------------- istio-ingressgateway
@test "istio-ingressgateway running" {
  run bash -c "kubectl -n istio-ingress rollout status deployment/istio-ingressgateway"
  [[ "${output}" =~ "successfully rolled out" ]]
}

@test "aws loadbalancer assigned/provisioned" {
  run bash -c "kubectl -n istio-ingress get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer}'"
  [[ "${output}" =~ "elb.amazonaws.com" ]]
}

@test "ingressgateway endpoints assigned" {
  run bash -c "kubectl -n istio-ingress get endpoints istio-ingressgateway"
  [[ "${output}" =~ "80" ]]
  [[ "${output}" =~ "443" ]]
  [[ "${output}" =~ "15021" ]]
}

# ------------------------------------- revision tags
@test "revisionTag base assigned" {
  run bash -c "kubectl get mutatingwebhookconfiguration istio-revision-tag-base -o jsonpath='{.metadata.labels.istio\.io/rev}'"
  [[ "${output}" =~ "${BASE}" ]]
}

@test "revisionTag release assigned" {
  if [ "${SKIP_RELEASE_TAG_CHECK}" = "true" ]; then
    skip "SKIP_RELEASE_TAG_CHECK is true"
  fi
  run bash -c "kubectl get mutatingwebhookconfiguration istio-revision-tag-release -o jsonpath='{.metadata.labels.istio\.io/rev}'"
  [[ "${output}" =~ "${RELEASE}" ]]
}

@test "revisionTag staged assigned" {
  if [ "${SKIP_STAGED_TAG_CHECK}" = "true" ]; then
    skip "SKIP_STAGED_TAG_CHECK is true"
  fi
  run bash -c "kubectl get mutatingwebhookconfiguration istio-revision-tag-staged -o jsonpath='{.metadata.labels.istio\.io/rev}'"
  [[ "${output}" =~ "${STAGED}" ]]
}
