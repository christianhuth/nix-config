{ ... }:

{
  # kubeswitch ships only the `switcher` binary, and upstream is explicit that
  # it must not be called directly -- the actual command is a shell function,
  # because changing KUBECONFIG in the current shell cannot be done by a child
  # process. This module generates that function plus completions and wires
  # them into programs.bash, which is why home/bash.nix has to be enabled.
  programs.kubeswitch = {
    enable = true;

    # The module would default to "kswitch". Upstream's own shell function is
    # called "switch", so its documentation matches this name.
    commandName = "switch";

    # `settings` would be written to ~/.kube/switch-config.yaml and is where
    # kubeconfig stores go (filesystem paths, Gardener, CAPI, Vault, ...).
    # Left out for now; without it kubeswitch uses its defaults.
  };
}
