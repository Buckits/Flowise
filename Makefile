# Application configurations
UID ?= $(shell id -u 2>/dev/null || echo 1000)
GID ?= $(shell id -g 2>/dev/null || echo 1000)
USER ?= $(shell id -un 2>/dev/null || echo appuser)

# Docker image configuration
IMAGE_NAME ?= gjdeal/flowise
IMAGE_TAG ?= latest
FULL_IMAGE_NAME = $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: build
build:
	docker build \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--build-arg USER=$(USER) \
		-t $(FULL_IMAGE_NAME) \
		.

.PHONY: build-no-cache
build-no-cache:
	docker build \
		--no-cache \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--build-arg USER=$(USER) \
		-t $(FULL_IMAGE_NAME) \
		.

.PHONY: push
push: build
	docker push $(FULL_IMAGE_NAME)

.PHONY: run
run:
	docker run -it --rm \
		-p 3000:3000 \
		$(FULL_IMAGE_NAME)

.PHONY: shell
shell:
	docker run -it --rm \
		-p 3000:3000 \
		$(FULL_IMAGE_NAME) \
		/bin/sh

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build           - Build Docker image with current user UID/GID/USER"
	@echo "  build-no-cache  - Build Docker image without cache"
	@echo "  push            - Build and push image to registry"
	@echo "  run             - Run the container"
	@echo "  shell           - Run container with shell access"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  UID=$(UID)"
	@echo "  GID=$(GID)"
	@echo "  USER=$(USER)"
	@echo "  IMAGE_NAME=$(IMAGE_NAME)"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"

