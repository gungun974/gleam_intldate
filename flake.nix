{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    in {
      devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.gleam
          pkgs.erlang
          pkgs.rebar3
          pkgs.icu78
          pkgs.pkg-config
          pkgs.nodejs
        ];
      };
    });
}
