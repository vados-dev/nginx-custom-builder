SHELL=		/bin/bash

BASE_VERSION=	1.29.6
BASE_RELEASE=	1
BASE_SRC=	nginx-$(BASE_VERSION).tar.gz
SRCPATH?=	../SOURCES
CONTRIB?=       ../contrib
CONTRIB:=       $(abspath $(CONTRIB))
BUILD_ENV_PATH=	${HOME}/rpmbuild
ARTIFACTS_DIR?=	/.data/nfs/dst/nginx/RPMS all
COPY_ARTIFACTS?=	1 #$(if $(CI),1,0)
BUILD_SOURCES=	$(BUILD_ENV_PATH)/SOURCES
MODULE_TARGET?=	oss
MODSRC_PREFIX=
MODSRC_PATH=	$(SRCPATH)
BUILD_DIR=	%{bdir}
RPMBUILD_ARGS?=	-bb
RPMBUILD_EXTRA_DEFINES?=

GITHUB := https://github.com/vados-dev

ifndef GIT
ifeq ($(shell git --version >/dev/null 2>&1 || echo FAIL),)
GIT = git
endif
endif
GIT ?= $(error git not found)

ifeq ($(MODULE_TARGET), plus)
MODULE_SPEC_TEMPLATE=	nginx-plus-module.spec.in
MODULE_SUMMARY_PREFIX=	NGINX Plus
else
MODULE_SPEC_TEMPLATE=	nginx-module.spec.in
MODULE_SUMMARY_PREFIX=	nginx
endif

ifeq ($(MODULE_TARGET), plus)
MODULE_SUMMARY_PREFIX=  NGINX Plus
TARGET_VERSION=$(PLUS_VERSION)
MODULE_SUFFIX=-plus
PACKAGE_URL=     https://www.nginx.com/
PACKAGE_LICENSE= Proprietary (EULA included)
else
MODULE_SUMMARY_PREFIX=  nginx
TARGET_VERSION=$(BASE_VERSION)
PACKAGE_URL=     https://nginx.org/
PACKAGE_LICENSE=2-clause BSD-like license
endif

PACKAGE_VENDOR=	NGINX Inc.

# Unified module selection point:
# - module metadata stays in Makefile.module-*
# - enabled set is controlled only here.
MODULES?=

-include Makefile.module-*

DISCOVERED_MODULES := $(strip $(MODULES))
ENABLED_MODULES ?= acme geoip image-filter njs otel perl xslt markdown-filter 	error-page-inherit include-server
MODULES := $(strip $(filter $(ENABLED_MODULES),$(DISCOVERED_MODULES)))

STANDARD_CONFIGURE_MODULES=\
	--with-compat \
	--with-file-aio \
	--with-threads \
	--with-http_addition_module \
	--with-http_auth_request_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_mp4_module \
	--with-http_random_index_module \
	--with-http_realip_module \
	--with-http_secure_link_module \
	--with-http_slice_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-http_v3_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-stream \
	--with-stream_realip_module \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module

EXTRA_BASE_CONFIGURE_ARGS?=

BASE_CONFIGURE_ARGS=\
	--prefix=%{_sysconfdir}/nginx \
	--sbin-path=%{_sbindir}/nginx \
	--modules-path=%{_libdir}/nginx/modules \
	--conf-path=%{_sysconfdir}/nginx/nginx.conf \
	--error-log-path=%{_localstatedir}/log/nginx/error.log \
	--http-log-path=%{_localstatedir}/log/nginx/access.log \
	--pid-path=%{_localstatedir}/run/nginx.pid \
	--lock-path=%{_localstatedir}/run/nginx.lock \
	--http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp \
	--http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp \
	--user=%{nginx_user} \
	--group=%{nginx_group} \
	$(STANDARD_CONFIGURE_MODULES) \
	$(EXTRA_BASE_CONFIGURE_ARGS)

BASE_DYNAMIC_MODULES_ARGS=\
	--with-http_image_filter_module=dynamic \
	--with-http_xslt_module=dynamic \
	--with-http_perl_module=dynamic

ifeq ($(BASE_TARGET), plus)
BASE_CONFIGURE_ARGS+= \
        --build=nginx-plus-r$(PLUS_VERSION) \
        --mgmt-id-path=/var/lib/nginx/nginx.id \
        --with-http_auth_jwt_module \
        --with-http_f4f_module \
        --with-http_hls_module \
        --with-http_proxy_protocol_vendor_module \
        --with-http_session_log_module \
        --with-mgmt \
        --with-stream_mqtt_filter_module \
        --with-stream_mqtt_preread_module \
        --with-stream_proxy_protocol_vendor_module
endif

include $(CONTRIB)/attestation.mak

export CR=\\n

modname = $(shell echo $1 | tr '-' '_')
#modname = $(shell basename "$(1)" | sed -e 's#^nginx-module-##' -e 's#\.spec$$##' | tr '-' '_')

default:
	@echo "valid targets: all clean cln tree base $(addprefix module-, $(MODULES)) test test-debug"
	@echo "list targets: list list-all-modules"

all:
	@$(MAKE) clean
	@$(MAKE) tree
	@$(MAKE) specs
	@$(MAKE) base modules
	@echo "===> $@ done!"

tree:
	@rpmdev-setuptree
	@echo "===> setuptree done"

modules:	$(addprefix module-, $(MODULES))

list-base:
	@printf "%-20s\t%s\n" nginx $(BASE_VERSION)-$(BASE_RELEASE)

list-module-%:
	@printf "%-20s\t%s\n" $* $(MODULE_VERSION_$(call modname, $*))-$(MODULE_RELEASE_$(call modname, $*))
#	@printf '%s\n' "$*"

list-all-modules: $(addprefix list-module-, $(MODULES))

list-base-modules: $(addprefix list-module-, $(BASE_MODULES))

list: list-base list-all-modules

specs:
	@rm -f nginx.spec nginx-module-*.spec
	@$(MAKE) nginx.spec $(addsuffix .spec, $(addprefix nginx-module-, $(MODULES)))
	@echo "===> $@ done!"

$(BUILD_SOURCES)/$(BASE_SRC):
	@mkdir -p $(BUILD_SOURCES)
	@cd $(BUILD_SOURCES) && wget -N http://nginx.org/download/$(BASE_SRC)
	@echo "===> $@ done!"

stage-sources: $(BUILD_SOURCES)/$(BASE_SRC)
	@mkdir -p $(BUILD_SOURCES)
	@find $(SRCPATH) -maxdepth 1 \( -type f -o -type l \) ! -name "$(BASE_SRC)" -exec cp -Lf {} $(BUILD_SOURCES)/ \;
	@echo "===> $@ done!"

base:	nginx.spec stage-sources
	@echo "===> Building base package" ; \
	$(SHELL) -c "time -p rpmbuild $(RPMBUILD_ARGS) $(RPMBUILD_EXTRA_DEFINES) nginx.spec" && \
	if [ "$(COPY_ARTIFACTS)" = "1" ]; then \
		mkdir -p $(ARTIFACTS_DIR) && \
		find $(BUILD_ENV_PATH)/RPMS -type f -name "*.rpm" -exec cp -f {} $(ARTIFACTS_DIR)/ \; && \
		find $(BUILD_ENV_PATH)/SRPMS -maxdepth 1 -type f -name "*.src.rpm" -exec cp -f {} $(ARTIFACTS_DIR)/ \; ; \
	fi && \
	ln -s ../BUILD/nginx-$(BASE_VERSION)/objs base
	@echo "===> $@ done!"

nginx.spec:
	@echo "===> Creating $@"
	@{ \
	set -e ; \
	cat nginx.spec.in | sed \
		-e 's#%%PACKAGE_VENDOR%%#$(PACKAGE_VENDOR)#g' \
		-e 's#%%PACKAGE_URL%%#$(PACKAGE_URL)#g' \
		-e 's#%%BASE_VERSION%%#$(BASE_VERSION)#g' \
		-e 's#%%BASE_RELEASE%%#$(BASE_RELEASE)#g' \
		-e 's#%%MAIN_VERSION%%#$(BASE_VERSION)#g' \
		-e 's#%%MAIN_RELEASE%%#$(BASE_RELEASE)#g' \
		-e "s#%%BASE_PATCHES%%#$$patches#g" \
		-e 's#%%BASE_CONFIGURE_ARGS%%#$(BASE_CONFIGURE_ARGS)#g' \
		-e 's#%%BASE_DYNAMIC_MODULES_ARGS%%#$(BASE_DYNAMIC_MODULES_ARGS)#g' \
		> nginx.spec ; \
	}
	@echo "===> $@ done!"

.deps-module-%:
	@if [ -n "$(MODULE_CONTRIB_DEPS_$(call modname,$*))" ]; then \
		cd $(CONTRIB) && make $(foreach dep,$(MODULE_CONTRIB_DEPS_$(call modname,$*)),.sum-$(dep)); \
	fi ; \
	touch $@

module-%: nginx-module-%.spec .deps-module-% stage-sources
	@echo "===> Building nginx-$@ package" ; \
	$(MAKE) --no-print-directory stage-sources && \
	$(SHELL) -c "time -p rpmbuild $(RPMBUILD_ARGS) $(RPMBUILD_EXTRA_DEFINES) nginx-$@.spec" && \
	if [ "$(COPY_ARTIFACTS)" = "1" ]; then \
		mkdir -p $(ARTIFACTS_DIR) && \
		find $(BUILD_ENV_PATH)/RPMS -type f -name "*.rpm" -exec cp -f {} $(ARTIFACTS_DIR)/ \; && \
		find $(BUILD_ENV_PATH)/SRPMS -maxdepth 1 -type f -name "*.src.rpm" -exec cp -f {} $(ARTIFACTS_DIR)/ \; ; \
	fi && \
	ln -s ../BUILD/nginx-$@-$(BASE_VERSION)/objs $@
	@echo "===> $@ done!"

nginx-module-%.spec:
	@echo "===> Creating $@"
	@{ \
	set -e ; \
	i=100 ; \
	sources= ; \
	prepsources= ; \
	for src in $(MODULE_SOURCES_$(call modname,$*)); do \
		is_archive=0 ; \
		case "$${src}" in \
			http://*.tar|https://*.tar|http://*.tar.gz|https://*.tar.gz|http://*.tgz|https://*.tgz|http://*.tar.bz2|https://*.tar.bz2|http://*.tbz2|https://*.tbz2|http://*.tar.xz|https://*.tar.xz|http://*.txz|https://*.txz) \
				s="`printf "Source%d: %s\n" $${i} $${src}`" ; \
				sources="$${sources}\n$${s}" ; \
				is_archive=1 ; \
				s="`printf "src=%%{SOURCE%d}; file=$${src##*/}; curl -fL \"$${src}\" -o \"$${file}\"; tar -xf \"$${file}\"" $${i}`" ;; \
			*.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) \
				if [ -f "$(CONTRIB)/tarballs/$${src}" ]; then \
					cp -f "$(CONTRIB)/tarballs/$${src}" "$(SRCPATH)/$${src}" ; \
				fi ; \
				s="`printf "Source%d: %s\n" $${i} $${src}`" ; \
				sources="$${sources}\n$${s}" ; \
				is_archive=1 ; \
				s="`printf "tar -xf %%{SOURCE%d}" $${i}`" ;; \
			*.git) \
				s="`printf "git clone %s" $${src}`" ;; \
			*) \
				s="`printf "Source%d: %s\n" $${i} $${src}`" ; \
				sources="$${sources}\n$${s}" ; \
				s="`printf "echo Skipping non-archive SOURCE%d" $${i}`" ;; \
		esac ; \
		prepsources="$${prepsources}\n$${s}" ; \
		if [ "$${is_archive}" = "1" ]; then \
			sn=`echo $${src##*/} | sed -e 's/[?].*$$//' -e 's/\(\\.tar\\.gz\\|\\.tgz\\|\\.tar\\.bz2\\|\\.tbz2\\|\\.tar\\.xz\\|\\.txz\\|\\.tar\\)$$//' -e 's/-[0-9].*$$//'` ; \
			[ -n "$${sn}" ] && prepsources="$${prepsources}\nln -sfn $${sn}-* $${sn} || true" ; \
		fi ; \
		i=$$(($${i}+1)) ; \
	done ; \
	i=100 ; \
	patches= ; \
	preppatches= ; \
	for src in $(MODULE_PATCHES_$(call modname,$*)); do \
		patch_src="$${src}" ; \
		patch_dir="" ; \
		case "$${src}" in \
			*::* ) \
				patch_dir="$${src%%::*}" ; \
				patch_src="$${src#*::}" ;; \
		esac ; \
		dn=`dirname "$${patch_src}"` ; \
		bdn=`basename "$${dn}"` ; \
		pn="$${bdn}_`basename "$${patch_src}"`" ; \
		cp -f "$${patch_src}" "$(SRCPATH)/$${pn}" ; \
		s="`printf "Patch%d: %s\n" $${i} $${pn}`" ; \
		patches="$${patches}\n$${s}" ; \
		if [ -n "$${patch_dir}" ]; then \
			s="`printf "(cd %s \\&\\& %%{__patch} -p1 < %%{PATCH%d})" "$${patch_dir}" $${i}`" ; \
		else \
			s="`printf "%%patch%d -p1" $${i}`" ; \
		fi ; \
		preppatches="$${preppatches}\n$${s}" ; \
		i=$$(($${i}+1)) ; \
	done ; \
	module_copyright=`echo $@ | sed -e "s#.spec#.copyright#"` ; \
	module_package_license="$(strip $(MODULE_PACKAGE_LICENSE_$(call modname,$*)))" ; \
	module_changelog=`echo $@ | sed -e "s#.spec#.changelog.in#"` ; \
	if [ -f $${module_changelog} ]; then \
		changelog_file=$${module_changelog} ; \
	else \
		changelog_file=nginx-module.changelog.in ; \
	fi ; \
	pkgname=`echo $@ | cut -d '.' -f 1` ; \
	if [ "$(MODULE_TARGET)" = "plus" ]; then \
		pkgname=`echo $${pkgname} | sed -e "s#^nginx-#nginx-plus-#"` ; \
	fi ; \
	if [ -z "$${module_package_license}" ]; then \
		tmplic=`mktemp -d` ; \
		found_license="" ; \
		for src in $(MODULE_SOURCES_$(call modname,$*)); do \
			work="$${tmplic}/scan" ; \
			rm -rf "$${work}" ; \
			mkdir -p "$${work}" ; \
			case "$${src}" in \
				*.git) \
					git clone --depth 1 "$${src}" "$${work}/src" >/dev/null 2>&1 || true ; \
					[ -d "$${work}/src" ] && found_license=`find "$${work}/src" -maxdepth 4 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'COPYRIGHT*' \) | head -n 1` ;; \
				http://*|https://*) \
					case "$${src}" in \
						*.git) \
							git clone --depth 1 "$${src}" "$${work}/src" >/dev/null 2>&1 || true ; \
							[ -d "$${work}/src" ] && found_license=`find "$${work}/src" -maxdepth 4 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'COPYRIGHT*' \) | head -n 1` ;; \
						*.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) \
							file="$${work}/$${src##*/}" ; \
							curl -fsSL "$${src}" -o "$${file}" >/dev/null 2>&1 || true ; \
							if [ -f "$${file}" ]; then \
								mkdir -p "$${work}/src" ; \
								tar -xf "$${file}" -C "$${work}/src" >/dev/null 2>&1 || true ; \
								found_license=`find "$${work}/src" -maxdepth 4 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'COPYRIGHT*' \) | head -n 1` ; \
							fi ;; \
					esac ;; \
				*) \
					file="$(SRCPATH)/$${src}" ; \
					if [ -f "$${file}" ]; then \
						case "$${file}" in \
							*.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) \
								mkdir -p "$${work}/src" ; \
								tar -xf "$${file}" -C "$${work}/src" >/dev/null 2>&1 || true ; \
								found_license=`find "$${work}/src" -maxdepth 4 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'COPYRIGHT*' \) | head -n 1` ;; \
						esac ; \
					fi ;; \
			esac ; \
			[ -n "$${found_license}" ] && break ; \
		done ; \
		if [ -n "$${found_license}" ]; then \
			if [ ! -f ../SOURCES/$${module_copyright} ]; then \
				cp -f "$${found_license}" ../SOURCES/$${module_copyright} || true ; \
			fi ; \
			if grep -qiE 'apache[[:space:]-]*2(\.0)?|apache license' "$${found_license}"; then \
				module_package_license="Apache-2.0" ; \
			elif grep -qiE 'mit license|permission is hereby granted, free of charge' "$${found_license}"; then \
				module_package_license="MIT" ; \
			elif grep -qiE 'bsd|redistribution and use in source and binary forms' "$${found_license}"; then \
				module_package_license="BSD-2-Clause" ; \
			elif grep -qiE 'gnu general public license|\\bgpl\\b' "$${found_license}"; then \
				module_package_license="GPL-2.0-or-later" ; \
			else \
				module_package_license="LicenseRef-See-Source" ; \
			fi ; \
		else \
			module_package_license="MIT" ; \
			if [ ! -f ../SOURCES/$${module_copyright} ]; then \
				printf '%s\n' 'MIT' > ../SOURCES/$${module_copyright} ; \
			fi ; \
		fi ; \
		rm -rf "$${tmplic}" ; \
	fi ; \
	if [ -f ../SOURCES/$${module_copyright} ]; then \
		copyright_source=$${module_copyright} ; \
	else \
		if [ -f ../docs/$${module_copyright} ]; then \
			cp -f ../docs/$${module_copyright} ../SOURCES/$${module_copyright} ; \
		else \
			printf '%s\n' 'MIT' > ../SOURCES/$${module_copyright} ; \
		fi ; \
		copyright_source=$${module_copyright} ; \
	fi ; \
	if [ -z "$${module_package_license}" ]; then \
		module_package_license="MIT" ; \
	fi ; \
	definitions=`echo "$$MODULE_DEFINITIONS_$(call modname,$*)" | sed -e ':a' -e 'N' -e '$$!ba' -e "s/\n/\$$CR/g"` ; \
	prebuild=`echo "$$MODULE_PREBUILD_$(call modname,$*)" | sed -e ':a' -e 'N' -e '$$!ba' -e "s/\n/\$$CR/g"` ; \
	preinstall=`echo "$$MODULE_PREINSTALL_$(call modname,$*)" | sed -e ':a' -e 'N' -e '$$!ba' -e "s/\n/\$$CR/g"` ; \
	buildenv=`echo "$$MODULE_ENV_$(call modname,$*)" | sed -e ':a' -e 'N' -e '$$!ba' -e "s/\n/\$$CR/g"` ; \
	files=`echo "$$MODULE_FILES_$(call modname,$*)" | sed -e ':a' -e 'N' -e '$$!ba' -e "s/\n/\$$CR/g"` ; \
	post=`echo "$$MODULE_POST_$(call modname,$*)" | sed -e ':a' -e 'N' -e '$$!ba' -e "s/\n/\$$CR/g"` ; \
	cat $(MODULE_SPEC_TEMPLATE) | sed \
			-e "s#%%NAME%%#$${pkgname}#g" \
			-e "s#%%PACKAGE_VENDOR%%#$(if $(strip $(MODULE_PACKAGE_VENDOR_$(call modname,$*))),$(strip $(MODULE_PACKAGE_VENDOR_$(call modname,$*))),$(PACKAGE_VENDOR))#g" \
			-e "s#%%MODULE_PACKAGE_VENDOR%%#$(if $(strip $(MODULE_PACKAGE_VENDOR_$(call modname,$*))),$(strip $(MODULE_PACKAGE_VENDOR_$(call modname,$*))),$(PACKAGE_VENDOR))#g" \
			-e "s#%%MODULE_PACKAGE_URL%%#$(if $(strip $(MODULE_PACKAGE_URL_$(call modname,$*))),$(strip $(MODULE_PACKAGE_URL_$(call modname,$*))),$(PACKAGE_URL))#g" \
			-e "s#%%MODULE_PACKAGE_LICENSE%%#$${module_package_license}#g" \
			-e "s#%%SUMMARY%%#$(MODULE_SUMMARY_PREFIX) $(MODULE_SUMMARY_$(call modname,$*))#g" \
		-e "s#%%SHORT_SUMMARY%%#$(MODULE_SUMMARY_$(call modname,$*))#g" \
		-e "s#%%TARGET_VERSION%%#$(TARGET_VERSION)#g" \
		-e "s#%%MAIN_VERSION%%#$(BASE_VERSION)#g" \
		-e "s#%%MAIN_RELEASE%%#$(BASE_RELEASE)#g" \
		-e "s#%%BASE_VERSION%%#$(BASE_VERSION)#g" \
		-e "s#%%BASE_RELEASE%%#$(BASE_RELEASE)#g" \
		-e "s#%%VERSION_PREFIX%%#$(MODULE_VERSION_PREFIX_$(call modname,$*))#g" \
		-e "s#%%MODULE_VERSION_PREFIX%%#$(MODULE_VERSION_PREFIX_$(call modname,$*))#g" \
		-e "s#%%VERSION%%#$(MODULE_VERSION_$(call modname,$*))#g" \
		-e "s#%%RELEASE%%#$(MODULE_RELEASE_$(call modname,$*))#g" \
		-e "s#%%BASE_CONFIGURE_ARGS%%#$(BASE_CONFIGURE_ARGS)#g" \
		-e "s#%%MODULE_CONFIGURE_ARGS%%#$(MODULE_CONFARGS_$(call modname,$*))#g" \
		-e "s#%%COPYRIGHT_SOURCE%%#$${copyright_source}#g" \
		-e "s#%%MODULE_SOURCES%%#$${sources}#g" \
		-e "s#%%MODULE_PATCHES%%#$${patches}#g" \
		-e "s#%%MODULE_PREP_SOURCES%%#$${prepsources}#g" \
		-e "s#%%MODULE_PREP_PATCHES%%#$${preppatches}#g" \
		-e "s#%%MODULE_DEFINITIONS%%#$${definitions}#g" \
		-e "s#%%MODULE_PREBUILD%%#$${prebuild}#g" \
		-e "s#%%MODULE_ENV%%#$${buildenv}#g" \
		-e "s#%%MODULE_CC_OPT%%#$(MODULE_CC_OPT_$(call modname,$*))#g" \
		-e "s#%%MODULE_LD_OPT%%#$(MODULE_LD_OPT_$(call modname,$*))#g" \
		-e "s#%%MODULE_CC_OPT_DEBUG%%#$(MODULE_CC_OPT_DEBUG_$(subst -,_,$*))#g" \
		-e "s#%%MODULE_LD_OPT_DEBUG%%#$(MODULE_LD_OPT_DEBUG_$(subst -,_,$*))#g" \
		-e "s#%%MODULE_CC_OPT_NODEBUG%%#$(MODULE_CC_OPT_NODEBUG_$(subst -,_,$*))#g" \
		-e "s#%%MODULE_PREINSTALL%%#$${preinstall}#g" \
		-e "s#%%MODULE_FILES%%#$${files}#g" \
		-e "s#%%MODULE_POST%%#$${post}#g" \
		> $@.tmp && \
	sed -i -e 's#^Vendor URL:#URL:#' $@.tmp && \
	cat $${changelog_file} | grep -v "^#" >> $@.tmp && \
	mv $@.tmp $@ ; \
	}
	@echo "===> $@ done!"

nginx-tests:
	@{ \
	if [ -d "../nginx-tests" ]; then \
		echo "===> Copying tests from ../nginx-tests" ; \
		cp -rP ../nginx-tests nginx-tests ; \
	else \
		echo "===> Cloning tests" ; \
		hg clone http://hg.nginx.org/nginx-tests ; \
	fi ; \
	}
	@echo "===> $@ done!"

test: base nginx-tests
	@echo "===> Running tests with regular binary/modules"
	@{ \
	pwd=`pwd` ; \
	globals= ; \
	for so in `find module-*/ -maxdepth 1 -type f -name "*module.so"`; do \
		globals="$$globals load_module $$pwd/$$so;" ; \
	done ; \
	if [ -d $$pwd/module-perl ]; then \
		globals="$$globals env PERL5LIB=$$pwd/module-perl/src/http/modules/perl:$$pwd/module-perl/src/http/modules/perl/blib/arch;" ; \
	fi ; \
	cd nginx-tests && TEST_NGINX_BINARY=$$pwd/base/nginx TEST_NGINX_GLOBALS="$$globals" prove . ; \
	}
	@echo "===> $@ done!"

test-debug: base nginx-tests
	@echo "===> Running tests with debug binary/modules"
	@{ \
	pwd=`pwd` ; \
	globals= ; \
	for so in `find module-*/ -maxdepth 1 -type f -name "*module-debug.so"`; do \
		globals="$$globals load_module $$pwd/$$so;" ; \
	done ; \
	if [ -d $$pwd/module-perl ]; then \
		globals="$$globals env PERL5LIB=$$pwd/module-perl/src/http/modules/perl:$$pwd/module-perl/src/http/modules/perl/blib/arch;" ; \
	fi ; \
	cd nginx-tests && TEST_NGINX_BINARY=$$pwd/base/nginx-debug TEST_NGINX_GLOBALS="$$globals" prove . ; \
	}
	@echo "===> $@ done!"

prepare-build-env: $(BASE_SRC)
	@{ \
	set -e ; \
	cwd=`pwd` ; \
	case $$cwd in $(BUILD_ENV_PATH)*) \
		echo "You are in $(BUILD_ENV_PATH), skipping" >&2 ; \
		exit 1 ; \
	esac ; \
	if [ -e $(BUILD_ENV_PATH) ]; then \
		echo "$(BUILD_ENV_PATH) is already exists and going to be removed." ; \
		echo "Press Enter to continue or Ctrl+C to exit" ; \
		read ; \
		rm -rf $(BUILD_ENV_PATH) ; \
	fi ; \
	mkdir -p $(BUILD_ENV_PATH) ; \
	pd=`dirname $${cwd}` ; \
	cp -rP $${pd}/SPECS $(BUILD_ENV_PATH)/ ; \
	cp -rP $${pd}/SOURCES $(BUILD_ENV_PATH)/ ; \
	cp $(BASE_SRC) $(BUILD_ENV_PATH)/SOURCES/ ; \
	echo "Build environment has been created in: $(BUILD_ENV_PATH)" ; \
	echo ; \
	echo "Please do the following in order to get available build targets:" ; \
	echo "    cd $(BUILD_ENV_PATH)/SPECS" ; \
	echo "    make" ; \
	}
	@echo "===> $@ done!"

cln:
	@rm -f base module-*
	@rm -f nginx.spec nginx-module-*.spec
	@rm -rf nginx-tets
	@rm -rf $(SRCPATH)/$(BASE_SRC)
	@echo "===> $@ done!"

clean: cln
	@rpmdev-wipetree
	@echo "===> $@ done!"

detect-module-licenses:
	@{ \
	set -e ; \
	tmpdir=`mktemp -d` ; \
	keep_tmp="$(KEEP_TMP)" ; \
	if [ -z "$${keep_tmp}" ] || [ "$${keep_tmp}" = "0" ]; then \
		trap 'rm -rf "$${tmpdir}"' EXIT ; \
	else \
		echo "tmpdir kept: $${tmpdir}" ; \
	fi ; \
	meta="$${tmpdir}/modules.tsv" ; \
	: > "$${meta}" ; \
	$(foreach m,$(MODULES),printf '%s|%s|%s|%s\n' '$(m)' '$(MODULE_SOURCES_$(subst -,_,$(m)))' '$(MODULE_PACKAGE_LICENSE_$(subst -,_,$(m)))' '$(MODULE_PACKAGE_URL_$(subst -,_,$(m)))' >> "$${meta}" ; ) \
	while IFS='|' read -r mod src lic vendor ; do \
		echo ; \
		echo "===> $${mod}" ; \
		if [ -z "$${src}" ] && [ -n "$${vendor}" ]; then src="$${vendor}" ; fi ; \
		if [ -z "$${src}" ]; then echo "source: <not found>" ; continue ; fi ; \
		echo "source: $${src}" ; \
		if [ -n "$${vendor}" ]; then echo "vendor url: $${vendor}" ; fi ; \
		if [ -n "$${lic}" ]; then \
			echo "configured license: $${lic}" ; \
		fi ; \
		work="$${tmpdir}/$${mod}" ; \
		scan="" ; \
		mkdir -p "$${work}" ; \
		case "$${src}" in \
			*.git) \
				if git clone --depth 1 "$${src}" "$${work}/src" >/dev/null 2>&1 ; then \
					scan="$${work}/src" ; \
				else \
					if [ -n "$${vendor}" ] && git clone --depth 1 "$${vendor}" "$${work}/src" >/dev/null 2>&1 ; then \
						scan="$${work}/src" ; \
						echo "clone via vendor url succeeded" ; \
					elif [ -n "$${vendor}" ] && git clone --depth 1 "$${vendor}.git" "$${work}/src" >/dev/null 2>&1 ; then \
						scan="$${work}/src" ; \
						echo "clone via vendor .git succeeded" ; \
					else \
						echo "clone failed" ; \
						continue ; \
					fi ; \
				fi ;; \
			http://*|https://*) \
				case "$${src}" in \
					*.git) \
						git clone --depth 1 "$${src}" "$${work}/src" >/dev/null 2>&1 && scan="$${work}/src" ;; \
					*.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) \
						file="$${work}/$${src##*/}" ; \
						if ! curl -fsSL "$${src}" -o "$${file}" >/dev/null 2>&1 ; then \
							echo "download failed" ; \
							continue ; \
						fi ; \
						mkdir -p "$${work}/src" ; \
						tar -xf "$${file}" -C "$${work}/src" >/dev/null 2>&1 || true ; \
						scan="$${work}/src" ;; \
					*) \
						if git clone --depth 1 "$${src}" "$${work}/src" >/dev/null 2>&1 ; then \
							scan="$${work}/src" ; \
						elif git clone --depth 1 "$${src}.git" "$${work}/src" >/dev/null 2>&1 ; then \
							scan="$${work}/src" ; \
							echo "clone via .git suffix succeeded" ; \
						else \
							echo "source URL is neither cloneable repo nor supported archive" ; \
						fi ;; \
				esac ; \
				if [ -z "$${scan}" ] && [ -n "$${vendor}" ]; then \
					if git clone --depth 1 "$${vendor}" "$${work}/src" >/dev/null 2>&1 ; then \
						scan="$${work}/src" ; \
						echo "clone via vendor url succeeded" ; \
					elif git clone --depth 1 "$${vendor}.git" "$${work}/src" >/dev/null 2>&1 ; then \
						scan="$${work}/src" ; \
						echo "clone via vendor .git succeeded" ; \
					fi ; \
				fi ;; \
			*) \
				if [ ! -f "$(SRCPATH)/$${src}" ]; then \
					echo "local source missing: $(SRCPATH)/$${src}" ; \
					continue ; \
				fi ; \
				file="$(SRCPATH)/$${src}" ; \
				case "$${file}" in \
					*.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) \
						mkdir -p "$${work}/src" ; \
						tar -xf "$${file}" -C "$${work}/src" >/dev/null 2>&1 || true ; \
						scan="$${work}/src" ;; \
					*) \
						echo "local source is not an archive: $${src}" ;; \
				esac ;; \
		esac ; \
		if [ -z "$${scan}" ] || [ ! -d "$${scan}" ]; then \
			echo "license scan skipped" ; \
			continue ; \
		fi ; \
		cand=`find "$${scan}" -maxdepth 4 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'COPYRIGHT*' \) | head -n 5` ; \
		if [ -n "$${cand}" ]; then \
			echo "license files:" ; \
			echo "$${cand}" | sed -e 's#^#  - #' ; \
			if [ -z "$${lic}" ]; then \
				modkey=`echo "$${mod}" | tr '-' '_'` ; \
				first_license=`echo "$${cand}" | head -n 1` ; \
				title=`head -n 1 "$${first_license}" | tr -d '\r'` ; \
				guess="" ; \
				case "$${title}" in \
					*MIT*) guess="MIT" ;; \
					*Apache*2.0*) guess="Apache-2.0" ;; \
					*BSD*3*) guess="BSD-3-Clause" ;; \
					*BSD*2*) guess="BSD-2-Clause" ;; \
					*GNU\ GENERAL\ PUBLIC\ LICENSE*3*) guess="GPL-3.0-only" ;; \
					*GNU\ GENERAL\ PUBLIC\ LICENSE*2*) guess="GPL-2.0-only" ;; \
				esac ; \
				echo "warning: MODULE_PACKAGE_LICENSE_$${modkey} is empty" ; \
				if [ -n "$${guess}" ]; then \
					echo "suggested license: $${guess}" ; \
				else \
					echo "suggested license: inspect $${first_license}" ; \
				fi ; \
			fi ; \
		else \
			echo "license files: not found" ; \
		fi ; \
		spdx=`grep -R -m1 -h -E 'SPDX-License-Identifier:[[:space:]]*[^[:space:]]+' "$${scan}" 2>/dev/null | sed -E 's/.*SPDX-License-Identifier:[[:space:]]*//' | head -n 1` ; \
		if [ -n "$${spdx}" ]; then \
			echo "spdx hint: $${spdx}" ; \
		fi ; \
	done < "$${meta}" ; \
	if [ -n "$${keep_tmp}" ] && [ "$${keep_tmp}" != "0" ]; then \
		echo ; \
		echo "inspect files under: $${tmpdir}" ; \
	fi ; \
	}

.PHONY:	default all modules specs stage-sources test test-debug clean cln detect-module-licenses list list-base list-all-modules


.SECONDARY:
