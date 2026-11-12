#!/usr/bin/env bash
set -euo pipefail
release=${1:?Missing release directory}
container_name=${2:?Missing container name}
app_port=${3:?Missing port}
version=${4:?Missing version}
image="cute-boi-site:$version"
candidate="$container_name-check-$version"
backup="$container_name-backup-$version"
had_previous=false
switching=false

command -v curl >/dev/null
docker info >/dev/null

cleanup() {
  result=$?
  trap - EXIT
  docker rm -f "$candidate" >/dev/null 2>&1 || true
  if (( result != 0 )) && [[ "$switching" == true ]]; then
    docker logs --tail 30 "$container_name" >&2 || true
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    if [[ "$had_previous" == true ]]; then
      docker rename "$backup" "$container_name"
      docker start "$container_name" >/dev/null
      echo 'Restored previous container.' >&2
    fi
  fi
  exit "$result"
}
trap cleanup EXIT

wait_ready() {
  local name=$1
  for ((attempt=0; attempt<20; attempt++)); do
    if docker exec "$name" wget -q -O /dev/null http://localhost/; then
      return 0
    fi
    sleep 1
  done
  docker logs --tail 30 "$name" >&2 || true
  return 1
}

# Validate the new image before stopping the current website.
docker build --pull -t "$image" "$release"
docker run -d --name "$candidate" "$image" >/dev/null
wait_ready "$candidate"
docker rm -f "$candidate" >/dev/null

if docker container inspect "$container_name" >/dev/null 2>&1; then
  docker rename "$container_name" "$backup"
  had_previous=true
fi
switching=true
if [[ "$had_previous" == true ]]; then
  docker stop "$backup" >/dev/null
fi
docker run -d --name "$container_name" --restart unless-stopped \
  -p "$app_port:80" "$image" >/dev/null
wait_ready "$container_name"
curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 \
  --connect-timeout 3 --max-time 5 "http://localhost:$app_port/" >/dev/null
switching=false
if [[ "$had_previous" == true ]]; then
  docker rm "$backup" >/dev/null
fi
docker ps --filter "name=^/$container_name$"
