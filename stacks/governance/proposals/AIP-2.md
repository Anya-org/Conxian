# AIP-2: Implement Time-Weighted Voting Power

## Simple Summary
Implement time-weighted voting power to prevent flash loan attacks on governance proposals.

## Abstract
This proposal introduces a snapshot-based voting system that requires tokens to be held for a minimum period before they can be used for governance voting, preventing flash loan and borrowing attacks.

## Motivation
Current governance threshold (100k tokens) can be bypassed through flash loans or temporary token borrowing, allowing malicious actors to create proposals without proper long-term stake in the protocol.

## Specification
- Implement snapshot-based voting power calculation
- Require tokens to be held for minimum 48 hours before voting eligibility
- Add time-weighted delegation system
- Prevent same-block voting and proposal creation

## Rationale
Time-weighted voting ensures that only committed token holders can participate in governance, improving protocol security and decision quality.

## Test Cases
- Flash loan attacks fail to meet voting thresholds
- Time-weighted power calculation is accurate
- Delegation respects time requirements

## Implementation
[Link to implementation PR]

## Copyright
Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
