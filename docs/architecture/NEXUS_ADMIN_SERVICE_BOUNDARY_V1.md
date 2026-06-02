# Nexus Admin Service Boundary v1

This document defines the expected ownership split between the BOS control plane and `conxian-nexus` for admin workflow integration.

## Control-plane responsibilities

- present workflow state
- collect operator intent
- submit typed admin requests
- display decision outcomes
- display audit records

## `conxian-nexus` responsibilities

- validate admin requests
- enforce policy and approval rules
- emit durable audit events
- coordinate downstream runtime actions
- reject invalid or unauthorized actions

## Required runtime guarantees

- request validation happens server-side
- authorization is re-checked server-side
- audit events are durable
- downstream execution is fail-closed

## Near-term integration target

The first concrete integration target is:
- release approval request
- release decision submission
- governance decision submission

## Non-goals for v1

- direct runtime promotion from the UI
- direct signing or secret handling in the control plane
- embedding banking or settlement execution in `conxian-business`
