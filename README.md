<div align="center">
	<p>
	<img alt="Thoughtworks Logo" src="https://raw.githubusercontent.com/twplatformlabs/static/master/psk_banner.png" width=800 />
	<h2>psk-platform-ext-istio</h2>
	<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/github/license/twplatformlabs/psk-platform-ext-istio"></a> <a href="https://aws.amazon.com"><img src="https://img.shields.io/badge/-deployed-blank.svg?style=social&logo=amazon"></a>
	</p>
</div>

Following App of Apps Argo install, this pipeline performs canary release upgrades










Helm install of istio


helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

syncwave 1

helm install istio-base istio/base -n istio-system --set defaultRevision=1-28-9 --version=1.28.9    # no other values really for this



syncwave 2

helm install istio-cni istio/cni -n istio-system --version=1.28.9 --values=deploy-templates/istio-cni-default-values.yaml

syncWave 3

helm install istiod istio/istiod -n istio-system --version=1.28.9 --values=deploy-templates/istiod-default-values.yaml





helm show values <chart>
