#!/usr/bin/env bash
set -euo pipefail

state_dir="${1:-.github/version-state}"
mkdir -p "${state_dir}"

changed_any="false"
report=""

while IFS= read -r row; do
  name="$(jq -r '.name' <<< "${row}")"
  repo="$(jq -r '.repo' <<< "${row}")"
  mode="$(jq -r '.version_mode // "head_commit"' <<< "${row}")"
  resolved_mode="${mode}"

  ref_line="$(git ls-remote --symref "${repo}" HEAD | awk '/^ref:/ {print $2}' | head -n1)"
  head_sha="$(git ls-remote "${repo}" "${ref_line}" | awk '{print $1}' | head -n1)"
  resolved_sha="${head_sha}"

  if [[ "${mode}" == "latest_tag" ]]; then
    tag_name="$(git ls-remote --tags --refs "${repo}" | awk -F/ '{print $NF}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$|^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)"
    if [[ -n "${tag_name}" ]]; then
      tag_sha="$(git ls-remote --tags --refs "${repo}" "refs/tags/${tag_name}" | awk '{print $1}' | head -n1)"
      if [[ -n "${tag_sha}" ]]; then
        resolved_sha="${tag_sha}"
      else
        resolved_mode="head_commit"
      fi
    else
      resolved_mode="head_commit"
    fi
  elif [[ "${mode}" != "head_commit" ]]; then
    echo "Unsupported version_mode for ${name}: ${mode}" >&2
    exit 1
  fi

  if [[ -z "${resolved_sha}" ]]; then
    echo "Unable to resolve HEAD sha for ${name} (${repo})" >&2
    exit 1
  fi

  state_file="${state_dir}/module-${name}.txt"
  old_sha=""
  if [[ -f "${state_file}" ]]; then
    old_sha="$(tr -d '\r\n' < "${state_file}")"
  fi

  changed="false"
  if [[ -z "${old_sha}" || "${old_sha}" != "${resolved_sha}" ]]; then
    printf '%s\n' "${resolved_sha}" > "${state_file}"
    changed="true"
    changed_any="true"
  fi

  report+="${name}|${old_sha:-none}|${resolved_sha}|${changed}|${resolved_mode}"$'\n'
done < <(jq -c '.custom_modules[] | select(.enabled == true)' config/modules.json)

echo "changed_any=${changed_any}"
echo "report<<EOF"
printf '%s' "${report}"
echo "EOF"
