set -euo pipefail

cluster_name=$1
cluster_role=$2
istio_base_version=$(jq -er .istio_base_version environments/$cluster_role.json)
istio_release_version=$(jq -er .istio_release_version environments/$cluster_role.json)
istio_staged_version=$(jq -er .istio_staged_version environments/$cluster_role.json)
base_revision=$(echo "${istio_base_version}" | tr '.' '-')
release_revision=$(echo "${istio_release_version}" | tr '.' '-')
staged_revision=$(echo "${istio_staged_version}" | tr '.' '-')

echo "smoke test $cluster_name for istio $cluster_role configuration"
echo "BASE_REV: $base_revision"
echo "RELEASE_REV: $release_revision"
echo "STAGED_REV: $staged_revision"

# run basic smoketest for istio health
BASE=$base_revision RELEASE=$release_revision STAGED=$staged_revision bats test/istio-deployment-checks.bats
