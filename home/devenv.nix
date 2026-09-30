{ pkgs, ... }:

{
  home.packages = [
    # From nixos-unstable via pkgs/overlay.nix, not from 26.05 -- see the comment
    # there. Also provides `devenv-proxy`, `devenv-run-tests` and `secretspec`.
    pkgs.devenv
  ];

  # Deliberately NOT wired into direnv's lib/ directory, even though `devenv
  # direnvrc` exists and that is where home/direnv.nix puts nix-direnv's
  # equivalent.
  #
  # devenv's direnvrc says of itself "adapted from nix-community/nix-direnv", and
  # it redefines three of nix-direnv's functions:
  #
  #   _nix_direnv_preflight
  #   _nix_export_or_unset
  #   _nix_import_env
  #
  # direnv sources ~/.config/direnv/lib/*.sh in glob order, so whichever file
  # sorts last wins for all three. Either order breaks something: with devenv
  # first, `use_devenv` silently runs nix-direnv's preflight (which checks for
  # `nix`, not `devenv`, and sets up nix-direnv-reload); with devenv last, the
  # `use flake` that this repository itself relies on loses its own helpers.
  #
  # So devenv's direnvrc belongs in the .envrc of the project that wants it, where
  # its definitions are scoped to that evaluation:
  #
  #   source_url "https://raw.githubusercontent.com/cachix/devenv/v2.4.0/direnvrc" \
  #     "sha256-..."
  #   use devenv
  #
  # A project uses either `use flake` or `use devenv`, never both, so scoping it
  # per project costs nothing.
  #
  # One optional system-level step: devenv's documentation recommends adding
  # https://devenv.cachix.org as a substituter. That cannot be done from here --
  # `nix config show trusted-users` is `root` only, so a non-root user's
  # substituters are ignored. It needs /etc/nix/nix.conf and is worth doing only if
  # devenv turns out to build a lot locally; devenv itself comes prebuilt from
  # cache.nixos.org.
}
