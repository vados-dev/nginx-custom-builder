CI_REGISTRY ?= reg.vados.ru
CI_IMAGE ?= $(CI_REGISTRY)/nginx-custom-builder-ci:lts
CI_PROJECT ?= nginxci
CI_SERVICE ?= nginx-ci-runner
CI_WORKDIR ?= /work
CI_BASE_IMAGE ?= $(CI_REGISTRY)/centos:stream10
#quay.io/centos/centos:stream10
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
	echo "Valid targets: ci-build ci-build-compose ci-buildx-bootstrap ci-build-buildx \
	ci-push ci-push-buildx ci-deploy ci-rm ci-ps ci-init-home ci-shell ci-shell-root ci-check ci-rpm ci-rpm-channel ci-rpm-all \
	ci-check-mainline ci-check-stable ci-check-all ci-rpm-mainline ci-rpm-stable ci-artifacts ci-specs-clean ci-clean-worktree help clean" ; \
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

#help:
#	@$(MAKE) -C SPECS
#	@$(MAKE) -C contrib

#fetch:
#	@$(MAKE) -C contrib fetch

#install:
#	@$(MAKE) -C contrib install

#list:
#	@$(MAKE) -C contrib list

clean:
	@$(MAKE) ci-specs-clean
	@$(MAKE) ci-clean-worktree

#	@$(MAKE) -C SPECS cln
#	@$(MAKE) -C SPECS clean
#	@$(MAKE) -C contrib clean

%:
	@$(MAKE) -C SPECS $@

.PHONY: \
	ci-build ci-build-compose ci-buildx-bootstrap ci-build-buildx \
	ci-push ci-push-buildx ci-deploy ci-rm ci-ps ci-init-home ci-shell ci-shell-root ci-check ci-rpm ci-rpm-channel ci-rpm-all \
	ci-check-mainline ci-check-stable ci-check-all \
	ci-rpm-mainline ci-rpm-stable ci-artifacts ci-specs-clean ci-clean-worktree 7clean

# \
#	fetch version-check version-check-njs release release-njs revert commit tag clean
