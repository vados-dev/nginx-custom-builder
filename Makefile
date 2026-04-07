CI_IMAGE ?= reg.vados.ru/nginx-rpmbuild-ci:lts
CI_PROJECT ?= nginxci
CI_SERVICE ?= nginx-ci-runner
CI_WORKDIR ?= /work
CI_CHANNEL ?= mainline
CI_COMPOSE_FILE ?= docker-compose.ci.yml
CI_UID ?= $(shell id -u)
CI_GID ?= $(shell id -g)
CI_USER ?= $(shell id -un)

ci-build:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) build --pull

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
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && CHANNEL=$(CI_CHANNEL) WRITE_STATE=true bash scripts/check-version-local.sh'

ci-rpm:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && make -C SPECS tree specs base modules'

ci-check-mainline:
	@$(MAKE) ci-check CI_CHANNEL=mainline

ci-check-stable:
	@$(MAKE) ci-check CI_CHANNEL=stable

ci-check-all:
	@$(MAKE) ci-check-mainline
	@$(MAKE) ci-check-stable

ci-rpm-mainline:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && make -C SPECS clean tree specs base modules'

ci-rpm-stable:
	docker compose -p $(CI_PROJECT) -f $(CI_COMPOSE_FILE) exec -T -u $(CI_UID):$(CI_GID) $(CI_SERVICE) bash -c 'mkdir -p /work/.ci-home && export HOME=/work/.ci-home USER=$(CI_USER) LOGNAME=$(CI_USER) && make -C SPECS clean tree specs base modules BASE_VERSION=$$(curl -fsSL https://nginx.org/packages/centos/10/SRPMS/ | grep -oE "nginx-[0-9][0-9.]*-[^\"<>[:space:]]*\\.src\\.rpm" | sort -V | tail -n1 | sed -E "s/^nginx-([0-9][0-9.]*).*/\\1/")'

help:
	@make -C SPECS/
%:
	@make -C SPECS/ $@
