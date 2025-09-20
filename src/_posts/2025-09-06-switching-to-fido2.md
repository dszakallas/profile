---
layout: article
title: Switching from GPG to FIDO2
key: 2025-09-06-switching-to-fido2
tags:
  - nix
  - ssh
  - macOS
  - yubikey
excerpt: "Not a turn-key solution yet."
article_header:
  type: overlay
  theme: dark
---

- Argue that hardware keys are essential in today's world of sophisticated cyber attacks

 https://socket.dev/blog/duckdb-npm-account-compromised-in-continuing-supply-chain-attack


Pesronally I have been using GPG on my Yubikey for GitHub SSH auth for quite a while.

Namely I had 3 keys (Authentication, Signing and Encryption) stored on my yubikey.

I was using the authentication key for SSH into my personal GitHub account, as well as to personal devices.

For that I had been running GPG agent with SSH support.

My signing key was used to sign my commits.

For work on remote devices, I was forwarding my GPG agent.

A few weeks ago, I finally decided to ditch GPG for good. Reasons:
- GPG has a bad rep. Security experts recommend to stay away from it if you can (link!)
- SSH authentication with GPG, was infeasible in my corporate notebook, where corp provisioned certificates are incompatible with gpg-agent
- I was not using GPG for anything else. I am using age (link!) for asymmetric encryption
  of secrets with SOPS (link!)
- A recent bug in GPG that I encountered when recently generating new keys really put me off https://dev.gnupg.org/T7072

Yubikey support to other apps that can be used for SSH auth:
- PIV, which I decided to not to use after learning about the ECDSA scandal of FIPS (link!)
- FIDO2: a modern standard for secure key authentication developed by the open industry association FIDO Alliance (link!)

# Switching SSH to FIDO2 on my mac


At the time of writing I am using Sequoia, which doesn't have builtin FIDO2 support for openssh. According to reports on the internet, in older macOS versions (before Ventura), the fido2 support is entirely disabled: https://github.com/Yubico/libfido2/issues/464, however in newer versions the required securekey library is still not compiled in. 

An alternative would be to install a compatible openssh with my package manager, but I decided to use the built-in openssh nevertheless, to keep the macOS KeyChain support.

To use libfido2 with macOS's built-in openssh, we need to compile the standalone secure key
library from openssh-portable. A handy build target was recently contributed for this purpose
(https://github.com/openssh/openssh-portable/commit/ca0697a90e5720ba4d76cb0ae9d5572b5260a16c.patch). My nix derivation for this is here https://github.com/dszakallas/dotfiles-common/blob/970c8dacdfdadd79544219e98ebc2418543434a9/pkgs/openssh-sk-standalone/default.nix

# Generating keys

For experimenting we can use `nix profile`. Later you can add to your persistent config.

So to install it to your current Nix profile, run:

```bash
nix profile install github:dszakallas/dotfiles-common/970c8dacdfdadd79544219e98ebc2418543434a9/#openssh-sk-standalone
```

The built-in `ssh-keygen` utility does not have the FIDO2 support compiled in but we can
use the `-w` switch to specify the provider we just installed.

>        -w provider
>               Specifies a path to a library that will be used when creating FIDO authenticator-hosted keys, overriding the default of using the internal  USB  HID
>               support.

```nix
SSH_FIDO_LIB=$(nix profile list --json | jq -r '.elements."openssh-sk-standalone".storePaths[0]')/lib/sk-libfido2.dylib
ssh-keygen -w $SSH_FIDO_LIB -t ed25519-sk
```

> [!Note]
> I am not a security expert and I do not focus on best practices on various options
> when generating keys. Take a look at https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html and https://karubits.com/posts/Yubikey-and-FIDO2-SSH/

## Using with the ssh client with GitHub

Let's say we generated the file at `~/.ssh/id_ed25519_sk`.
After adding the public key to GitHub, we can test that it is working.
The critical step is setting `SecurityKeyProvider` to the lib. 

```bash
ssh -vT -i ~/.ssh/id_ed25519_sk \
  -o "IdentitiesOnly=yes" \
  -o "SecurityKeyProvider=$SSH_FIDO_LIB" \
  git@github.com
```

If this is OK, we are ready to add to the SSH config, for example in
our home-manager configuration

```nix
# home-manager configuration for ssh
# results in something like:
#  ```
#  Match user git host github.com
#    IdentitiesOnly yes
#    IdentityFile ~/.ssh/id_ed25519_sk
#    AddKeysToAgent yes
#    SecurityKeyProvider /nix/store/a9b7xl9451myk0pfg85hpmqgcisblarc-openssh-sk-standalone-10.0p2/lib/sk-libfido2.dylib
#  ``` 
{
  pkgs,
  openssh-sk-standalone,
  ...
}
let
  standaloneFIDO2 = "${
    openssh-sk-standalone
  }/lib/sk-libfido2${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
in 
{
  programs.ssh.matchBlocks."git@github.com" = {
    match = "user git host github.com";
    identitiesOnly = true;
    addKeysToAgent = "yes"; # I want to use this remotely
    identityFile = "~/.ssh/id_ed25519_sk"; 
    extraOptions = {
      "SecurityKeyProvider" = standaloneFIDO2;
    };
  };
}
```

### Using remotely

In the previous step, I specified `AddKeysToAgent yes`, but this is not enough.
Indeed when calling 

```bash
ssh-add -S "$SSH_FIDO_LIB" ~/.ssh/id_ed25519_sk
```

We receive an error `agent refused operation`. The reason is apparent after reading the man pages of `ssh-agent`:

>       -P allowed_providers
>               Specify a pattern-list of acceptable paths for PKCS#11 provider and FIDO authenticator middleware shared libraries that may be used with the  -S  or
>               -s  options  to  ssh-add(1).  Libraries that do not match the pattern list will be refused.  See PATTERNS in ssh_config(5) for a description of pat‐
>               tern-list syntax.  The default list is “usr/lib*/*,/usr/local/lib*/*”.

So our lib is not any of the allowed paths. The solution is to run ssh-agent specifying the correct path:

```bash
eval $(ssh-agent -P $SSH_FIDO_LIB -s)
ssh-add -S $SSH_FIDO_LIB ~/.ssh/id_ed25519_sk
```

This should work.

The question is, how to set this for the whole system? Unfortunately the system-wide ssh-agent is under SIP, so it's better not to edit `/System/Library/LaunchAgents/com.openssh.ssh-agent.plist`.

What we can do is disable that agent, but reuse its socket for ours. This is admittedly a very hacky solution, but I couldn't find a better way.

Once again, using home-manager,

```nix
{
  pkgs,
  lib,
  openssh-sk-standalone,
  ...
}
let
  inherit (lib)
    concatStringsSep;
  standaloneFIDO2 = "${
    openssh-sk-standalone
  }/lib/sk-libfido2${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
in
{
  launchd.agents = {
    # Uber-hacky way to redirect the default ssh-agent socket to our agent
    # We can't use the standard /System/Library/LaunchAgents/com.openssh.ssh-agent.plist
    # because we need to customize the arguments to support FIDO2
    # SSH_AUTH_SOCK will always be allocated (unless someone turned off SIP and unloaded the system ssh-agent)
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

after applying this configuration run

```bash
launchctl disable gui/$UID/com.openssh.ssh-agent
```

and log in / log out.
