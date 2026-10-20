{
  config,
  lib,
  pkgs,
  ...
}:

let
  krewRoot = "${config.home.homeDirectory}/.krew";

  # Heads up: this list is the one deliberately NON-declarative part of this
  # configuration. krew fetches its plugins from its own index at runtime, so
  # the result depends on when you run it. See README.md, section "krew".
  # Removing a name from this list does NOT uninstall the plugin: the activation
  # only ever installs, deliberately, so a switch cannot tear tooling out from
  # under a running shell. Clean up by hand with `krew uninstall <name>`.
  #
  # Plugins that exist in nixpkgs under the *same binary name* were moved to
  # home/default.nix -- explore, tree and view-secret. krew installs those as
  # kubectl-explore, kubectl-tree and kubectl-view_secret, and nixpkgs ships
  # exactly those names, so nothing changes about how they are invoked; they are
  # simply part of the generation now instead of a download on every activation.
  #
  # Everything left here has either no nixpkgs package (get-all, rbac-lookup,
  # rbac-view, rolesum, topology, who-can, whoami) or one whose binary is named
  # differently -- rakkess, kubepug, df-pv, kubelogin, kube-capacity, stern,
  # kail. Moving those would trade `kubectl stern` for `stern`, which is a change
  # to how the command is typed, not a packaging detail.
  plugins = [
    "access-matrix"
    "deprecations"
    "df-pv"
    "get-all"
    "oidc-login"
    "rbac-lookup"
    "rbac-view"
    "resource-capacity"
    "rolesum"
    "stern"
    "tail"
    "topology"
    "virt"
    "who-can"
    "whoami"
  ];
in
{
  # krew itself; the plugins are handled below.
  #
  # Note it is invoked as `krew`, NOT `kubectl krew`. Upstream's installer puts
  # krew in ~/.krew/bin as kubectl-krew, which makes it a kubectl plugin;
  # pkgs.krew just provides a binary called `krew`, so
  #
  #   kubectl krew uninstall tree
  #   error: unknown command "krew" for "kubectl"
  #
  # The working form is `krew uninstall tree`. KREW_ROOT does not need setting by
  # hand -- it defaults to ~/.krew, which is what krewRoot above resolves to --
  # but the activation sets it explicitly so the two can never drift.
  home.packages = [ pkgs.krew ];

  # kubectl discovers its plugins purely through PATH.
  home.sessionPath = [ "${krewRoot}/bin" ];

  # Runs on every `home-manager switch`. Idempotent, and it does not abort the
  # switch when you happen to be offline.
  home.activation.krewPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export KREW_ROOT=${lib.escapeShellArg krewRoot}
    krew=${lib.getExe pkgs.krew}

    if ! "$krew" update >/dev/null 2>&1; then
      echo "krew: index update failed (offline?) -- skipping plugins."
    else
      for p in ${lib.escapeShellArgs plugins}; do
        # krew writes a "receipt" for every installed plugin.
        if [ -f "$KREW_ROOT/receipts/$p.yaml" ]; then
          continue
        fi
        run "$krew" install "$p" || echo "krew: could not install plugin '$p'."
      done
    fi
  '';
}
