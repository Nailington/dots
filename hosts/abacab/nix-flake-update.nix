{ config, pkgs, self, ... }:

{
  fileSystems."/var/lib/nix-flake-update" = {
    device = "/mnt/storage/nix-automation/flake-update";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/mnt/storage" ];
  };
  # Update in an automation-owned checkout, never in Potter's working tree.
  # Credentials are decrypted outside the store and passed through systemd.
  age.secrets.github-automation.file = ../../secrets/github-automation.age;
  systemd.services.nix-flake-update = {
    description = "Update flake packages and merge evaluated updates through a PR";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "nix-cache-build.service" ];
    unitConfig.RequiresMountsFor = [ "/var/lib/nix-flake-update" "/mnt/storage/nix-automation/tmp" ];
    path = [
      pkgs.git pkgs.gh pkgs.nix pkgs.jq pkgs.coreutils
      self.packages.${pkgs.stdenv.hostPlatform.system}.update-local-packages
    ];
    environment = {
      HOME = "/var/lib/nix-flake-update";
      TMPDIR = "/mnt/storage/nix-automation/tmp";
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
      stamp=$(date -u +%Y%m%dT%H%M%S)-$RANDOM
      run="$PWD/runs/$stamp"
      mkdir -p "$run"
      exec > >(tee -a "$run/run.log") 2>&1
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

      updates_ok=true
      nix flake update || updates_ok=false
      update-local-packages --flake "$PWD" --all || updates_ok=false
      git add --update -- flake.nix flake.lock pkgs
      if git diff --cached --quiet; then
        if ! "$updates_ok"; then
          echo "Updating failed without a publishable diff; see $run/run.log" >&2
          exit 1
        fi
        echo "No package or input updates; cache build may proceed."
        exit 0
      fi
      git commit -m "Update flake inputs and local packages ($stamp)"
      head=$(git rev-parse HEAD)

      # Check all exported package systems and explicitly force every host.
      # Darwin is evaluated here, never built or activated on Linux.
      eval_ok=true
      nix flake check --no-build --all-systems --no-update-lock-file || eval_ok=false
      for kind in nixosConfigurations darwinConfigurations homeConfigurations; do
        if nix eval --no-update-lock-file --json ".#$kind" \
          --apply builtins.attrNames > "$run/$kind.json"; then
          while IFS= read -r host; do
            case "$kind" in
              nixosConfigurations) target="config.system.build.toplevel.drvPath" ;;
              darwinConfigurations) target="system.drvPath" ;;
              homeConfigurations) target="activationPackage.drvPath" ;;
            esac
            nix eval --no-update-lock-file --raw ".#$kind.\"$host\".$target" || eval_ok=false
            printf '\n'
          done < <(jq -r '.[]' "$run/$kind.json")
        else
          eval_ok=false
        fi
      done
      # The exact committed tree must be the tree checked above.
      git diff --quiet && git diff --cached --quiet || eval_ok=false
      git fetch --depth 1 origin main
      base_ok=true
      if [ "$(git rev-parse origin/main)" != "$base" ]; then base_ok=false; fi
      {
        printf 'Updates flake inputs and the supported local package pins/hashes.\n\n'
        printf -- '- Package/input updates completed: %s\n' "$updates_ok"
        printf -- '- All-system flake and explicit host evaluations passed: %s\n' "$eval_ok"
        printf -- '- Main unchanged during evaluation: %s\n' "$base_ok"
        printf '\nEvaluated commit: %s. No system activation is performed.\n' "$head"
        printf '\nDetailed logs on abacab: %s/run.log.\n' "$run"
      } > "$run/pr-body.md"
      git push origin "HEAD:refs/heads/$branch"
      pr=$(gh pr create --repo "$repo" --base main --head "$branch" \
        --title "Update flake inputs and local packages ($stamp)" \
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
      if ! "$eval_ok"; then
        request_review
        echo "Evaluation failed; review requested and cache build blocked: $pr" >&2
        exit 1
      fi
      if ! "$updates_ok" || ! "$base_ok"; then
        echo "Update incomplete or main advanced; blocking without review notifications: $pr" >&2
        exit 1
      fi
      # Respect repository protection and reject a concurrently changed PR head.
      if ! gh pr merge "$pr" --repo "$repo" --squash --match-head-commit "$head"; then
        echo "Merge failed; blocking without review notifications: $pr" >&2
        exit 1
      fi
      if [ "$(gh pr view "$pr" --repo "$repo" --json state --jq .state)" != MERGED ]; then
        echo "PR is not merged yet; cache build remains blocked: $pr" >&2
        exit 1
      fi
    '';
  };
}
