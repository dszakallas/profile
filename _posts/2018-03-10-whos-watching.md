---
layout: post
title: Who's watching? 👀
key: 2018-03-10-whos-watching
tags:
  - JavaScript
  - Makefile
  - developer tooling
---

I have yet to meet a serious frontend programmer who hasn\'t used file
system watcher tasks to recompile/rebuild/redeploy code and enjoy the
instant feedback. In Javascript land all build tools/bundlers/packers
and whatnot provide `watch`​ flags to make them watch for changes
forever.  This sounds a good idea at first, but when you have to use
more of these tools in the same process, it gets unmanageable. But why
do we even need these watchers? Transpiling, bundling and minifying
Javascript takes a non-negligible time and is a rather complex process.
Eg., bundlers have to create a module graph to resolve dependencies
between source files. Browserify as well as Rollup uses an in-memory
cache for these and can detect changes in the module graph between
successive builds so it can recompile only the necessary parts. This is
known as incremental compilation and makes building significantly faster
for small, local changes. And we know that programmers usually make
exactly these kind of changes during development. If you caught the
\'in-memory\' qualifier, you are now also aware of the limitation of
these tools, ie. they only retain the cache within a single process,
hence the endless watch tasks. The problem with watchers is that they
don\'t fit with the well-established, cosy, (mostly) correct and fast
model that traditional build systems like
[Make](https://www.gnu.org/software/make/) and its derivatives use for
incremental building. In these you declaratively define targets with
requirements, and let the build tool figure out changes and rerun the
necessary steps to update the targets in the task graph (directed
acyclic graph). This is great because if you have well defined
dependencies everywhere, the build system ensures that you have correct
and fast incremental builds all the time. It is also great because the
build tools is no longer a blackbox, and you and only you define the
requirements for your targets. But what if defining the exact
requirements is too complex, and you simply have to delegate it to
Browserify, [Rollup](https://rollupjs.org/guide/en) or whatever? You
cannot put an arbitrary watch target into a makefile as it will run
forever, so it has to be a top-level one! If you have different such
watchers, coalescing them into a top level task quickly becomes a
nightmare. [Gulp](https://gulpjs.com/) aimed to solve this problem with
its \'streams instead of files\' philosophy, which is nice but who the
heck wants to write build files in Javascript ever? I so loved
rebuilding my thesis written in LaTeX with a simple make target
using [fswatch](https://github.com/emcrisostomo/fswatch) - a cross
platform command line utility for watching for file system changes. It
is the only watcher I am willing to use!

```
watch :
@echo Stop watching with Ctrl-C
@sleep 1 # Wait a bit, so users can read
@$(MAKE) || exit 0;
@trap exit SIGINT; fswatch -o $(INPUT_FILES) | while read; do $(MAKE); done
.PHONY : watch
```
So I hacked around the bit and I figured out that with Rollup, I can
actually save the cache, load it later and it just works. Let me show my
complicated build file of my toy project
[here](https://github.com/szdavid92/mixxx-launchpad/blob/master/Makefile).
I have two recipes:

-   one that calls a `compile-mappings.js` script that just assembles a
    lovely XML (no smirking!) that I happen to know that exact
    dependencies of,
-   and a `compile-scripts.js` that uses Rollup for bundling my source
    files into a fat JAR\... erhm sorry, bundle.

I want to watch both of them, so I cannot stall make just to run
`rollup --watch` for sake of the second task! I instead do the following
in `compile-scripts.js`:

```js
readFile('tmp/cache.json')
.then((cache) => JSON.parse(cache))
.catch((err) => null)
.then((cache) => rollup.rollup({ cache, entry, plugins}))
.then((bundle) => {
  const cache = JSON.stringify(bundle)
  return mkdirp('tmp')
    .then(() => writeFile('tmp/cache.json', cache))
    .then(() => bundle.write({ dest }))
})
```

I am trying to use a previously saved cache and creating a new one when
bundling is done. And it works! This way I can use my regular make
recipes and just run them manually to enjoy the shorter build times, or
create the same top-level watch task for them already shown above. This
solution might not be as fast as an in-memory cache, but I am glad that
it works and plays nice with my existing build tools. So guess who\'s
watching?

![]({{ "/assets/2018-03-10-whos-watching/fswatch-is.jpg" | absolute_url }})   
