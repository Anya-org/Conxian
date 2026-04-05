# Tasks: CSF Autonomous Launch Execution

Note: This task list describes the intended execution plan. For code-anchored gaps that still block enforceable fee capture and founder royalty routing in the pinned Conxian contracts, see `docs/FOUNDER_RIGHTS_ROYALTIES_AND_SABDAO_ECONOMICS.md`.

## 1. Governance & Specs
- [x] 1.1 Finalize OpenSpec Change Proposal.
- [x] 1.2 Validate specifications using `openspec validate`.

## 2. Smart Contract Extension
- [x] 2.1 Implement `revenue-automation.clar` with Founder's Cut logic.
- [x] 2.2 Update lending modules for USDCx and uncapped sBTC.
- [x] 2.3 Build the "5-5-5" referral engine in Clarity.
- [x] 2.4 Create `launch-sequencer.clar` for IDO lifecycle management.
- [x] 2.5 Create `autonomous-registry.clar` for module registration.

## 3. Infrastructure Integration
- [x] 3.1 Integrate ALEX AMM SDK in Gateway (Rust client).
- [x] 3.2 Add Portal Swap SDK endpoints for native BTC routing (Rust client).
- [x] 3.3 Configure EventService for protocol broadcasting.

## 4. Launch Preparation
- [x] 4.1 Define CSF_LAUNCH_MANIFEST.md with deployment order.
- [x] 4.2 Document LBP parameters (90:10 ratio).

## 5. Security & Verification
- [x] 5.1 Perform manual pre-implementation audit.
- [x] 5.2 Add smart contract integrity tests.
- [x] 5.3 Recorded all technical learnings in system memory.
