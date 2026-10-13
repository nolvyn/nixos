{
  upstream ? builtins.getFlake "github:nix-community/nixos-anywhere",
  system ? builtins.currentSystem,
}:
let
  installer = upstream.packages.${system}.default;
  inherit (upstream.inputs.nixpkgs) lib;
  original = ''declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere" "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no")'';
  replacement = ''
    : "''${NIXOS_ANYWHERE_KNOWN_HOSTS:?verified known-hosts file is required}"
    [[ -r $NIXOS_ANYWHERE_KNOWN_HOSTS ]] || exit 1
    declare -a sshArgs=(
      -o StrictHostKeyChecking=yes
      -o "UserKnownHostsFile=$NIXOS_ANYWHERE_KNOWN_HOSTS"
      -o GlobalKnownHostsFile=/dev/null
      -o KnownHostsCommand=none
      -o VerifyHostKeyDNS=no
      -o NoHostAuthenticationForLocalhost=no
      -o HostKeyAlgorithms=ssh-ed25519
      -o HostKeyAlias=nixos-anywhere-verified
      -o CheckHostIP=no
      -o UpdateHostKeys=no
      -o ControlPath=none
      -o IdentitiesOnly=yes
      -i "$tempDir/nixos-anywhere"
    )
  '';
in
installer.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    # OpenSSH takes the first value. Enforce authentication at the shared array,
    # before upstream/user options, and fail closed if this upstream seam drifts.
    test "$(grep -Fxc -- ${lib.escapeShellArg original} src/nixos-anywhere.sh)" -eq 1
    substituteInPlace src/nixos-anywhere.sh \
      --replace-fail ${lib.escapeShellArg original} ${lib.escapeShellArg replacement}
  '';
})
