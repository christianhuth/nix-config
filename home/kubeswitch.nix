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

  # Familiar names from kubectx/kubens.
  #
  # Both deliberately point at the shell function `switch`, never at the
  # `switcher` binary. The binary only prints "__ <kubeconfig path>,<context>" on
  # stdout; it cannot touch the calling shell's environment. It is the function
  # that parses that and runs `export KUBECONFIG=...`. An alias to `switcher`
  # would therefore select a cluster and leave KUBECONFIG unset, which makes
  # kubectl fall back to localhost:8080 -- the failure upstream warns about when
  # it says not to call the binary directly.
  programs.bash.shellAliases = {
    kubectx = "switch";
    kubens = "switch namespace";
  };
}
