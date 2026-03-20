# ngx_http_include_server_module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
INCLUDE_SERVER_NGINX_MODULE_URL := $(GITHUB)/vados-dev/ngx_http_include_server_module/archive/$(INCLUDE_SERVER_NGINX_MODULE_VERSION).tar.gz

PKGS += ngx_http_include_server_module

$(TARBALLS)/ngx_http_include_server_module-$(INCLUDE_SERVER_NGINX_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(INCLUDE_SERVER_NGINX_MODULE_URL),ngx_http_include_server_module)

.sum-ngx_http_include_server_module: ngx_http_include_server_module-$(INCLUDE_SERVER_NGINX_MODULE_VERSION).tar.gz

ngx_http_include_server_module: ngx_http_include_server_module-$(INCLUDE_SERVER_NGINX_MODULE_VERSION).tar.gz .sum-ngx_http_include_server_module
	$(UNPACK)
	$(MOVE)

.ngx_http_include_server_module: ngx_http_include_server_module
	touch $@
