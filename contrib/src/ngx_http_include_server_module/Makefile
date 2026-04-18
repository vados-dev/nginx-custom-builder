# ngx_http_include_server_module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGX_HTTP_INCLUDE_SERVER_MODULE_URL := $(GITHUB)/RekGRpth/ngx_http_include_server_module/archive/$(NGX_HTTP_INCLUDE_SERVER_MODULE_GITHASH).tar.gz

PKGS += ngx_http_include_server_module

$(TARBALLS)/ngx_http_include_server_module-$(NGX_HTTP_INCLUDE_SERVER_MODULE_GITHASH).tar.gz:
	$(call download_pkg,$(NGX_HTTP_INCLUDE_SERVER_MODULE_URL),ngx_http_include_server_module)

.sum-ngx_http_include_server_module: ngx_http_include_server_module-$(NGX_HTTP_INCLUDE_SERVER_MODULE_GITHASH).tar.gz

ngx_http_include_server_module: ngx_http_include_server_module-$(NGX_HTTP_INCLUDE_SERVER_MODULE_GITHASH).tar.gz .sum-ngx_http_include_server_module
	$(UNPACK)
	$(MOVE)

.ngx_http_include_server_module: ngx_http_include_server_module
	touch $@
