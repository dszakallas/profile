---
layout: article
title: My Emacs with Nix on macOS
key: 2025-08-02-my-emacs-with-nix-macos
tags:
  - nix
  - developer tools
  - emacs
  - macOS
excerpt: "Time to migrate my Emacs."
article_header:
  type: overlay
  theme: dark
  background_image:
    gradient: 'linear-gradient(135deg, rgba(204, 204, 42, 0), rgba(139, 34, 139, .5))'
    src: /assets/2025-08-02-my-emacs-with-nix-macos/header.png
---


<!--more-->
Ever since I started using Nix on my daily drivers, I have wanted to migrate my Emacs installation to it.

I was hesitant for some time, since [d12frosted's emacs-plus][emacs-plus] brew formula
is very convenient, and I have been using it for several years. Even with [nix-darwin][nix-darwin],
I still have some packages installed with brew; however, I want to eventually migrate every non-cask
package away. This time it's Emacs.

## Oh my emacs.d

Managing my configuration with Nix is quite straightforward. I am using [Spacemacs][spacemacs]
and have a single `init.el` configuration, and a few local Spacemacs layers (sort of packages) in
my `spacemacs.d` directory. All I had to do was install these files with [home-manager][home-manager].
Of course, making my configuration immutable means that `SPC f e d` (edit configuration) and
`SPC f e D` (diff configuration with template) no longer work since the files are not writable,
and I have to look up the [source `init.el`][init-el] instead.

So far, the configuration is simple, and I can just use the `home.file` option to install
my `spacemacs.d` directory into the home directory:

```nix
# default.nix
{ ... }:

{
  home.file.".spacemacs.d" = {
    source = ./spacemacs.d;
  };
}
```

## Packaging the Spacemacs distribution

We would normally install Spacemacs with

```bash
git clone https://github.com/syl20bnr/spacemacs $HOME/.emacs.d
```

in a vanilla installation. With Nix, the idiomatic way to install software is through packages.
Since Spacemacs doesn't have one in nixpkgs, let's create our own [derivation][spacemacs-drv].
It requires some patching, but it is still pretty simple.

```nix
# spacemacs.nix
{
  stdenvNoCC,
  fetchFromGitHub,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "spacemacs";
  version = "2025-07-30-develop";
  src = fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "214de2f3398dd8b7b402ff90802012837b8827a5";
    hash = "sha256-a3EkS4tY+VXWqm61PmLnF0Zt94VAsoe5NmubaLPNxhE=";
  };

  patches = [
    ## ELPA packages were previously installed in spacemacs' source directory,
    ## which is in the Nix store, so we patch it to install them in the user 
    ## directory.
    ## This patch was merged upstream, and is no longer needed.
    # ./elpa-in-userdir.diff

    ## quelpa would copy source files to a build directory, without
    ## changing their permissions, so we patch it to make them writable
    ./quelpa-build-writable.diff
  ];

  installPhase = ''
    mkdir -p $out/share/spacemacs
    cp -r * .lock $out/share/spacemacs
  '';
}
```

Then, we can use this package in our home-manager configuration by
adding it to the `home.packages` list. We also need to load the
Spacemacs configuration files in Emacs, which we can do in our
init files.

```nix
{ pkgs, ... }:

let
  spacemacs = pkgs.callPackage ./spacemacs.nix {};
  spacemacs-start-directory = "${spacemacs.out}/share/spacemacs";
  load-spacemacs-init = f: ''
    (setq spacemacs-start-directory "${spacemacs-start-directory}/")
    (add-to-list 'load-path spacemacs-start-directory)
    (load "${f}" nil t)
  '';
in  
{
  home.packages = [
    spacemacs
  ];
  home.file.".spacemacs.d" = {
    source = ./spacemacs.d;
  };
  home.file.".emacs.d/init.el" = {
    text = load-spacemacs-init "init";
  };
  home.file.".emacs.d/early-init.el" = {
    text = load-spacemacs-init "early-init";
  };
  home.file.".emacs.d/dump-init.el" = {
    text = load-spacemacs-init "dump-init";
  };
}
```

This is still just half the story, as for a fully reproducible Emacs environment,
we also need to ensure that all the Emacs packages that we use are installed with Nix.
Spacemacs doesn't use lock files, and switching to a newer version of Emacs triggers
downloading the latest version of all packages, which often break in various ways — a
frequent pain point during Emacs upgrades.

As Nix is fundamentally incompatible with Spacemacs' package management, this might not
be very easy to do and remains to be done.

## Building emacs

The last thing is to build Emacs with Nix. I was delaying this for a long time, since
I am using macOS and was aware that various patches would be needed, and I was
afraid that [nixpkgs][nixpkgs-emacs] would have subpar support.

However, I was pleasantly surprised that after applying
the [emacs-plus set of patches][emacs-plus-patches], I could get a build without major
flaws, even for the GUI.

```nix
# emacs.nix
{
  emacs,
  lib,
  stdenv,
  withNS ? stdenv.hostPlatform.isDarwin,
  # Has been reported not-working in macOS 15.4:
  # https://github.com/NixOS/nixpkgs/issues/395169
  # however, I have not seen any issues on macOS 15.5
  withNativeCompilation ? true,
  ...
}:
# These patches mainly fix GUI issues on macOS, I sourced them from
# https://github.com/d12frosted/homebrew-emacs-plus
let
  nsPatches = [
    ./osx-fix-window-role.patch
    ./osx-round-undecorated-frame.patch
    ./osx-system-appearance.patch
  ];
in
(emacs.override {
  inherit withNS withNativeCompilation;
}).overrideAttrs
  (prev: {
    patches = (prev.patches or [ ]) ++ lib.optionals withNS nsPatches;
  })
```

Of course, this requires the package to be built from source, so expect some
15-20 minutes of build time on your MacBook ☕️.

The package also builds a macOS application bundle by default, which is
the best way to run it, as icons and other GUI elements will show up properly
even when running it as a daemon.

By the way, for the daemon, all we need to do is add the `launchd` agent to our
home-manager configuration:

```nix
# default.nix
{ pkgs, ... }:
let
  emacs = pkgs.callPackage ./emacs.nix {};
  # rest omitted for brevity ...
in
{
  launchd.agents."emacs" = mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      # use the Emacs application bundle instead of bin/emacs
      # for better GUI support
      ProgramArguments = [
        "${emacs}/Applications/Emacs.app/Contents/MacOS/Emacs"
        "--fg-daemon"
      ];
      KeepAlive = true;
    };
  };
  # rest omitted for brevity ...
}
```

By default, home-manager also [links][hm-link-apps] application bundles to the
`~/Applications/Home Manager` directory, so an icon can be easily added to the Dock.

I extended my [Emacs derivation][emacs-drv] to create an additional application bundle
for launching `emacsclient`, so I can put that on my Dock too.

## Conclusion

That's basically it. It took a few hours of effort to create a viable substitute for
my brew installation that also manages my configuration across multiple machines.

This reassured me that Nix is one of the best ways to consume software and
configure my system.

PS: This should work for Linux too, since the macOS-specific patches are
guarded by platform checks, but I have not tested it yet. Nevertheless, if I ever start
using Linux as a dev machine again, I will want to use the same Emacs package.

[nix-darwin]: https://github.com/nix-darwin/nix-darwin
[emacs-plus]: https://github.com/d12frosted/homebrew-emacs-plus
[spacemacs]: https://github.com/syl20bnr/spacemacs
[home-manager]: https://nix-community.github.io/home-manager
[init-el]: https://github.com/dszakallas/dotfiles-common/blob/530eb5c32df5b6dcb6ec468d07e8300a8330cec7/modules/home/emacs/spacemacs.d/init.el
[spacemacs-drv]: https://github.com/dszakallas/dotfiles-common/blob/530eb5c32df5b6dcb6ec468d07e8300a8330cec7/pkgs/spacemacs/default.nix
[nixpkgs-emacs]: https://search.nixos.org/packages?channel=unstable&from=0&size=1&sort=relevance&type=packages&query=emacs
[emacs-plus-patches]: https://github.com/d12frosted/homebrew-emacs-plus/tree/3e95d573d5f13aba7808193b66312b38a7c66851/patches/emacs-30
[hm-link-apps]: https://nix-community.github.io/home-manager/options.xhtml#opt-targets.darwin.linkApps.enable
[emacs-drv]: https://github.com/dszakallas/dotfiles-common/blob/530eb5c32df5b6dcb6ec468d07e8300a8330cec7/pkgs/davids-emacs/default.nix
