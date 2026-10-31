{ lib, codexModuleRoot }:
let
  originalLib = builtins.readFile "${codexModuleRoot}/lib.nix";
  sourceBefore = ''path = "./''${homeRelativePluginsCacheDir}/''${pluginsMarketplaceName}/''${mkPluginPathName plugin}/''${mkPluginPathVersion plugin}";'';
  sourceAfter = ''path = if plugin ? codexLocalSource then toString plugin.codexLocalSource else "./''${homeRelativePluginsCacheDir}/''${pluginsMarketplaceName}/''${mkPluginPathName plugin}/''${mkPluginPathVersion plugin}";'';
  once = needle: text: builtins.length (lib.splitString needle text) == 2;
  patchedLib = builtins.toFile "codex-local-source-lib.nix" (
    assert once sourceBefore originalLib;
    builtins.replaceStrings [ sourceBefore ] [ sourceAfter ] originalLib
  );
  originalModule = builtins.readFile "${codexModuleRoot}/default.nix";
  cleanupBefore = "              ) staticPluginEntries)";
  cleanupAfter = "              ) (lib.filter (entry: !(entry.plugin ? codexLocalSource)) staticPluginEntries))";
  paths = [
    "./lib.nix"
    "./options.nix"
    "./normalize-plugins.py"
  ];
in
assert once cleanupBefore originalModule;
assert builtins.all (path: once path originalModule) paths;
builtins.toFile "codex-local-source-module.nix" (
  builtins.replaceStrings (paths ++ [ cleanupBefore ]) [
    (toString patchedLib)
    "${codexModuleRoot}/options.nix"
    "${codexModuleRoot}/normalize-plugins.py"
    cleanupAfter
  ] originalModule
)
