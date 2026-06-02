# Control-Plane Authorization Model

This document defines the initial authorization model for the BOS control plane.

## Principles

- Authentication is required for all non-public routes.
- Authorization is role-based, with room for future policy-based refinement.
- High-risk actions should require stronger approval paths than read-only actions.
- Auditability is required for all mutating operations.

## Initial roles

### `viewer`
- Read-only access to dashboards, audit views, release state, and environment metadata.

### `operator`
- Can prepare actions and request approvals.
- Cannot unilaterally approve high-risk actions.

### `approver`
- Can approve or reject governance and release actions.
- Intended for dual-control workflows.

### `admin`
- Can manage control-plane configuration, access mappings, and emergency controls.
- Use sparingly.

## Initial module permissions

| Module | Viewer | Operator | Approver | Admin |
|---|---|---|---|---|
| Overview | read | read | read | read |
| Release governance | read | request approval | approve/reject | full |
| Audit | read | read | read | full |
| Policy approvals | read | submit/request changes | approve/reject | full |
| Environments | read | verify/request change | approve restricted actions | full |

## Future hardening

- SSO integration
- fine-grained policy rules
- time-bound elevated access
- break-glass flows
- dual-control enforcement for sensitive production actions
