#!/usr/bin/env bash
set -euo pipefail

ME="build_module_local.sh"
OUTPUT_DIR="$(pwd)/rpm"
CHECK_DEPENDS=0
SAY_YES=""
COPY_CMD="cp -r"
DO_DYNAMIC_CONVERT=0
MODULE_NAME=""
MODULE_VERSION="0.0.1"
MODULE_RELEASE="1"
BUILD_PLATFORM="OSS"
OSS_VER=""
PKG_OSS_ROOT="${PKG_OSS_ROOT:-}"
RPMBUILD_ARGS_VALUE="${BUILD_ARGS:--bb}"
PACKAGE_OUTPUT_DIR=RPMS
#    -o "${repo_root}/artifacts/${module_name}" \


if [[ $# -eq 0 ]]; then
  echo "USAGE: $ME [options] <URL | path to module source>"
  echo " -n | --nickname <word>"
  echo " -V | --module-version <ver[-rel]>"
  echo " -f | --force-dynamic"
  echo " -v [NGINX OSS version number]"
  echo " -o <package output directory>"
  exit 1
fi

while [[ $# -gt 1 ]]; do
  case "$1" in
    "-y"|"--non-interactive") SAY_YES="-y"; COPY_CMD="cp -f"; shift ;;
    "-f"|"--force-dynamic") DO_DYNAMIC_CONVERT=1; shift ;;
    "-n"|"--nickname") MODULE_NAME="$2"; shift 2 ;;
    "-V"|"--module-version") MODULE_VERSION="${2%-*}"; [[ "${2#*-}" != "$2" ]] && MODULE_RELEASE="${2#*-}"; shift 2 ;;
    "-v") BUILD_PLATFORM="OSS"; [[ ${2:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && OSS_VER="$2" && shift; shift ;;
    "-o") OUTPUT_DIR="$(realpath "$2")"; shift 2 ;;
    *) echo "$ME: ERROR: Invalid option $1"; exit 1 ;;
  esac
done

MODULE_SOURCE="$1"

if [[ -z "${PKG_OSS_ROOT}" || ! -d "${PKG_OSS_ROOT}" ]]; then
  echo "$ME: ERROR: PKG_OSS_ROOT is not set or invalid" >&2
  exit 1
fi

if [[ -z "${MODULE_NAME}" ]]; then
  echo "$ME: ERROR: -n is required (explicit nickname)" >&2
  exit 1
fi

if printf '%s' "${MODULE_NAME}" | grep -q '["$#@]'; then
  echo "$ME: WARNING: nickname contains characters that may break packaging: ${MODULE_NAME}" >&2
fi

mkdir -p "${OUTPUT_DIR}"

BUILD_DIR="/tmp/${ME}.$$"
MODULE_DIR="${BUILD_DIR}/${MODULE_NAME}"
mkdir -p "${BUILD_DIR}"

if [[ -d "${MODULE_SOURCE}" ]]; then
  mkdir -p "${MODULE_DIR}"
  cp -a "${MODULE_SOURCE}"/* "${MODULE_DIR}"/
else
  case "${MODULE_SOURCE##*.}" in
    git)
      git clone --recursive "${MODULE_SOURCE}" "${MODULE_DIR}"
      ;;
    zip)
      wget -O "${BUILD_DIR}/module.zip" "${MODULE_SOURCE}"
      archive_dir="$(zipinfo -1 "${BUILD_DIR}/module.zip" | sed -n '1{s#/.*##;p;q;}')"
      unzip "${BUILD_DIR}/module.zip" -d "${BUILD_DIR}" >/dev/null
      mv "${BUILD_DIR}/${archive_dir}" "${MODULE_DIR}"
      ;;
    *)
      wget -O "${BUILD_DIR}/module.tgz" "${MODULE_SOURCE}"
      archive_dir="$(tar tfz "${BUILD_DIR}/module.tgz" | sed -n '1{s#/.*##;p;q;}')"
      ( cd "${BUILD_DIR}" && tar xfz module.tgz )
      mv "${BUILD_DIR}/${archive_dir}" "${MODULE_DIR}"
      ;;
  esac
fi

if [[ ! -f "${MODULE_DIR}/config" ]]; then
  echo "$ME: ERROR: Cannot locate module config file" >&2
  exit 1
fi

if ! grep -q "\.[[:space:]]auto/module" "${MODULE_DIR}/config"; then
  if [[ "${DO_DYNAMIC_CONVERT}" == "1" ]]; then
    grep -ve HTTP_MODULES -e STREAM_MODULES -e NGX_ADDON_SRCS "${MODULE_DIR}/config" > "${MODULE_DIR}/config.dynamic"
    echo "ngx_module_name=$(grep ngx_addon_name= "${MODULE_DIR}/config" | cut -d= -f2)" >> "${MODULE_DIR}/config.dynamic"
    if grep -q "HTTP_AUX_FILTER_MODULES=" "${MODULE_DIR}/config"; then
      echo "ngx_module_type=HTTP_AUX_FILTER" >> "${MODULE_DIR}/config.dynamic"
    elif grep -q "STREAM_MODULES=" "${MODULE_DIR}/config"; then
      echo "ngx_module_type=Stream" >> "${MODULE_DIR}/config.dynamic"
    else
      echo "ngx_module_type=HTTP" >> "${MODULE_DIR}/config.dynamic"
    fi
    echo "ngx_module_srcs=\"$(grep NGX_ADDON_SRCS= "${MODULE_DIR}/config" | cut -d'"' -f2 | sed -e 's/^\$NGX_ADDON_SRCS \(\$ngx_addon_dir\/.*$\)/\1/')\"" >> "${MODULE_DIR}/config.dynamic"
    echo ". auto/module" >> "${MODULE_DIR}/config.dynamic"
    mv "${MODULE_DIR}/config" "${MODULE_DIR}/config.static"
    cp "${MODULE_DIR}/config.dynamic" "${MODULE_DIR}/config"
  else
    echo "$ME: ERROR: static module config detected; use --force-dynamic" >&2
    exit 1
  fi
fi

cp -a "${PKG_OSS_ROOT}" "${BUILD_DIR}/pkg-oss"

if [[ -n "${OSS_VER}" ]]; then
  # best effort checkout tag in local clone
  ( cd "${BUILD_DIR}/pkg-oss" && git checkout "$(git tag -l | sed -n "/^${OSS_VER}/ {p;q;}")" ) || true
fi

if [[ -d "${BUILD_DIR}/pkg-oss/contrib" ]]; then
  VERSION="$(grep '^NGINX_VERSION :=' "${BUILD_DIR}/pkg-oss/contrib/src/nginx/version" | cut -d= -f2 | tr -d '[:blank:]')"
else
  VERSION="$(grep '^BASE_VERSION=' "${BUILD_DIR}/pkg-oss/rpm/SPECS/Makefile" | cut -d= -f2 | tr -d '[:blank:]')"
fi

mv "${MODULE_DIR}" "${BUILD_DIR}/${MODULE_NAME}-${VERSION}"
( cd "${BUILD_DIR}" && tar cf - "${MODULE_NAME}-${VERSION}" | gzip -1 > "${MODULE_NAME}-${VERSION}.tar.gz" )

mkdir -p "${BUILD_DIR}/pkg-oss/contrib/tarballs"
cp "${BUILD_DIR}/${MODULE_NAME}-${VERSION}.tar.gz" "${BUILD_DIR}/pkg-oss/contrib/tarballs/"

cat > "${BUILD_DIR}/pkg-oss/docs/nginx-module-${MODULE_NAME}.xml" <<EOF
<?xml version="1.0" ?>
<!DOCTYPE change_log SYSTEM "changes.dtd" >
<change_log title="nginx_module_${MODULE_NAME}">
<changes apply="nginx-module-${MODULE_NAME}" ver="${MODULE_VERSION}" rev="${MODULE_RELEASE}" basever="${VERSION}" date="$(date +%Y-%m-%d)" time="$(date +%H:%M:%S%z)" packager="Build Script &lt;build.script@example.com&gt;">
<change><para>initial release</para></change>
</changes>
</change_log>
EOF

echo "placeholder" > "${BUILD_DIR}/pkg-oss/docs/nginx-module-${MODULE_NAME}.copyright"

cat > "${BUILD_DIR}/Makefile.module-${MODULE_NAME}" <<EOF
MODULES=${MODULE_NAME}
MODULE_PACKAGE_VENDOR= Build Script <build.script@example.com>
MODULE_PACKAGE_URL= https://www.nginx.com/blog/compiling-dynamic-modules-nginx-plus/
MODULE_SUMMARY_${MODULE_NAME}= ${MODULE_NAME} dynamic module
MODULE_VERSION_${MODULE_NAME}= ${MODULE_VERSION}
MODULE_RELEASE_${MODULE_NAME}= ${MODULE_RELEASE}
MODULE_VERSION_PREFIX_${MODULE_NAME}= \$(MODULE_TARGET_PREFIX)
MODULE_CONFARGS_${MODULE_NAME}= --add-dynamic-module=\$(MODSRC_PREFIX)${MODULE_NAME}-$VERSION
MODULE_SOURCES_${MODULE_NAME}= ${MODULE_NAME}-$VERSION.tar.gz
EOF

cp "${BUILD_DIR}/Makefile.module-${MODULE_NAME}" "${BUILD_DIR}/pkg-oss/rpm/SPECS/"

( cd "${BUILD_DIR}/pkg-oss/rpm/SPECS" && RPMBUILD_ARGS="${RPMBUILD_ARGS_VALUE}" make "module-${MODULE_NAME}" )

#find "${BUILD_DIR}/pkg-oss/rpm" -type f -name "*.rpm" -exec ${COPY_CMD} -v {} "${OUTPUT_DIR}/" \;
${COPY_CMD}
rm -rf "${BUILD_DIR}"
