CI_IMAGE ?= reg.vados.ru/nginx-rpmbuild-ci:lts
CI_STACK ?= nginxci
CI_SERVICE ?= nginx-ci-runner
CI_WORKDIR ?= /work
CI_CHANNEL ?= mainline

ci-build:
	docker build -f Dockerfile.ci -t $(CI_IMAGE) .

ci-push:
	docker push $(CI_IMAGE)

ci-deploy:
	docker stack deploy -c ci-stack.yml $(CI_STACK)

ci-rm:
	docker stack rm $(CI_STACK)

ci-ps:
	docker service ls | grep $(CI_STACK) || true

ci-shell:
	@CID=$$(docker ps -q --filter "label=com.docker.swarm.service.name=$(CI_STACK)_$(CI_SERVICE)" | head -n1); \
	if [ -z "$$CID" ]; then \
		echo "No running container for service $(CI_STACK)_$(CI_SERVICE). Run: make ci-deploy"; \
		exit 1; \
	fi; \
	docker exec -it "$$CID" bash

ci-check:
	@CID=$$(docker ps -q --filter "label=com.docker.swarm.service.name=$(CI_STACK)_$(CI_SERVICE)" | head -n1); \
	if [ -z "$$CID" ]; then \
		echo "No running container for service $(CI_STACK)_$(CI_SERVICE). Run: make ci-deploy"; \
		exit 1; \
	fi; \
	docker exec -it "$$CID" bash -lc 'CHANNEL=$(CI_CHANNEL) WRITE_STATE=true scripts/check-version-local.sh'

ci-rpm:
	docker exec -it $$(docker ps -qf name=$(CI_STACK)_$(CI_SERVICE)) bash -lc 'make -C SPECS tree specs base modules'

ci-check-mainline:
	@$(MAKE) ci-check CI_CHANNEL=mainline

ci-check-stable:
	@$(MAKE) ci-check CI_CHANNEL=stable

ci-check-all:
	@$(MAKE) ci-check-mainline
	@$(MAKE) ci-check-stable

ci-rpm-mainline:
	@CID=$$(docker ps -q --filter "label=com.docker.swarm.service.name=$(CI_STACK)_$(CI_SERVICE)" | head -n1); \
	if [ -z "$$CID" ]; then \
		echo "No running container for service $(CI_STACK)_$(CI_SERVICE). Run: make ci-deploy"; \
		exit 1; \
	fi; \
	docker exec -it "$$CID" bash -lc 'make -C SPECS clean tree specs base modules'

ci-rpm-stable:
	@CID=$$(docker ps -q --filter "label=com.docker.swarm.service.name=$(CI_STACK)_$(CI_SERVICE)" | head -n1); \
	if [ -z "$$CID" ]; then \
		echo "No running container for service $(CI_STACK)_$(CI_SERVICE). Run: make ci-deploy"; \
		exit 1; \
	fi; \
	docker exec -it "$$CID" bash -lc 'make -C SPECS clean tree specs base modules BASE_VERSION=$$(curl -fsSL https://nginx.org/packages/centos/10/SRPMS/ | grep -oE "nginx-[0-9][0-9.]*-[^\"<>[:space:]]*\\.src\\.rpm" | sort -V | tail -n1 | sed -E "s/^nginx-([0-9][0-9.]*).*/\\1/")'

help:
	@make -C SPECS/
%:
	@make -C SPECS/ $@
