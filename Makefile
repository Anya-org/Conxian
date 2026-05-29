# Conxian: Root Management & Architectural Unbundling
# Orchestrates development across isolated product suites.
#
# ─── Dev Profiles ─────────────────────────────────────────────────────────────
# Profile 1 (Public RPC Lite - default):
#   Clone only what you need. Public RPCs require zero local blockchain nodes.
#   Examples:
#     make build-wallet      # Wallet dev (public RPCs)
#     make build-ui          # UI dev (public RPCs + nexus API)
#     make build-gateway     # Gateway Rust dev (public RPCs)
#     make build-nexus       # Nexus Rust dev (public RPCs)
#
# Profile 2 (Docker Compose Services):
#   make docker-up          # docker compose up with public RPCs
#   Uses env templates: docker-compose.env.{example,testnet,local,mainnet}
#
# Profile 3 (Local Regtest Full Stack):
#   make docker-up-local    # docker compose up with local blockchain nodes
#   make full-build         # Build ALL Rust + JS projects
#
# ─── Quick Start ──────────────────────────────────────────────────────────────
#   make init               # Initialize submodules
#   make rpc-env            # Show available RPC profiles
#   cp docker-compose.env.example .env && docker compose up

.PHONY: help init dev-profiles rpc-env \
	build-gateway build-nexus build-enclave build-core build-wallet build-ui build-platform build-all \
	test-gateway test-nexus test-core test-all \
	docker-up docker-up-local docker-up-testnet docker-up-mainnet \
	update-all unbundle clean

help:
	@echo "Conxian: Unified Orchestrator"
	@echo ""
	@echo "── Dev Profiles ──"
	@echo "  make dev-profiles          - List all dev setup profiles"
	@echo "  make rpc-env               - Show RPC configuration guide"
	@echo ""
	@echo "── Per-Component Builds (Profile 1: Public RPC Lite) ──"
	@echo "  make build-core            - Build lib-conxian-core (Rust)"
	@echo "  make build-nexus           - Build conxian-nexus indexer (Rust)"
	@echo "  make build-gateway         - Build conxian-gateway (Rust)"
	@echo "  make build-enclave         - Build conxius-enclave-sdk (Rust)"
	@echo "  make build-wallet          - Build conxius-wallet (React/Capacitor)"
	@echo "  make build-ui              - Build conxian-ui dashboard (Next.js)"
	@echo "  make build-orbit           - Build conxius-orbit CLI"
	@echo "  make build-platform        - Build conxius-platform services"
	@echo ""
	@echo "── Docker Compose (Profile 2 & 3) ──"
	@echo "  make docker-up             - docker compose up (public RPCs)"
	@echo "  make docker-up-testnet     - docker compose up (testnet RPCs)"
	@echo "  make docker-up-local       - docker compose up (local mock nodes)"
	@echo "  make docker-up-mainnet     - docker compose up (mainnet RPCs)"
	@echo ""
	@echo "── Testing ──"
	@echo "  make test-core             - Test lib-conxian-core"
	@echo "  make test-nexus            - Test conxian-nexus"
	@echo "  make test-gateway          - Test conxian-gateway"
	@echo "  make test-all              - Run all Rust tests"
	@echo ""
	@echo "── Operations ──"
	@echo "  make init                  - Initialize and update all submodules"
	@echo "  make unbundle              - Verify architectural isolation"
	@echo "  make update-all            - Sync all modules to pinned SHAs"
	@echo "  make clean                 - Clean all build artifacts"

dev-profiles:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "  Conxian Dev Profiles"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Profile 1: Public RPC Lite (~1-2 GB, fastest to start)"
	@echo "  Build only the component(s) you need."
	@echo "  Uses public Hiro + publicnode.com RPCs — no local nodes."
	@echo "  Run: make build-{component}"
	@echo "  Good for: wallet dev, UI dev, API dev, contract dev"
	@echo ""
	@echo "Profile 2: Docker Compose Services (~3-5 GB)"
	@echo "  Full docker-compose stack with public RPCs."
	@echo "  Run: cp docker-compose.env.example .env && make docker-up"
	@echo "  Good for: integration testing, full-stack development"
	@echo ""
	@echo "Profile 3: Local Regtest Full Stack (~8-12 GB)"
	@echo "  Everything local — bitcoin regtest + stacks mocknet."
	@echo "  Run: make docker-up-local"
	@echo "  Good for: offline dev, deep protocol work, CI hardening"
	@echo "═══════════════════════════════════════════════════════════════"

rpc-env:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "  RPC Configuration Guide"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Set via env vars: STACKS_NODE_RPC_URL, BITCOIN_RPC_URL, STACKS_RPC_URL"
	@echo ""
	@echo "Stacks Mainnet: https://api.mainnet.hiro.so"
	@echo "Stacks Testnet: https://api.testnet.hiro.so"
	@echo "Bitcoin Mainnet: https://bitcoin-rpc.publicnode.com"
	@echo "Bitcoin Testnet: https://bitcoin-testnet-rpc.publicnode.com"
	@echo ""
	@echo "Local Stacks:   http://localhost:20443"
	@echo "Local Bitcoin:  http://localhost:8332"
	@echo "Local Regtest:  http://localhost:18443"
	@echo ""
	@echo "Docker sibling: http://stacks-node:20443"
	@echo "Kubernetes:     http://svc.ns.svc.cluster.local:20443"
	@echo "Cloud:          https://your-node.cloud.com:8332"
	@echo ""
	@echo "See docker-compose.env.example for full details."
	@echo "═══════════════════════════════════════════════════════════════"

init:
	@echo "Initializing unbundled submodules..."
	git submodule update --init --recursive

# ─── Rust Builds ──────────────────────────────────────────────────────────────

build-core:
	@echo "Building lib-conxian-core..."
	cd lib-conxian-core && cargo build $(CARGO_FLAGS)

build-nexus:
	@echo "Building conxian-nexus..."
	cd conxian-nexus && cargo build $(CARGO_FLAGS)

build-gateway:
	@echo "Building conxian-gateway..."
	cd conxian-gateway && cargo build $(CARGO_FLAGS)

build-enclave:
	@echo "Building conxius-enclave-sdk..."
	cd conxius-enclave-sdk && cargo build $(CARGO_FLAGS)

# ─── JS/TS Builds ─────────────────────────────────────────────────────────────

build-wallet:
	@echo "Building conxius-wallet..."
	cd conxius-wallet && npm install && npm run build

build-ui:
	@echo "Building conxian-ui..."
	cd conxian-ui && npm install && npm run build

build-orbit:
	@echo "Building conxius-orbit..."
	cd conxius-orbit && npm install && npm run build

build-platform:
	@echo "Building conxius-platform services..."
	cd conxius-platform && pnpm install && pnpm build

build-all: build-core build-nexus build-gateway build-enclave

# ─── Docker Compose ───────────────────────────────────────────────────────────

docker-up:
	@echo "Starting with public RPCs (use .env from docker-compose.env.example)..."
	docker compose up -d

docker-up-testnet:
	@echo "Starting with testnet RPCs..."
	cp docker-compose.env.testnet.example .env && docker compose up -d

docker-up-local:
	@echo "Starting with local regtest/mock nodes..."
	cp docker-compose.env.local.example .env && docker compose up -d

docker-up-mainnet:
	@echo "Starting with mainnet public RPCs..."
	cp docker-compose.env.mainnet.example .env && docker compose up -d

# ─── Testing ──────────────────────────────────────────────────────────────────

test-core:
	@echo "Testing lib-conxian-core..."
	cd lib-conxian-core && cargo test

test-nexus:
	@echo "Testing conxian-nexus..."
	cd conxian-nexus && cargo test

test-gateway:
	@echo "Testing conxian-gateway..."
	cd conxian-gateway && cargo test

test-all: test-core test-nexus test-gateway
	@echo "All Rust tests passed."

# ─── Operations ───────────────────────────────────────────────────────────────

unbundle:
	@echo "Verifying no cross-contamination between B2B and B2C..."
	@# B2B must not depend on B2C UI components
	@if grep -r "conxius-wallet" lib-conxian-core conxian-nexus 2>/dev/null; then \
		echo "FAIL: B2B contamination detected"; \
		false; \
	fi
	@echo "Compartmentalization verified: OK"

update-all:
	@echo "Syncing all suites to committed pinned submodule SHAs..."
	git submodule sync --recursive
	git submodule update --init --recursive
	@echo "Pinned submodule sync complete."

clean:
	@echo "Cleaning Rust build artifacts..."
	cd lib-conxian-core && cargo clean 2>/dev/null || true
	cd conxian-nexus && cargo clean 2>/dev/null || true
	cd conxian-gateway && cargo clean 2>/dev/null || true
	cd conxius-enclave-sdk && cargo clean 2>/dev/null || true
	@echo "Cleaning JS build artifacts..."
	rm -rf conxius-wallet/node_modules 2>/dev/null || true
	rm -rf conxian-ui/node_modules 2>/dev/null || true
	rm -rf conxius-orbit/node_modules 2>/dev/null || true
	rm -rf conxius-platform/node_modules 2>/dev/null || true
	@echo "Done."

# Legacy compatibility
start:
	$(MAKE) -C conxius-platform start

stop:
	$(MAKE) -C conxius-platform stop
