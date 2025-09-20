# [profile](https://szakallas.net/)

## Install

Install Nix and devenv.sh

## Development

Spin up development environment with live regen:

```bash
devenv up -d
```

Site is available at `http://localhost:4000`.

## Build the site

```bash
devenv build outputs.staging
devenv build outputs.producion
```

### Update dependencies

```bash
bundle update
bundix
```
