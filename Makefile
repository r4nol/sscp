.PHONY: help build scan secrets check run clean verify

REGISTRY ?= ghcr.io
IMAGE_NAME ?= secure-supply-chain
IMAGE_TAG ?= local
FULL_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

TRIVY_SEVERITY := CRITICAL,HIGH

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "🏗️  Building $(FULL_IMAGE)..."
	docker build -t $(FULL_IMAGE) .
	@echo "✅ Build complete"

scan: build ## Scan image for vulnerabilities with Trivy
	@echo "🔍 Scanning for vulnerabilities..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v $(HOME)/.cache/trivy:/root/.cache/ \
		aquasec/trivy:latest image \
		--severity $(TRIVY_SEVERITY) \
		--ignore-unfixed \
		--exit-code 1 \
		$(FULL_IMAGE) || (echo "❌ Vulnerabilities found!" && exit 1)
	@echo "✅ No critical/high vulnerabilities found"

secrets: ## Scan for leaked secrets with Gitleaks
	@echo "🔐 Scanning for secrets..."
	@if command -v gitleaks > /dev/null; then \
		gitleaks detect --source . --verbose; \
	else \
		docker run --rm -v $(PWD):/path ghcr.io/gitleaks/gitleaks:latest detect --source /path --verbose; \
	fi
	@echo "✅ No secrets detected"

check: secrets scan ## Run all security checks
	@echo ""
	@echo "🎉 All security gates passed!"

run: build ## Build and run the container locally
	@echo "🚀 Starting container on http://localhost:8080"
	docker run --rm -p 8080:80 $(FULL_IMAGE)

clean: ## Remove built images
	@echo "🧹 Cleaning up..."
	-docker rmi $(FULL_IMAGE) 2>/dev/null || true
	-docker rmi $(IMAGE_NAME):scan-target 2>/dev/null || true
	@echo "✅ Cleanup complete"

sign: ## Sign image with Cosign (requires COSIGN_PRIVATE_KEY)
	@if [ -z "$(COSIGN_PRIVATE_KEY)" ]; then \
		echo "❌ COSIGN_PRIVATE_KEY not set. Generate keys with: cosign generate-key-pair"; \
		exit 1; \
	fi
	cosign sign --key env://COSIGN_PRIVATE_KEY $(FULL_IMAGE)

verify: ## Verify image signature with Cosign
	@if [ ! -f cosign.pub ]; then \
		echo "❌ cosign.pub not found. Place your public key in the repo root."; \
		exit 1; \
	fi
	cosign verify --key cosign.pub $(FULL_IMAGE)

keygen: ## Generate Cosign key pair
	@echo "🔑 Generating Cosign key pair..."
	@echo "⚠️  Store cosign.key securely and add to GitHub Secrets as COSIGN_PRIVATE_KEY"
	cosign generate-key-pair
