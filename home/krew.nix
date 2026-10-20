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
  home.packages = [ pkgs.krew ]; # krew itself; the plugins are handled below

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
