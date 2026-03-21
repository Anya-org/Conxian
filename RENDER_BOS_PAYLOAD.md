# Render Service Payload: Conxian Institutional UI

To output the visual proof of architecture for the institutional UI, the following payload structure is required for the Render-hosted services.

## Service 1: Conxian Gateway (Middleware)
- **Runtime**: Rust
- **Build Command**: `cargo build --release -p cmd-gateway`
- **Start Command**: `./target/release/gateway`
- **Env Vars**:
  - `DATABASE_URL`: Neon PostgreSQL connection string.
  - `SUPABASE_URL`: Conxian-platform Supabase URL.
  - `API_TOKEN`: Bearer token for institutional auth.
  - `NEXUS_URL`: URL for Conxian Nexus state source.

## Service 2: Institutional Dashboard (UI)
- **Runtime**: Node.js (Next.js)
- **Build Command**: `npm install && pnpm run lint && next build`
- **Start Command**: `next start`
- **Theme Alignment**:
  - Primary Background: `#0d1312`
  - Surface: `#2e403b` (Forest Green)
  - Accent: `#d4a017` (Conxian Gold)

## Visual Proof Requirements (ATS v4.0)
- **Root to Leaf Proof**: Render real-time grid orchestration state from `grid_oracle_logs`.
- **Leaf to Root Proof**: Render validated settlement receipts from Stacks block data via Nexus.
- **DeAI Proof**: Display Phala/Ritual attestation strings directly in the inference log.
- **ERP Proof**: Visualize energy saving vs compute yield deltas from `erp_sync_events`.
