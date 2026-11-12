#!/usr/bin/env bash
set -euo pipefail

: "${VPS_HOST:?Add VPS_HOST to GitHub Actions secrets}"
: "${VPS_PRIVATE_KEY:?Add VPS_PRIVATE_KEY to GitHub Actions secrets}"
: "${VPS_KNOWN_HOSTS:?Add VPS_KNOWN_HOSTS to GitHub Actions secrets}"
: "${VPS_USER:=deploy}"
: "${VPS_PORT:=22}"
: "${VPS_DEPLOY_PATH:=/var/www/cute-boi}"
: "${GITHUB_SHA:?Missing commit SHA}"
: "${GITHUB_RUN_ID:?Missing run ID}"
: "${GITHUB_RUN_ATTEMPT:=1}"

[[ "$VPS_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo 'Invalid VPS_HOST (hostname or IPv4, without scheme).'; exit 1; }
[[ "$VPS_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] || exit 1
[[ "$VPS_PORT" =~ ^[0-9]{1,5}$ ]] && (( 10#$VPS_PORT > 0 && 10#$VPS_PORT <= 65535 )) || exit 1
[[ "$VPS_DEPLOY_PATH" =~ ^/[a-zA-Z0-9_/-]+$ && "$VPS_DEPLOY_PATH" != / && "$VPS_DEPLOY_PATH" != *..* ]] || exit 1
[[ "$GITHUB_SHA" =~ ^[a-f0-9]{40}$ && "$GITHUB_RUN_ID" =~ ^[0-9]+$ && "$GITHUB_RUN_ATTEMPT" =~ ^[0-9]+$ ]] || exit 1
[[ -f nho-em/dist/index.html ]] || exit 1

ssh_dir=$(mktemp -d)
trap 'rm -rf "$ssh_dir"' EXIT
chmod 700 "$ssh_dir"
printf '%s\n' "$VPS_PRIVATE_KEY" > "$ssh_dir/key"
printf '%s\n' "$VPS_KNOWN_HOSTS" > "$ssh_dir/known_hosts"
chmod 600 "$ssh_dir/key" "$ssh_dir/known_hosts"
ssh_options=(-i "$ssh_dir/key" -p "$VPS_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$ssh_dir/known_hosts" -o ConnectTimeout=15)
target="$VPS_USER@$VPS_HOST"
release="$VPS_DEPLOY_PATH/releases/$GITHUB_SHA-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"

# Only the website output is transferred; no Git files, keys or hosting metadata.
ssh "${ssh_options[@]}" "$target" "mkdir -p '$release'"
tar -C nho-em/dist --exclude='.DS_Store' -czf - . | ssh "${ssh_options[@]}" "$target" "tar -xzf - -C '$release' && test -s '$release/index.html' && chmod -R a+rX '$release'"
# Switch the served directory only after upload succeeds; keep old releases for rollback.
ssh "${ssh_options[@]}" "$target" "ln -s '$release' '$release.link' && mv -Tf '$release.link' '$VPS_DEPLOY_PATH/current'"
echo 'Deployment complete. Previous releases retained for rollback.'
