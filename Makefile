# Conxian: Root Management & Architectural Unbundling
# Orchestrates development across isolated product suites.

.PHONY: help init unbundle build-b2b build-b2c build-infra test-all update-all

help:
	@echo "Conxian: Unified Orchestrator"
	@echo "Suite Management:"
	@echo "  make build-b2b   - Build B2B SDK (lib-conclave-sdk) and Nexus"
	@echo "  make build-b2c   - Build B2C Wallet (conxius-wallet)"
	@echo "  make build-infra - Build Gateway and Platform Infrastructure"
	@echo "Operations:"
	@echo "  make init        - Initialize and update all submodules"
	@echo "  make unbundle    - Verify architectural compartmentalization"
	@echo "  make test-all    - Run tests across all isolated suites"
	@echo "  make update-all  - Sync all modules to latest main"

init:
	@echo "Initializing unbundled submodules..."
	git submodule update --init --recursive

unbundle:
	@echo "Verifying no cross-contamination between B2B and B2C..."
	@# B2B must not depend on B2C UI components
	@if grep -r "conxius-wallet" lib-conclave-sdk conxian-nexus 2>/dev/null; then \
		echo "FAIL: B2B contamination detected"; \
		false; \
	fi
	@echo "Compartmentalization verified: OK"

build-b2b:
	@echo "Building B2B Suite (Conclave SDK & Nexus)..."
	cd lib-conclave-sdk && cargo build
	cd conxian-nexus && cargo build

build-b2c:
	@echo "Building B2C Suite (Conxius Wallet)..."
	cd conxius-wallet && npm run build

build-infra:
	@echo "Building Infrastructure Suite (Gateway & Admin)..."
	cd conxian-gateway && cargo build
	cd conxius-platform/services/admin-dashboard && npm run build

test-all:
	@echo "Executing Full System Test Suite..."
	cd conxian-gateway && cargo test
	cd conxian-nexus && cargo test
	cd conxius-wallet && npm test

update-all:
	@echo "Updating all suites to main..."
	git submodule foreach 'git fetch origin && git checkout main && git pull'

# Legacy compatibility
start:
	$(MAKE) -C conxius-platform start

stop:
	$(MAKE) -C conxius-platform stop

docs-build:
	@ls SUMMARY.md .gitbook.yaml > /dev/null
