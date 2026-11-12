#!/usr/bin/env bash
set -euo pipefail

: "${VPS_HOST:?Add VPS_HOST to GitHub Actions secrets}"
: "${VPS_PRIVATE_KEY:?Add VPS_PRIVATE_KEY to GitHub Actions secrets}"
: "${CONTAINER_NAME:=cute-boi}"
: "${APP_PORT:=3015}"
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
[[ "$CONTAINER_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || exit 1
[[ "$APP_PORT" =~ ^[0-9]{1,5}$ ]] && (( 10#$APP_PORT > 0 && 10#$APP_PORT <= 65535 )) || exit 1
[[ -f nho-em/dist/index.html ]] || exit 1

ssh_dir=$(mktemp -d)
trap 'rm -rf "$ssh_dir"' EXIT
chmod 700 "$ssh_dir"
printf '%s\n' "$VPS_PRIVATE_KEY" > "$ssh_dir/key"
touch "$ssh_dir/known_hosts"
chmod 600 "$ssh_dir/key" "$ssh_dir/known_hosts"
ssh_options=(-i "$ssh_dir/key" -p "$VPS_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$ssh_dir/known_hosts" -o ConnectTimeout=15)
target="$VPS_USER@$VPS_HOST"
release="$VPS_DEPLOY_PATH/releases/$GITHUB_SHA-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"

# Upload only the Docker build context, never Git files or credentials.
ssh "${ssh_options[@]}" "$target" "mkdir -p '$release'"
tar --exclude='.DS_Store' -czf - Dockerfile .dockerignore deploy/nginx.conf scripts/deploy-container.sh nho-em/dist | ssh "${ssh_options[@]}" "$target" "tar -xzf - -C '$release'"
ssh "${ssh_options[@]}" "$target" "bash '$release/scripts/deploy-container.sh' '$release' '$CONTAINER_NAME' '$APP_PORT' '$GITHUB_SHA-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT'"
echo "Docker deployment complete on port $APP_PORT."
