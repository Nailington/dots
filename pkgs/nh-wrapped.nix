# nh that runs sync-age-recipients before os/darwin switch (Linux + Darwin).
{ pkgs, syncAgeRecipientsText }:
let
  sync-age-recipients = pkgs.writeShellApplication {
    name = "sync-age-recipients";
    runtimeInputs = with pkgs; [
      age
      curl
      git
      openssh
      nix
      python3
      findutils
      coreutils
    ];
    text = syncAgeRecipientsText;
  };
in
{
  inherit sync-age-recipients;
  nh = pkgs.writeShellApplication {
    name = "nh";
    runtimeInputs = [ sync-age-recipients ];
    text = ''
      if [[ -z "''${SYNC_AGE_DONE:-}" ]]; then
        case "''${1:-} ''${2:-}" in
          "os switch" | "os boot" | "os test" | "darwin switch")
            export SYNC_AGE_DONE=1
            sync-age-recipients || exit $?
            ;;
        esac
      fi
      exec ${pkgs.lib.getExe pkgs.nh} "$@"
    '';
  };
}
