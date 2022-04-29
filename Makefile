# Ensure Make is run with bash shell as some syntax below is bash-specific
SHELL:=/usr/bin/env bash

# repo and version info
REPO_NAME    := redfish-esxi-os-installer
ROOT_DIR     := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
BUILD_TIME   := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
REPO_TAG     ?= v0.1.0-alpha.1
REGISTRY     ?= ghcr.io
IMAGE_TAG    ?= $(REPO_TAG)
IMAGE_NAME   ?= $(REGISTRY)/muzi502/$(REPO_NAME):$(REPO_TAG)

# iso parameters
SRC_ISO_DIR     ?= /usr/share/nginx/html/iso
HTTP_DIR        ?= /usr/share/nginx/html/iso/redfish
HTTP_URL        ?= http://172.20.29.171/iso/redfish
ESXI_ISO        ?= VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso

# ansible parameters
ENV_YML         := $(ROOT_DIR)/env.yml
CONFIG_YAML     ?= $(ROOT_DIR)/config.yaml
INVENTORY       := $(ROOT_DIR)/inventory.ini
PLAYBOOK        := $(ROOT_DIR)/playbook.yml
RUN_IN_DOCKER   ?= false
ANSIBLE_ARGS    := -i $(INVENTORY) \
		-e @$(ENV_YML) \
		-e iso_name=$(ESXI_ISO) \
		-e http_url=$(HTTP_URL)

ifeq ($(DEBUG), true)
  ANSIBLE_ARGS += -vvv
endif

ANSIBLE_STDOUT_CALLBACK ?= yaml

.PHONY: docker-build docker-push docker-run
docker-build: ## docker build redfish-esxi-os-installer container image
	docker build -t $(IMAGE_NAME) \
	--label build_time=$(BUILD_TIME) \
	--label build_commit=$(REPO_TAG) \
	-f $(ROOT_DIR)/Dockerfile $(ROOT_DIR)

docker-push: docker-build ## docker push redfish-esxi-os-installer container image
	docker push $(IMAGE_NAME)

DOCKER_ARGS := --rm -it \
		--net=host \
		--privileged \
		--name $(REPO_NAME) \
		--workdir $(ROOT_DIR) \

DOCKER_ENVS := -e HTTP_DIR=$(HTTP_DIR) \
	    -e HTTP_URL=$(HTTP_URL) \
	    -e ESXI_ISO=$(ESXI_ISO) \
	    -e INVENTORY=$(INVENTORY) \
	    -e CONFIG_YAML=$(CONFIG_YAML) \
	    -e SRC_ISO_DIR=$(SRC_ISO_DIR) \
	    -e ANSIBLE_STDOUT_CALLBACK=$(ANSIBLE_STDOUT_CALLBACK)

DOCKER_VOLUMES := -v /dev:/dev \
		-v $(ROOT_DIR):$(ROOT_DIR) \
		-v $(HTTP_DIR):$(HTTP_DIR) \
		-v $(SRC_ISO_DIR):$(SRC_ISO_DIR)

DOCKER_RUN_CMD := docker run $(DOCKER_ARGS) $(DOCKER_ENVS) $(DOCKER_VOLUMES) $(IMAGE_NAME)

docker-run: ## run all make command in docker
	$(DOCKER_RUN_CMD) bash

.PHONY: inventory build-iso
inventory: ## generate inventory.ini
	bash $(ROOT_DIR)/tools.sh inventory

build-iso:  ## rebuild ESXi ISO for every host
	DEST_ISO_DIR=$(HTTP_DIR) bash $(ROOT_DIR)/tools.sh build-iso $(SRC_ISO_DIR)/$(ESXI_ISO)

ANSIBLE_TARGETS := pre-check mount-iso reboot post-check umount-iso
.PHONY: $(ANSIBLE_TARGETS)
$(ANSIBLE_TARGETS):
	export ANSIBLE_STDOUT_CALLBACK=$(ANSIBLE_STDOUT_CALLBACK)
	$(shell which ansible-playbook) $(ANSIBLE_ARGS) --tags "$@" $(PLAYBOOK)

.PHONY: install-os
install-os: pre-check mount-iso reboot post-check ## run mount-iso, reboot, and post-check

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
