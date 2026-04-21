#!/usr/bin/env bash
set -euo pipefail

# Local equivalent of .github/workflows/check-version.yml -> detect step.
# Intended to run in CentOS Stream 10 (or the same container as CI).
#
# Usage:
#   scripts/check-version-local.sh
#   CHANNEL=stable scripts/check-version-local.sh
#   FORCE_BUILD=true scripts/check-version-local.sh
#   WRITE_STATE=false scripts/check-version-local.sh
#
# Output:
#   channel=<...>
#   source_repo=<...>
#   new_version=<...>
#   previous_version=<...>
#   should_build=<true|false>
#   reason=<unchanged|manual-force|new-version>

CHANNEL="${CHANNEL:-mainline}"
FORCE_BUILD="${FORCE_BUILD:-false}"
WRITE_STATE="${WRITE_STATE:-true}"
RETRIES="${RETRIES:-3}"

if [[ "${CHANNEL}" != "mainline" && "${CHANNEL}" != "stable" ]]; then
  echo "Invalid CHANNEL: ${CHANNEL} (expected: mainline|stable)" >&2
  exit 1
fi

source_repo="nginx-mainline-source"
if [[ "${CHANNEL}" == "stable" ]]; then
  source_repo="nginx-source"
fi

if [[ ! -f "SOURCES/nginx.repo" ]]; then
  echo "Missing file: SOURCES/nginx.repo" >&2
  exit 1
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

need_cmd dnf
need_cmd rpm
need_cmd sed
need_cmd cp
need_cmd ls
need_cmd head
need_cmd tr
need_cmd mktemp

retry() {
  local max="$1"
  shift
  local n=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [[ "$n" -ge "$max" ]]; then
      return 1
    fi
    echo "Retry $n/$max: $*" >&2
    n=$((n + 1))
    sleep 5
  done
}

retry "${RETRIES}" dnf -y --disablerepo='nginx*' install dnf-plugins-core rpm >/dev/null

source /etc/os-release
os_token="${ID}"
case "${os_token}" in
  almalinux|rocky|rhel|ol|oraclelinux)
    os_token="centos"
    ;;
esac
release_token="${VERSION_ID%%.*}"
repo_file="/tmp/nginx.repo"

cp SOURCES/nginx.repo "${repo_file}"
sed -i \
  -e "s|OS|${os_token}|g" \
  -e "s|RELEASEVER|${release_token}|g" \
  "${repo_file}"
sed -i -E 's/^enabled=1$/enabled=0/' "${repo_file}"
sed -i -E "/^\[${source_repo}\]/,/^\[/{s/^enabled=.*/enabled=1/}" "${repo_file}"
cp "${repo_file}" /etc/yum.repos.d/nginx.repo

tmp_dir="$(mktemp -d /tmp/nginx-check.XXXXXX)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

retry "${RETRIES}" bash -lc "cd '${tmp_dir}' && dnf -y --disablerepo='*' --enablerepo='${source_repo}' download --source nginx" >/dev/null

src_rpm="$(ls -1t "${tmp_dir}"/nginx-*.src.rpm | head -n 1)"
new_version="$(rpm -qp --queryformat '%{VERSION}\n' "${src_rpm}")"

state_dir=".github/version-state"
state_file="${state_dir}/nginx-${CHANNEL}.txt"
previous_version=""
if [[ -f "${state_file}" ]]; then
  previous_version="$(tr -d '\r\n' < "${state_file}")"
fi

should_build="false"
reason="unchanged"
if [[ "${FORCE_BUILD}" == "true" ]]; then
  should_build="true"
  reason="manual-force"
elif [[ -z "${previous_version}" || "${new_version}" != "${previous_version}" ]]; then
  should_build="true"
  reason="new-version"
fi

if [[ "${should_build}" == "true" && "${WRITE_STATE}" == "true" ]]; then
  mkdir -p "${state_dir}"
  printf '%s\n' "${new_version}" > "${state_file}"
fi

echo "channel=${CHANNEL}"
echo "source_repo=${source_repo}"
echo "new_version=${new_version}"
echo "previous_version=${previous_version}"
echo "should_build=${should_build}"
echo "reason=${reason}"
