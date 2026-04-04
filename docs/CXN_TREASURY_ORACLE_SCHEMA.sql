-- CONXIAN-LABS HOLDCO: cxn-treasury-oracle SCHEMA (Supabase)
-- Single Source of Truth for Yield, Runway, and Locked Principal
-- Last Update: April 4, 2026

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Ensure gen_random_uuid() resolves whether pgcrypto is installed in public or extensions.
SET search_path = public, extensions;

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

-- 8. EXTERNAL SETTLEMENT LOGS (REFERENCE-ONLY)
-- Record off-chain / cross-network settlement references without mutating native settlement state trackers.
--
-- NOTE:
-- - `fiat_value_pegged` is informational only and MUST NOT be treated as authoritative for execution.
-- - Visual proof fields exist to preserve auditability for render + business operations reporting.
CREATE TABLE IF NOT EXISTS public.cxn_external_settlement_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    native_tx_hash TEXT NOT NULL,
    settlement_network_origin TEXT NOT NULL,
    external_tx_reference TEXT NOT NULL,
    fiat_value_pegged NUMERIC,

    visual_proof_uri TEXT,
    visual_proof_hash TEXT,
    proof_metadata JSONB,

    CONSTRAINT cxn_external_settlement_logs_native_tx_hash_not_empty CHECK (btrim(native_tx_hash) <> ''),
    CONSTRAINT cxn_external_settlement_logs_origin_not_empty CHECK (btrim(settlement_network_origin) <> ''),
    CONSTRAINT cxn_external_settlement_logs_external_ref_not_empty CHECK (btrim(external_tx_reference) <> '')
);

-- Enforce idempotent, traceable origin/reference pairing.
CREATE UNIQUE INDEX IF NOT EXISTS ux_external_settlement_logs_origin_reference
    ON public.cxn_external_settlement_logs (settlement_network_origin, external_tx_reference);

-- Query index (origin network + native hash is the primary lookup path).
CREATE INDEX IF NOT EXISTS idx_external_settlement_logs_origin_native_hash
    ON public.cxn_external_settlement_logs (settlement_network_origin, native_tx_hash);

-- If the native settlement tracker table exists, attach a best-effort foreign key for traceability.
DO $$
DECLARE
    fk_applied BOOLEAN := false;
    fk_candidate_found BOOLEAN := false;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = 'treasury_actions'
    ) THEN
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.table_constraints
            WHERE table_schema = 'public'
              AND table_name = 'cxn_external_settlement_logs'
              AND constraint_name = 'fk_external_settlement_logs_native_tx_hash'
        ) THEN
            IF EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'treasury_actions'
                  AND column_name = 'native_tx_hash'
            ) AND EXISTS (
                SELECT 1
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu
                  ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
                WHERE tc.table_schema = 'public'
                  AND tc.table_name = 'treasury_actions'
                  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
                GROUP BY tc.constraint_name
                HAVING COUNT(*) = 1
                   AND MAX(kcu.column_name) = 'native_tx_hash'
            ) THEN
                fk_candidate_found := true;
                IF EXISTS (
                    SELECT 1
                    FROM information_schema.columns l
                    JOIN information_schema.columns r
                      ON r.table_schema = 'public'
                     AND r.table_name = 'treasury_actions'
                     AND r.column_name = 'native_tx_hash'
                    WHERE l.table_schema = 'public'
                      AND l.table_name = 'cxn_external_settlement_logs'
                      AND l.column_name = 'native_tx_hash'
                      AND (
                        l.udt_name = r.udt_name
                        OR (l.udt_name IN ('text', 'varchar', 'bpchar') AND r.udt_name IN ('text', 'varchar', 'bpchar'))
                      )
                ) THEN
                    BEGIN
                        ALTER TABLE public.cxn_external_settlement_logs
                            ADD CONSTRAINT fk_external_settlement_logs_native_tx_hash
                            FOREIGN KEY (native_tx_hash)
                            REFERENCES public.treasury_actions (native_tx_hash)
                            ON DELETE RESTRICT
                            NOT VALID;
                        fk_applied := true;
                    EXCEPTION
                        WHEN duplicate_object THEN
                            fk_applied := true;
                        WHEN OTHERS THEN
                            RAISE WARNING 'cxn_external_settlement_logs: could not attach FK to public.treasury_actions(native_tx_hash): %', SQLERRM;
                    END;
                ELSE
                    RAISE NOTICE 'cxn_external_settlement_logs: type mismatch; skipping FK attachment to public.treasury_actions(native_tx_hash)';
                END IF;
            ELSIF EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'treasury_actions'
                  AND column_name = 'native_transaction_hash'
            ) AND EXISTS (
                SELECT 1
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu
                  ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
                WHERE tc.table_schema = 'public'
                  AND tc.table_name = 'treasury_actions'
                  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
                GROUP BY tc.constraint_name
                HAVING COUNT(*) = 1
                   AND MAX(kcu.column_name) = 'native_transaction_hash'
            ) THEN
                fk_candidate_found := true;
                IF EXISTS (
                    SELECT 1
                    FROM information_schema.columns l
                    JOIN information_schema.columns r
                      ON r.table_schema = 'public'
                     AND r.table_name = 'treasury_actions'
                     AND r.column_name = 'native_transaction_hash'
                    WHERE l.table_schema = 'public'
                      AND l.table_name = 'cxn_external_settlement_logs'
                      AND l.column_name = 'native_tx_hash'
                      AND (
                        l.udt_name = r.udt_name
                        OR (l.udt_name IN ('text', 'varchar', 'bpchar') AND r.udt_name IN ('text', 'varchar', 'bpchar'))
                      )
                ) THEN
                    BEGIN
                        ALTER TABLE public.cxn_external_settlement_logs
                            ADD CONSTRAINT fk_external_settlement_logs_native_tx_hash
                            FOREIGN KEY (native_tx_hash)
                            REFERENCES public.treasury_actions (native_transaction_hash)
                            ON DELETE RESTRICT
                            NOT VALID;
                        fk_applied := true;
                    EXCEPTION
                        WHEN duplicate_object THEN
                            fk_applied := true;
                        WHEN OTHERS THEN
                            RAISE WARNING 'cxn_external_settlement_logs: could not attach FK to public.treasury_actions(native_transaction_hash): %', SQLERRM;
                    END;
                ELSE
                    RAISE NOTICE 'cxn_external_settlement_logs: type mismatch; skipping FK attachment to public.treasury_actions(native_transaction_hash)';
                END IF;
            ELSIF EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'treasury_actions'
                  AND column_name = 'tx_hash'
            ) AND EXISTS (
                SELECT 1
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu
                  ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
                WHERE tc.table_schema = 'public'
                  AND tc.table_name = 'treasury_actions'
                  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
                GROUP BY tc.constraint_name
                HAVING COUNT(*) = 1
                   AND MAX(kcu.column_name) = 'tx_hash'
            ) THEN
                fk_candidate_found := true;
                IF EXISTS (
                    SELECT 1
                    FROM information_schema.columns l
                    JOIN information_schema.columns r
                      ON r.table_schema = 'public'
                     AND r.table_name = 'treasury_actions'
                     AND r.column_name = 'tx_hash'
                    WHERE l.table_schema = 'public'
                      AND l.table_name = 'cxn_external_settlement_logs'
                      AND l.column_name = 'native_tx_hash'
                      AND (
                        l.udt_name = r.udt_name
                        OR (l.udt_name IN ('text', 'varchar', 'bpchar') AND r.udt_name IN ('text', 'varchar', 'bpchar'))
                      )
                ) THEN
                    BEGIN
                        ALTER TABLE public.cxn_external_settlement_logs
                            ADD CONSTRAINT fk_external_settlement_logs_native_tx_hash
                            FOREIGN KEY (native_tx_hash)
                            REFERENCES public.treasury_actions (tx_hash)
                            ON DELETE RESTRICT
                            NOT VALID;
                        fk_applied := true;
                    EXCEPTION
                        WHEN duplicate_object THEN
                            fk_applied := true;
                        WHEN OTHERS THEN
                            RAISE WARNING 'cxn_external_settlement_logs: could not attach FK to public.treasury_actions(tx_hash): %', SQLERRM;
                    END;
                ELSE
                    RAISE NOTICE 'cxn_external_settlement_logs: type mismatch; skipping FK attachment to public.treasury_actions(tx_hash)';
                END IF;
            END IF;

            IF NOT fk_applied AND NOT fk_candidate_found THEN
                RAISE NOTICE 'cxn_external_settlement_logs: expected a single-column PK/UNIQUE native hash on public.treasury_actions but none was found; skipping FK attachment';
            END IF;
        END IF;
    END IF;
END $$;

-- RLS (ROW LEVEL SECURITY) POLICIES
-- Writes are expected via privileged service roles (TEE agents/admin) that bypass RLS.
ALTER TABLE public.cxn_locked_principal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_snackable_lockins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_yield_generation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_csf_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_timelock_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cxn_external_settlement_logs ENABLE ROW LEVEL SECURITY;

-- Default Read-Only access for authenticated clients (Conxius/Gateway)
CREATE POLICY "Read-only for authenticated clients" ON public.cxn_csf_state
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Read-only for authenticated clients" ON public.cxn_external_settlement_logs
    FOR SELECT TO authenticated USING (true);

-- cxn_external_settlement_logs is append-only by design: allow INSERT only.
CREATE POLICY "Insert for service role" ON public.cxn_external_settlement_logs
    FOR INSERT TO service_role WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.cxn_external_settlement_logs_immutable()
RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'cxn_external_settlement_logs is append-only; % is not allowed', TG_OP;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE t.tgname = 'cxn_external_settlement_logs_no_update_delete'
          AND n.nspname = 'public'
          AND c.relname = 'cxn_external_settlement_logs'
    ) THEN
        EXECUTE $sql$
            CREATE TRIGGER cxn_external_settlement_logs_no_update_delete
            BEFORE UPDATE OR DELETE ON public.cxn_external_settlement_logs
            FOR EACH ROW EXECUTE FUNCTION public.cxn_external_settlement_logs_immutable();
        $sql$;
    END IF;
END $$;

-- Indices for performance on large historical datasets
CREATE INDEX IF NOT EXISTS idx_locked_principal_timestamp ON public.cxn_locked_principal (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_yield_generation_timestamp ON public.cxn_yield_generation (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_snackable_lockins_user ON public.cxn_snackable_lockins (user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.cxn_referrals (referrer_id);
CREATE INDEX IF NOT EXISTS idx_timelock_release_block ON public.cxn_timelock_status (release_block);

RESET search_path;
