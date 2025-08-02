---
layout: article
title: mixxx-launchpad 3 is out
key: 2023-05-06-mixxx-launchpad-3-is-out
tags:
  - Mixxx
  - Launchpad
  - MIDI
  - JavaScript
  - TypeScript
---

I finally found some time to work on [mixxx-launchpad](https://github.com/dszakallas/mixxx-launchpad), my Novation Launchpad
mappings for the popular Mixxx DJ software, which I started back in
[2017]({% post_url 2017-05-20-modern-javascripting-a-midi-controller %}).

<!--more-->
The current spike was mostly driven by the desire to add some long awaited features such supporting RGB LEDs
and samplers. Additionally I wanted to modernize and componentize
the code and make it easier for users with limited programming skills to customize their layouts.

Moreover, I've recently bought a Novation LaunchControl XL, which I am going to use for mixing and
effects, and I want to reuse existing functionality in mixxx-launchpad for the new controller as much as I can.
The repo already provides fairly general and high level abstractions for various aspects of authoring control mappings:

 - a compiler toolchain to enable writing modern JavaScript whilst targeting the old ~ES5 engine of Mixxx <2.4,
 - framework for writing components; stateful event handlers with lifecycle hooks,
 - typesafe Mixxx control definitions, and a higher level API for Mixxx,
 - a framework for creating mappings for multiple controllers,
 - a generator that uses JSON to produce XML mapping files.

However it also has some flaws:

- it is written in [facebook/flow](https://github.com/facebook/flow), which is no longer practical given the direction of the industry,
- bad, overcomplicated code that's difficult to modify at places,
- compatibility with the old JS engine requires heavily transpiled code and limits the use of new language features (eg. generators),
- Launchpad specific stuff creeping into places it shouldn't.

These prompt some refactors to streamline continued development and facilitate authoring mappings for
new devices. Part of these refactors are also shipping with version 3.

So without further ado, let's dive into the most important changes!

# Dropping support for Mixxx 2.3 and below

That's right, we're dropping support for the current stable release of Mixxx. Mixxx 2.4 ships a new
JS engine supporting ES6, so we can finally get rid all of the ES5 / ES3 transforms in our Babel
pipeline. What a time to be alive. Version 2.4 is still in the works, but you can find binary snapshots
hosted on Mixxx's [official download site](https://downloads.mixxx.org/snapshots/2.4/). If you run on macOS
with Apple Silicon, you can grab yourself an unofficial alpha build at [fwcd/m1xxx](https://github.com/fwcd/m1xxx) that
runs natively. Alternatively, you can compile from source.

# Sampler palette & RGB LEDs

Both are long-awaited features. Sampler palette allows for mapping a 8x8 sampler grid on the Launchpad. It is
the second 'Grande' preset (Select a single channel, then cycle once with Shift+ChannelX). It is special in the
sense that irrespective of the selected channel it always lays out Sampler1 - Sampler64 on the grid in left to right,
top to bottom order. The controls were picked following [Be.'s recommendations](https://mixxx.discourse.group/t/new-multi-layout-multi-deck-novation-launchpad-mapping/16542/4?u=midiparse).

Since [Mixxx 2.3](https://mixxx.org/news/2020-08-25-new-in-2-3-hotcue-colors/), you can assign colors to hotcues and samplers
to easily distinguish between them. This is quite essential when working with a vast grid of 64 samplers, and since all but the ancient
Launchpad MK1 have RGB LEDs, it was time to add support.

# Launchpad Mini MK3 support

Thanks to [contribution by @chrneumann](https://github.com/dszakallas/mixxx-launchpad/pull/62), we now support
Launchpad Mini Mk3. On a less cheerful note, Launchpad Pro support was removed. If you own this controller,
contributions are welcome!

# Flow -> TypeScript rewrite

I originally chose [Facebook's Flow type checker](https://github.com/facebook/flow) in 2017, because it was novel and
had very nice structural typing capabilities that were missing from TypeScript at the time. Also, Flow's more conservative
approach of confining itself to type checking was appealing: JavaScript was rapidly changing
at the time, with significant language changes dropping with every new version. TypeScript did
(and still does) code generation and had its own definition of `class` predating ES6. I saw a chance that conflicts with
the new standard would make TypeScript obsolete, like it happened to
[CoffeeScript](https://en.wikipedia.org/wiki/CoffeeScript).

Since then, things have changed a lot in tech. Cryptocurrencies, then AI became mainstream. Everyone wants to be cloud native
and former Java folks flock to WASM to have their write once, run everywhere promise finally fulfilled. My fears with TypeScript
has proven groundless, as the industry de-facto standardized around it, while [flow](https://github.com/facebook/flow) continues to
remain niche to this day. (Not my worst bet though.)

TypeScript turned out to be easy to integrate into the existing toolchain (in fact, it actually reduces the amount of
configuration required) and editor integration is better. Regarding the type system, it is on-par with Flow. I particularly liked
[indexed access types](https://www.typescriptlang.org/docs/handbook/2/indexed-access-types.html), which I find similar
to [dependent object types](https://www.scala-lang.org/blog/2016/02/03/essence-of-scala.html) of Scala. It allows the
developer to associate types in a straightforward way, through object definitions.

The best example of indexed access types in mixxx-launchpad is the control template framework.

`ControlType` represents a logical group of controls that work together to solve a specific function,
and may contain multiple MIDI and engine control bindings, expose parameters and maintain internal state.

```typescript
type Binding = ControlComponent | MidiComponent
type State = { [k: string]: any }
type Params = { [k: string]: any }

type ControlType = {
  type: string
  bindings: { [k: string]: Binding }
  params: Params
  state: State
}
```

A `Control` instance corresponds to a specific control whose bindings are instatiations of
`ControlComponent`s and `MidiComponent`s. That is, a `Control` works with a concrete deck, and mapped to specific MIDI buttons
on the Launchpad's grid. It also inherits the lifecycle management hooks and event listeners of `Component`s.

```typescript
type IControl<C extends ControlType> = {
  bindings: C['bindings']
  state: C['state']
  context: ControlContext
}

class Control<C extends ControlType> extends Component implements IControl<C> {
  bindings: C['bindings']
  bindingTemplates: ControlTemplate<C>['bindings']
  state: C['state']
  context: ControlContext

  constructor(ctx: ControlContext, controlTemplate: ControlTemplate<C>) {
    super()
    /* implementation omitted */
  }

  onMount() {
    super.onMount()
    /* implementation omitted */
  }

  onUnmount() {
    /* implementation omitted */
    super.onUnmount()
  }
}
```

It might not be evident why we need all these types such as `IControl` and `ControlType`. `IControl` is only to get
the warm fuzzy feeling of an extracted interface, nothing more interesting. `ControlType` is used as a type aggregator,
it collects related types together which are used in several places, and as you can see only a (real) subset of its
properties are used in `IControl`.

Since we want to have an abstraction that enables instantiating a control for an arbitrary channel (deck), and an
arbitrary offset on the grid, we need a separate type, acting as a factory. This is called `ControlTemplate`:


```typescript
type ControlBindingTemplate<C extends ControlType> = {
  type: 'control'
  target: ControlDef
  update?: (c: Control<C>) => (message: ControlMessage) => void
  mount?: (c: Control<C>) => () => void
  unmount?: (c: Control<C>) => () => void
}

type ButtonBindingTemplate<C extends ControlType> = {
  type: 'button'
  target: [number, number]
  midi?: (c: Control<C>) => (message: MidiMessage) => void
  mount?: (c: Control<C>) => () => void
  unmount?: (c: Control<C>) => () => void
}

type BindingTemplate<B extends Binding, C extends ControlType> = B extends ControlComponent
  ? ControlBindingTemplate<C>
  : ButtonBindingTemplate<C>

type ControlTemplate<C extends ControlType> = {
  bindings: {
    [Prop in keyof C['bindings']]: BindingTemplate<C['bindings'][Prop], C>
  }
  state: C['state']
}
```

You can see how conveniently we could lift concepts one layer above with mapped types and indexed access types.
`ControlTemplate` is the factory for `Control`, `ControlBindingTemplate` for `ControlBinding`, etc. The matching
type argument in `Control`'s constructor argument map the type to the factory type.

# More declarative presets

Preset authoring just got a bit simpler. Presets are configured in a single file, [`config.ts`](https://github.com/dszakallas/mixxx-launchpad/blob/v3.0.0/packages/app/src/config.ts). Here you can reorder presets, add new ones, change controls, etc. The document should be pretty self-describing. You can look up the available controls [here](https://github.com/dszakallas/mixxx-launchpad/blob/v3.0.0/packages/app/src/controls/index.ts).


# Summary & What's coming next

Hope you like the changes. You can find the full changelog attached to the [release](https://github.com/dszakallas/mixxx-launchpad/releases/tag/v3.0.0).

As a functional programmer, I am not entirely happy with the amount of classes and state involved,
but moving to a reactive functional paradigm seems to be too much work, as the system boundaries are
imperative by nature, requiring extensive plumbing; while the inner, reactive part would be too thin.

More refactors will be landing in advent of the upcoming Novation LaunchControl support. This will incur changes to the package structure to allow
for more sharing. Also, the control framework will likely get a revamp to remove the LaunchPad specific notions (eg. grid placement)
and allow specifying other targets than decks (e.g effect units). The Mixxx control API will be extended to support effects and soft takeover.

That's all for now. Happy mixxxing with Launchpad, and stay tuned for further updates!
