# ngx_markdown_filter_module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGX_MARKDOWN_FILTER_MODULE_URL := $(GITHUB)/ukarim/ngx_markdown_filter_module/archive/refs/tags/$(NGX_MARKDOWN_FILTER_MODULE_VERSION).tar.gz

PKGS += ngx_markdown_filter_module

$(TARBALLS)/ngx_markdown_filter_module-$(NGX_MARKDOWN_FILTER_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(NGX_MARKDOWN_FILTER_MODULE_URL),ngx_markdown_filter_module)

.sum-ngx_markdown_filter_module: ngx_markdown_filter_module-$(NGX_MARKDOWN_FILTER_MODULE_VERSION).tar.gz

ngx_markdown_filter_module: ngx_markdown_filter_module-$(NGX_MARKDOWN_FILTER_MODULE_VERSION).tar.gz .sum-ngx_markdown_filter_module
	$(UNPACK)
	$(MOVE)

.ngx_markdown_filter_module: ngx_markdown_filter_module
	touch $@
