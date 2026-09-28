{
  config,
  lib,
  pkgs,
  ...
}:

let
  confDir = "${config.home.homeDirectory}/.wireguard";

  # Tunnels that should come up on their own. Everything not listed here gets
  # autoconnect disabled, and the setting is reconciled on every run -- not only
  # at import time -- so this list is the single source of truth.
  #
  # Currently empty: all tunnels are brought up by hand. All five configurations
  # are split tunnels (no default route), so running several at once would work,
  # but VPNs starting by themselves are surprising.
  autoconnect = [ ];

  # Rendered into the script below. `$name` has to be the case subject, not the
  # list -- with the list there, ShellCheck rightly flags SC2194 because the
  # subject would be a constant after Nix interpolation.
  autoconnectCase =
    if autoconnect == [ ] then
      "want=no"
    else
      ''
        case "$name" in
          ${lib.concatStringsSep "|" autoconnect}) want=yes ;;
          *) want=no ;;
        esac'';

  # Deliberately Ubuntu's nmcli, not nixpkgs'. nmcli talks to the running
  # NetworkManager over D-Bus, and the versions differ: Ubuntu runs 1.54.3 while
  # nixpkgs 26.05 ships 1.56.0. Matching the daemon is the safer choice -- the
  # same reasoning as for gpg and its agent.
  nmcli = "/usr/bin/nmcli";

  # The tunnel configurations hold WireGuard *private keys*, so they are
  # deliberately NOT moved into this repository: everything in /nix/store is
  # world-readable. They stay in ~/.wireguard, and Nix only orchestrates the
  # import. NetworkManager stores the imported profile under
  # /etc/NetworkManager/system-connections with mode 0600, root-owned, which is
  # stricter than the source file.
  importer = pkgs.writeShellApplication {
    name = "wireguard-nm-import";
    # Declared explicitly: PATH is only *prefixed* by writeShellApplication, so
    # an undeclared tool would silently fall through to Ubuntu's copy and break
    # the day that changes. nmcli is the deliberate exception -- see above.
    runtimeInputs = with pkgs; [
      coreutils # basename
      gawk # parsing nmcli's NAME:FILENAME output
    ];
    text = ''
      confDir=${lib.escapeShellArg confDir}
      nmcli=${lib.escapeShellArg nmcli}

      if [ ! -x "$nmcli" ]; then
        echo "wireguard: $nmcli not found -- is NetworkManager installed?" >&2
        exit 1
      fi
      # The directory is managed here; its contents deliberately are not.
      # `home.file` is unusable for it -- that would turn ~/.wireguard into a
      # symlink into the store, while the tunnel configurations have to stay
      # mutable and outside Nix. systemd.user.tmpfiles could do it too, but that
      # module installs four of nixpkgs' systemd units into ~/.config/systemd/user
      # plus a cleanup timer and runs `systemd-tmpfiles --remove`; that is a lot
      # of machinery, and cleanup semantics next to private keys, for one mkdir.
      #
      # Mode 0700 is enforced on every run, not just at creation: the files in
      # here hold WireGuard private keys.
      if [ ! -d "$confDir" ]; then
        echo "wireguard: creating $confDir"
      fi
      mkdir -p "$confDir"
      chmod 700 "$confDir"

      # NAME:FILENAME -- the filename reveals whether a profile is persistent
      # (/etc/...) or merely volatile (/run/..., i.e. tmpfs, gone after reboot).
      existing=$("$nmcli" -t -f NAME,FILENAME connection show 2>/dev/null || true)

      # nullglob matters: with an empty directory the pattern expands to nothing
      # and the loop simply does not run, instead of iterating over the literal
      # string "*.conf".
      shopt -s nullglob
      found=0
      for conf in "$confDir"/*.conf; do
        found=1
        name=$(basename "$conf" .conf)
        file=$(printf '%s\n' "$existing" | awk -F: -v n="$name" '$1 == n { print $2; exit }')

        ${autoconnectCase}

        if [ -n "$file" ]; then
          # Reconcile autoconnect for tunnels NetworkManager already knows, so
          # editing the list above is enough. The running state is deliberately
          # left alone here: autoconnect governs boot behaviour, and tearing down
          # a tunnel someone is using just because a switch ran would be hostile.
          # At import time it is different -- see below.
          current=$("$nmcli" -g connection.autoconnect connection show "$name" 2>/dev/null || true)
          if [ -n "$current" ] && [ "$current" != "$want" ]; then
            if "$nmcli" connection modify "$name" connection.autoconnect "$want"; then
              echo "wireguard: '$name' autoconnect $current -> $want"
            fi
          fi

          # Being under /run is NOT by itself a sign of trouble: Ubuntu lets
          # netplan own NetworkManager's profiles, so /etc/netplan holds the
          # source and /run only the render. Those renders are named
          # "netplan-<something>". A file in /run *without* that prefix has no
          # netplan source and therefore exists in tmpfs only.
          case "$file" in
            /run/*)
              case "$(basename "$file")" in
                netplan-*)
                  echo "wireguard: '$name' already known to NetworkManager, skipping"
                  ;;
                *)
                  echo "wireguard: '$name' exists but only in $file -- tmpfs with no" >&2
                  echo "           netplan source, so it will be gone after a reboot." >&2
                  echo "           To make it persistent:" >&2
                  echo "             nmcli connection delete $name && wireguard-nm-import" >&2
                  ;;
              esac
              ;;
            *)
              echo "wireguard: '$name' already known to NetworkManager, skipping"
              ;;
          esac
          continue
        fi

        if "$nmcli" connection import type wireguard file "$conf" >/dev/null; then
          "$nmcli" connection modify "$name" connection.autoconnect "$want" || true

          # `nmcli connection import` brings the tunnel up immediately: at that
          # moment the profile's autoconnect is still at its default of yes, so
          # NetworkManager activates it. Setting autoconnect afterwards only
          # affects later boots and leaves the running tunnel up, so anything
          # that should not be running has to be taken down explicitly.
          if [ "$want" = no ]; then
            "$nmcli" connection down "$name" >/dev/null 2>&1 || true
            echo "wireguard: imported '$name' (autoconnect=no, brought down again)"
          else
            echo "wireguard: imported '$name' (autoconnect=yes, left running)"
          fi
        else
          echo "wireguard: failed to import '$name'" >&2
        fi
      done

      if [ "$found" -eq 0 ]; then
        echo "wireguard: no *.conf files in $confDir, nothing to import"
      fi
    '';
  };
in
{
  home.packages = [
    # Provides `wg` and `wg-quick`. Still useful alongside NetworkManager:
    # `wg show` is the quickest way to inspect a live tunnel's handshakes and
    # transfer counters. Bringing tunnels up is NetworkManager's job now.
    pkgs.wireguard-tools

    # Also exposed as a command so a newly dropped .conf can be picked up
    # without a full `home-manager switch`.
    importer
  ];

  # Runs on every switch. Idempotent -- it skips anything NetworkManager already
  # knows -- and `|| true` keeps a failure from aborting the activation.
  home.activation.wireguardImport = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe importer} || true
  '';
}
