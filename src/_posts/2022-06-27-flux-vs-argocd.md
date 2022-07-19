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



<!--
intro:
- how to create cloud native apps
- how to learn advanced features such as pod disruptions
- abundance of tooling
-->

Lately I've been working on establishing cloud-native practice at [Turbine.ai](https://turbine.ai). Part of the job entailed figuring out
a way to do continuous delivery that offers a smooth ramp up for developers coming from a practice oblivious to DevOps.

K8s can be daunting for such newcomers. Not only you have to get acquinted with the principles and the architecture of K8s 
in order to understand the fundamental building blocks it offers; you have to learn how to rebuild you existing applications 
using these blocks and familiarize yourself with the limitations and any idiosynchronicities they have. The [landscape of cloud native tech]([https://landscape.cncf.io]) 
is vast and rapidly changing, so the best way to do X might be completely different than it was two years ago.

<!-- There's a gap here -->

All the companies I've worked for in the last 5 years have been using or evaluating Kubernetes, and I am proud to add that Turbine.ai, the last of that list, did so under my lead. 
It's been quite a journey since I first encountered the technology in 2015, not long after securing my first full time role as a software engineer at RisingStack, 
a company developing a SaaS app monitoring product at the time. Back then, the only cloud vendor that had a managed K8s offering was GCP (GKE). 
It was fresh and since we were already using GCP, pretty much all backend engineers at our company were pretty hyped 
about moving our backend to GKE. I didn't care that much as my mind was completely set on doing distributed data processing with Apache Spark. 
Nevertheless I had my introduction to K8s.

I later moved on to a role were I could better fulfill my datalaking (sic) aspirations, and had little to no exposure to K8s for
over a year and a half. Then, I started working with Apache Airflow, both as user and operator, thus the winding path led me back to 
the container orchestrator. I recall manually installing and upgrading Airflow with Helm, the single application I operated.
I did all of these directly from my development laptop. If the templates rendered it was good to go. Ahh, those were the days!

Fast forward to my next role where I joined a way more mature K8s development lifecycle. There, the teams used ArgoCD to deploy to multiple clusters,
and where I first encountered the GitOps term. I felt that using ArgoCD was a radical quality of life improvement: no manual deployment operations, 
a nice GUI, alerts on failures and a unified approach for all applications instead of pile of deployment scripts; what's not to love?

> GitOps is a way of implementing Continuous Deployment for cloud native applications. It focuses on a developer-centric experience when operating infrastructure,
by using tools developers are already familiar with, including Git and Continuous Deployment tools. The core idea of GitOps is having a Git repository that always 
contains declarative descriptions of the infrastructure currently desired in the production environment and an automated process to make the production environment 
match the described state in the repository. If you want to deploy a new application or update an existing one, you only need to update the repository - the automated
process handles everything else. It’s like having cruise control for managing your applications in production. -- Definition of GitOps from [gitops.tech](gitops.tech)

I was determined that GitOps is essential; that we need to have it before on-boarding developers or we risk ending up in a mess with
ad-hoc manual installations and frustratingly error-prone CD scripts.

<!-- More reasons -->


There are two popular GitOps frameworks: Flux and ArgoCD.

<div class="grid">
  <div class="cell cell--5 center"><img class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/flux-stacked-white.png"/></div>
  <div class="cell cell--2 center">vs</div>
  <div class="cell cell--5 center"><img class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/argo-stacked-white.png"/></div>
</div>

Flux is a set of continuous and progressive delivery solutions for Kubernetes that are open and extensible.

||[Flux2](https://landscape.cncf.io/?selected=flux)|[ArgoCD](https://landscape.cncf.io/?selected=argo)|
|-|-|-|
|initial release|Flux2: v0.0.1 (Jun 25, 2020)<br>Flux (succeded): v0.1.0 (Jun 27, 2017)|v0.1.0 (Mar 18, 2018)|
|license|![License on GitHub](https://img.shields.io/github/license/fluxcd/flux?style=for-the-badge)|![License on GitHub](https://img.shields.io/github/license/argoproj/argo-cd?style=for-the-badge)|
|maturity|CNCF Incubating Project<br>LF Project<br>[CNCF End User Tech Radar Continuous Delivery, June 2020: Adopt](https://radar.cncf.io/2020-06-continuous-delivery)<br>![GitHub Repo stars](https://img.shields.io/github/stars/fluxcd/flux2?style=for-the-badge) |CNCF Incubating Project<br>LF Project<br>[CNCF End User Tech Radar DevSecOps, September 2021: Adopt](https://radar.cncf.io/2021-09-devsecops)<br>![GitHub Repo stars](https://img.shields.io/github/stars/argoproj/argo-cd?style=for-the-badge)|
|enterprise support| ? | [Akuity](https://akuity.io) - managed offering |


Both Flux and ArgoCD are widely popular and have an active community. Flux defines itself as "a set of continuous and progressive delivery solutions for Kubernetes that are open and extensible", 
whereas ArgoCD is " a declarative, GitOps continuous delivery tool for Kubernetes". There's no real distinction between their goals. Both tools incubate under the CNCF.

<!-- Insert Flux CD trivia -->

ArgoCD is...

<!-- Insert ArgoCD trivia -->

ArgoCD is part of [Argo](https://argoproj.github.io), an umbrella project comprising of multiple productivity focused tools, which is incubating under the CNCF. 


# Kustomize support

Kustomize is a popular tool for declaring resource manifests and applying patches on them in a hierarchical manner. It is a core K8s utility governed by SIG CLI and bundled with `kubectl`. Both GitOps toolkits support Kustomize. For Flux, the `kustomize.toolkit.fluxcd.io/Kustomization` CRD defines an application installed with Kustomize.

`kustomize.toolkit.fluxcd.io/Kustomization` and `kustomize.config.k8s.io/Kustomization` are different resources despite their identical resource name. The first one defines a Kustomization for Flux to be deployed and reconciled, while the latter is the actual Kustomize manifest (kustomization).
{:.warning}



One downside of ArgoCD comes from the lack of support for inline resource configuration. You can define patches, image overrides and apply variable substitution in the `kustomize.toolkit.fluxcd.io/Kustomization` [resource](https://fluxcd.io/docs/components/kustomize/kustomization/#override-kustomize-config), when using Flux. With ArgoCD however, you have to place virtually all your edits into overlays (with [some exceptions](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/#kustomize)) alongside the application.


||Flux|Helm|
|-|-|-|
|Configured with CRDs|✅ Kustomization| ✅ Application|
|Reconcile cluster drift automatically|✅|✅ Referred to as [Automatic Self-Healing](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-self-healing)|
|Automated sync|✅|✅|
|Inline Kustomization patches in the GitOps resource|✅|⛔|


Patches in configmap?



# Helm support

Managing Helm releases with GitOps is obviously more complicated than using Kustomize.



Helm dependencies must be declared as HelmCharts or HelmRepositories before they can be installed.
Helm dependencies must be allowed in the Project before they can be installed.



||Flux|Helm|
|-|-|-|
|Configured with CRDs|✅ HelmRelease, HelmChart, HelmRepository| ✅ Application|
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
