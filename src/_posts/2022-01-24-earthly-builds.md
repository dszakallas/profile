---
layout: article
title: Earthly builds for containerized apps
key: 2022-01-24-earthly-builds
tags:
  - Earthly
  - buildkit
  - Docker
  - DevOps
---

## Motivation

Building applications in containers has some well-documented benefits. By wrapping the whole build environment, 
it requires zero setup and increases reproducibility; while smart use of build stages and layers opens 
opportunities for [caching and parallelism](https://www.gasparevitta.com/posts/advanced-docker-multistage-parallel-build-buildkit/). 
Currently however, containerized builds are mainly used to package the application for deployment, which constitutes only part of an ordinary CI workflow; tests, static checks, and other 
development related tasks are often left uncontainerized. These tasks require largely the same setup 
as building the application itself. For builds
that have a long setup process, e.g when the application has lots of dependencies or the dependencies
have to be compiled from source, incremental builds become unavoidable. Extending containerization to all CI jobs can simplify CI setups and can lead to more portable, more incremental builds.

## The case for unification

> There are only two hard things in Computer Science: cache invalidation and naming things.
>
> -- [Phil Karthon (?)](https://www.martinfowler.com/bliki/TwoHardThings.html)

Differences between the CI and the developer's local environment can lead to unreprodicible bugs, and "works on my machine" effect. Modern CI runners can utilize containers, however locally running these steps might be a bit of a chore. You can use CI specific helpers (e.g there's a tool called [act](https://github.com/nektos/act) which can be used to simulate GitHub Action Workflows locally), however using a vendor specific solution feels a desperate attempt at curbing complexity. The puritan engineer would rather opt for a thin shell wrapper around each job, so that the job consist of a single shell script invocation both in the CI config file and when running locally using e.g. `docker run`. However this approach is oblivious to some important aspects of your CI build, e.g caching. Moreover it would be desireable to be able to run whole workflows locally, without manually stepping through the build. Should we manually write aggregate scripts, or use an incremental build system?

Earthly is an LLB [buildkit](https://github.com/moby/buildkit) frontend with syntax and additional features making it more tailored to defining incremental builds than the Dockerfile. This comes with two important benefits: for once, there is little to learn for someone already knowing buildkit; twice, if you already use buildkit during CI/CD, chances you can introduce Earthly with little setup. It is shipped as a single statically-linked binary, and it depends on the docker daemon for running containers. I am not aiming to give tutorial on Earthly in this post, you should check out their official [Getting Started guide](https://docs.earthly.dev/basics) for that.
 
Earthly provides the following benefits:
- eliminates the need to use the CI-specific caching system, which can reduce the complexity of the build. If you are happy with how layer based caching works when building the application image during CI, likely you will be happy with it during other steps. There's also a less stringent (and less correct) mount based caching for frequently changing build steps that pose a performance bottleneck. As this is an introductory post, mount based caching will not be discussed here.
- makes your CI config file thinner, thus your jobs easier to run locally; and should the need arise, easier to port to a different CI framework.
- little to learn for people already writing Dockerfiles.
- little setup for CI environments already using `docker buildx`

I follow up with two case studies to help place these benefits in context. 

## Gems and yarn won't cause no harm ... 

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
        - .yarn-cache/
  script:
    - bundle install --path=vendor
    - yarn install --cache-folder .yarn-cache
    - echo Run tests...
```
During the first run of this job, the cache is empty, so dependencies have to be downloaded and installed. Then, at the end of the job, the cache is saved. Consecutive runs with unchanged lock files will reuse this cache, so that the first two steps of the job are effectively skipped.

A downside of this approach is that caching is now part of the CI runner's configuration, 
so you cannot use it locally (with Docker) as is. It also leaks some info about your build which can lead to configuration drift. (What if the build steps are extracted to a shell script and someone changes the yarn cache folder in the script, but forgets to update the CI config?) Furthermore, the cache key is not implied by the build definition, requiring additional effort from the engineer to make the connection. Most importantly though,
this sort of caching works solely because the respective tools (`bundle` and `yarn`) are written to work this way, i.e. they are able to detect that all
dependencies have been installed already and skip the time consuming process of downloading, building and installing them.

This example can be formulated in Earthly the following way:

```earthfile
ruby-deps:
  COPY Gemfile Gemfile.lock .
  RUN bundle install --path=vendor
  SAVE ARTIFACT vendor/ruby AS cache

node-deps:
  COPY package.json yarn.lock .
  RUN yarn install --cache-folder .yarn-cache
  SAVE ARTIFACT .yarn-cache AS cache

tests:
  COPY +ruby-deps/cache vendor/ruby
  COPY +node-deps/cache .yarn-cache
  RUN echo Run tests...
```

Here, the final layer that makes up the `ruby-deps` target has to be recreated if `Gemfile` or `Gemfile.lock` changes, 
keying the cache with the files that are required for `bundle install`. (Unfortunately, unrelated changes in the required
`Gemfile` also affect the layer.) The same applies for `node-deps`. The `tests` target depends on both of them, so it gets recomputed 
if any of them changes. The cache key is derived implicitly and intrinsically from the build step, although the directory to save and restore is specified by hand. Another important features is that the approach would work even if the tools didn't support caching, because the whole `RUN` step is skipped. This will become important in the next example.

For the record, here's the relevant part of the GitLab CI config file:

```yaml
test-job:
  stage: build
  image: earthly/earthly:v0.6.2
  script:
    - earthly +test
```

## ... but make makes it fall apart
In the previous scenario, native CI caching worked remarkably well. However this is not generally the case, as demonstrated by the following counterexample featuring GitHub Actions and the ancient but still widely used `make`.

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

In this (rather bareboned and uninspired) example, the build process entails multiplying the number in `number` by 2 in `build/step1`, then subtracting 1 from the result in `build/step2`. The surprised engineer will find after trying out in GitHub Actions, that both target rules get executed no matter what. This happens because the runner restores the original timestamp of the cache, whereas the source file `number`'s timestamp will point to when it was checked out from git. Since `make` remakes any (existing) target that is older than its prerequisites, it will determine that `build/step1` has to be remade (which implies that `build/step2` has to be remade as well). This unfortunate constellation of circumstances renders `make` unusable for incremental builds on GitHub Actions in a straightforward way. Not incremental, alas, but at least correct. Imagine what would happen if the cache's timestamp referred to the time it had been extracted into the build environment. In this workflow, that happens after the source code checkout so `make` would find nothing to redo at all!


Let's forget about this issue for a moment and assume that the timestamps are consistent with what you would see locally (i.e the timestamp of `number` marks the time of its commit), and so `make` could actually skip remaking these steps. Now imagine that we would like to split up the target lineage (`number` <- `build/step1` <- `build/step2`) into two CI jobs for independent execution.

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

Due to the runner's caching mechanism, one option we have is to save each target output under a different cache keyed by the prerequisites of that CI step. This is problematic, because `make` has to inspect not only the direct dependencies of the target rule (goal), but its transitive dependencies too. This means we either need to include all transitive dependency caches individually, or save each cache as a 'rollup' including all transitive dependencies. Our other option is to use a single cache, and have the build system figure out what to rebuild. This approach requires us to work around the default caching behavior with e.g. including a nonce in the cache key (so the result needs to be saved unconditionally) and a catch-all fallback key (so there's always some cached state available). It's left to the interested reader to explore these two options further. (Once again, it's hypothetical because of the timestamp issue.)

It is a reasonable approach to adopt Earthly incrementally and leaving the Makefile intact, especially for larger builds. To do this, we can create a thin wrapper around the `make` goals we want to 'embellish'.

```earthfile
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

This works but introduces duplication in the build configuration and is more verbose than comfortable. Also, it exhibits the same problem with transitive dependencies. However, our CI configuration is drastically simplified:

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


Ultimately, we should rewrite our Makefile in Earthly:

```earthfile
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

## Conclusion

This blogpost demonstrated how Earthly can simplify the build in two case studies. Whether BuildKit matures to be the go-to build
sytem in the upcoming years, and whether Earthly will gain momentum against the widely established Dockerfile frontend
is hard to predict. There are also some contenders on the stage to look out for:

[HLB](https://openllb.github.io/hlb/): another BuildKit (LLB) frontend that has a more developer-oriented, brace-style syntax. It features a `mkFile` command that can write output to a file without depending on any user-level shell utilities, making it easier to create minimal images.

[buildah](https://github.com/containers/buildah): a shell command oriented tool to build OCI images. An important goal of Buildah is integration into Kubernetes and potentially other tools. The achieve that, developers are working to make Buildah work within a standard linux container without SYS_ADMIN privileges. This would allow Buildah to run non-privileged containers inside of Kubernetes, similarly to [kaniko](https://github.com/GoogleContainerTools/kaniko). It more of a competitor to BuildKit than of Earthly. 
