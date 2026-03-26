-- CONXIAN-LABS HOLDCO: cxn-treasury-oracle SCHEMA (Supabase)
-- Single Source of Truth for Yield, Runway, and Locked Principal
-- Last Update: March 25, 2026

-- 1. BASE-LAYER ASSETS (LOCKED PRINCIPAL)
-- Track base BTC locked in DLC Bonds and non-custodial multisigs.
CREATE TABLE IF NOT EXISTS public.cxn_locked_principal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT now(),
    asset_type TEXT NOT NULL DEFAULT 'BTC', -- BTC, sBTC, STX
    amount_sats BIGINT NOT NULL,            -- Amount in Satoshis/Atomic units
    vault_address TEXT NOT NULL,            -- On-chain address
    dlc_contract_id TEXT,                   -- Optional DLC bond identifier
    attestation_proof TEXT,                  -- TEE-signed attestation hash
    status TEXT DEFAULT 'LOCKED'            -- LOCKED, UNLOCKING, RELEASED
);

-- 2. SNACKABLE ADOPTION (FRACTIONAL LOCK-INS)
-- Design the UI/UX and smart contract entry points to allow users to lock a *fraction* of their dormant BTC.
CREATE TABLE IF NOT EXISTS public.cxn_snackable_lockins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now(),
    amount_sats BIGINT NOT NULL,
    target_vault TEXT NOT NULL,
    lock_duration_blocks INTEGER,
    yield_multiplier NUMERIC DEFAULT 1.0,
    status TEXT DEFAULT 'ACTIVE' -- ACTIVE, MATURED, WITHDRAWN
);

-- 3. LIQUID YIELD GENERATION & REFERRAL ATTRIBUTION
-- Track the flow of yield from base-layer to CSF protocol layers.
CREATE TABLE IF NOT EXISTS public.cxn_yield_generation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT now(),
    asset TEXT NOT NULL,                    -- sBTC, STX, USDCx
    amount_atomic BIGINT NOT NULL,          -- Amount generated
    yield_source TEXT NOT NULL,             -- Stacking, Liquidity, Lending
    target_vault TEXT NOT NULL,             -- CSF vault or rebalance target
    is_liquid BOOLEAN DEFAULT true,
    verification_hash TEXT,                 -- Link to TEE verification
    referral_id UUID,                       -- Attribution for viral growth
    referral_kickback_atomic BIGINT DEFAULT 0
);

-- 4. ON-CHAIN VIRALITY (REFERRAL SCHEMA)
-- Native, programmatic yield-sharing/referral schema.
CREATE TABLE IF NOT EXISTS public.cxn_referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL,
    referred_id UUID NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now(),
    referral_code TEXT UNIQUE NOT NULL,
    total_yield_shared_atomic BIGINT DEFAULT 0,
    status TEXT DEFAULT 'ACTIVE'
);

-- 5. CSF PROTOCOL STATE (MULTI-DIMENSIONAL)
-- High-level protocol state for rebalancing logic and institutional audits.
CREATE TABLE IF NOT EXISTS public.cxn_csf_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT now(),
    protocol_version TEXT NOT NULL,         -- e.g., Apex v1.1.0
    total_value_locked_sbtc NUMERIC,
    utilization_rate NUMERIC,               -- Percentage of liquidity utilized
    stability_fee_bps INTEGER DEFAULT 100,  -- Current protocol stability fee
    circuit_breaker_status TEXT DEFAULT 'NORMAL' -- NORMAL, WARNING, HALTED
);

-- 6. INSTITUTIONAL TIMELOCK (144-BLOCK)
-- Tracking institutional settlements exceeding R100M threshold.
CREATE TABLE IF NOT EXISTS public.cxn_timelock_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    release_block BIGINT NOT NULL,          -- Target Stacks block for release
    current_block BIGINT,                   -- Updated block height
    transaction_amount_zar NUMERIC NOT NULL,
    settlement_details JSONB,               -- ISO 20022 payload metadata
    status TEXT DEFAULT 'PENDING'           -- PENDING, READY, EXECUTED, CANCELLED
);

-- 7. RUNWAY METRICS & INSTITUTIONAL YIELD TRACKING
-- Update existing runway_metrics to include SARB limit tracking and deep analytics.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'runway_metrics' AND column_name = 'sarb_sda_utilized_zar') THEN
        ALTER TABLE public.runway_metrics ADD COLUMN sarb_sda_utilized_zar NUMERIC DEFAULT 0;
        ALTER TABLE public.runway_metrics ADD COLUMN sarb_fia_utilized_zar NUMERIC DEFAULT 0;
        ALTER TABLE public.runway_metrics ADD COLUMN sovereign_yield_index NUMERIC; -- SYI tracking
        ALTER TABLE public.runway_metrics ADD COLUMN mrr_institutional_zar NUMERIC DEFAULT 0;
        ALTER TABLE public.runway_metrics ADD COLUMN yield_velocity_score NUMERIC; -- Momentum tracking
    END IF;
END $$;

-- RLS (ROW LEVEL SECURITY) POLICIES
-- Only TEE-authenticated agents (WIF) and authorized admins can write.
ALTER TABLE public.cxn_locked_principal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_snackable_lockins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_yield_generation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_csf_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_timelock_status ENABLE ROW LEVEL SECURITY;

-- Default Read-Only access for authenticated clients (Conxius/Gateway)
CREATE POLICY "Read-only for authenticated clients" ON public.cxn_csf_state
    FOR SELECT TO authenticated USING (true);

-- Indices for performance on large historical datasets
CREATE INDEX IF NOT EXISTS idx_locked_principal_timestamp ON public.cxn_locked_principal (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_yield_generation_timestamp ON public.cxn_yield_generation (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_snackable_lockins_user ON public.cxn_snackable_lockins (user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.cxn_referrals (referrer_id);
CREATE INDEX IF NOT EXISTS idx_timelock_release_block ON public.cxn_timelock_status (release_block);
