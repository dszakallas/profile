---
layout: article
title: "Comparison: Flux vs ArgoCD" 
key: 2022-06-27-flux-vs-argocd
tags:
  - Flux
  - ArgoCD
  - DevOps
  - GitOps
  - Kubernetes
---


Recently, I've been on-boarding Turbine.ai to Kubernetes, and chose a GitOps framework as part of that effort.
The benefits of utilizing GitOps are well-known and numerous. [Insert benefits]

There are two main competitors in this space: Flux and ArgoCD.

<div class="grid">
  <div class="cell cell--5 center"><img class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/flux-stacked-white.png"/></div>
  <div class="cell cell--2 center">vs</div>
  <div class="cell cell--5 center"><img class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/argo-stacked-white.png"/></div>
</div>

Flux is...

ArgoCD is...

# Kustomize support

||Flux|Helm|
|-|-|-|
|Configured with CRDs|✅ Kustomization, GitRepository| ✅ Application, AppProject|
|Reconcile cluster drift automatically|✅|✅ Referred to as [Automatic Self-Healing](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-self-healing)|
|Automated sync|✅|✅|
|Inline Kustomization patches in the GitOps resource|✅|⛔|


Patches in configmap?



# Helm support

Managing Helm releases with GitOps is a bit more complicated than using Kustomize.



Helm dependencies must be declared as HelmCharts or HelmRepositories before they can be installed.
Helm dependencies must be allowed in the Project before they can be installed.



||Flux|Helm|
|-|-|-|
|Configured with CRDs|✅ HelmRelease, HelmChart, HelmRepository, GitRepository| ✅ Application, AppProject|
|Reconcile cluster drift automatically|⛔ Unsupported for HelmReleases currently. See [issue on GitHub](https://github.com/fluxcd/helm-controller/issues/186)|✅ Referred to as [Automatic Self-Healing](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-self-healing)|
|Chart can be installed directly from chart repository source|✅|⚠️ Yes, but the OTS chart has to be wrapped in an umbrella chart if you wish to override with values outside the chart|
|Upgrade chart stored in git on template change without changing chart version|✅ Using the [`Revision` reconcile strategy](https://fluxcd.io/docs/components/source/helmcharts/#artifact-example).|✅|
|Receive auto-updates from versioned charts using semver version ranges|✅|⛔|
|Install helm chart dependencies|✅|✅|
|Replace default values.yaml with custom values.yaml(s) shipped with the chart|✅|⚠️ Only for charts hosted in git.|
|Inline values in the GitOps resource|✅| See [issue on GitHub](https://github.com/argoproj/argo-cd/issues/2789) for workarounds.|
|Helm hooks support|✅|✅|
|Rollback on failed Helm upgrade|✅|⚠️ Rollback cannot be performed against an application with automated sync enabled.|
|Apply Kustomizations to Helm releases|✅ Using [built-in PostRenderers](https://fluxcd.io/docs/components/helm/helmreleases/#post-renderers).|⚠️ Via a custom rendering plugin. See [this example](https://github.com/argoproj/argocd-example-apps/tree/master/plugins/kustomized-helm).|
  

Diffing customizations
 
Values file in configmap?

# Other tooling

Gotcha ArgoCD: tool detection is implicit https://argo-cd.readthedocs.io/en/release-1.8/user-guide/tool_detection/


# Notifications

||Flux|Helm|
|-|-|-|
|Configured with CRDs|✅|⛔|
|Send notifications to Slack on GitOps lifecycle events|✅|✅|
|Templated messages|⛔|✅|
|Configure alert by lifecycle event type|⛔|✅|
|Configure alert by resource|✅|✅|


# Operations


# 
