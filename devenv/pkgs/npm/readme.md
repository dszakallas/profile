# node2nix-pkgs

Nix packages derived from npm with [node2nix](https://github.com/svanderburg/node2nix).

Add new stuff to `node-packages.json` and regenerate nix expressions with:

```bash
nix shell nixpkgs#node2nix --command node2nix \
  -i node-packages.json \
  -c _default.nix \
  -e _node-env.nix \
  -o _node-packages.nix
```
