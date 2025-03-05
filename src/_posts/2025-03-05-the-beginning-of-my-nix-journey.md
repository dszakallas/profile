---
layout: article
title: The beginning of my Nix journey
key: 2025-03-05-the-beginning-of-my-nix-journey
tags:
  - nix
---

It's been half a year since I started using Nix, and I feel the time has come to look back and reflect
on the experience.
Interestingly, I didn't start using it as a fancy dotfiles/devenv manager; in fact, that only came later
as a side effect (pun intended!).

I had a retrogaming Raspberry Pi 4 for some time, running Raspbian with RetroPie. My configuration had evolved
'organically' over the years, as one would expect.
Then, last spring, I bought an RPi 5 and wanted to replicate the setup of the original machine.
With fading memories and no documentation, it was a trial-and-error process to get all the configurations in
place and working, even with parts of it version-controlled. I needed a way to automate this better for
the future.

I turned to Ansible at first. You might be surprised, but I had no prior experience with it.
Professionally, I work with cloud infrastructure and Kubernetes, which means Terraform or K8s GitOps coupled
with some cloud image or container builder. Ansible was fairly simple to get started with. After some time,
however, I realized I was looking for something else.
I found it error-prone having to ensure idempotency myself; since steps are not reversible, it wasn't very
experimentation-friendly, especially when in a constant undo-modify-redo loop optimizing a solution.

I'd had NixOS in the back of my head; I'd heard some of my friends getting excited about it. The only thing
I knew at the time was that it's some kind of declarative Linux distribution. After finding out that its
core functionality, the package manager, can also be installed independently, I decided to give it a spin
on Raspbian, since one of the main things I needed was the ability to package my emulators built with various
tweaks.

Over one weekend, I got Nix installed on the device and familiarized myself with the language enough to produce
my first customized derivation (~package) for a RetroArch emulator and get it up and running. I remember being
quite amazed at how easy it was. Thus, I started writing derivations for the emulators from scratch, trying to
replicate the original shell build steps; but after searching nixpkgs, I soon realized they already had plenty
contributed upstream. (Nevertheless, these have proven to be too generic to work out of the box, so I had to
tweak nearly all of them in some way with the help of overlays.)

I was happy with the results, especially the fact that extending the package manager was quite natural and easy
compared to the existing system, where this was managed with a custom framework built on top of apt, written in
Bash.
However, I also needed to deploy some custom kernel modules for my gamepad, alongside other system-wide packages
still installed with apt. And of course, I had to install the Nix package manager, too.
So, Ansible was still in the picture. If only I could flash NixOS onto the Raspberry Pi...

So I came across [nix-community/raspberry-pi-nix](https://github.com/nix-community/raspberry-pi-nix), which I
used to build the OS (including all my packages and configuration). But for that, I needed a Nix environment.
So I thought I'd need Nix installed on my laptop - the humble beginning to using Nix on my daily driver.
Ironically, I couldn't get the cross-compilation working for the Raspberry Pi on my macOS, so I ended up building
the image in Docker. For months, I didn't even touch that nix-darwin installation on my laptop, as I was focused
on the retrogaming system and I wasn't invested in switching my brew/dotfiles/whatever-version-manager setup just
yet. But as I was working with Nix m ore and more on the Pi, and my confidence with the language grew, that point
came effortlessly during the autumn.

With the Pi, I've reached a state where it has everything I need for personal use, but it's not good enough to
open-source it yet. I have some ideas to make the system suited for people without Nix experience, but I hardly
find the will and time to work on it nowadays. I hope to invest some time in it in the near future though.

On my dev laptop, however, I have a constantly growing nix-darwin/home-manager configuration that I use daily.
It's a versatile tool, replacing many other fragmented methods. Nixpkgs is
pretty comprehensive, and I can always create a package in a matter of minutes if I need to. The biggest
challenge is working with language-specific package ecosystems.
(One of the worst offenders I encountered is Python.) But if you are not using Nix for distribution, e.g.,
you just want a development environment, where you produce artifacts for publishing on PyPI or build a
container image, then this is not a problem. The biggest enabler for me was [devenv](https://devenv.sh/),
if not for this tool, I probably wouldn't have done the switch to Nix. Finally, a hassle-free local development
environment.
I use the direnv integration, so it activates automatically when I enter a project directory. I currently use it
for several personal projects; including Go, Python, Node.js, Ruby, K8s Helm...

To conclude, I would like to shout out to all members from the Nix community, for creating awesome tools like
this.
