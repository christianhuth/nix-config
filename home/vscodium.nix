{ pkgs, ... }:

{
  # Important: VSCodium has its OWN module. As of Home Manager 26.05,
  # `programs.vscode` always writes to the real VS Code paths (~/.vscode)
  # and only warns if you point its `package` at vscodium.
  programs.vscodium = {
    enable = true; # installs VSCodium itself

    # Since Home Manager 25.05 these options live under profiles.<name>.
    # Sorted by publisher, purely so additions have an obvious place to go.
    profiles.default.extensions = with pkgs.vscode-extensions; [
      anthropic.claude-code
      eamodio.gitlens
      ms-kubernetes-tools.vscode-kubernetes-tools
    ];
  };
}
