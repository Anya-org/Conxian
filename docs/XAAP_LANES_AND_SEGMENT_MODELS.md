# Conxian XaaP: Deployment Lanes and Segment Models

This document defines the target customer segments, delivery models, and deployment lanes for the Conxian Offering (XaaP - Everything as a Protocol).

## 1. Segment Mapping & Success Criteria

| Segment | Target Audience | Primary Needs | Success Criteria |
| :--- | :--- | :--- | :--- |
| **Retail** | Individual Users, DeFi Natives | Non-custodial UX, sBTC Yield, Low Fees | Payout-ready sBTC strategies; Active CSF routing. |
| **Business** | SMEs, Digital Agencies | B2B Payments, Automated Invoicing | ERP-aligned settlement; Job-card completion verification. |
| **Enterprise** | Large Corps, FinTechs | Compliance, High-Volume Rails | MiCA/VASP compliance; Private-cloud deployment. |
| **FinTech** | Neo-banks, Payment Rails | Liquidity-as-a-Service | Deep CSF liquidity; Low-latency API response. |

## 2. Deployment Lanes (Runtime Architecture)

### Lane A: Sovereign/Self-Hosted
- **Target**: Power Users, Sovereign Entities.
- **Model**: User hosts their own Conxian Node (Sovereign Node Runtime).
- **Control**: 100% user-managed.

### Lane B: Business-Managed (SaaS-like)
- **Target**: Retail, SMEs.
- **Model**: Conxian Labs or a Business Partner hosts the infrastructure.
- **Control**: Users retain key control (non-custodial), but interface/API is managed.

### Lane C: Enterprise/Private-Cloud
- **Target**: Enterprise, FinTech.
- **Model**: Dedicated single-tenant instance on Akash, Oracle, or SAP-adjacent cloud.
- **Control**: High-security isolation; strictly compliant.

## 3. Deployment Summary

| Segment | Preferred Lane | Infrastructure Focus |
| :--- | :--- | :--- |
| Retail | Lane B | Scale, UX, Wallet Integration |
| Business | Lane B | ERP Bridge, Reconciliation |
| Enterprise | Lane C | Security, Compliance, Auditability |
| Fintech | Lane C | Liquidity, API Performance |

---
*Last Updated: April 2026*
