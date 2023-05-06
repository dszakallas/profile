---
layout: article
title: mixxxx-launchpad 3 is out!
key: 2023-05-06-mixxx-launchpad-3-is-out
tags:
  - Mixxx
  - Launchpad
  - MIDI
  - JavaScript
  - TypeScript
---

I finally found some time to work on my [Novation Launchpad mappings for Mixxx](https://github.com/dszakallas/mixxx-launchpad), which I started
[back in 2017]({% post_url 2017-05-20-modern-javascripting-a-midi-controller %}). This spike was mostly driven by the desire to modernize and componentize
the code and to make it easier for users with limited programming skills to add new controls.

I've recently bought a Novation LaunchControl XL, which I am going to use for mixing and effects and I wanted to reuse as much as mixxx-launchpad for the new controller
as I could. The repo already provided fairly general and high level abstractions for various aspects of authoring control mappings:

 - a compiler toolchain to enable writing modern JavaScript whilst targeting the old ~ES5 engine of Mixxx <2.4,
 - framework for writing components; stateful event handlers with lifecycle hooks,
 - typesafe Mixxx control definitions, and a higher level API for Mixxx,
 - a framework for creating mappings for multiple controllers,
 - a generator that uses JSON to produce XML mapping files,
 - and omiscellaneous utilities.

However it also had some problems:

- it was written in [facebook/flow](https://github.com/facebook/flow), which is no longer practical given the direction of the industry,
- the code was over complicated and difficult to modify at some parts,
- compatibility with the old JS engine required heavily transpiled code and limited use of new language features.

# Dropping support for Mixxx 2.3 and below

That's right, we're dropping support for the current stable release of Mixxx. Mixxx 2.4 ships a new
JS engine supporting ES6, so we can finally get rid all of the ES5 / ES3 transforms in our Babel
pipeline. What a time to be alive. Version 2.4 is still in the works, but you can find Linux/Windows/macOS Intel
snapshots hosted on the [official download site](https://downloads.mixxx.org/snapshots/2.4/), or if you run on macOS
with Apple Silicon, you can grab yourself an unofficial alpha build at [fwcd/m1xxx](https://github.com/fwcd/m1xxx).

# Sampler palette & RGB LEDs

Both are long-awaited features. Sampler palette allows for mapping a 8x8 sampler grid on the Launchpad. It is
the second 'Grande' preset. Irrespective of the selected channel it lays out Sampler1 - Sampler64
on the grid in left to right, top to bottom order. The controls were selected according to
[Be.'s suggestions](https://mixxx.discourse.group/t/new-multi-layout-multi-deck-novation-launchpad-mapping/16542/4?u=midiparse).

Since [Mixxx 2.3](https://mixxx.org/news/2020-08-25-new-in-2-3-hotcue-colors/), you can assign colors to hotcues and samplers
to easily distinguish them. This is quite essential when working with a vast grid of 64 samplers, and since all but the ancient
Launchpad MK1 have RGB LEDs, it was time to add support.

# Launchpad Mini MK3 support

Thanks to the [contribution by @chrneumann](https://github.com/dszakallas/mixxx-launchpad/pull/62), we now support
Launchpad Mini Mk3. On a less cheerful note, Launchpad Pro support was removed. If you own this controller,
contributions are welcome!

# Flow -> TypeScript rewrite

I originally chose [Facebook's Flow type checker](https://github.com/facebook/flow) in 2017, because it was novel and
had very nice structural typing capabilites that were missing from TypeScript at the time. Also, Flow's more conservative
approach of confining itself to type checking was very appealing: JavaScript was rapidly changing
at that time, with significant language changes appearing in every new version. TypeScript did
(and still does) code generation and had its own definition of `class` predating ES6. I saw a chance that conflicts with
the new standard would make TypeScript obsolete, like it happened to
[CoffeeScript](https://en.wikipedia.org/wiki/CoffeeScript).

Since then, things have changed a lot in tech. Cryptocurrencies, then AI became mainstream. Everyone wants to be cloud native
and former Java folks flock to WASM to have their write once, run everywhere promise finally fulfilled. Regarding TypeScript,
it has matured with the industry de-facto standardizing around it, while [flow](https://github.com/facebook/flow) continues to
remain niche to this day.

TypeScript turned out to be easy to integrate into the existing toolchain (in fact, it actually reduces the amount of
configuration required) and editor integration is better. Regarding the type system, it is on-par with Flow. I particularly liked
[indexed access types](https://www.typescriptlang.org/docs/handbook/2/indexed-access-types.html), which I find similar
to [dependent object types](https://www.scala-lang.org/blog/2016/02/03/essence-of-scala.html) of Scala. It allows the
developer to associate types in a straightforward way, through object definitions.

The best example of indexed access types in mixxx-launchpad is the control template framework.

`ControlType` represents a logical group of controls that work together to solve a specific function,
and may contain multiple MIDI and engine control bindings, expose parameters and maintain internal state.

```typescript
export type Binding = ControlComponent | MidiComponent
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
`ControlComponent`s and `MidiComponent`. That is, a `Control` works with a concrete deck, and mapped to specific MIDI buttons
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

You can see how conviently we could lift concepts one layer above with mapped types and indexed access types.
`ControlTemplate` is the factory for `Control`, `ControlBindingTemplate` for `ControlBinding`, etc. The matching
type argument in `Control`'s constructor argument map the type with its factory.


# More declarative presets

Preset authoring just got a bit simpler. Presets are configured in a single file, [`config.ts`](https://github.com/dszakallas/mixxx-launchpad/blob/v3.0.0/packages/app/src/config.ts). Here you can reorder presets, add new ones, change controls, etc. The document should be more self-describing. You can look up the available controls [here](https://github.com/dszakallas/mixxx-launchpad/blob/v3.0.0/packages/app/src/controls/index.ts).
