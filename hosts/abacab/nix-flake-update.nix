{ config, lib, pkgs, self, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nix-cache-update";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        case "$#:$*" in
          0:) unit=nix-flake-update.service ;;
          1:--skip-custard) unit=nix-flake-update-skip-custard.service ;;
          1:--help|1:-h) echo 'Usage: nix-cache-update [--skip-custard]'; exit 0 ;;
          *) echo 'Usage: nix-cache-update [--skip-custard]' >&2; exit 2 ;;
        esac
        exec /run/wrappers/bin/sudo systemctl start --no-block "$unit"
      '';
    })
  ];

  fileSystems."/var/lib/nix-flake-update" = {
    device = "/mnt/storage/nix-automation/flake-update";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/mnt/storage" ];
  };
  # Update in an automation-owned checkout, never in Potter's working tree.
  # Credentials are decrypted outside the store and passed through systemd.
  age.secrets.github-automation.file = ../../secrets/github-automation.age;
  systemd.services = lib.genAttrs [ "nix-flake-update" "nix-flake-update-skip-custard" ] (name:
  let
    skipCustard = name == "nix-flake-update-skip-custard";
  in {
    description = "Update flake packages and merge evaluated updates through a PR";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.RequiresMountsFor = [ "/var/lib/nix-flake-update" "/var/lib/nix-automation-tmp" ];
    path = [
      pkgs.git pkgs.gh pkgs.nix pkgs.jq pkgs.coreutils pkgs.gnused pkgs.util-linux
      self.packages.${pkgs.stdenv.hostPlatform.system}.update-local-packages
    ];
    environment = {
      HOME = "/var/lib/nix-flake-update";
      TMPDIR = "/var/lib/nix-automation-tmp";
      GIT_TERMINAL_PROMPT = "0";
      GH_PROMPT_DISABLED = "1";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "potter";
      Group = "users";
      StateDirectory = "nix-flake-update";
      WorkingDirectory = "/var/lib/nix-flake-update";
      LoadCredential = "github-token:${config.age.secrets.github-automation.path}";
      UMask = "0077";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "infinity";
    };
    script = ''
      set -euo pipefail
      exec 9>update.lock
      flock 9
      scope=()
      if ${lib.boolToString skipCustard}; then
        scope=(--skip-custard)
      fi
      GH_TOKEN=$(cat "$CREDENTIALS_DIRECTORY/github-token")
      export GH_TOKEN
      export GITHUB_TOKEN="$GH_TOKEN"
      export NIX_CONFIG="access-tokens = github.com=$GH_TOKEN"
      repo=Nailington/dots
      pending=$(gh pr list --repo "$repo" --base main --state open \
        --json headRefName,url \
        --jq '.[] | select(.headRefName | startswith("automation/flake-update-")) | .url')
      if [ -n "$pending" ]; then
        echo "An update PR still needs attention; blocking this run: $pending" >&2
        exit 1
      fi
      # The scheduler checks this marker; manual starts always update.
      week=$(date -d "today -$(date +%w) days" +%F)
      week_file="$PWD/last-successful-update-week"
      mark_updated() {
        if ${lib.boolToString skipCustard}; then
          return 0
        fi
        printf '%s\n' "$week" > "$week_file.tmp"
        mv -f -- "$week_file.tmp" "$week_file"
      }
      stamp=$(date -u +%Y%m%dT%H%M%S)-$RANDOM
      run="$PWD/runs/$stamp"
      mkdir -p "$run"
      exec > >(tee -a "$run/run.log") 2>&1
      pr=""
      phase="preparing the update checkout"
      failure_reason=""
      record_failure() {
        failure_reason="$failure_reason- $1"$'\n'
      }
      record_affected_hosts() {
        local installable="$1" package_drv host closure
        local -a affected_hosts=() unchecked_hosts=()
        if ! package_drv=$(nix eval --no-update-lock-file --raw "$installable.drvPath" </dev/null) || [ -z "$package_drv" ]; then
          record_failure 'Affected NixOS hosts for this output: unknown (could not resolve the package derivation).'
          return 0
        fi
        for host in "''${!nixos_drvs[@]}"; do
          closure="$run/nixos-$host.requisites"
          if [ ! -e "$closure" ]; then
            if ! nix-store --query --requisites "''${nixos_drvs[$host]}" > "$closure"; then
              : > "$closure"
            fi
          fi
          if [ ! -s "$closure" ]; then
            unchecked_hosts+=("$host")
          elif grep -Fxq -- "$package_drv" "$closure"; then
            affected_hosts+=("$host")
          fi
        done
        record_failure "Affected NixOS hosts for this output: ''${affected_hosts[*]:-none found among checked hosts}."
        if ((''${#unchecked_hosts[@]})); then
          record_failure "Could not check host dependencies for this output: ''${unchecked_hosts[*]}."
        fi
      }
      record_build_failure() {
        local target="$1" target_system="$2" installable="$3" log="$4" failed_drv
        local drv="/nix/store/[a-z0-9]{32}-[a-zA-Z0-9+._?=-]+\.drv"
        record_failure "Package build failed: \`$target\` (target system: \`$target_system\`)."
        record_affected_hosts "$installable"
        while IFS= read -r failed_drv; do
          record_failure "Failing derivation for \`$target\` on \`$target_system\`: \`$failed_drv\`."
        done < <(
          sed -nE \
            -e "s@^[[:space:]]*error: (builder for|hash mismatch in fixed-output derivation) '($drv)'.*@\2@p" \
            -e "\@^[[:space:]]*error: Cannot build '($drv)'\.\$@ {N; s@^[[:space:]]*error: Cannot build '($drv)'\.\n[[:space:]]*Reason: builder .*@\1@p;}" \
            "$log" | sort -u | sed -n '1,5p'
        )
      }
      close_failed_pr() {
        status=$?
        trap - EXIT
        if [ "$status" -ne 0 ] && [ -n "$pr" ]; then
          # Never close a successfully merged PR, even if a later step fails.
          if state=$(gh pr view "$pr" --repo "$repo" --json state --jq .state); then
            if [ "$state" = OPEN ]; then
              comment=$(printf 'Closing this automated update because the run failed.\n\n%s\nStopped while %s (exit status %s).\n\nDetailed logs on abacab: %s/run.log\n\nThe next scheduled or manual run can retry with a fresh PR.' \
                "$failure_reason" "$phase" "$status" "$run")
              gh pr close "$pr" --repo "$repo" --comment "$comment" \
                || echo "Could not close failed update PR; manual cleanup required: $pr" >&2
            fi
          else
            echo "Could not check failed update PR state; manual cleanup required: $pr" >&2
          fi
        fi
        exit "$status"
      }
      trap close_failed_pr EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM
      if [ ! -d checkout/.git ]; then
        git clone --depth 1 --branch main "https://github.com/$repo.git" checkout
      fi
      cd checkout
      git fetch --depth 1 origin main
      base=$(git rev-parse origin/main)
      branch="automation/flake-update-$stamp"
      # Discard only this service's leftovers from a prior interrupted run.
      git checkout -f -B "$branch" origin/main
      actor=$(gh api user --jq .login)
      actor_id=$(gh api user --jq .id)
      git config user.name "$actor"
      git config user.email "$actor_id+$actor@users.noreply.github.com"
      git config credential.helper '!gh auth git-credential'

      update_flake_inputs() {
        if ! ${lib.boolToString skipCustard}; then
          nix flake update
          return
        fi
        local inputs
        local -a input_names
        inputs=$(jq -er '
          . as $lock | $lock.nodes[$lock.root].inputs | keys[]
          | select(. != "nixpkgs-aarch64" and . != "nixos-raspberrypi")
        ' flake.lock) || return 1
        mapfile -t input_names <<< "$inputs"
        echo "Updating flake inputs except nixpkgs-aarch64 and nixos-raspberrypi."
        nix flake update "''${input_names[@]}"
      }

      phase="updating inputs and local packages"
      updates_ok=true
      update_flake_inputs || { updates_ok=false; record_failure "nix flake update failed."; }
      if ! UPDATE_LOCAL_PACKAGES_FAILURE_FILE="$run/failed-updates" \
        update-local-packages --flake "$PWD" --all "''${scope[@]}"; then
        updates_ok=false
        if [ -s "$run/failed-updates" ]; then
          while IFS= read -r package; do
            record_failure "Package update failed: $package."
          done < "$run/failed-updates"
        else
          record_failure "update-local-packages failed before reporting individual packages."
        fi
      fi
      git add --update -- flake.nix flake.lock pkgs
      if git diff --cached --quiet; then
        if ! "$updates_ok"; then
          echo "Updating failed without a publishable diff; see $run/run.log" >&2
          exit 1
        fi
        echo "No package or input updates; cache build may proceed."
        mark_updated
        exit 0
      fi
      title="Update flake inputs and local packages ($stamp)"
      if ${lib.boolToString skipCustard}; then
        title="Update flake inputs and local packages (skip custard; $stamp)"
      fi
      git commit -m "$title"
      head=$(git rev-parse HEAD)

      # Full runs evaluate Darwin but never build or activate it on Linux.
      phase="evaluating the updated configuration"
      eval_ok=true
      declare -A nixos_drvs=()
      kinds=(nixosConfigurations darwinConfigurations homeConfigurations)
      eval_scope="All-system flake and explicit host evaluations"
      if ${lib.boolToString skipCustard}; then
        kinds=(nixosConfigurations)
        eval_scope="Roundabout and abacab evaluations"
      else
        nix flake check --no-build --all-systems --no-update-lock-file \
          || { eval_ok=false; record_failure "All-system flake evaluation failed."; }
      fi
      for kind in "''${kinds[@]}"; do
        if nix eval --no-update-lock-file --json ".#$kind" \
          --apply builtins.attrNames > "$run/$kind.json"; then
          while IFS= read -r host; do
            if ${lib.boolToString skipCustard} && [[ "$host" != roundabout && "$host" != abacab ]]; then
              continue
            fi
            case "$kind" in
              nixosConfigurations) target="config.system.build.toplevel.drvPath" ;;
              darwinConfigurations) target="system.drvPath" ;;
              homeConfigurations) target="activationPackage.drvPath" ;;
            esac
            if host_drv=$(nix eval --no-update-lock-file --raw ".#$kind.\"$host\".$target"); then
              printf '%s\n' "$host_drv"
              if [ "$kind" = nixosConfigurations ]; then
                nixos_drvs["$host"]="$host_drv"
              fi
            else
              eval_ok=false
              record_failure "Evaluation failed for $kind.$host.$target."
            fi
          done < <(jq -r '.[]' "$run/$kind.json")
        else
          eval_ok=false
          record_failure "Could not list hosts in $kind."
        fi
      done

      phase="building the local packages"
      target_system=x86_64-linux
      builds_ok=skipped
      if "$updates_ok" && "$eval_ok"; then
        builds_ok=true
        targets=$(update-local-packages --list-build-targets "''${scope[@]}")
        while IFS= read -r target; do
          installable=".#packages.$target_system.$target"
          echo "Building $target for $target_system before merge."
          build_log="$run/build-$target.log"
          if ! NO_COLOR=1 nix build --no-link --no-update-lock-file --max-jobs 2 --cores 3 --print-build-logs \
            "$installable" </dev/null 2>&1 | tee "$build_log"; then
            builds_ok=false
            record_build_failure "$target" "$target_system" "$installable" "$build_log"
          fi
        done <<< "$targets"
      fi
      # The exact committed tree must be the tree checked above.
      if ! git diff --quiet || ! git diff --cached --quiet; then
        eval_ok=false
        record_failure "The checkout changed after the update commit was created."
      fi
      git fetch --depth 1 origin main
      base_ok=true
      if [ "$(git rev-parse origin/main)" != "$base" ]; then
        base_ok=false
        record_failure "Main advanced during validation; the update needs a fresh base."
      fi
      {
        printf '%s\n\n' "$title"
        if ${lib.boolToString skipCustard}; then
          printf -- '- Input refresh excludes only the custard-specific pins: `nixpkgs-aarch64` and `nixos-raspberrypi`.\n'
        fi
        printf -- '- Package/input updates completed: %s\n' "$updates_ok"
        printf -- '- %s passed: %s\n' "$eval_scope" "$eval_ok"
        printf -- '- Local %s package builds passed: %s\n' "$target_system" "$builds_ok"
        printf -- '- Main unchanged during validation: %s\n' "$base_ok"
        printf '\nValidated commit: %s. No system activation is performed.\n' "$head"
        printf '\nDetailed logs on abacab: %s/run.log.\n' "$run"
      } > "$run/pr-body.md"
      phase="publishing the update PR"
      git push origin "HEAD:refs/heads/$branch"
      pr=$(gh pr create --repo "$repo" --base main --head "$branch" \
        --title "$title" \
        --body-file "$run/pr-body.md")
      printf '%s\n' "$pr" | tee "$run/pr-url"

      request_review() {
        for reviewer in HammerPot Nailington; do
          gh pr edit "$pr" --repo "$repo" --add-assignee "$reviewer" || true
          if [ "$reviewer" != "$actor" ]; then
            gh pr edit "$pr" --repo "$repo" --add-reviewer "$reviewer" || true
          else
            echo "$reviewer is the PR author; assigned instead of requesting self-review."
          fi
        done
      }
      if ! "$eval_ok" || [ "$builds_ok" = false ]; then
        phase="rejecting an update that failed evaluation or package builds"
        request_review
        echo "Validation failed; review requested, closing PR and blocking this cache build: $pr" >&2
        exit 1
      fi
      if ! "$updates_ok" || ! "$base_ok"; then
        phase="rejecting an incomplete or outdated update"
        echo "Update incomplete or main advanced; closing PR and blocking this cache build: $pr" >&2
        exit 1
      fi
      # Respect repository protection and reject a concurrently changed PR head.
      phase="merging the evaluated update"
      if ! gh pr merge "$pr" --repo "$repo" --squash --match-head-commit "$head"; then
        record_failure "GitHub rejected the squash merge (see the run log for the GitHub error)."
        echo "Merge failed; closing PR and blocking this cache build: $pr" >&2
        exit 1
      fi
      if [ "$(gh pr view "$pr" --repo "$repo" --json state --jq .state)" != MERGED ]; then
        record_failure "The merge command returned but the PR was not merged."
        echo "PR is not merged yet; cache build remains blocked: $pr" >&2
        exit 1
      fi
      phase="recording the successful update week"
      mark_updated
    '';
  });
}
