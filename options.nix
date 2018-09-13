{ lib, config, ... }:
with lib;

let
  stdOptions = (import ./active/lib/stdOptions.nix) {inherit lib; inherit config;};
  # select the most recent implementation as default, keep the others for backward compatibility
  allActiveTargets = (import ./client_active_targets.nix) lib config;
  passive = (import ./passive_targets.nix) { inherit config; inherit lib; };
in
{
  options = {
    active = mkOption {
      description = ''A list of active monitoring target checks'';
      default = {};
      type = types.submodule {
        #transformes all active client targets.
        options = fold (e: c: { "${e}" = allActiveTargets.${e}.${e}; } // c) {} (attrNames allActiveTargets);
      };
    };
    inherit passive;
  };
}
