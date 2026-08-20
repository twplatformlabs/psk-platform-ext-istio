#!/usr/bin/env bash
set -euo pipefail

app_of_app_repo="twplatformlabs/psk-aws-control-plane-configuration"

get_app_target_revision() {
    if [[ $# -ne 2 ]]; then
      echo "usage: get_app_target_revision <role> <app-folder>" >&2
      return 2
    fi

    local role=$1
    local app=$2
    local repo="$app_of_app_repo"
    local url="https://raw.githubusercontent.com/${repo}/main/roles/${role}/${app}/application.yaml"
    local yaml rev

    if ! yaml=$(curl -sf -H "Authorization: Bearer ${GH_TOKEN}" "$url"); then
      echo "none"
      return 0
    fi

    rev=$(printf '%s' "$yaml" | yq -r '.spec.sources[] | select(.chart != null) | .targetRevision')

    if [[ -z "$rev" || "$rev" == "null" ]]; then
      echo "none"
    else
      echo "$rev"
    fi
  }


cluster_role=$1
istio_base_version=$(jq -er .istio_base_version environments/$cluster_role.json)
istio_release_version=$(jq -er .istio_release_version environments/$cluster_role.json)
istio_staged_version=$(jq -er .istio_staged_version environments/$cluster_role.json)
echo "Starting Revision release of:"
echo "base: $istio_base_version"
echo "release: $istio_release_version"
echo "staged: $istio_staged_version" && echo

argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_role.json)
configuration_repo_url="https://github.com/twplatformlabs/psk-aws-control-plane-configuration/tree/main/roles"
role_search_url="$configuration_repo_url/$cluster_role"

installed_base=$(get_app_target_revision sandbox istio-base)
installed_release=$(get_app_target_revision sandbox istio-release)
installed_staged=$(get_app_target_revision sandbox istio-staged)

# Used when debugging script logic testing
# installed_base=1.29.3
# installed_staged=1.29.3
# installed_release=1.29.0

echo "Currently deployed versions:"
echo "base: $installed_base"
echo "release: $installed_release"
echo "staged: $installed_staged" && echo

if [[ ("$istio_base_version" != "$istio_release_version") && ("$istio_base_version" != "$istio_staged_version") ]]; then
    echo "FAIL: base ≠ release || staged"
    echo "The desired deployment version for base MUST equal the either release or staged desired versions."
    exit 1
fi

if [[ ("$istio_base_version" == "$istio_release_version") && ("$istio_base_version" != "$istio_staged_version") ]]; then
    echo "base = release && base != staged"
    if [[ "$installed_release" == "$istio_release_version" ]]; then
        echo "installed release = release"
        echo "FAIL: istio_base_version and istio_release_version are not equal to istio_staged_version,"
        echo "and the currently deployed release version does match istio_base_version. This"
        echo "indicates a ROLLBACK is desired. Rollbacks are performed by"
        echo "setting istio_base_version = istio_release_version = istio_staged_version where"
        echo "istio_base_version and istio_staged_version were previously deployed as new versions"
        exit 1
    else
        echo "FAIL: the currently installed release version does not match istio_release_version."
        echo "This indicates an attempt to install and release a version of istio at the same time."
        echo "All versions must first be staged and testing before being set as release."
        exit 1
    fi
fi

if [[ ("$istio_base_version" == "$istio_release_version") && ("$istio_base_version" == "$istio_staged_version") ]]; then
      echo "base = release = stage"
    if [[ ("$installed_release" == "$istio_release_version") && ("$installed_release" != "$installed_base") && ("$installed_release" != "$installed_staged") ]]; then
        echo "installed release = release && installed release ≠ installed base && installed release ≠ installed stage"
        echo "Begin completion of rollback to version $istio_release_version"
    elif [[ ("$installed_release" != "$istio_release_version") && ("$installed_base" == "$istio_base_version") && ("$installed_staged" == "$istio_staged_version")]]; then
        echo "installed release ≠ release, installed base = base, installed staged = staged"
        echo "Begin completion of upgrade of release version $installed_release to $istio_release_version"
    else
        echo "FAIL: unexpected version combination. Likely indicates an attempt to install and"
        echo "release a version of istio at the same time. All versions must be staged and"
        echo "tested before being set as release"
        exit 1
    fi
fi

if [[ ("$istio_base_version" != "$istio_release_version") && ("$istio_base_version" == "$istio_staged_version") ]]; then
    echo "Stage istio version $istio_staged_version for testing."
fi

# generate_istio_base
# bash scripts/generate_istio_base_application.sh $cluster_role # perform both base and CNI as they are always the same version
# Set default revision to base version.

# # generate_istiod and _ingressgateway --staged revision
# bash scripts/generate_istio_application.sh $cluster_role staged   # perform both istiod and ingressgatewat as they are same version

# # generate_istiod and _ingressgateway --release revision
# bash scripts/generate_istio_application.sh $cluster_role release  # perform both istiod and ingressgatewat as they are same version


# set_revisionTag staged on --revision=STAGED_VERSION_STRING
# set_revisionTag release on --revision=RELEASE_VERSION_STRING
