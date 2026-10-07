# Run the key sync BEFORE nh builds/applies the configuration, so it sees fresh keys.
# os switch/boot/test and darwin switch can therefore re-encrypt, commit and push.
# SYNC_AGE_DONE prevents repeated syncs in the same inherited environment.
# See docs/agents/secrets-and-ssh.md.
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
      diffutils
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
