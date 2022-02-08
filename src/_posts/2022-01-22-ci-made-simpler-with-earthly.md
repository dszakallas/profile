---
layout: article
title: CI made simpler with Earthly
key: 2022-01-22-ci-made-simpler-with-earthly
tags:
  - Earthly
  - BuildKit
  - Docker
  - DevOps
---

## Motivation

Building applications in containers has well-known benefits. Encapsulating the whole build environment in a container removes the possibly lenghty and hardly reproducible process of setting up the build environment; while the smart use of build stages and layers opens up
 opportunities for [caching and parallelism](https://www.gasparevitta.com/posts/advanced-docker-multistage-parallel-build-buildkit/). For builds
that consist of several long-running steps, incremental builds become unavoidable. Extending containerization to all CI jobs can simplify CI configuration and can lead to more portable builds, while enjoying the caching opportunities BuildKit provides.

Currently however, containerized builds are mainly used for the purpose of packaging the application for deployment, which is only a part of an ordinary CI workflow; tests, static checks, and other 
development related tasks are often left uncontainerized; build processes are often complicated by the use of different tools when executed on the developer's machine or CI; and rely on CI platform features for efficient caching. This post shows how a platform-independent unified build system called Earthly can improve upon this situation.

## Build on every platform

> There are only two hard things in Computer Science: cache invalidation and naming things.
>
> -- [Phil Karthon (?)](https://www.martinfowler.com/bliki/TwoHardThings.html)

Differences between the CI and the developer's local environment can lead to unreproducible builds, and the "works on my machine" effect. Modern CI runners can utilize containers, however locally running these steps can be a chore. You can use CI specific helpers (e.g there's a tool called [act](https://github.com/nektos/act) which can be used to simulate GitHub Action Workflows locally), however using a platform specific solution feels a desperate attempt at curbing complexity. The puritan engineer would rather opt for a thin shell (or `make`, `npm` script, etc.) wrapper around each CI job, so that it's a single script command invocation both in the CI config file as well as running locally in container with `docker run`. However this approach is oblivious to some important aspects of your CI build. First, although usually not a problem when running locally, caching needs to be taken into account when using containers either by smart use of layers (placing everything in opaque scripts limits this), or externalizing caches by mounting them as volumes (which complicates configuration). Moreover, it is desirable to run whole workflows locally, not just individual steps.

Earthly is a [BuildKit](https://github.com/moby/buildkit) frontend whose syntax is based on Dockerfiles and comes with syntactical and feature extensions tailored to containerized incremental builds. This comes with two important benefits: for once, there is little to learn for existing users of `docker buildx`; twice, if you already use BuildKit during CI/CD to build the production images of your app, chances you can introduce Earthly without additional architectural requirements. It is packaged as a single statically-linked binary, and it depends on the docker daemon for running containers. Furthermore it
- eliminates the need to use the CI-specific caching system, which can reduce the complexity of the build. If you are happy with how layer based caching works when building the application image during CI, likely you will be happy with it during other steps. For more advanced users, volume based caching is also available. 
- makes your CI config file thinner, thus your jobs easier to run locally; and should the need arise, easier to port to a different CI framework.
- is approachable, easy to learn, and based on widely used tech. 

I am not aiming to give a tutorial on Earthly in this post, you should check out their official [Getting Started guide](https://docs.earthly.dev/basics) for that. Instead, I will showcase its strengths in contrast to using CI framework native tooling only (GitLab and GitHub) for containerized builds through two case studies. 

## Gems and yarn won't cause any harm 

Modern package managers give a unified and easy process of managing library dependencies. 
They output a lock file as a complete and canonical representation 
of all installed dependencies which conform to semantic requirements
and produce a working bundle. In this case, the cryptographic hash of the lock file
can serve as the cache key for the dependencies.
Keyed caches are a common feature of modern CI runners, e.g the following GitLab CI job uses a separate cache
for its Ruby gem and Node package dependencies, which have to be installed before running any of the tests: 

```yaml
test-job:
  stage: build
  cache:
    - key:
        files:
          - Gemfile.lock
      paths:
        - vendor/ruby
    - key:
        files:
          - yarn.lock
      paths:
        - node_modules
  script:
    - bundle config path vendor
    - bundle install
    - yarn install
    - echo Run tests...
```
During the first run of this job, the cache is empty, so dependencies have to be downloaded and installed. Then, at the end of the job, the cache is saved. Consecutive runs with unchanged lock files will reuse this cache, so that the first two steps of the job are effectively skipped.

A downside of this approach is that caching is now part of the CI runner's configuration, 
so you cannot use it locally (with Docker) as is. It also leaks some info about your build which can lead to configuration drift. (What if the build steps are extracted to a shell script and someone changes the yarn cache folder in the script, but forgets to update the CI config?) Furthermore, the cache key is not implied by the build definition, requiring additional effort from the engineer to make the connection. Most importantly though,
this sort of caching works solely because the respective tools (`bundle` and `yarn`) are written to work this way, i.e. they are able to detect that all
dependencies have been installed already and skip the time consuming process of downloading, building and installing them.

In Earthly we can model the build the following way:

```
VERSION 0.6

FROM node:17
RUN apt-get update -yq \
    && apt-get install -yq --no-install-recommends ruby-full \
    && gem install bundler \
    && bundle config path vendor
WORKDIR /workspace

ruby-deps:
  COPY Gemfile Gemfile.lock .
  RUN bundle install
  SAVE ARTIFACT vendor/ruby vendor/ruby

node-deps:
  COPY package.json yarn.lock .
  RUN yarn install
  SAVE ARTIFACT node_modules

tests:
  COPY +ruby-deps/vendor/ruby vendor/ruby
  COPY +node-deps/node_modules node_modules
  RUN echo Run tests...
```

Here, the final layer that makes up the `ruby-deps` target has to be recreated if `Gemfile` or `Gemfile.lock` changes, 
keying the cache with the files that are required for `bundle install`. The same applies for `node-deps`. The `tests` target depends on both of them, so it gets recomputed 
if any of them changes. This approach would work even if the tools didn't support caching, because the whole `RUN` step is skipped. This will become important in the next case study.

With caching now part of the Earthly build description, `.gitlab-ci.yml` becomes very simple.

```yaml
test-job:
  stage: build
  image: earthly/earthly:v0.6.2
  script:
    - earthly +test
```

Our dependencies have to installed from scratch if the dependency descriptor files change which ensures the build's integrity. However, let's assume one of the node packages has to be built 
from source and it takes 15 minutes. We have to rebuild this dependency even in case of an unrelated change in the `package.json` file. We can resolve this by using
a shared cache for our packages. As Yarn stores every package in a global cache on the file system, by saving this directory as a cache volume, it can be reused in later builds. 

```
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn yarn install
```

Although this approach works for many situations, it also has some possible downsides. The cache will grow and become bloated over time. Also, platform-dependent libraries
may break on another system and the dependency manager might not be smart enough to handle such cases (my knowledge on Yarn is limited). This means, cache mounts should be used with care and knowledge of 
the build tool. To minimize such edge cases, Earthly only [shares cache mounts](https://docs.earthly.dev/docs/earthfile#run) between repeated builds of the same target, and only if the build args are the same between invocations.

## How to keep our make targets warm
In the previous scenario, the CI platform's native caching mechanism worked remarkably well. However this is not generally the case, as demonstrated by the following counterexample featuring GitHub Actions and the ancient but still widely used `make`.

Contents of `.github/workflows/make.yaml`:


<!-- {% raw %} -->
```yaml
name: Caching with make

on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Cache build files
        uses: actions/cache@v2
        env:
          cache-name: default
        with:
          path: build
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('number') }}
      - name: List directory contents
        run: ls -R --full-time
      - name: Execute step1
        run: make build/step1
      - name: Execute step2
        run: make build/step2
```
<!-- {% endraw %} -->

Contents of `Makefile`:

```makefile
build/step1: number
	echo $$(expr $$(cat $?) \* 2) > $@

build/step2: build/step1
	echo $$(expr $$(cat $?) - 1) > $@
```

In this (admittedly rather uninspired) toy example, the build process entails multiplying the number in `number` by 2 in `build/step1`, then subtracting 1 from the result in `build/step2`. As you can find out by running in GitHub Actions, both target rules get executed regardless of the existence of the cache. This happens because the runner restores the original timestamp of the cache, whereas the source file `number`'s timestamp will point to when it was checked out from git. Since `make` remakes any (existing) target that is older than its prerequisites, it will determine that `build/step1` has to be remade (which implies that `build/step2` has to be remade as well). This unfortunate constellation of circumstances renders `make` unusable for incremental builds on GitHub Actions in a straightforward way. Not incremental, alas, but at least correct. Imagine what would happen if the cache's timestamp referred to the time it had been extracted into the build environment. In this workflow, that happens after the source code checkout so `make` would find nothing to redo at all!

Let's forget about this issue for a moment and assume that the timestamps are OK (i.e the timestamp of `number` marks the time of its commit), so `make` can actually skip remaking these steps. Let's split the target lineage (`number` <- `build/step1` <- `build/step2`) into two CI jobs for independent execution.

<!-- {% raw %} -->
```yaml
name: Caching with make

on: push

jobs:
  build-step1:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Cache step1
        uses: actions/cache@v2
        env:
          cache-name: step1
        with:
          path: build/step1
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('build/step1') }}
      - name: List directory contents
        run: ls -R --full-time
      - name: Execute step1
        run: make build/step1
  build-step2:
    needs: build-step1
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Cache step1
        uses: actions/cache@v2
        env:
          cache-name: step1
        with:
          path: build/step1
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('build/step1') }}
      - name: Cache step2
        uses: actions/cache@v2
        env:
          cache-name: step2
        with:
          path: build/step2
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('build/step2') }}
      - name: List directory contents
        run: ls -R --full-time
      - name: Execute step2
        run: make build/step2
```
<!-- {% endraw %} -->

Due to the runner's caching mechanism, one option we have is saving each target output under a different cache keyed by the prerequisites of that CI step. This is problematic, because `make` has to inspect not only the direct dependencies of the given goal, but its transitive dependencies too. This means we either need to include all transitive dependency caches individually, or save each cache as a 'rollup' including all of its own transitive dependencies. Our other option is to use a single cache, and have the build system figure out what to rebuild. This approach requires us to work around the default caching behavior for instance by including a nonce in the cache key (so the result needs to be saved unconditionally) and a catch-all fallback key (so there's always some cached state available). It's left to the interested reader to explore these two options further.

It is a reasonable approach to adopt Earthly incrementally and leaving the Makefile intact, especially for larger builds. To do this, we can create a thin wrapper around the `make` goals we want to export as individual CI jobs.

```
sources:
  COPY Makefile number .
  SAVE ARTIFACT ./

build-step1:
  COPY +sources/* ./
  RUN make build/step1
  SAVE ARTIFACT build/step1 AS LOCAL build/step1

build-step2:
  COPY +sources/* ./
  COPY +build-step1/step1 build/step1
  RUN make build/step2
  SAVE ARTIFACT build/step2 AS LOCAL build/step2
```

This introduces duplication in the build configuration and is more verbose than is comfortable. Also, it exhibits the same problem with transitive dependencies mentioned earlier. Nevertheless, it enables `make` to work as intended, and our CI configuration is drastically simplified too:

```yaml
name: Caching with make

on: push

jobs:
  build-step1:
    runs-on: ubuntu-latest
    container: earthly/earthly:v0.6.2
    steps:
      - name: Execute step1
        run: earthly +build-step1
  build-step2:
    needs: build-step1
    runs-on: ubuntu-latest
    container: earthly/earthly:v0.6.2
    steps:
      - name: Execute step2
        run: earthly +build-step2
```

In this case, it is very simple to rewrite our Makefile in Earthly:

```
build-step1:
    RUN mkdir -p build
    COPY number .
    RUN echo $(expr $(cat number) \* 2) > step1
    SAVE ARTIFACT step1 AS LOCAL build/step1

build-step2:
    COPY +build-step1/step1 step1
    RUN echo $(expr $(cat step1) - 1) > step2
    SAVE ARTIFACT step2 AS LOCAL build/step2
```

The exploration of using volume based caching in conjunction with this example is left to the interested reader.

## Wrapping up

In this blogpost I demonstrated how Earthly can be used as our build backbone in two case studies. I think BuildKit will become more popular in the upcoming years, however whether Earthly will gain momentum against the widely established Dockerfile frontend is hard to predict. There are also some contenders on the stage to look out for:

[HLB](https://openllb.github.io/hlb/): another BuildKit (LLB) frontend that has a more developer-oriented, brace-style syntax. It features a `mkFile` command that can write output to a file without depending on any user-level shell utilities, making it easier to create minimal images.

[buildah](https://github.com/containers/buildah): a shell command oriented tool to build OCI images. An important goal of Buildah is integration into Kubernetes and potentially other tools. The achieve that, developers are working to make Buildah work within a standard linux container without SYS_ADMIN privileges. This would allow Buildah to run non-privileged containers inside of Kubernetes, similarly to [kaniko](https://github.com/GoogleContainerTools/kaniko).

Hope your builds work like a charm!
