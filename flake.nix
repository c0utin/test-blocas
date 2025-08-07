{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, fenix }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in {
      devShells = eachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ fenix.overlays.default ];
          };

          lib = pkgs.lib;

          toolchain = fenix.packages.${system}.stable.withComponents [
            "rustc"
            "cargo"
            "rustfmt"
            "clippy"
            "rust-src"
          ];

        in {
          default = pkgs.mkShell {
            name = "test-blocas-dev";

            nativeBuildInputs = with pkgs; [
              pkg-config
              toolchain
              solc
              vyper
              dprint
              nodejs
              foundry
            ] ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.AppKit
            ];

            shellHook = ''
              echo "Welcome to test-blocas dev shell 🦀"
              export RUST_SRC_PATH="${toolchain}/lib/rustlib/src/rust/library"
              export LD_LIBRARY_PATH="${lib.makeLibraryPath [ pkgs.libusb1 ]}"
              export CFLAGS="-DJEMALLOC_STRERROR_R_RETURNS_CHAR_WITH_GNU_SOURCE"
            '';
          };
        });
    };
}
