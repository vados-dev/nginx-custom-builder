BRANCH?=                $(shell git rev-parse --abbrev-ref HEAD)

ifeq (,$(findstring stable,$(BRANCH)))
FLAVOR=         mainline
else
FLAVOR=         stable
endif

CURRENT_VERSION_STRING=$(shell curl -fs https://version.nginx.com/nginx/$(FLAVOR))

CURRENT_VERSION=$(word 1,$(subst -, ,$(CURRENT_VERSION_STRING)))
CURRENT_RELEASE=$(word 2,$(subst -, ,$(CURRENT_VERSION_STRING)))

CURRENT_VERSION_STRING_NJS=$(shell curl -fs https://version.nginx.com/njs/$(FLAVOR))
CURRENT_VERSION_NJS=$(word 2,$(subst +, ,$(word 1,$(subst -, ,$(CURRENT_VERSION_STRING_NJS)))))
CURRENT_RELEASE_NJS=$(word 2,$(subst -, ,$(CURRENT_VERSION_STRING_NJS)))

VERSION?=       $(shell curl -Lfs https://github.com/nginx/nginx/raw/$(BRANCH)/src/core/nginx.h | grep -F 'define NGINX_VERSION' | cut -d '"' -f 2)
RELEASE?=       1

VERSION_NJS?= $(shell curl -Lfs https://github.com/nginx/njs/raw/master/src/njs.h | grep -F -m 1 'define NJS_VERSION' | cut -d '"' -f 2)
RELEASE_NJS?= 1

PACKAGER?=      Nginx Packaging <nginx-packaging@f5.com>

TARBALL?=       https://nginx.org/download/nginx-$(VERSION).tar.gz

TARBALL_NJS?=   https://github.com/nginx/njs/archive/refs/tags/${VERSION_NJS}.tar.gz

BASE_MAKEFILES= alpine/Makefile \
                debian/Makefile \
                SPECS/Makefile

#MODULES=        geoip image-filter perl xslt
#EXTERNAL_MODULES=       acme error-page-inherit include-server markdown-filter njs
#auth-spnego brotli encrypted-session fips-check geoip2 headers-more lua ndk njs opentracing otel passenger rtmp set-misc subs-filter

MODULES=        image-filter perl xslt
EXTERNAL_MODULES=       acme auth-spnego brotli encrypted-session fips-check geoip2 headers-more lua ndk njs otel error-page-inherit include-server markdown-filter
#passenger rtmp set-misc subs-filter

ifeq ($(shell sha512sum --version >/dev/null 2>&1 || echo FAIL),)
SHA512SUM = sha512sum
else ifeq ($(shell shasum --version >/dev/null 2>&1 || echo FAIL),)
SHA512SUM = shasum -a 512
else ifeq ($(shell openssl version >/dev/null 2>&1 || echo FAIL),)
SHA512SUM = openssl dgst -r -sha512
else
SHA512SUM = $(error SHA-512 checksumming not found)
endif

CI_IMAGE ?= reg.vados.ru/nginx-custom-builder-ci:lts
CI_PROJECT ?= nginxci
CI_SERVICE ?= nginx-ci-runner
CI_WORKDIR ?= /work
CI_BASE_IMAGE ?= almalinux:9
CI_BUILD_ENGINE ?= buildx
CI_BUILDX_BUILDER ?= nginx-custom-builder-ci
CI_BUILDX_PLATFORMS ?= linux/amd64
CI_CHANNEL ?= mainline
CI_FORCE_BUILD ?= false
CI_WRITE_STATE ?= true
CI_RETRIES ?= 3
CI_ENABLED_MODULES ?= image-filter perl xslt error-page-inherit include-server markdown-filter acme njs
CI_AUTOCLEAN_WORKTREE ?= true
CI_COMPOSE_FILE ?= docker-compose.ci.yml
CI_UID ?= $(shell id -u)
CI_GID ?= $(shell id -g)
CI_USER ?= $(shell id -un)
CI_HOME ?= .ci-home
CI_ARTIFACTS_DIR ?= /.data/nfs/dst/nginx/RPMS
CI_RPMBUILD_DIR ?= $(CI_HOME)/rpmbuild
CI_NGINX_REPO_BASE ?= https://nginx.org/packages
CI_NGINX_REPO_OS ?=
CI_NGINX_REPO_RELEASE ?=

CI_HOME_PATH ?= $(CI_WORKDIR)/$(CI_HOME)
CI_DOCKER_COMPOSE = CI_IMAGE="$(CI_IMAGE)" docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE)


default:
	@{ \
	echo "Latest available $(FLAVOR) nginx package version: $(CURRENT_VERSION)-$(CURRENT_RELEASE)" ; \
	echo "Next $(FLAVOR) release version: $(VERSION)-$(RELEASE)" ; \
	echo "Latest available $(FLAVOR) njs package version: $(CURRENT_VERSION_NJS)-$(CURRENT_RELEASE_NJS)" ; \
	echo "Next njs version: $(VERSION_NJS)" ; \
	echo ; \
	echo "Valid targets: ci-build ci-build-compose ci-buildx-bootstrap ci-build-buildx \
	ci-push ci-push-buildx ci-deploy ci-rm ci-ps ci-init-home ci-shell ci-shell-root ci-check ci-rpm ci-rpm-channel ci-rpm-all \
	ci-check-mainline ci-check-stable ci-check-all ci-rpm-mainline ci-rpm-stable ci-artifacts ci-specs-clean ci-clean-worktree help \
	fetch version-check version-check-njs release release-njs revert commit tag cleanrelease" ; \
	}

ci-build:
	@$(MAKE) ci-build-$(CI_BUILD_ENGINE)

ci-build-compose:
	CI_BASE_IMAGE="$(CI_BASE_IMAGE)" $(CI_DOCKER_COMPOSE) build --progress=plain --no-cache

ci-buildx-bootstrap:
	@if ! docker buildx inspect $(CI_BUILDX_BUILDER) >/dev/null 2>&1; then \
		docker buildx create --name $(CI_BUILDX_BUILDER) --driver docker-container --use ; \
	else \
		docker buildx use $(CI_BUILDX_BUILDER) ; \
	fi
	docker buildx inspect --bootstrap $(CI_BUILDX_BUILDER)

ci-build-buildx: ci-buildx-bootstrap
	docker buildx build \
		--builder $(CI_BUILDX_BUILDER) \
		--progress=plain \
		--platform $(CI_BUILDX_PLATFORMS) \
		--build-arg CI_BASE_IMAGE=$(CI_BASE_IMAGE) \
		--load \
		-t $(CI_IMAGE) \
		-f Dockerfile.ci \
		.

ci-push-buildx: ci-buildx-bootstrap
	docker buildx build \
		--builder $(CI_BUILDX_BUILDER) \
		--progress=plain \
		--platform $(CI_BUILDX_PLATFORMS) \
		--build-arg CI_BASE_IMAGE=$(CI_BASE_IMAGE) \
		--push \
		-t $(CI_IMAGE) \
		-f Dockerfile.ci \
		.

ci-push:
	docker push $(CI_IMAGE)

ci-deploy:
	$(CI_DOCKER_COMPOSE) up -d

ci-rm:
	$(CI_DOCKER_COMPOSE) down

ci-ps:
	$(CI_DOCKER_COMPOSE) ps

ci-init-home:
	$(CI_DOCKER_COMPOSE) exec -T -u 0:0 $(CI_SERVICE) bash -c 'mkdir -p "$(CI_HOME_PATH)/.config" /root/.config; if [ -f "$(CI_WORKDIR)/SOURCES/mc.tar.gz" ]; then tar -xzf "$(CI_WORKDIR)/SOURCES/mc.tar.gz" -C "$(CI_HOME_PATH)/.config"; tar -xzf "$(CI_WORKDIR)/SOURCES/mc.tar.gz" -C /root/.config; fi; chown -R $(CI_UID):$(CI_GID) "$(CI_HOME_PATH)"'

ci-shell: ci-init-home
	$(CI_DOCKER_COMPOSE) exec -u $(CI_UID):$(CI_GID) -e HOME=$(CI_HOME_PATH) -e USER=$(CI_USER) -e LOGNAME=$(CI_USER) $(CI_SERVICE) bash

ci-shell-root: ci-init-home
	$(CI_DOCKER_COMPOSE) exec -u 0:0 -e HOME=/root -e USER=root -e LOGNAME=root $(CI_SERVICE) bash

ci-check:
	$(CI_DOCKER_COMPOSE) exec -T -u 0:0 $(CI_SERVICE) bash -c 'mkdir -p "$(CI_HOME_PATH)" && export HOME="$(CI_HOME_PATH)" USER=root LOGNAME=root && CHANNEL=$(CI_CHANNEL) FORCE_BUILD=$(CI_FORCE_BUILD) WRITE_STATE=$(CI_WRITE_STATE) RETRIES=$(CI_RETRIES) bash scripts/check-version-local.sh && chown -R $(CI_UID):$(CI_GID) "$(CI_HOME_PATH)" "$(CI_WORKDIR)/.github/version-state" || true'

ci-rpm: ci-rpm-channel

ci-rpm-channel:
	@$(MAKE) ci-init-home
	$(CI_DOCKER_COMPOSE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p "$(CI_HOME_PATH)" && export HOME="$(CI_HOME_PATH)" USER=$(CI_USER) LOGNAME=$(CI_USER) && base_version="$$(CHANNEL=$(CI_CHANNEL) NGINX_REPO_BASE="$(CI_NGINX_REPO_BASE)" NGINX_REPO_OS="$(CI_NGINX_REPO_OS)" NGINX_REPO_RELEASE="$(CI_NGINX_REPO_RELEASE)" bash scripts/get-nginx-srpm-version.sh)" && make -C SPECS clean tree specs base modules BASE_VERSION=$$base_version ENABLED_MODULES="$(CI_ENABLED_MODULES)"'
	@$(MAKE) ci-artifacts
	@$(MAKE) ci-specs-clean
	@if [ "$(CI_AUTOCLEAN_WORKTREE)" = "true" ]; then $(MAKE) ci-clean-worktree; fi

ci-check-mainline:
	@$(MAKE) ci-check CI_CHANNEL=mainline

ci-check-stable:
	@$(MAKE) ci-check CI_CHANNEL=stable

ci-check-all:
	@$(MAKE) ci-check-mainline
	@$(MAKE) ci-check-stable

ci-rpm-mainline:
	@$(MAKE) ci-rpm-channel CI_CHANNEL=mainline

ci-rpm-stable:
	@$(MAKE) ci-rpm-channel CI_CHANNEL=stable

ci-rpm-all:
	@$(MAKE) ci-rpm-mainline
	@$(MAKE) ci-rpm-stable

ci-artifacts:
	@mkdir -p "$(CI_ARTIFACTS_DIR)"
	@if [ -d "$(CI_RPMBUILD_DIR)/RPMS" ]; then \
		find "$(CI_RPMBUILD_DIR)/RPMS" -type f -name "*.rpm" | while read -r f; do \
			arch="$$(basename "$$(dirname "$$f")")"; \
			mkdir -p "$(CI_ARTIFACTS_DIR)/$$arch"; \
			cp -f "$$f" "$(CI_ARTIFACTS_DIR)/$$arch/"; \
		done; \
	fi
	@if [ -d "$(CI_RPMBUILD_DIR)/SRPMS" ]; then \
		mkdir -p "$(CI_ARTIFACTS_DIR)/SRPMS"; \
		find "$(CI_RPMBUILD_DIR)/SRPMS" -type f -name "*.src.rpm" -exec cp -f {} "$(CI_ARTIFACTS_DIR)/SRPMS/" \; ; \
	fi
	@echo "Artifacts copied to $(CI_ARTIFACTS_DIR)"

ci-specs-clean:
	@$(MAKE) ci-init-home
	$(CI_DOCKER_COMPOSE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p "$(CI_HOME_PATH)" && export HOME="$(CI_HOME_PATH)" USER=$(CI_USER) LOGNAME=$(CI_USER) && make -C SPECS cln && rpmdev-wipetree'

ci-clean-worktree:
	@git clean -f -- \
		SPECS/.deps-module-* \
		SPECS/module-* \
		SPECS/nginx-module-*.spec \
		SOURCES/nginx-module-*.copyright || true

help: default
	@$(MAKE) -C SPECS
#	@$(MAKE) -C contrib

fetch:
	@$(MAKE) -C contrib fetch

install:
	@$(MAKE) -C contrib install

list:
	@$(MAKE) -C contrib list


clean:
	@$(MAKE) -C SPECS cln
	@$(MAKE) -C SPECS clean
	@$(MAKE) -C contrib clean

%:
	@$(MAKE) -C SPECS $@
	@$(MAKE) -C contrib $@

version-check:
	@{ \
	if [ "$(VERSION)-$(RELEASE)" = "$(CURRENT_VERSION)-$(CURRENT_RELEASE)" ]; then \
	echo "Version $(VERSION)-$(RELEASE) is the latest one, nothing to do." >&2 ; \
	exit 1 ; \
	fi ; \
	}

version-check-njs:
	@{ \
	if [ "$(VERSION_NJS)-$(RELEASE_NJS)" = "$(CURRENT_VERSION_NJS)-$(CURRENT_RELEASE_NJS)" ]; then \
		echo "Version $(VERSION_NJS)-$(RELEASE_NJS) is the latest one, nothing to do." >&2 ; \
		exit 1 ; \
	fi ; \
	}

nginx-$(VERSION).tar.gz:
	curl -o nginx-$(VERSION).tar.gz -fL $(TARBALL)

njs-$(VERSION_NJS).tar.gz:
	curl -o njs-$(VERSION_NJS).tar.gz -fL $(TARBALL_NJS)

release: version-check nginx-$(VERSION).tar.gz
	@{ \
		set -e ; \
		echo "==> Preparing $(FLAVOR) release $(VERSION)-$(RELEASE)" ; \
		$(SHA512SUM) nginx-$(VERSION).tar.gz >>contrib/src/nginx/SHA512SUMS ; \
		sed -e "s,^NGINX_VERSION :=.*,NGINX_VERSION := $(VERSION),g" -i.bak contrib/src/nginx/version ; \
		for f in $(BASE_MAKEFILES); do \
			echo "--> $${f}" ; \
			sed -e "s,^BASE_RELEASE=.*,BASE_RELEASE=        $(RELEASE),g" \
			-i.bak $${f} ; \
		done ; \
		reldate=`date +"%Y-%m-%d"` ; \
		reltime=`date +"%H:%M:%S %z"` ; \
		packager=`echo "$(PACKAGER)" | sed -e 's,<,\\\\\\&lt\;,' -e 's,>,\\\\\\&gt\;,'` ; \
		CHANGESADD="\n\n\n<changes apply=\"nginx\" ver=\"$(VERSION)\" rev=\"$(RELEASE)\"\n         date=\"$${reldate}\" time=\"$${reltime}\"\n         packager=\"$${packager}\">\n<change>\n<para>\n$(VERSION)-$(RELEASE)\n</para>\n</change>\n\n</changes>" ; \
		sed -i.bak -e "s,title=\"nginx\">,title=\"nginx\">$${CHANGESADD}," docs/nginx.xml ; \
		for module in $(MODULES); do \
			echo "--> changelog for nginx-module-$${module}" ; \
			module_underscore=`echo $${module} | tr '-' '_'` ; \
			CHANGESADD="\n\n\n<changes apply=\"nginx-module-$${module}\" ver=\"$(VERSION)\" rev=\"$(RELEASE)\"\n         date=\"$${reldate}\" time=\"$${reltime}\"\n         packager=\"$${packager}\">\n<change>\n<para>\nbase version updated to $(VERSION)-$(RELEASE)\n</para>\n</change>\n\n</changes>" ; \
			sed -i.bak -e "s,title=\"nginx_module_$${module_underscore}\">,title=\"nginx_module_$${module_underscore}\">$${CHANGESADD}," docs/nginx-module-$${module}.xml ; \
		done ; \
		for module in $(EXTERNAL_MODULES); do \
			echo "--> changelog for nginx-module-$${module}" ; \
			module_version=`grep -F apply docs/nginx-module-$${module}.xml | head -1 | cut -d '"' -f 4` ; \
			module_underscore=`echo $${module} | tr '-' '_'` ; \
			CHANGESADD="\n\n\n<changes apply=\"nginx-module-$${module}\" ver=\"$${module_version}\" rev=\"$(RELEASE)\" basever=\"$(VERSION)\"\n         date=\"$${reldate}\" time=\"$${reltime}\"\n         packager=\"$${packager}\">\n<change>\n<para>\nbase version updated to $(VERSION)-$(RELEASE)\n</para>\n</change>\n\n</changes>" ; \
			sed -i.bak -e "s,title=\"nginx_module_$${module_underscore}\">,title=\"nginx_module_$${module_underscore}\">$${CHANGESADD}," docs/nginx-module-$${module}.xml ; \
			sed -i.bak -e "s,^MODULE_RELEASE_$${module_underscore}=.*,MODULE_RELEASE_$${module_underscore}=\t1," {alpine,debian}/Makefile.module-$${module} ; \
		done ; \
		echo ; \
		echo "Done. Please carefully check the diff. Use \"make revert\" to revert any changes." ; \
		echo ; \
	}

release-njs: version-check-njs njs-$(VERSION_NJS).tar.gz
	@{ \
		set -e ; \
		echo "==> Preparing $(FLAVOR) njs release $(VERSION_NJS)-$(RELEASE_NJS)" ; \
		$(SHA512SUM) njs-$(VERSION_NJS).tar.gz > contrib/src/njs/SHA512SUMS ; \
		sed -e "s,^NJS_VERSION :=.*,NJS_VERSION := $(VERSION_NJS),g" -i.bak contrib/src/njs/version ; \
		reldate=`date +"%Y-%m-%d"` ; \
		reltime=`date +"%H:%M:%S %z"` ; \
		packager=`echo "$(PACKAGER)" | sed -e 's,<,\\\\\\&lt\;,' -e 's,>,\\\\\\&gt\;,'` ; \
		echo "--> changelog for nginx-module-njs" ; \
		CHANGESADD="\n\n\n<changes apply=\"nginx-module-njs\" ver=\"$(VERSION_NJS)\" rev=\"$(RELEASE_NJS)\" basever=\"$(CURRENT_VERSION)\"\n         date=\"$${reldate}\" time=\"$${reltime}\"\n         packager=\"$${packager}\">\n<change>\n<para>\nnjs updated to $(VERSION_NJS)\n</para>\n</change>\n\n</changes>" ; \
		sed -i.bak -e "s,title=\"nginx_module_njs\">,title=\"nginx_module_njs\">$${CHANGESADD}," docs/nginx-module-njs.xml ; \
		echo ; \
		echo "Done. Please carefully check the diff. Use \"make revert\" to revert any changes." ; \
		echo ; \
	}

revert:
	@git checkout -- contrib/src/nginx/ docs/ $(BASE_MAKEFILES) contrib/src/njs/

commit:
	@git commit -am 'Updated nginx to $(VERSION)'

tag:
	@git tag -a $(VERSION)-$(RELEASE)

.PHONY: \
	ci-build ci-build-compose ci-buildx-bootstrap ci-build-buildx \
	ci-push ci-push-buildx ci-deploy ci-rm ci-ps ci-init-home ci-shell ci-shell-root ci-check ci-rpm ci-rpm-channel ci-rpm-all \
	ci-check-mainline ci-check-stable ci-check-all \
	ci-rpm-mainline ci-rpm-stable ci-artifacts ci-specs-clean ci-clean-worktree help \
	fetch version-check version-check-njs release release-njs revert commit tag clean
