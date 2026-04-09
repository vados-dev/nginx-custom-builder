CI_IMAGE ?= reg.vados.ru/nginx-rpmbuild-ci:lts
CI_PROJECT ?= nginxci
CI_SERVICE ?= nginx-ci-runner
CI_WORKDIR ?= /work
CI_CHANNEL ?= mainline
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

ci-build:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) build --progress=plain --no-cache

ci-push:
	docker push $(CI_IMAGE)

ci-deploy:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) up -d

ci-rm:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) down

ci-ps:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) ps

ci-shell:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash

ci-check:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home && CHANNEL=$(CI_CHANNEL) WRITE_STATE=true bash scripts/check-version-local.sh'

ci-rpm:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && make -C SPECS tree specs base modules'
	@$(MAKE) ci-artifacts
	@$(MAKE) ci-specs-clean

ci-check-mainline:
	@$(MAKE) ci-check CI_CHANNEL=mainline

ci-check-stable:
	@$(MAKE) ci-check CI_CHANNEL=stable

ci-check-all:
	@$(MAKE) ci-check-mainline
	@$(MAKE) ci-check-stable

ci-rpm-mainline:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && base_version="$$(CHANNEL=mainline NGINX_REPO_BASE="$(CI_NGINX_REPO_BASE)" NGINX_REPO_OS="$(CI_NGINX_REPO_OS)" NGINX_REPO_RELEASE="$(CI_NGINX_REPO_RELEASE)" bash scripts/get-nginx-srpm-version.sh)" && make -C SPECS clean tree specs base modules BASE_VERSION=$$base_version'
	@$(MAKE) ci-artifacts
	@$(MAKE) ci-specs-clean

ci-rpm-stable:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && base_version="$$(CHANNEL=stable NGINX_REPO_BASE="$(CI_NGINX_REPO_BASE)" NGINX_REPO_OS="$(CI_NGINX_REPO_OS)" NGINX_REPO_RELEASE="$(CI_NGINX_REPO_RELEASE)" bash scripts/get-nginx-srpm-version.sh)" && make -C SPECS clean tree specs base modules BASE_VERSION=$$base_version'
	@$(MAKE) ci-artifacts
	@$(MAKE) ci-specs-clean

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
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && make -C SPECS cln && rpmdev-wipetree'

help:
	@make -C SPECS/
%:
	@make -C SPECS/ $@

.PHONY: \
	ci-build ci-push ci-deploy ci-rm ci-ps ci-shell ci-check ci-rpm \
	ci-check-mainline ci-check-stable ci-check-all \
	ci-rpm-mainline ci-rpm-stable ci-artifacts ci-specs-clean help
