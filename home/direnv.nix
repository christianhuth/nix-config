{ ... }:

{
  programs.direnv = {
    enable = true; # installs direnv itself

    # Replaces direnv's own use_nix/use_flake with nix-direnv's implementation.
    # It caches the evaluated environment and anchors it as a GC root, so
    # entering a project directory does not re-evaluate every time, and
    # `nix-collect-garbage` cannot remove the result from under it.
    nix-direnv.enable = true;

    # Appends `eval "$(direnv hook bash)"` to the generated ~/.bashrc -- via
    # mkAfter, so it lands after anything that manipulates the prompt. Depends on
    # home/bash.nix owning that file.
    enableBashIntegration = true;

    # Deliberately not set yet: `silent = true` would add log_format = "-" and
    # log_filter = "^$" to direnv.toml, which stops it from printing the loaded
    # variables on every directory change. Left off until it has been seen how
    # chatty it actually is in practice.
  };
}
