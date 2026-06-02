# Control-Plane Action Flow Notes

This document captures the first mutating workflow shapes for the BOS control plane.

## Release governance flow

1. Operator reviews a release artifact.
2. Operator requests approval.
3. Approver or admin approves, rejects, or requests changes.
4. Runtime promotion remains outside the control plane and is triggered through trusted runtime services.
5. Each mutation emits an audit event.

## Policy approval flow

1. Operator drafts or submits a governance action.
2. Approver or admin records a decision.
3. The decision is preserved as an auditable event.
4. Follow-on execution remains outside the control-plane UI.

## Audit event expectations

Each action should produce a normalized audit event with:
- event id
- category
- actor
- summary
- timestamp
- related entity id
- action type
- outcome

## Current implementation status

The current app implementation provides:
- local action forms
- typed request/decision payloads
- synthetic audit event creation helpers
- UI feedback for accepted actions

Future work should replace synthetic behavior with trusted admin/runtime clients.
