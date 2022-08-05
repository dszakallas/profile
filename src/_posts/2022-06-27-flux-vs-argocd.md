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

Since February we have been working on adopting Kubernetes and cloud-native technologies at [Turbine.ai](https://turbine.ai) for our simulation platform. 
Part of the job entailed figuring out how to onboard developers who didn't practice DevOps before.

I've worked for couple of companies in the last 7 years. All of them have been using Kubernetes to some degree, and I am proud to add that Turbine.ai adopted it with my lead. It's been quite a journey for me 
since I first encountered the technology in 2015, not long after securing my first full time role as a software engineer at RisingStack, 
a company developing a SaaS app monitoring product at the time. Back then, the only major cloud vendor that had a managed public K8s offering was GCP (GKE). 
It was fresh and pretty much all backend engineers at our company were pretty hyped about migrating to GKE from Heroku.

I later moved on to a role more aligned with my aspiration of working on distributed data processing pipelines with Apache Spark and had little exposure to K8s for
over a year and a half. My path eventually lead back to the container orchestrator when I started working with the ML team, and deployed workflows. I recall manually installing and upgrading Apache Airflow (which was the only service I operated) with Helm, all from my development laptop. If the templates rendered the release was good to go.

Fast-forward to my next role where I operated an internal data platform that required a more mature development lifecycle. It was here I first encountered GitOps, 
as teams were using Argo CD to deploy our applications checked into source control. It felt to me a radical quality of life improvement over what I've been practicing previously. Deployment automatised from git, 
a nice GUI, alerts on failures and a unified approach for all applications instead of pile of deployment scripts; what's not to love?

At Turbine.ai, backend developers weren't generally practicing DevOps when I joined, so even a simple configuration change in a web app often involved a sysadmin in the loop. K8s can
be daunting for such newcomers, as they have to learn how to rebuild their existing applications according to principles aligned with cloud native application development practices
such as [12 factor app](https://12factor.net); learn the fundamentals of a complex cluster operating system itself, pick up new tools and infrastructure components, 
familiarize themselves with the limitations and idiosynchronicities of k8s, etc. Moreover, the [cloud native landscape]([https://landscape.cncf.io])
is vast and rapidly changing, so the best way to do X might be completely different than it was two years ago.

So, I was confident that we should do GitOps to avoid ending up with a mess, and I convinced the team that we should deliver it as part of the milestone marking k8s general availability for production.

# What is GitOps?

The term has been coined by Weaveworks with the following definition that can be found on [gitops.tech](gitops.tech):

> GitOps is a way of implementing Continuous Deployment for cloud native applications. It focuses on a developer-centric experience when operating infrastructure,
by using tools developers are already familiar with, including Git and Continuous Deployment tools. The core idea of GitOps is having a Git repository that always 
contains declarative descriptions of the infrastructure currently desired in the production environment and an automated process to make the production environment 
match the described state in the repository. If you want to deploy a new application or update an existing one, you only need to update the repository - the automated
process handles everything else. It’s like having cruise control for managing your applications in production.

Making git the single source of truth for cluster state has many benefits. Without completeness:
1. git is the industry standard for source control, everyone should use it already
2. observability and time-travel with the full change history recorded. This simplifies rollbacks and helps developers move with confidence.
3. enables modifying multiple aspects of the application in single changeset
4. simplifies the share and reuse of common configuration patterns (eg. with ordinary file editing / templating tools)
5. enables the adoption of already existing DevOps/CI practices to infrastructure, such as static validation, tests, manual approvals, automated vulnerability scans, etc

Check out gitops.tech if you would like to learn more.

# GitOps frameworks

The two mainstream open-source GitOps tools for k8s currently are Flux and Argo CD. This blogpost attempts to compare them, focusing mostly on their core features; i.e what tools they support and how they _reconcile_ (in other term _synchronize_) them.

<!--
<div class="grid">
  <div class="cell cell--5 center"><a href=""><img class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/flux-stacked-white.png"/></a></div>
  <div class="cell cell--2 center">vs</div>
  <div class="cell cell--5 center"><a href=""><img class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/argo-stacked-white.png"/></a></div>
</div>
-->

||<a href="https://fluxcd.io" ><img alt="Flux logo" class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/flux-stacked-white.png"/> </a>|<a href="https://argoproj.github.io/cd"><img alt="Argo CD logo" class="image image--md" src="/assets/2022-06-27-flux-vs-argocd/argo-stacked-white.png"/></a>|
|-|-|-|
|initial release|Flux2: v0.0.1 (Jun 25, 2020)<br>Flux (succeded): v0.1.0 (Jun 27, 2017)|v0.1.0 (Mar 18, 2018)|
|license|![License on GitHub](https://img.shields.io/github/license/fluxcd/flux?style=for-the-badge)|![License on GitHub](https://img.shields.io/github/license/argoproj/argo-cd?style=for-the-badge)|
|maturity|CNCF Incubating Project<br>LF Project<br>[CNCF End User Tech Radar Continuous Delivery, June 2020: Adopt](https://radar.cncf.io/2020-06-continuous-delivery)<br>![GitHub Repo stars](https://img.shields.io/github/stars/fluxcd/flux2?style=for-the-badge) |CNCF Incubating Project<br>LF Project<br>[CNCF End User Tech Radar DevSecOps, September 2021: Adopt](https://radar.cncf.io/2021-09-devsecops)<br>![GitHub Repo stars](https://img.shields.io/github/stars/argoproj/argo-cd?style=for-the-badge)|
|enterprise offering| [Weave GitOps Enterprise](https://www.weave.works/product/gitops-enterprise/) | [Akuity](https://akuity.io) |


Both Flux and Argo CD are immensely popular and have an active community. Flux defines itself as "a set of continuous and progressive delivery solutions for Kubernetes that are open and extensible", 
whereas Argo CD is "a declarative, GitOps continuous delivery tool for Kubernetes". There's no clear distinction in their mission statement, however they take a different approach and offer a slightly different feature set.

Argo CD is part of [Argo](https://argoproj.github.io), an umbrella project comprising of multiple productivity focused tools, and is currently incubating under the CNCF. Jesse Suen, creator of the Argo project, [told in Kubernetes Podcast #172](https://kubernetespodcast.com/episode/172-argo/) about the origins of Argo CD: "we needed to build a delivery tool for developer teams and we heavily focused on things like the user experience and the UI, and GitOps happened to be the mechanism we chose to do the delivery aspect of it". He claims that Argo CD is more developer-experience-centric, whereas Flux is more operator centric. There has been an attempt to merge the two projects, but in the end the Flux team went with a different approach which became the GitOps Toolkit (Flux2).

Flux predates Argo CD and has been around since 2017. I explore the second major version of Flux, which offers better observability, ease of integrating, composability and extensibility over the first, which is in maintanence mode. Flux 2 is comprised of GitOps Toolkit components, which are k8s operators that reconcile GitOps resources of different kinds. For example, the [source controller](https://fluxcd.io/docs/components/source/) is responsible for synchronizing source repositories, where as the helm controller is responsible for Helm releases. Argo CD is not as modular as Flux, e.g Helm support can't be removed from it.

## Reconciliation

Both platforms support automated sync (i.e reconcile the cluster state automatically after a change in GitOps) and manual sync.


Note that although I am using Kustomization in the Flux examples, the concepts should work similarly for all syncable GitOps resources.
{:.info}

### Manual sync

#### Argo CD
With Argo CD, you declaratively specify manual sync by setting `syncPolicy: {}` on the `Application` GitOps resource. This way, Argo CD will detect changes, show them on the UI, etc., but will not take action to reconcile them. Instead synchronization can be manually triggered on the web UI (which is very straightforward for beginners) or the CLI with [`argocd app sync`](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_sync/).

#### Flux
Using Flux, automatic reconciliation is the norm, but you can opt-out of it by 'suspending' the GitOps resource. This can be done declaratively by setting [`suspend: true`](https://fluxcd.io/docs/components/kustomize/kustomization/#reconciliation). 

To do manual sync on-demand on a suspended GitOps resource, set the `reconcile.fluxcd.io/requestedAt` annotation:

```shell
kubectl annotate --field-manager=flux-client-side-apply --overwrite \
kustomization/podinfo reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

It's worth noting that running `flux reconcile` against a suspended resource will __not__ trigger the reconciliation. Requiring a manual edit to the cluster state for this override was [an intentional design choice](https://github.com/fluxcd/flux2/issues/959). Essentially, on-demand, manual synchronization is an imperative action, whereas Flux wants to follow a purely declarative approach, so it doesn't wish to support this through its user interface.

Another way to trigger reconciliation is of course to temporarily `flux unsuspend` the resource. One can argue that this is an imperative action too. However, this argument is flawed as `suspend` has a declaritive setting, so the command effectively edits an in-cluster resource, similarly to e.g `kubectl scale deployment`. Which means it doesn't really violate the 'everything is declarative' principle, however it does damage auditability, since the GitOps state is overriden (until the next reconcilation).
{: .info}

### Cluster drift reconciliation (Self heal)

Cluster drift reconcilation (self heal in Argo lingo) entails resyncing the cluster state after a change outside GitOps control, e.g a manual edit with `kubectl`. This is to ensure that the cluster adheres to the declared state (eventually). Both Argo CD and Flux support this feature with caveats. 

#### Argo CD
In Argo CD, this can be turned on, but it also requires automatic sync to be [enabled](https://github.com/argoproj/argo-cd/issues/4414), and it disables rollbacks.

#### Flux
Support varies by GitOps resource kind. For Kustomizations, cluster drift is reconciled by default, and the only way to opt-out is to annotate individual resources. On the other hand, Flux does not support this feature for Helm releases at all. (We'll see more on these in the Helm section.) Flux does not distinguish by trigger cause, consequently 'self-heal' won't be carried out if the resource is ignored or the owning GitOps resource is suspended. 

### Garbage collection (pruning)

Garbage collection controls what happens to resources getting untracked in source control. Both tools take a [similar](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-pruning) [approach](https://fluxcd.io/docs/components/kustomize/kustomization/#garbage-collection), exposing a setting whether they should be deleted or kept. You can also prevent garbage collection of specific resources with an annotation ([Argo](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#no-prune-resources), [Flux](https://fluxcd.io/docs/components/kustomize/kustomization/#garbage-collection)).

### Sync windows

There are use cases when you don't want to allow an app to be updated, only during a certain maintenance window. 

#### Argo CD

Using Argo CD, this can be achieved with
[sync windows](https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/). Using sync windows, automatic or all syncs can be denied except for a certain timeframe.

#### Flux 
Flux doesn't offer this feature, although a design has already been [proposed](https://github.com/fluxcd/flux2/discussions/870). Currently, it can be achieved with a CronJob that unsuspends the resource for the duration of the maintenance window.

### Selective sync

#### Argo CD

Argo CD supports selective (or partial) syncs, i.e only selected resources get synced. Similarly to an ordinary manual sync, this can be done from the web UI or the CLI. However, selected syncs are not recorded in history and hooks are not run.

#### Flux
In Flux there's no mechanism for this, however if your only use case is to ignore certain resources during reconciliation you can label them ([Flux](https://fluxcd.io/docs/components/kustomize/kustomization/#reconciliation)). 

### Hooks

#### Argo CD
Argo CD sync behavior can be customized with [hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/). If you are familiar with [Helm hooks](https://helm.sh/docs/topics/charts_hooks/), this is the same thing in essence, e.g. allows you to deploy resources in a specific order, run a job (such as a database migration) or trigger a notification after the deployment. Argo CD also understands Helm hooks. 

#### Flux

Flux doesn't provide hooks in general, but an individual tool might provide their own, e.g Helm hooks. 


### Reconcilation comparison

||Flux|Helm|
|-|-|-|
|Automated sync|✅|✅|
|Manual sync|✅|✅|
|Cluster drift reconciliation (Self heal)|⚠️|✅|
|Garbage collection (Pruning)|✅|✅|
|Sync windows|⛔|✅|
|Selective reconciliation|⛔|✅|
|Sync hooks|⚠️ Helm support|✅|


## User interfaces
The default Argo CD installation contains a web UI. There's no web UI for Flux.

## Kustomize

[Kustomize](https://kustomize.io) is a utility for customizing application configuration in a template-free way, and is a core K8s tool shipping with `kubectl`. Both tools support Kustomize.

Argo CD relies on a [tool detection](https://argo-cd.readthedocs.io/en/stable/user-guide/tool_detection/) mechanism, 
which checks the directory contents and uses kustomize if it finds a `kustomization.yaml`, `kustomization.yml`, or `Kustomization`.

Bear in mind that tool-specific settings will override the implicit behavior, which can be surprising at first.
```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  ...
spec:
  ...
  source:
    ...

    # Tool -> plain directory
    directory:
      recurse: false
...
```
The above snippet will make Argo CD detect a plain directory even in the presence of a `kustomization.yaml`. The same applies to Helm charts.

With Flux, the kustomize-controller operator and its `kustomize.toolkit.fluxcd.io/Kustomization` CRD is used to manage applications configured with Kustomize. 

Don't mistake `kustomize.toolkit.fluxcd.io/Kustomization` for `kustomize.config.k8s.io/Kustomization`! The first one defines the GitOps resource managed by Flux's kustomize-controller, while the latter is the actual manifest used by kustomize.
{:.warning}

### Configuration
Flux supports defining strategic merge and JSON patches, overriding images and the namespaces in the `kustomize.toolkit.fluxcd.io/Kustomization` [resource](https://fluxcd.io/docs/components/kustomize/kustomization/#override-kustomize-config). Argo CD is less flexible, you have to place your edits into the overlays of your kustomization (with [a few exceptions](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/#kustomize)). This might be a problem for certain repo layouts, e.g where kustomizations of an app live in a separate repo which is owned by a different team, and adding a new kustomization there is not preferable / feasible. It's not hard to see how this will cause a bigger problem with Helm, but about that later. As an additional customization, Flux supports [variable templating and substitution](https://fluxcd.io/docs/components/kustomize/kustomization/#variable-substitution).

### Runtime dependencies

An often occuring scenario is to have an ordering between applications, e.g. you want infrastructure applications (e.g. cert-manager) deployed before any service app.
With Flux's [`dependsOn`](https://fluxcd.io/docs/components/kustomize/kustomization/#kustomization-dependencies) you can prevent an application to be synced unless its dependencies are in the Ready state. Unfortunately, this feature is [missing from Argo CD](https://github.com/argoproj/argo-cd/issues/7437).

Note that currently a Kustomization can't depend on a HelmRelease and vice versa.
{: .warning}


||Flux|Argo CD|
|-|-|-|
|Configured with CRDs|✅ [Kustomization](https://fluxcd.io/docs/components/kustomize/kustomization/)| ✅ Application, AppProject|
|Inline configuration in the GitOps resource|✅|⛔|
|Variable substitution|[✅](https://fluxcd.io/docs/components/kustomize/kustomization/#variable-substitution)|⛔|
|Automated sync|✅|✅|
|Runtime dependencies|✅|⛔|
|Manual sync|✅|✅|
|Cluster drift reconciliation (Self heal)|✅|✅|
|Garbage collection|✅|✅|

## Helm

[Helm](https://helm.sh/) is a popular package manager for Kubernetes applications.

### Transactions

A caveat of Flux is providing no support for cluster drift reconciliation (self healing) of HelmReleases. See the [issue on GitHub](https://github.com/fluxcd/helm-controller/issues/186).

### Configuration

Helm charts can be configured with [values](https://helm.sh/docs/chart_best_practices/values/).

With Flux it is possible to provide a [`values` block](https://fluxcd.io/docs/components/helm/helmreleases/#values-overrides) with the desired configuration in the `HelmRelease` resource. (Similarly to Kustomization, where you provide patches.) Additionally, the contents of the values file can come from one or more ConfigMap or Secret resource deployed in the cluster, and will be merged similarly to when you provide multiple values files to the Helm CLI.

Unfortunately, this is not possible with Argo CD. Instead, the values file should be placed in the repo of the chart (in case the source is git) or packaged with it (in case a Helm repository is used). This pattern works with bespoke applications, however quite problematic for those off the shelf. 

Helm is essentially a package manager, and it supports packaging and distributing Helm charts. Many off the shelf (OTS) charts are available for open-source projects and can be downloaded from the internet. So there's a misalignment here between Helm and Argo CD as an OTS chart cannot possibly contain the configuration for its users, which makes this mechanism useless for anything beyond reading default values. To work around this issue, one can create a wrapper that refers to the original as a chart dependency, and include the custom value files. Although this is much better than copy-pasting the entire chart, it still results in some boilerplate.

### Reconciliation
Managing Helm releases with GitOps is more complicated than using Kustomize.

There's nothing special with Argo CD here, reconcilation happens on every git revision, so changes in any values or templates will be propagated to the cluster. Self-healing is also implemented.

Flux took a different approach however. As already mentioned, Helm is a package manager, and it happens to use [SemVer](https://semver.org/). Thus, packaged Helm chart releases (those with a 3-component semver) are expected to be immutable, so the templates need not be rerendered unless a new package version is available. This is quite straightforward for versioned packages distributed in Helm repositories, but what happens when the chart is from a git source?
Under the hood, Flux packages the Helm chart contained in the git repository and makes it available for internal consumption by HelmReleases. By default, it creates a new package from source only if the chart version has changed in `Chart.yaml`. To create a new package on every git revision, the [`reconcile strategy`](https://fluxcd.io/docs/components/helm/api/#helm.toolkit.fluxcd.io/v2beta1.HelmChartTemplateSpec) should be set to `Revision`. This will configure Flux to append build metadata containing the git commit SHA to the semver, thus reflecting every commit in a new package version.

Note that this does not affect changes to configuration (e.g the `values` block), since that is part of the GitOps resource not the packaged chart.
{: .info}

### Chart dependencies

Both tools support [chart dependencies](https://helm.sh/docs/topics/charts/#chart-dependencies), which are charts too and may come
from different repositories altogether, so care must be taken to allow only trusted sources. Both platforms provide a way for limiting trust.

You [shouldn't use](https://www.weave.works/blog/profile-layering-for-helm-encourages-self-service-for-kubernetes) chart dependencies to define runtime dependencies between applications. When Helm installs the charts it renders all the chart objects, sorts all the Kubernetes objects by `Kind`, and then installs each `Kind`. This can prevent collections of charts from installing cleanly, as some charts might depend on previously installed charts with all their `Kind`s running. Ideally, chart dependencies should be used for [libraries](https://helm.sh/docs/topics/library_charts/), as a way to extract common patterns to keep your application charts [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself). 
{: .warning}

### Runtime dependencies

Similarly to Kustomize, [`dependsOn`](https://fluxcd.io/docs/components/helm/helmreleases/#helmrelease-dependencies) can be used to establish installation ordering. No support in Argo CD.


Advice against using Helm for intermediate nodes in the app tree.

||Flux|Argo CD|
|-|-|-|
|Configured with CRDs|✅ HelmRelease, HelmChart, HelmRepository| ✅ Application, AppProject|
|Cluster drift reconciliation (Self heal)|⛔|✅|
|OTS chart support|✅|⚠️ The OTS chart has to be wrapped in a local chart if you wish to override with values outside the chart|
|Upgrade chart stored in git on template change without changing chart version|✅ Using the [`Revision` reconcile strategy](https://fluxcd.io/docs/components/source/helmcharts/#artifact-example).|✅|
|Receive auto-updates from versioned charts using semver version ranges|✅|⛔|
|Helm chart dependencies|✅|✅|
|Runtime dependencies|✅|⛔|
|Replace default values.yaml with custom values.yaml(s) shipped with the chart|✅|⚠️ Only for charts hosted in git.|
|Inline values in the GitOps resource|✅|⛔ See [issue on GitHub](https://github.com/argoproj/argo-cd/issues/2789) for workarounds.|
|Helm hooks support|✅|✅|
|Rollback on failed Helm upgrade|✅|⚠️ Rollback cannot be performed against an application with automated sync enabled.|
|Apply Kustomizations to Helm releases|✅ Using [built-in PostRenderers](https://fluxcd.io/docs/components/helm/helmreleases/#post-renderers).|⚠️ Via a custom rendering plugin. See [this example](https://github.com/argoproj/argocd-example-apps/tree/master/plugins/kustomized-helm).|
  

Values file in configmap?


## Notifications

||Flux|Helm|
|-|-|-|
|Configured with CRDs|✅|⛔|
|Send notifications to Slack on GitOps lifecycle events|✅|✅|
|Templated messages|⛔|✅|
|Configure alert by lifecycle event type|⛔|✅|
|Configure alert by resource|✅|✅|


## Operations


# Summary
