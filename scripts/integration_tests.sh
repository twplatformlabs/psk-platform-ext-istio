set -euo pipefail

cluster=$1
cluster_role=$2


# run basic smoketest for istio health
bats test/istio-deployment-checks.bats
