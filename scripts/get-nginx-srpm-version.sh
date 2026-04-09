#!/usr/bin/env bash
set -euo pipefail

# Resolve latest nginx source RPM version for a channel/repo path.
# Defaults:
# - CHANNEL=mainline
# - NGINX_REPO_OS from /etc/os-release ID
# - NGINX_REPO_RELEASE from /etc/os-release VERSION_ID major part
# - NGINX_REPO_BASE=https://nginx.org/packages

CHANNEL="${CHANNEL:-mainline}"
NGINX_REPO_BASE="${NGINX_REPO_BASE:-https://nginx.org/packages}"

if [[ -z "${NGINX_REPO_OS:-}" || -z "${NGINX_REPO_RELEASE:-}" ]]; then
  source /etc/os-release
fi

repo_os="${NGINX_REPO_OS:-${ID}}"
repo_release="${NGINX_REPO_RELEASE:-${VERSION_ID%%.*}}"

case "${CHANNEL}" in
  mainline)
    srpms_url="${NGINX_REPO_BASE}/mainline/${repo_os}/${repo_release}/SRPMS/"
    ;;
  stable)
    srpms_url="${NGINX_REPO_BASE}/${repo_os}/${repo_release}/SRPMS/"
    ;;
  *)
    echo "Unsupported CHANNEL: ${CHANNEL} (expected: mainline|stable)" >&2
    exit 2
    ;;
esac

html="$(curl -fsSL "${srpms_url}")" || {
  echo "Failed to fetch SRPMS index: ${srpms_url}" >&2
  exit 3
}

version="$(
  printf '%s\n' "${html}" \
    | grep -oE 'nginx-[0-9][0-9.]*-[^"<>[:space:]]*\.src\.rpm' \
    | sort -V \
    | tail -n 1 \
    | sed -E 's/^nginx-([0-9][0-9.]*).*/\1/'
)"

if [[ -z "${version}" ]]; then
  echo "Could not parse nginx version from: ${srpms_url}" >&2
  exit 4
fi

printf '%s\n' "${version}"
