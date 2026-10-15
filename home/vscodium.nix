{ config, pkgs, ... }:

{
  # Important: VSCodium has its OWN module. As of Home Manager 26.05,
  # `programs.vscode` always writes to the real VS Code paths (~/.vscode)
  # and only warns if you point its `package` at vscodium.
  programs.vscodium = {
    enable = true; # installs VSCodium itself

    # This is the setting that makes the extension list actually hold.
    #
    # Its default is true whenever only the `default` profile is used, and it
    # means what it says: "whether extensions can be installed or updated
    # manually or by VSCodium". VSCodium took that literally -- it fetched newer
    # marketplace builds, and since /nix/store is read-only it could not update
    # in place, so it installed parallel copies and wrote the Nix-provided ones
    # into ~/.vscode-oss/extensions/.obsolete:
    #
    #   { "anthropic.claude-code-2.1.223": true,
    #     "ms-kubernetes-tools.vscode-kubernetes-tools-1.3.29": true,
    #     "eamodio.gitlens-17.11.1": true }
    #
    # Net effect: the declared extensions were disabled, and the one with no
    # marketplace replacement (kubernetes-tools) vanished entirely.
    #
    # With false, Home Manager owns the whole extensions directory as a single
    # store path. VSCodium cannot install or update anything there -- which is
    # only tolerable because the versions below are current, see flake.nix.
    mutableExtensionsDir = false;

    # From nix-vscode-extensions, not pkgs.vscode-extensions. The `-release`
    # channel on purpose: the plain `open-vsx` set also carries pre-releases,
    # which for gitlens means a date-versioned build (2026.9.250515) instead of
    # the 19.2.0 release. Open VSX rather than vscode-marketplace because the
    # latter's terms cover Microsoft products, which VSCodium is not.
    #
    # Sorted by publisher, purely so additions have an obvious place to go.
    profiles.default.extensions = with pkgs.open-vsx-release; [
      anthropic.claude-code
      eamodio.gitlens

      # Powers the containerlab topology editor (hence its drawioDefaultTheme
      # setting). Listed in that extension's `extensionPack`, so VSCodium would
      # normally pull it in on install -- it cannot here, because
      # mutableExtensionsDir = false makes the extensions directory a read-only
      # store path. Everything a declared extension needs has to be declared too.
      hediet.vscode-drawio

      ms-kubernetes-tools.vscode-kubernetes-tools

      # Not optional: ms-kubernetes-tools declares this in
      # `extensionDependencies`, which VSCodium enforces at activation time --
      # without it the Kubernetes extension refuses to start with
      #   Cannot activate the 'Kubernetes' extension because it depends on the
      #   'YAML' extension from 'Red Hat', which is not installed.
      # srl-labs.vscode-containerlab also lists it, in its extensionPack.
      redhat.vscode-yaml

      # 0.26.3. Needs `vscode ^1.105.1` per its engines field -- satisfied by
      # 26.05's VSCodium 1.116. It is only a front end for the containerlab CLI,
      # which this repository deliberately does NOT install; see
      # home/containerlab.nix for the SUID and group reasons.
      srl-labs.vscode-containerlab
    ];

    # Nix owns ~/.config/VSCodium/User/settings.json from here on, which means
    # VSCodium can no longer save setting changes made through its UI -- the file
    # becomes a read-only store symlink. New settings go in this list followed by
    # a switch. The five entries below were carried over verbatim from what was
    # there before, so nothing is lost.
    profiles.default = {
      userSettings = {
        # The reason this file is managed at all: the integrated terminal has its
        # own font setting, entirely separate from Ptyxis (which home/fonts.nix
        # handles through dconf). Without it the starship prompt renders its
        # powerline separators and Nerd Font icons as replacement boxes in
        # VSCodium's terminal while looking correct in Ptyxis.
        "terminal.integrated.fontFamily" = "'FiraCode Nerd Font Mono', monospace";

        # Claude in the right-hand secondary side bar, full height. The
        # extension's own enum is ['sidebar', 'panel'] with descriptions
        # "Sidebar (Right)" and "Panel (New Tab)"; `panel` was opening it as an
        # editor tab, which put it beside the editor and made the terminal span
        # underneath both.
        #
        # Careful: the extension documents this setting as one it "updates
        # automatically when you open Claude in a new location" -- and it cannot,
        # because settings.json is a read-only store symlink here. Moving Claude
        # through the UI will not stick; this value is the source of truth.
        "claudeCode.preferredLocation" = "sidebar";

        # The extension checks github for a newer containerlab release and offers
        # to run `curl -sL https://containerlab.dev/setup | sudo bash -s all`.
        # Harmless to decline, but the prompt is noise on a machine where the CLI
        # is managed outside VSCodium either way.
        "containerlab.skipUpdateCheck" = true;

        # Pre-existing, kept as they were.
        "claudeCode.focusView" = false;
        "claudeCode.hideOnboarding" = true;
        "explorer.confirmDelete" = false;
        "explorer.confirmDragAndDrop" = false;
      };

      # With mutableExtensionsDir = false there is nothing VSCodium could do with
      # a discovered update, so the check is only a prompt it cannot act on.
      enableExtensionUpdateCheck = false;

      # Same reasoning for VSCodium itself: its version comes from nixpkgs.
      enableUpdateCheck = false;
    };
  };

  # The existing settings.json is a real file that VSCodium keeps writing to -- it
  # had gained an `explorer.confirmDelete` entry between two looks -- so Home
  # Manager refuses to replace it:
  #   Existing file '~/.config/VSCodium/User/settings.json' would be clobbered
  # Forcing it hands ownership over now. Nothing is lost: every key that was in
  # the file is listed in userSettings above.
  # Note the absolute path: the module registers this file under
  # "${config.xdg.configHome}/VSCodium/User/settings.json", and home.file entries
  # are keyed by that string. Using the relative ".config/..." form creates a
  # second entry pointing at the same target, which Home Manager rejects with
  # "Conflicting managed target files".
  home.file."${config.xdg.configHome}/VSCodium/User/settings.json".force = true;
}
