# ngx_http_error_page_inherit_module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
ERROR_PAGE_INHERIT_NGINX_MODULE_URL := $(GITHUB)/vados-dev/ngx_http_error_page_inherit_module/archive/$(ERROR_PAGE_INHERIT_NGINX_MODULE_VERSION).tar.gz

PKGS += ngx_http_error_page_inherit_module

$(TARBALLS)/ngx_http_error_page_inherit_module-$(ERROR_PAGE_INHERIT_NGINX_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(ERROR_PAGE_INHERIT_NGINX_MODULE_URL),ngx_http_error_page_inherit_module)

.sum-ngx_http_error_page_inherit_module: ngx_http_error_page_inherit_module-$(ERROR_PAGE_INHERIT_NGINX_MODULE_VERSION).tar.gz

ngx_http_error_page_inherit_module: ngx_http_error_page_inherit_module-$(ERROR_PAGE_INHERIT_NGINX_MODULE_VERSION).tar.gz .sum-ngx_http_error_page_inherit_module
	$(UNPACK)
	$(MOVE)

.ngx_http_error_page_inherit_module: ngx_http_error_page_inherit_module
	touch $@
