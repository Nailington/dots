# Back-compat shim — prefer importing tailscale.nix / mullvad.nix separately.
# Desktop hosts that want both can keep this single import.
{
  imports = [
    ./tailscale.nix
    ./mullvad.nix
  ];
}
