# nginx-error-page-inherit

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_ERROR_PAGE_INHERIT_URL := $(GITHUB)/vados-dev/ngx_http_error_page_inherit_module/archive/v$(NGINX_ERROR_PAGE_INHERIT_VERSION).tar.gz

PKGS += nginx-error-page-inherit

$(TARBALLS)/nginx-error-page-inherit-$(NGINX_ERROR_PAGE_INHERIT_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_ERROR_PAGE_INHERIT_URL),nginx-error-page-inherit)

.sum-nginx-error-page-inherit: nginx-error-page-inherit-$(NGINX_ERROR_PAGE_INHERIT_VERSION).tar.gz

nginx-error-page-inherit: nginx-error-page-inherit-$(NGINX_ERROR_PAGE_INHERIT_VERSION).tar.gz .sum-nginx-error-page-inherit
	$(UNPACK)
	$(MOVE)

.nginx-error-page-inherit: nginx-error-page-inherit
	touch $@
