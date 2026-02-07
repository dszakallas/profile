---
layout: article
title: Switching from GPG to FIDO2 on macOS
key: 2025-09-21-switching-to-fido2
tags:
  - nix
  - ssh
  - macOS
  - yubikey
  - gpg
  - fido2
excerpt: "It's time to ditch GPG"
article_header:
  type: overlay
  theme: dark
  background_image:
    gradient: 'linear-gradient(180deg, rgba(50, 50, 0, 0.1), rgba(0, 0, 0, .5))'
    src: /assets/2025-09-21-switching-to-fido2/header.png
---

The recent supply chain attack campaign that compromised many popular npm packages,
such as [DuckDB](https://news.ycombinator.com/item?id=45179939), clearly shows us
that using phishing-resistant authentication methods is more of a necessity
than a nice-to-have nowadays.

An ideal credential is one that is either single-use or has a short validity timespan at most,
and requires some form of user presence verification.

I am not a high-profile package author, but I have been using my YubiKey as a WebAuthn passkey to
log into my GitHub and other important accounts for a while.
For pushing commits to GitHub, I have been using SSH authentication with GPG keys stored on the YubiKey too.

I recently decided to finally retire GPG for several compelling reasons:

- **Controversial Reputation:** GPG's suitability for modern applications is a topic of
  debate among some security experts, who often [advise against its use](https://www.latacora.com/blog/2019/07/16/the-pgp-problem/).
- **Compatibility Issues:** Using GPG for SSH authentication was impossible on my corporate
  laptop, as the company-provisioned certificates were incompatible with `gpg-agent`.
- **Redundancy in My Workflow:** I wasn't using GPG for its primary purpose.
  No, I don't encrypt my emails, sorry. For encrypting offline files, I have already transitioned to
  [age](https://github.com/FiloSottile/age) which I use with
  [SOPS](https://github.com/getsops/sops) whenever I need to commit secrets in public repositories.
- **Usability Concerns:** A [frustrating bug](https://dev.gnupg.org/T7072) that I
  encountered while generating new keys—present in popular distributions like
  Ubuntu 24.04 LTS—was the final straw.

The YubiKey 5 supports two other applications for SSH authentication: PIV and FIDO2. Since
**FIDO2**, is a modern, open standard for secure authentication developed
by the [FIDO Alliance](https://fidoalliance.org/), I chose that over PIV, which is an older
standard created by the US government.

This guide is for a very specific audience: those who want to set up FIDO2 authentication on macOS
using Nix. It's also useful for those who don't use Nix, but you will need to do some manual editing and
compiling.

## The Challenge: FIDO2 on macOS

There's a lengthy discussion about the [hurdles of trying to use OpenSSH with FIDO2 on macOS](https://github.com/Yubico/libfido2/issues/464).

**tl;dr**: At the time of writing, macOS Sequoia's native OpenSSH client does not have FIDO2 support compiled
in. FIDO2 support was entirely disabled in versions before Ventura, and newer versions still omit the
necessary library.

You could install a complete OpenSSH build from a package manager, but I chose to stick with the built-in version
to retain its native macOS Keychain integration.

The workaround, then, is to compile the standalone FIDO2 library from
[openssh-portable](https://github.com/openssh/openssh-portable) and convince the system's SSH binaries to use it.

## Step 1: Build the FIDO2 Middleware

A recently added
[build target in `openssh-portable`](https://github.com/openssh/openssh-portable/commit/ca0697a90e5720ba4d76cb0ae9d5572b5260a16c.patch)
makes it straightforward to compile just the FIDO2 support library.

I've created a Nix derivation in my
[dotfiles-common repo](https://github.com/dszakallas/dotfiles-common/blob/970c8dacdfdadd79544219e98ebc2418543434a9/pkgs/openssh-sk-standalone/default.nix)
to handle this process, so you can experiment in a shell with the following command:

```bash
nix shell github:dszakallas/dotfiles-common/970c8dacdfdadd79544219e98ebc2418543434a9/#openssh-sk-standalone
```

>💡 If you don't use Nix but use Homebrew, someone has created a tap; check out the discussion linked above.

## Step 2: Generate Your FIDO2-backed SSH Key

With the middleware installed, you can now generate a FIDO2-hosted key. Since the system's `ssh-keygen`
utility lacks built-in FIDO2 support, we must specify the path to our newly compiled library using the
`-w` flag.

> **-w provider**
> Specifies a path to a library that will be used when creating FIDO authenticator-hosted keys,
> overriding the default of using the internal USB HID support.

First, define a variable pointing to the library path, and then generate the key:

```bash
# Get the path to the library from your Nix profile
SSH_FIDO_LIB=$(nix profile list --json | jq -r '.elements."openssh-sk-standalone".storePaths[0]')/lib/sk-libfido2.dylib

# Generate an ed25519-sk key, using the library as the provider
ssh-keygen -w $SSH_FIDO_LIB -t ed25519-sk
```

> ⚠️ I am not a security expert. For a deep dive into best practices and the various options for key
> generation, I recommend reviewing the official documentation from Yubico and other community guides.
>
> - [Yubico: Securing SSH with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html)
> - [Karubits: Yubikey and FIDO2 SSH](https://karubits.com/posts/Yubikey-and-FIDO2-SSH/)
>

## Step 3: Configure the SSH Client

Let's assume you saved your new key to `~/.ssh/id_ed25519_sk`. After adding the public key to your
authorized keys on GitHub or another service, you can test the connection. The crucial step is to
tell the SSH client where to find the FIDO2 provider library using the `SecurityKeyProvider` option.

```bash
ssh -vT -i ~/.ssh/id_ed25519_sk \
  -o "IdentitiesOnly=yes" \
  -o "SecurityKeyProvider=$SSH_FIDO_LIB" \
  git@github.com
```

If the connection is successful, you can make this configuration permanent in your SSH config.
The following example shows how to achieve this using `home-manager` in a Nix configuration.

```nix
# home-manager configuration for ssh
# This generates the following snippet in ~/.ssh/config:
#
#  Match user git host github.com
#    IdentitiesOnly yes
#    IdentityFile ~/.ssh/id_ed25519_sk
#    AddKeysToAgent yes
#    SecurityKeyProvider /nix/store/...-openssh-sk-standalone-10.0p2/lib/sk-libfido2.dylib

{
  pkgs,
  openssh-sk-standalone,
  ...
}:
let
  standaloneFIDO2 = "${
    openssh-sk-standalone
  }/lib/sk-libfido2${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
in
{
  programs.ssh.matchBlocks."git@github.com" = {
    match = "user git host github.com";
    identitiesOnly = true;
    addKeysToAgent = "yes"; # For agent forwarding
    identityFile = "~/.ssh/id_ed25519_sk";
    extraOptions = {
      "SecurityKeyProvider" = standaloneFIDO2;
    };
  };
}
```

## Step 4: Configuring the SSH Agent

In the configuration above, `AddKeysToAgent yes` signals the intent to use the key with `ssh-agent`.
However, this is not enough to make it work, as running `ssh-add` with a FIDO2 key results in an error:

```bash
ssh-add -S "$SSH_FIDO_LIB" ~/.ssh/id_ed25519_sk
# --> Error: agent refused operation
```

Running `ssh-agent` with `-D` clearly shows that the library is refused to be loaded.
Reading the `ssh-agent` man page reveals why:

> **-P allowed_providers**
> Specify a pattern-list of acceptable paths for PKCS#11 provider and FIDO authenticator
> middleware shared libraries... Libraries that do not match the pattern list will be refused.
> The default list is “/usr/lib*/*,/usr/local/lib*/*”.

Since our library is located in the Nix store (`/nix/store/...`), the agent rejects it.
The immediate solution is to start a new agent with a modified allowlist:

```bash
eval $(ssh-agent -P $SSH_FIDO_LIB -s)
ssh-add -S $SSH_FIDO_LIB ~/.ssh/id_ed25519_sk
```

> 💡 If you'd rather confirm adding keys to the agent using a GUI prompt
> you might want to try [this small utility](https://github.com/theseal/ssh-askpass).

This works, but it's temporary. Making this change permanent on macOS is complicated because
the system-wide `ssh-agent` is protected by System Integrity Protection (SIP), and its
launchd plist at `/System/Library/LaunchAgents/com.openssh.ssh-agent.plist` cannot be modified.

My solution is admittedly a hack: disable the system agent and create a custom user agent
that reuses the original agent's socket path. This way, all applications continue to
work seamlessly.

Here is the `home-manager` configuration to create the replacement `launchd` agent:

```nix
{
  pkgs,
  lib,
  openssh-sk-standalone,
  ...
}:
let
  inherit (lib) concatStringsSep;
  standaloneFIDO2 = "${
    openssh-sk-standalone
  }/lib/sk-libfido2${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
in
{
  launchd.agents = {
    # This is a hacky way to redirect the default ssh-agent socket to our agent.
    # We can't use the standard system agent because we need to customize its
    # arguments to add our FIDO2 library to the allowlist.
    "ssh-agent" = {
      enable = true;
      config = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          (concatStringsSep " " [
            "rm -f $SSH_AUTH_SOCK;"
            "exec /usr/bin/ssh-agent"
            "-d"
            "-a $SSH_AUTH_SOCK"
            "-P ${standaloneFIDO2}"
          ])
        ];
        EnableTransactions = true;
        RunAtLoad = true;
      };
    };
  };
}
```

After applying this configuration, disable the default system agent for your user:

```bash
launchctl disable gui/$UID/com.openssh.ssh-agent
```

> ℹ️ There's no prompt message displayed for touch-only user presence verification when using the agent.

## Bonus: Signing Git Commits

Once SSH agent FIDO2 integration is set up, signing Git
commits is a breeze.

You can test it by signing an empty commit in a repository:

```bash
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519_sk.pub
git commit -S --allow-empty -m "My signed commit"
```

To set it up globally, you can follow the steps in the [official
YubiKey documentation](https://developers.yubico.com/SSH/Securing_git_with_SSH_and_FIDO2.html).

## Conclusion

While macOS does not yet offer a turnkey solution for FIDO2-based SSH authentication,
it is achievable with some effort, allowing us to migrate away from the aging GPG infrastructure.
