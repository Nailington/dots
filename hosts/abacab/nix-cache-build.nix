{ config, pkgs, ... }:

{
  # Prebuild main only after updates have merged (or found no changes).
  # Each output link is a GC root; retain three successful revisions per client.
  systemd.services.nix-cache-build = {
    description = "Prebuild flake clients for abacab's binary cache";
    wants = [ "network-online.target" ];
    requires = [ "nix-flake-update.service" ];
    after = [ "network-online.target" "nix-flake-update.service" ];
    path = [ pkgs.git pkgs.gh pkgs.nix pkgs.coreutils pkgs.findutils ];
    environment.HOME = "/var/lib/nix-cache-build";
    serviceConfig = {
      Type = "oneshot";
      User = "potter";
      Group = "users";
      StateDirectory = "nix-cache-build";
      WorkingDirectory = "/var/lib/nix-cache-build";
      LoadCredential = "github-token:${config.age.secrets.github-automation.path}";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "infinity";
    };
    script = ''
      set -euo pipefail
      if [ ! -d checkout/.git ]; then
        git clone --depth 1 --branch main https://github.com/Nailington/dots.git checkout
      fi
      git -C checkout fetch --depth 1 origin main
      git -C checkout checkout --detach FETCH_HEAD
      revision=$(git -C checkout rev-parse HEAD)
      stamp=$(date -u +%Y%m%dT%H%M%S%N)
      report_build_failure() {
        local host="$1" title issue token body
        title="Cache build failed: $host at $revision"
        token=$(cat "$CREDENTIALS_DIRECTORY/github-token") || return 1
        issue=$(GH_TOKEN="$token" gh issue list --repo Nailington/dots --state open \
          --search "\"$title\" in:title" --json number --jq '.[0].number // empty') || return 1
        if [ -n "$issue" ]; then
          echo "Build failure already reported in issue #$issue; not tagging again."
          return 0
        fi
        body="$PWD/build-failure-$host-$revision.md"
        {
          printf '@HammerPot @Nailington — please review this failed cache build.\n\n'
          printf 'Host: %s\nCommit: https://github.com/Nailington/dots/commit/%s\n' "$host" "$revision"
          printf '\nThe system was not activated. Previous successful cache roots are preserved.\n'
          printf '\nLogs on abacab: sudo journalctl -u nix-cache-build.service\n'
        } > "$body"
        GH_TOKEN="$token" gh issue create --repo Nailington/dots --title "$title" \
          --body-file "$body" --assignee HammerPot --assignee Nailington
      }
      failed=0
      for host in roundabout custard; do
        mkdir -p "roots/$host"
        output="$PWD/roots/$host/$stamp-$revision"
        if nix build --no-update-lock-file --max-jobs 2 --cores 3 \
          --out-link "$output" \
          "./checkout#nixosConfigurations.$host.config.system.build.toplevel"; then
          # Only prune this host after a successful build; failures keep old roots.
          find "roots/$host" -maxdepth 1 -type l -printf '%f\n' \
            | sort -r | tail -n +4 \
            | while IFS= read -r old; do rm -- "roots/$host/$old"; done
        else
          failed=1
          # Merged PRs cannot request another review; report a build failure as
          # an issue, once per host/revision. Successful builds never tag anyone.
          report_build_failure "$host" || echo "Could not report $host build failure to GitHub." >&2
        fi
      done
      exit "$failed"
    '';
  };
  systemd.timers.nix-cache-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };
}
