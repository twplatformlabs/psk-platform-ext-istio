## Revision release flow for sidecar-proxy installation

The Revision release pattern is a mechanism for performing a simple Canary release of a new Istio version.  

Generally, with any version of Istio installed, a namespace is included into the mesh by setting a namespace label of:
```yaml
  labels:
    istio.-injection: enabled
    ...
```
However, Istio supports an alternative naming scheme whereby a namespace can be labeled with a `revision` tag instead:
```yaml
  labels:
    istio.io/rev: release
    ...
```
When installing Istio, both a `version` and a `revision` are defined. For example, if Istio version 1.29.3 were deployed with the revision of `1-29-3` and istio version 1.30.0 is also deployed with a revision of `1-30-0` then you would see the following istiod instances running:  
```bash
NAME                                 READY   STATUS    RESTARTS   AGE   REV
  istiod-1-29-3-5649c48ddc-dlkh8     1/1     Running   0          71m   1-29-3
  istiod-1-30-0-9cc9fd96f-jpc7n      1/1     Running   0          34m   1-30-0
``` 
At this point, to have version 1.29.3 be applied to namespaces with the `release` revision label, you would set a revision Tag `release` to version 1.29.3. (_Though referred to as "Tags", these are not metadata added to the Revision installation but are stand-alone cluster definitions. A Tag is only every associated with a single revisioned install._)  

If we set a revision Tag of `staged` to revision 1-30.0, then a namespace with the label `staged` would be using the version 1.30.0 of Istio. We could then perform any validation tests to whether the new version would cause an issues. Once we were satisfied that new version will not break anything, we set the `release` tag to point to 1-30-0 and now all namespaces with  that rev label are using the new version.  

In order to fully pick up the new version, everything running in the namespace needs to get restarted.  

Before staging a new istio version for testing, Run `istioctl VERSION precheck` for confirmation the upgrade can proceed.  

### How does this pipeline manage a Canary release?

Within a PSK cluster, all namespaces intended for mesh capabilities will have the following label, indicating that anything deployed within the namespace will have an Istio proxy sidecar (managed by istio policies):  
```yaml
  labels:
    istio.io/rev: release   # indicating this nameing space will always be on the revision of istio with the "release" tag
    ...
```

There will also be one namespace created for performing new version testing of a staged upgrade version of istio.  
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: default-mtls-stage   # test namespace for the pending "stage" revision
  labels:
    istio.io/rev: stage
    platform-vault: "true"
    pod-security.kubernetes.io/enforce: baseline
```

In the environments folder settings, there are 3 versiom settings to maintain:  
{
  "istio_base_version": "",
  "istio_release_version": "",
  "istio_stage_version": "",
  ...
}

There are four components within the primary istio deployment:

* Istio Base
* Istio CNI
* Istio Discovery (istiod)
* Istio Gateway

**Istio Base** is the CRDs defining the baseline istio schema and actions.  
**Istio CNI** is a privileged service that maintains the proxy routing changes.  
**Istio Discovery** is the actual Istio extension application.  
**Istio Gateway** is the Istio managed LB controller and optional ingress routing controller.  

The **Base* amd **CNI** deployments do not have a `Revision` setting. These are more traditional deployments where there is only a single version deployed at a time. They are also guaranteed to always be backwards compatible for several versions.  

**gateways** will be treated similar to Base and CNI by this pipelines. They do support their own revision release process. But there are additional steps involved when using this approach as the external LB will be now directing traffic to both Envoy ingressgateway  proxies and you have to use specific routing rules to creating the testing scenary for which this is intended. Therefore it is quite common for this to be treated like Base of CNI where you do in-place upgrade and then rollback where issues are found (hence the importance of non-production testing environments). This is the approach used here.  

**istiod** is deployed as a Revision, and Tags defined will control which version a namespace is using.  

In our environment state, we track the _base_ value (used for _base_, _cni_, and _ingressgateway_) separately. The deployment will simply install which ever version we set for these applications.  

The basic flow is that, with each new version of istio adopted, _base_ and _staged_ are first set to this new version and then integration testing is performed within the default-mtls-staged namespace. Once we are satisfied with the health of the new version, then _release_ is also set to the new version and the upgrade is complete - apart from the required rolling restart.  

Should there be problems with the staged release, the deployment can remain in this "staged" condition while we work out the issues. The _base_ installation is reasonably assured to not be the source of the issue. Typically, once the problem is understood, either there is a configuration adjustment to the staged version or (more often) deprecated configurations of application using Istio are correct and then the upgrade can continue. Should we want to "rollback" and remain at the prior version for an extended time, set _base_ and _staged_ back to the _release_ version to effect a rollback of the _base_ and _cni_ applications.   

Keeping this flow expectation in mind, we will use the _base_ version to guide the flow. _Base_ defines the direction we moving and there are four comparison outcomes possible relative to _release_ and _staged_.  

|      | release | staged | result |
|------|:-------:|:------:|-------
| base |    ≠    |    ≠   | base must always match either release or staged, this is an error - FAIL |
| base |    =    |    ≠   | if base is moving backwards, this suggests a rollback. But we require that all three values match to indicate this. This is an error, warn with the rollback requirements and FAIL |
| base |    =    |    =   | indicates either completion of a successful upgrade or finalized rollback. Check first that base already matches this version (which it must in both these success conditions). If not, that means an attempt to both install and release the version at the same time. A new version must be staged first, even if this is a greenfield install. This is an error - FAIL. Else - SUCCESS |
| base |    ≠    |    =   | Indicates the normal upgrade flow of staging a new version for testing. Check first that the upgrade version is not more than two minor versions ahead. If so, this is against Istio guideance - FAIL. Else - SUCCESS | 

After performing the above checks, then the standard revision deployment action is to:  
* Deploy **Base**, **CNI**, and **IngressGateways** at the base_version
* Deploy --revisioned **Istiod** at the staged_version^†
* Deploy --revisioned **Istiod** at the release_version
* Set the RevisionTag on the stage revision deployment to "staged"
* Set the RevisionTag on the release revision deployment to "release"

^These --revisioned deployments are idempotent. The pipeline should always be able to successful complete whether there is an ongoing upgrade happening or not. When a new staged version is deployed, that is an actual new install of a new version of istio. A _deployment_ of the release version is expected to always be just the idempotent check of a helm install where the version already exists since a prior staged deployment is how all new versions are installed. The full test and release pipeline, across all cluster roles could be run every night as a form of configuration self-correction, or just the integration tests for the specified versions.  

†Always use `istiocel "version" precheck` in the sandbox environment before proceeding with the install.  

## pipeline steps:

The canary release process is the pipeline process. The istio_revision_deployment.sh script manages this each pipelin run whther any upgrade activity is happening or not. It is the manipulation of the base, staged, and release versions that manages change when desired.  

The revisino deployment script first analyzes the versions provided to confirm they adhere to the expectations of the flow.  

### Version Error Checks

1. get list of installed versions (what does the argocd app-of-apps folder currently show as base, release, and staged versions)

    installed_base  
    installed_release  
    installed_staged

2. If base ≠ release || stage - FAIL

    Base must be equal to either stage or release.

3. If base = release && base ≠ stage - FAIL

  a. if installed_release = release_version, this indicates a rollback, but rollback must be performed by setting all 3 values the same.  
    
  b. If installed_release ≠ release_version, this indicates an attempt to install and release a version all at once - must first stage a version of istio before releasing - even in greenfield setting.  

4. if base = release && stage - indicates either successful upgrade completiong or full rollback.

  a. If release_version = install_release && release_version ≠ installed_base && installed_stage - this is a full rollback - SUCCESS.  
    
  b. If release_version ≠ installed_release && stage_version = installed_base && base_version && installed_staged, this indicates a completed upgrade - SUCCESS.  
    
  c. Else, an error, probably an attempt to deploy and set release version at same time. Indicate staging is required - FAIL.  

5. if base ≠ release && base = staged - indicates the normal first step in canary release - SUCCESS.

### If SUCCESS in evaluation of desired versions

Assuming none of the above checks results is a failure the the following deployment can occur, the same events, regardless of versions specified that meet the requirements, and it is idempotent. Each of the steps modified, as needed, the contents of the Argo app-of-apps role configuration in psk-aws-control-plane-configuration.  

1. Generate istio_base and istio_cni Application defintions at the istio_base_version value
```
role/
│
├── istio-base     # the base install also sets defaultRevision to BASE_REVISION_STRING^
├── istio-cni
```
2. Generate istio_discovery and istio_gateway Application definitions, istio_staged_version first, then istio_release_version
```
role/
│
├── istio-staged
├── istio-release
```
2. Generate an ingressgateway Application definition at istio_base_revision
```
role/
│
├── istio-ingressgateway
```
3. Generate revision tags using local revision charts

Set --revisionTags=`staged` on --revision=STAGED_VERSION_STRING
Set --revisionTags=`release` on --revision=RELEASE_VERSION_STRING
```
role/
│
├── istio-staged-revision
├── istio-release-revision
```
4. **Testing**

At this point:
* all namespaces with the label `istio.io/rev: staged` will use istio-STAGED_VERSION_STRING  
* all namespaces with the label `istio.io/rev: release` will use istio-RELEASE_VERSION_STRING  

Deploy testing application to default-mtls-staged perform health check

Deploy testing application to default-mtls perform health check

^VERSION_STRINGS mean subtitute "_" for "." as in 1.29.3 = 1-29-3 in revision name  

## Additional Maintenance

The "Revision" template in the istio-revision-* charts folders, is created via a specific template resource in the isito-discovery chart:  

example:  
```
helm template istiod istio/istiod -s templates/revision-tags-mwc.yaml --version (the same version in the revision) --set revisionTags="{default}" --set revision=$base_revision -n istio-system 
```

This is a "slow to change" resource within istiod, but still, the practical issue is that the structure of the "template" that used to create the helm deploy to "set" a revision to a version is fixed to the structure of the version of istiod that was used to create this template. So we can't indefinitely ignore doing some recurring checks against the template contents we have and the template resulting from a "current version" of istiod.

A TODO would be to add "CI" style check that always get the latest sementic release from Istio and compare the resource generated by that versino of istiod with our template so at least we get an earlier alert.  