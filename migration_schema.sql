-- New table for external settlement logs
-- Requirement: record external_tx_reference, settlement_network_origin, and fiat_value_pegged.
-- Requirement: Link each record to the corresponding native transaction hash.
-- Target Schema: cnx_bos

CREATE TABLE IF NOT EXISTS cnx_bos.cxn_external_settlement_logs (
    id SERIAL PRIMARY KEY,
    native_tx_hash TEXT NOT NULL,
    external_tx_reference TEXT NOT NULL,
    settlement_network_origin TEXT NOT NULL,
    fiat_value_pegged NUMERIC(20, 2) NOT NULL,
    currency_code CHAR(3) DEFAULT 'USD',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_ext_settlement_native_hash ON cnx_bos.cxn_external_settlement_logs(native_tx_hash);
