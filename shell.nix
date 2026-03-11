{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    gh
    scaleway-cli
    k9s
    kubectl
    jq
    fzf
    terraform
    python313Packages.pyyaml
    act
    packer
    bun
    uv
    argocd
  ];
}
