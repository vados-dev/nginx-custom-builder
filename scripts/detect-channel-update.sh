#!/usr/bin/env bash
set -euo pipefail

channel="${1:?channel is required}"
state_dir="${2:-.github/version-state}"

mkdir -p "${state_dir}"
version_url="$(jq -r --arg c "${channel}" '.channels[$c].nginx_version_url' config/modules.json)"
if [[ -z "${version_url}" || "${version_url}" == "null" ]]; then
  echo "Unsupported channel: ${channel}" >&2
  exit 1
fi

raw_version="$(curl -fsSL "${version_url}")"
new_version="${raw_version%%-*}"
state_file="${state_dir}/nginx-${channel}.txt"
old_version=""
if [[ -f "${state_file}" ]]; then
  old_version="$(tr -d '\r\n' < "${state_file}")"
fi

if [[ -z "${old_version}" || "${old_version}" != "${new_version}" ]]; then
  printf '%s\n' "${new_version}" > "${state_file}"
  echo "changed=true"
else
  echo "changed=false"
fi

echo "channel=${channel}"
echo "old=${old_version:-none}"
echo "new=${new_version}"