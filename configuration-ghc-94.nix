{ pkgs, inputs, ghc-lib ? false }:

let
  disabledPlugins = [
    # That one is not technically a plugin, but by putting it in this list, we
    # get it removed from the top level list of requirement and it is not pull
    # in the nix shell.
    "shake-bench"
  ];
  ghc-lib-opt = if ghc-lib then "-fghc-lib" else "-f-ghc-lib";

  hpkgsOverride = hself: hsuper:
    with pkgs.haskell.lib;
    {
      hlsDisabledPlugins = disabledPlugins;
    } // (builtins.mapAttrs (_: drv: disableLibraryProfiling drv) {
      apply-refact = dontCheck (hself.callCabal2nix "apply-refact" inputs.apply-refact {});

      fourmolu = dontCheck (hself.callCabal2nix "fourmolu" inputs.fourmolu-011 {});

      stylish-haskell = appendConfigureFlag hsuper.stylish-haskell ghc-lib-opt;

      ghc-lib-parser-ex = appendConfigureFlag hsuper.ghc-lib-parser-ex (if ghc-lib then "-f-no-ghc-lib" else "-fno-ghc-lib");
      hlint = hself.callCabal2nixWithOptions "hlint" inputs.hlint-35 ghc-lib-opt {};

      hls-hlint-plugin =
        hself.callCabal2nixWithOptions "hls-hlint-plugin" ./plugins/hls-hlint-plugin
        (pkgs.lib.concatStringsSep " " [ "--no-check" ghc-lib-opt ]) { };

      lsp = hself.callCabal2nix "lsp" inputs.lsp {};
      lsp-types = hself.callCabal2nix "lsp-types" inputs.lsp-types {};
      lsp-test = dontCheck (hself.callCabal2nix "lsp-test" inputs.lsp-test {});

      # Re-generate HLS drv excluding some plugins
      haskell-language-server =
        hself.callCabal2nixWithOptions "haskell-language-server" ./.
        # Pedantic cannot be used due to -Werror=unused-top-binds
        # Check must be disabled due to some missing required files
        (pkgs.lib.concatStringsSep " " [ "--no-check" "-f-pedantic" ]) { };
    });
in {
  inherit disabledPlugins;
  tweakHpkgs = hpkgs: hpkgs.extend hpkgsOverride;
}
