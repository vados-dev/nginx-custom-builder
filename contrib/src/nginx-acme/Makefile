# nginx-acme
#
# https://github.com/nginx/nginx-acme/

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_ACME_URL := $(GITHUB)/nginx/nginx-acme/releases/download/v$(NGINX_ACME_VERSION)/nginx-acme-$(NGINX_ACME_VERSION).tar.gz

PKGS += nginx-acme

DEPS_nginx-acme =

$(TARBALLS)/nginx-acme-$(NGINX_ACME_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_ACME_URL),nginx-acme)

.sum-nginx-acme: nginx-acme-$(NGINX_ACME_VERSION).tar.gz

nginx-acme: nginx-acme-$(NGINX_ACME_VERSION).tar.gz .sum-nginx-acme
	$(UNPACK)
	$(MOVE)

.nginx-acme: nginx-acme
	touch $@
