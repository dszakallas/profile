{
  pkgs,
  ...
}:
{
  module = {
    packages = [ pkgs.texliveFull ];
  };
}
