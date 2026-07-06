# Conxian Gateway ISO 20022 Integration Specification
> For: Conxian Gateway | Standard: ISO 20022 MX | Generated: 2026-07-06

## Overview

This document specifies the ISO 20022 message integration for the Conxian Gateway, enabling enterprise ISO 20022 payments to settle via Bitcoin L1 and Stacks smart contracts.

---

## 1. Message Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ISO 20022 → Bitcoin Settlement Flow               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐     ┌──────────────┐     ┌─────────────────────┐     │
│  │ pain.001 │────▶│   Conxian    │────▶│     pacs.008        │     │
│  │Customer  │     │   Gateway    │     │ FI Credit Transfer  │     │
│  │ Init     │     │ (Validate,   │     │                     │     │
│  └──────────┘     │  KYC, FX)    │     └──────────┬──────────┘     │
│                   └──────────────┘                │                 │
│                                                   ▼                 │
│                   ┌──────────────────────────────────────┐          │
│                   │         Settlement Adapter          │          │
│                   ├──────────────────────────────────────┤          │
│                   │  ┌─────────┐  ┌─────────┐  ┌────┐ │          │
│                   │  │  BTC     │  │Lightning│  │WBTC│ │          │
│                   │  │  Native  │  │Invoice  │  │Token│ │          │
│                   │  └────┬────┘  └────┬────┘  └──┬─┘ │          │
│                   └───────┼───────────┼───────────┼──┘          │
│                           │           │           │                │
│                           ▼           ▼           ▼                │
│                   ┌──────────────────────────────────────┐        │
│                   │          Bitcoin L1 / Lightning       │        │
│                   │              Settlement               │        │
│                   └──────────────────┬───────────────────┘        │
│                                      │                            │
│                                      ▼                            │
│                   ┌──────────────────────────────────────┐        │
│                   │          camt.054 Notification       │        │
│                   │    (Debit/Credit with TX reference)  │        │
│                   └──────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Message Mapping Specification

### 2.1 pain.001 → Internal Canonical Format

| pain.001 Field | Internal Field | Type | Description |
|----------------|----------------|------|-------------|
| MsgId | `message_id` | string(35) | Unique message identifier |
| CreDtTm | `created_at` | ISODateTime | Creation timestamp |
| Dbtr/Nm | `originator_name` | string(140) | Sender name |
| DbtrAcct/Id/Othr/Id | `originator_account` | string(34) | Sender account |
| DbtrAgt/FinInstnId/Othr/id | `originator_agent` | string(11) | Sender BIC |
| Cdtr/Nm | `beneficiary_name` | string(140) | Receiver name |
| CdtrAcct/Id/Othr/Id | `beneficiary_account` | string(34) | Receiver account |
| CdtrAgt/FinInstnId/Othr/Id | `beneficiary_agent` | string(11) | Receiver BIC |
| CdtTrfTxInf/AmdmtIndctnRsn | `payment_purpose` | string(140) | Remittance info |
| IntrBkSttlmAmt | `settlement_amount` | ActiveOrHistoricCurrencyAndAmount | Settlement amount |

### 2.2 Internal → On-Chain Commitment

| Internal Field | On-Chain Representation | Location |
|----------------|------------------------|----------|
| `message_hash` | `OP_RETURN` | Bitcoin TX |
| `settlement_amount` | `Amount` | Stacks contract |
| `originator_LEI` | `Principal` | Stacks contract |
| `beneficiary_BTC` | `PubKeyHash` | Stacks contract |

### 2.3 Field Transformation Template

```rust
// pain.001 → Canonical JSON
pub fn transform_pain001_to_canonical(msg: Pain001) -> CanonicalPayment {
    CanonicalPayment {
        message_id: msg.msg_id.clone(),
        created_at: msg.cre_dt_tm,
        originator: Party {
            name: msg.dbtr.nm.clone(),
            account: msg.dbtr_acct.id.othr.id.clone(),
            lei: msg.dbtr_agt.fin_instn_id.othr.id.clone(),
        },
        beneficiary: Party {
            name: msg.cdtr.nm.clone(),
            account: msg.cdtr_acct.id.othr.id.clone(),
            lei: msg.cdtr_agt.fin_instn_id.othr.id.clone(),
        },
        amount: msg.cdt_trf_tx_inf[0].intr_bk_sttlm_amt.amt.clone(),
        currency: msg.cdt_trf_tx_inf[0].intr_bk_sttlm_amt.ccy.clone(),
        purpose: msg.cdt_trf_tx_inf[0].rmt_inf.ustrd.clone().unwrap_or_default(),
        // Generate commitment hash for on-chain
        commitment_hash: sha256_hash(&msg),
    }
}
```

---

## 3. OP_RETURN Commitment Schema

### 3.1 Format

```
OP_RETURN <version> <hash_type> <sha256_commitment>

Where:
- version: 1 byte (0x01)
- hash_type: 1 byte (0x01 = SHA256)
- sha256_commitment: 32 bytes
```

### 3.2 Commitment Contents

```json
{
  "v": 1,
  "ht": "sha256",
  "mid": "MSG-2024-001234",
  "amt": "100000",
  "ccy": "USD",
  "ts": "2024-01-15T10:30:00Z",
  "lei_o": "5493001KJTIIGCVRYV124",
  "lei_b": "5493001KJTIIGCVRYV125",
  "ref": "TX-REF-001"
}
```

### 3.3 Rust Implementation

```rust
use sha2::{Sha256, Digest};

pub struct OpReturnCommitment {
    pub version: u8,
    pub hash_type: u8,
    pub payload: Vec<u8>,
}

impl OpReturnCommitment {
    pub fn new(message_id: &str, amount: &str, lei_o: &str, lei_b: &str) -> Self {
        let payload = serde_json::json!({
            "v": 1,
            "ht": "sha256",
            "mid": message_id,
            "amt": amount,
            "lei_o": lei_o,
            "lei_b": lei_b,
            "ts": chrono::Utc::now().to_rfc3339(),
        });
        
        let json = payload.to_string();
        let mut hasher = Sha256::new();
        hasher.update(json.as_bytes());
        let hash = hasher.finalize();
        
        let mut data = vec![0x01, 0x01]; // version + hash_type
        data.extend_from_slice(&hash);
        
        OpReturnCommitment {
            version: 0x01,
            hash_type: 0x01,
            payload: data,
        }
    }
    
    pub fn to_script(&self) -> Script {
        let mut script = Script::new();
        script.push_opcode(opcodes::OP_RETURN);
        script.push_slice(&self.payload);
        script
    }
}
```

---

## 4. Settlement Adapters

### 4.1 BTC Native Adapter

```rust
pub struct BtcNativeAdapter {
    client: BitcoinClient,
    min_confirmations: u8,
}

impl BtcNativeAdapter {
    pub async fn settle(&self, payment: &CanonicalPayment) -> Result<SettlementProof> {
        // 1. Create Bitcoin address for beneficiary
        let btc_address = self.derive_address(&payment.beneficiary)?;
        
        // 2. Create PSBT
        let mut psbt = self.create_psbt(&btc_address, &payment.amount_sats)?;
        
        // 3. Add OP_RETURN commitment
        let commitment = OpReturnCommitment::new(
            &payment.message_id,
            &payment.settlement_amount,
            &payment.originator.lei,
            &payment.beneficiary.lei,
        );
        psbt.add_op_return(&commitment.to_script());
        
        // 4. Sign and broadcast
        let signed = self.sign_psbt(&mut psbt)?;
        let txid = self.broadcast(&signed).await?;
        
        Ok(SettlementProof {
            txid,
            confirmations: 0,
            on_chain_ref: txid.to_string(),
            adapter: "btc_native".to_string(),
        })
    }
}
```

### 4.2 Lightning Adapter

```rust
pub struct LightningAdapter {
    client: LndClient,
}

impl LightningAdapter {
    pub async fn settle(&self, payment: &CanonicalPayment) -> Result<SettlementProof> {
        // 1. Create BOLT11 invoice
        let invoice = self.create_invoice(
            &payment.amount_msat,
            &payment.payment_purpose,
            3600, // 1 hour expiry
        )?;
        
        // 2. Generate preimage and hash
        let preimage = invoice.preimage();
        let hash = invoice.payment_hash();
        
        // 3. Hold hash for atomic settlement
        self.hold_hash(hash, &payment.message_id).await?;
        
        // 4. Wait for payment and settle
        let settled = self.await_payment(hash).await?;
        
        Ok(SettlementProof {
            txid: settled.txid(),
            confirmations: 0,
            on_chain_ref: hash.to_hex(),
            adapter: "lightning".to_string(),
        })
    }
}
```

### 4.3 Wrapped BTC Adapter

```rust
pub struct WrappedBtcAdapter {
    bridge: WbtcBridge,
    dti_provider: DtiProvider,
}

impl WrappedBtcAdapter {
    pub async fn settle(&self, payment: &CanonicalPayment) -> Result<SettlementProof> {
        // 1. Validate DTI (Digital Token Identifier)
        let dti = self.dti_provider.get_dti("WBTC").await?;
        
        // 2. Lock BTC and mint wrapped token
        let mint_result = self.bridge.peg_in(
            &payment.btc_address,
            &payment.amount_sats,
            &payment.commitment_hash,
        ).await?;
        
        // 3. Transfer wrapped token on Stacks
        let transfer = self.stacks_transfer(
            &payment.beneficiary.stacks_address,
            &mint_result.wrapped_amount,
            &dti,
        ).await?;
        
        Ok(SettlementProof {
            txid: transfer.txid,
            confirmations: 6, // Stacks finality
            on_chain_ref: format!("SP:{}.{}:{}", 
                payment.beneficiary.stacks_address,
                dti,
                transfer.token_id
            ),
            adapter: "wbtc".to_string(),
        })
    }
}
```

---

## 5. Compliance Integration

### 5.1 Travel Rule Fields

| ISO 20022 Field | On-Chain | Storage |
|-----------------|----------|---------|
| UltmtDbtr | `UltmtDbtr` | Off-chain (encrypted) |
| UltmtCdtr | `UltmtCdtr` | Off-chain (encrypted) |
| RgltryRptg/Ctry | Jurisdiction | Compliance DB |
| TaxClctn/CdtNote | Tax reference | Compliance DB |

### 5.2 Travel Rule Rust Implementation

```rust
pub struct TravelRuleData {
    pub originator_name: String,
    pub originator_account: String,
    pub originator_address: String,
    pub originator_lei: String,
    pub beneficiary_name: String,
    pub beneficiary_account: String,
    pub beneficiary_address: String,
    pub beneficiary_lei: String,
}

impl TravelRuleData {
    pub fn from_pain001(msg: &Pain001) -> Self {
        TravelRuleData {
            originator_name: msg.dbtr.nm.clone(),
            originator_account: msg.dbtr_acct.id.othr.id.clone(),
            originator_address: msg.dbtr.pstl_adr.clone()
                .map(|a| format!("{}, {}", a.strtNm, a.pstCd))
                .unwrap_or_default(),
            originator_lei: msg.dbtr_agt.fin_instn_id.othr.id.clone(),
            beneficiary_name: msg.cdtr.nm.clone(),
            beneficiary_account: msg.cdtr_acct.id.othr.id.clone(),
            beneficiary_address: msg.cdtr.pstl_adr.clone()
                .map(|a| format!("{}, {}", a.strtNm, a.pstCd))
                .unwrap_or_default(),
            beneficiary_lei: msg.cdtr_agt.fin_instn_id.othr.id.clone(),
        }
    }
    
    pub fn to_zkp(&self) -> TravelRuleZKProof {
        // Generate zero-knowledge proof for compliance without revealing raw data
        TravelRuleZKProof {
            originator_known: self.originator_lei.len() > 0,
            beneficiary_known: self.beneficiary_lei.len() > 0,
            amount_range: self.validate_amount_range(),
            jurisdiction: self.validate_jurisdiction(),
        }
    }
}
```

---

## 6. camt.054 Notification Generation

### 6.1 Response Mapping

```rust
pub struct Camt054Notification {
    pub msg_id: String,
    pub cre_dt_tm: DateTime<Utc>,
    pub ntry: Vec<Entry>,
}

pub struct Entry {
    pub ntry_ref: String,
    pub amt: ActiveOrHistoricCurrencyAndAmount,
    pub cdt_dbt_ind: CreditDebitCode,
    pub ntry_ref: String,
    pub refs: EntryReferences,
    pub ntry_details: EntryDetails,
}

impl Camt054Notification {
    pub fn from_settlement(payment: &CanonicalPayment, proof: &SettlementProof) -> Self {
        Camt054Notification {
            msg_id: format!("CAMT054-{}", payment.message_id),
            cre_dt_tm: Utc::now(),
            ntry: vec![Entry {
                ntry_ref: proof.txid.to_string(),
                amt: ActiveOrHistoricCurrencyAndAmount {
                    value: payment.settlement_amount.clone(),
                    ccy: payment.currency.clone(),
                },
                cdt_dbt_ind: CreditDebitCode::Credit,
                refs: EntryReferences {
                    end_to_end_id: Some(payment.message_id.clone()),
                    tx_id: Some(proof.txid.to_string()),
                },
                ntry_details: EntryDetails {
                    refs: EntryReferences2 {
                        mnt_id: Some(payment.message_id.clone()),
                    },
                    rltd_agts: None,
                    rmt_inf: Some(RemittanceInformation {
                        ustrd: Some(format!("BTC Settlement: {}", proof.on_chain_ref)),
                        strd: None,
                    }),
                },
            }],
        }
    }
}
```

---

## 7. API Specification

### 7.1 REST Endpoints

```yaml
/openapi.yaml
paths:
  /v1/payments/initiate:
    post:
      operationId: initiatePayment
      summary: Initiate ISO 20022 payment
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Pain001Request'
      responses:
        '202':
          description: Payment accepted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PaymentResponse'
        '400':
          description: Validation error
        '403':
          description: KYC/AML check failed

  /v1/payments/{id}/status:
    get:
      operationId: getPaymentStatus
      summary: Get payment status
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Payment status
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PaymentStatus'

  /v1/payments/{id}/settlement:
    get:
      operationId: getSettlementProof
      summary: Get settlement proof
      responses:
        '200':
          description: Settlement proof
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SettlementProof'
```

---

## 8. Error Handling

### 8.1 Error Codes

| Code | Message | Resolution |
|------|---------|------------|
| `ERR_PAYMENT_001` | Invalid pain.001 format | Check message structure |
| `ERR_PAYMENT_002` | KYC verification failed | Submit additional documents |
| `ERR_PAYMENT_003` | Sanctions match | Transaction blocked |
| `ERR_PAYMENT_004` | Insufficient liquidity | Fund liquidity pool |
| `ERR_PAYMENT_005` | Settlement timeout | Retry or cancel |
| `ERR_PAYMENT_006` | BTC network error | Check node connectivity |

### 8.2 Investigation Messages

For failure handling, generate pacs.028 (payment cancellation) or camt.029:

```rust
pub fn create_investigation_msg(
    payment: &CanonicalPayment,
    reason: &InvestigationReason,
) -> Camt029 {
    Camt029 {
        msg_id: format!("CAMT029-{}", uuid()),
        cre_dt_tm: Utc::now(),
        case: Case {
            id: payment.case_id.clone(),
            creator: "CONXIAN".to_string(),
            date: payment.created_at,
        },
        details: InvestigationDetails {
            status: InvestigationStatus::Assigned,
            reason: reason.clone(),
            original_payment_ref: payment.message_id,
        },
    }
}
```

---

## 9. Source Evidence

- [BIS ISO 20022 Requirements](https://bis.org/cpmi/publ/d218.pdf)
- [ISO 20022 Web APIs White Paper 2025](https://iso20022.org/sites/default/files/media/file/ISO_20022_and_Web_APIs_An_Implementation_Best_Practices_White_Paper_10June2025.pdf)
- [SWIFT CBPR+ API Guide](https://sc.com/en/uploads/sites/66/content/docs/ISO-20022-CBPR-API-Guide.pdf)
- [Chainlink ISO 20022 Integration](https://chain.link/article/iso-20022-integration)
- [Lightspark ISO 20022](https://lightspark.com/glossary/iso-20022)
- [BIP-322 Signed Messages](https://bips.dev/322)
- [ISO Digital Token Identifier](https://21x.eu/21x-implements-the-iso-digital-token-identifier-dti-standard)

---

## 10. Checklist

- [ ] pain.001 parser implementation
- [ ] pacs.008 generation
- [ ] camt.054 notification service
- [ ] OP_RETURN commitment generation
- [ ] BTC native settlement adapter
- [ ] Lightning settlement adapter
- [ ] WBTC token adapter
- [ ] Travel Rule compliance integration
- [ ] Sanctions screening hooks
- [ ] Error handling and investigation flows
- [ ] API documentation (OpenAPI)
- [ ] Integration tests with test vectors

---

*Generated per Conxian Gateway requirements*
*Aligns with BIS ISO 20022 and SWIFT CBPR+ standards*
