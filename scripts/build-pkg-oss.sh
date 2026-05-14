#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
channel="${CHANNEL:?CHANNEL is required}"
target_id="${TARGET_ID:?TARGET_ID is required}"
build_base="${BUILD_BASE:-}"
base_modules="${BASE_MODULES:-}"
build_args="${BUILD_ARGS:--bb}"

nginx_version_url="$(jq -r --arg c "${channel}" '.channels[$c].nginx_version_url' config/modules.json)"

target_json="$(jq -c --arg id "${target_id}" '.targets[] | select(.id == $id and .enabled == true)' config/targets.json)"
if [[ -z "${target_json}" ]]; then
  echo "Enabled target not found: ${target_id}" >&2
  exit 1
fi

pkg_dir="$(jq -r '.pkg_oss_make_dir' <<< "${target_json}")"
pkg_target="$(jq -r '.pkg_oss_make_target' <<< "${target_json}")"

if [[ -n "${NGINX_VERSION:-}" ]]; then
  nginx_version="${NGINX_VERSION}"
else
  raw_version="$(curl -fsSL "${nginx_version_url}")"
  nginx_version="${raw_version%%-*}"
fi
export NGINX_VERSION="${nginx_version}"

nginx_mm="$(sed -E 's/^([0-9]+\.[0-9]+).*/\1/' <<< "${nginx_version}")"
if [[ ! "${nginx_mm}" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "Cannot parse major.minor from NGINX_VERSION=${nginx_version}" >&2
  exit 1
fi

work_root="/tmp/pkg-oss-build"
rm -rf "${work_root}"
mkdir -p "${work_root}" "${repo_root}/artifacts"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required in container" >&2
  exit 1
fi

if ! command -v make >/dev/null 2>&1; then
  echo "make is required in container" >&2
  exit 1
fi

pkg_oss_repo="$(jq -r '.pkg_oss_repo' config/targets.json)"
pkg_oss_branch="$(jq -r --arg c "${channel}" '.channels[$c].pkg_oss_branch // empty' config/modules.json)"

case "${pkg_oss_branch}" in
  mainline)
    # Для mainline ветку явно не указываем
    pkg_oss_branch=""
    ;;
  stable)
    pkg_oss_branch="stable-${nginx_mm}"
    ;;
  "")
    echo "pkg_oss_branch is empty for channel=${channel}" >&2
    exit 1
    ;;
  *)
    # Если в config задано конкретное имя ветки — используем как есть
    ;;
esac

if [[ -n "${pkg_oss_branch}" ]]; then
  echo "Resolved pkg-oss branch: ${pkg_oss_branch}"
  if ! git ls-remote --heads "${pkg_oss_repo}" "refs/heads/${pkg_oss_branch}" | grep -q "${pkg_oss_branch}"; then
    echo "pkg-oss branch not found: ${pkg_oss_branch}" >&2
    exit 1
  fi
  git clone --depth 1 --branch "${pkg_oss_branch}" "${pkg_oss_repo}" "${work_root}/pkg-oss"
else
  echo "Resolved pkg-oss branch: <default>"
  git clone --depth 1 "${pkg_oss_repo}" "${work_root}/pkg-oss"
fi

cp -a "${repo_root}/src/." "${work_root}/pkg-oss/SOURCES/" 2>/dev/null || true

pushd "${work_root}/pkg-oss/${pkg_dir}" >/dev/null
if [[ -n "${base_modules//[[:space:]]/}" ]]; then
  read -r -a modules_array <<< "${base_modules}"
  make_targets=()
  
  for mod in "${modules_array[@]}"; do
    [[ -z "${mod}" ]] && continue
    make_targets+=("module-${mod}")
  done
  if [[ "${#make_targets[@]}" -gt 0 ]]; then
    RPMBUILD_ARGS="${build_args}" make "${make_targets[@]}"
  else
    RPMBUILD_ARGS="${build_args}" make "${pkg_target}"
  fi
else
  echo "BASE_MODULES is empty, fallback to: make base"
  RPMBUILD_ARGS="${build_args}" make base
fi
popd >/dev/null

common_args="$(jq -r '.common_args // ""' config/modules.json)"
while IFS= read -r row; do
  module_name="$(jq -r '.name' <<< "${row}")"
  nickname="$(jq -r '.nickname' <<< "${row}")"
  repo="$(jq -r '.repo' <<< "${row}")"
  base_version="$(jq -r '.base_version // "0.0.1"' <<< "${row}")"
  version_mode="$(jq -r '.version_mode // "head_commit"' <<< "${row}")"

  ref_line="$(git ls-remote --symref "${repo}" HEAD | awk '/^ref:/ {print $2}' | head -n1)"
  head_sha="$(git ls-remote "${repo}" "${ref_line}" | awk '{print $1}' | head -n1)"
  resolved_sha="${head_sha}"

  if [[ "${version_mode}" == "latest_tag" ]]; then
    tag_name="$(git ls-remote --tags --refs "${repo}" | awk -F/ '{print $NF}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$|^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)"
    if [[ -n "${tag_name}" ]]; then
      tag_sha="$(git ls-remote --tags --refs "${repo}" "refs/tags/${tag_name}" | awk '{print $1}' | head -n1)"
      if [[ -n "${tag_sha}" ]]; then
        resolved_sha="${tag_sha}"
      fi
    fi
  fi

  short_sha="${resolved_sha:0:8}"
  module_version="${base_version}+${short_sha}"
  module_tarball="${repo}/archive/${resolved_sha}.tar.gz"
  stable_arg=()
  if [[ "${channel}" == "stable" ]]; then
    stable_arg=(-v "${NGINX_VERSION}")
  fi

  echo "Building custom module: ${module_name} (${module_version})"
  # shellcheck disable=SC2086
  PKG_OSS_ROOT="${work_root}/pkg-oss" bash "${repo_root}/scripts/build_module_local.sh" ${common_args} \
    --force-dynamic \
    -n "${nickname}" \
    -V "${module_version}" \
    "${stable_arg[@]}" \
    "${module_tarball}"
done < <(jq -c '.custom_modules[] | select(.enabled == true)' config/modules.json)
