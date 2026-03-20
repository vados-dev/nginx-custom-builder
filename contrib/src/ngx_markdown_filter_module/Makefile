# ngx_markdown_filter_module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
MARKDOWN_FILTER_NGINX_MODULE_URL := $(GITHUB)/vados-dev/ngx_markdown_filter_module/archive/$(MARKDOWN_FILTER_NGINX_MODULE_VERSION).tar.gz

PKGS += ngx_markdown_filter_module

$(TARBALLS)/ngx_markdown_filter_module-$(MARKDOWN_FILTER_NGINX_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(MARKDOWN_FILTER_NGINX_MODULE_URL),ngx_markdown_filter_module)

.sum-ngx_markdown_filter_module: ngx_markdown_filter_module-$(MARKDOWN_FILTER_NGINX_MODULE_VERSION).tar.gz

ngx_markdown_filter_module: ngx_markdown_filter_module-$(MARKDOWN_FILTER_NGINX_MODULE_VERSION).tar.gz .sum-ngx_markdown_filter_module
	$(UNPACK)
	$(MOVE)

.ngx_markdown_filter_module: ngx_markdown_filter_module
	touch $@
