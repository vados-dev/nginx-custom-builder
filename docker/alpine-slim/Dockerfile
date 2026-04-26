ARG BASE_IMAGE=nginx:mainline-alpine-slim
FROM ${BASE_IMAGE}

ARG APK_REPO_URL=
ARG APK_KEY_URL=
ARG ENABLED_MODULES="nginx-module-markdown-filter nginx-module-error-page-inherit nginx-module-include-server"

SHELL ["/bin/sh", "-ec"]

COPY apk-packages/ /tmp/apk-packages/

#RUN apk add --no-cache ca-certificates curl mc
RUN set -eux; apk update ; apk add --no-cache ca-certificates curl wget mc ;

RUN runtime_deps=""; \
    for pkg in ${ENABLED_MODULES}; do \
      case "${pkg}" in \
        nginx-module-markdown-filter) \
          runtime_deps="${runtime_deps} cmark" ;; \
      esac; \
    done; \
    runtime_deps="$(printf '%s\n' "${runtime_deps}" | xargs -n1 | awk 'NF && !seen[$0]++' | xargs || true)"; \
    if [ -n "${runtime_deps}" ]; then \
      apk add --no-cache ${runtime_deps}; \
    fi

RUN if ls /tmp/apk-packages/*.apk >/dev/null 2>&1; then \
      set --; \
      for pkg in ${ENABLED_MODULES}; do \
        pkg_file="$(find /tmp/apk-packages -maxdepth 1 -type f -name "${pkg}-*.apk" | head -n1)"; \
        if [ -z "${pkg_file}" ]; then \
          echo "Local APK for package not found: ${pkg}" >&2; \
          exit 1; \
        fi; \
        set -- "$@" "${pkg_file}"; \
      done; \
      apk add --no-cache --allow-untrusted "$@"; \
    else \
      if [ -z "${APK_REPO_URL}" ]; then \
        echo "Either local apk-packages or APK_REPO_URL is required" >&2; \
        exit 1; \
      fi; \
      if [ -n "${APK_KEY_URL}" ]; then \
        key_name="$(basename "${APK_KEY_URL}")"; \
        curl -fsSL "${APK_KEY_URL}" -o "/etc/apk/keys/${key_name}"; \
      fi; \
      echo "${APK_REPO_URL}" >> /etc/apk/repositories; \
      apk update; \
      apk add --no-cache ${ENABLED_MODULES}; \
    fi

RUN modules_conf="/etc/nginx/modules/50-custom-dynamic-modules.conf"; \
    mkdir -p /etc/nginx/modules; \
    : > "${modules_conf}"; \
    for pkg in ${ENABLED_MODULES}; do \
      case "${pkg}" in \
        nginx-module-markdown-filter) \
          echo "load_module /usr/lib/nginx/modules/ngx_http_markdown_filter_module.so;" >> "${modules_conf}" ;; \
        nginx-module-error-page-inherit) \
          echo "load_module /usr/lib/nginx/modules/ngx_http_error_page_inherit_module.so;" >> "${modules_conf}" ;; \
        nginx-module-include-server) \
          echo "load_module /usr/lib/nginx/modules/ngx_http_include_server_module.so;" >> "${modules_conf}" ;; \
        *) \
          echo "No load_module mapping for package: ${pkg}" >&2 ;; \
      esac; \
    done; \
    if [ -s "${modules_conf}" ] && ! grep -Fq 'include /etc/nginx/modules/*.conf;' /etc/nginx/nginx.conf; then \
      tmp_cfg="$(mktemp)"; \
      { echo 'include /etc/nginx/modules/*.conf;'; cat /etc/nginx/nginx.conf; } > "${tmp_cfg}"; \
      cat "${tmp_cfg}" > /etc/nginx/nginx.conf; \
      rm -f "${tmp_cfg}"; \
    fi; \
    rm -rf /tmp/apk-packages

LABEL org.opencontainers.image.description="nginx alpine-slim image with custom dynamic modules installed from an APK repository"
