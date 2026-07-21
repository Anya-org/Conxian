import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { ec as EC } from 'elliptic';
import crypto from 'node:crypto';
import { simnet } from '../setup-test-env';

const TOKEN_ROUTE = 'cxvg-token';
const COMPLIANCE_ROUTE = 'regulatory-adapter';
const TOKEN_NAME = 'cxvg-token';
const COMPLIANCE_NAME = 'regulatory-adapter';
const MOCK_TOKEN_NAME = 'mock-token';
const WRONG_TOKEN_NAME = 'community-governance-token';
const MOCK_COMPLIANCE_NAME = 'mock-regulatory-adapter';

const ERR_ROUTE_MISMATCH = 2101;
const ERR_TOKEN_CALL_FAILED = 2102;
const ERR_COMPLIANCE_CALL_FAILED = 2103;
const ERR_NON_COMPLIANT = 2104;
const ERR_START_NOT_FUTURE = 2105;
const ERR_INVALID_DURATION = 2106;
const ERR_INVALID_THRESHOLD = 2107;
const ERR_ZERO_SUPPLY = 2108;
const ERR_UNKNOWN_PROPOSAL = 2109;
const ERR_NOT_STARTED = 2110;
const ERR_VOTING_ENDED = 2111;
const ERR_INVALID_AMOUNT = 2112;
const ERR_ALREADY_VOTED = 2113;
const ERR_ALREADY_FINALIZED = 2114;
const ERR_VOTING_ACTIVE = 2115;
const ERR_NOT_FINALIZED = 2116;
const ERR_NOT_VOTED = 2117;
const ERR_ALREADY_CLAIMED = 2118;
const ERR_TOKEN_MISMATCH = 2119;
const ERR_COMPLIANCE_MISMATCH = 2120;
const ERR_SUPPLY_TOO_LARGE = 2121;
const ERR_SNAPSHOT_CAP = 2122;

const error = (code: number) => Cl.error(Cl.uint(code));

describe('Community voting engine', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  const authorityKey = new EC('secp256k1').genKeyPair();

  const token = (name = TOKEN_NAME) => Cl.contractPrincipal(deployer, name);
  const compliance = (name = COMPLIANCE_NAME) => Cl.contractPrincipal(deployer, name);

  function uintValue(result: any): bigint {
    return BigInt(result.value);
  }

  function responseUintValue(result: any): bigint {
    return BigInt(result.value.value);
  }

  function currentHeight(): bigint {
    return BigInt(simnet.stacksBlockHeight);
  }

  function setRoute(key: string, address: string) {
    const result = simnet.callPublicFn(
      'operational-treasury',
      'set-protocol-principal',
      [Cl.stringAscii(key), Cl.principal(address)],
      deployer,
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function configureRoutes() {
    setRoute(TOKEN_ROUTE, `${deployer}.${TOKEN_NAME}`);
    setRoute(COMPLIANCE_ROUTE, `${deployer}.${COMPLIANCE_NAME}`);
  }

  function markCompliant(user: string) {
    const userHash = crypto.createHash('sha256').update(user).digest();
    const registerResult = simnet.callPublicFn(
      'regulatory-adapter',
      'register-user-hash',
      [Cl.principal(user), Cl.buffer(userHash)],
      deployer,
    );
    expect(registerResult.result).toEqual(Cl.ok(Cl.bool(true)));

    const hashResult = simnet.callReadOnlyFn(
      'regulatory-adapter',
      'get-sip018-hash',
      [Cl.principal(user), Cl.stringAscii('USA'), Cl.uint(1)],
      deployer,
    );
    const hashHex = (hashResult.result as any).value.value as string;
    const hashBytes = Buffer.from(hashHex.startsWith('0x') ? hashHex.slice(2) : hashHex, 'hex');
    const signature = authorityKey.sign(hashBytes, { canonical: true });
    const signatureBuffer = Buffer.concat([
      Buffer.from(signature.r.toArray('be', 32)),
      Buffer.from(signature.s.toArray('be', 32)),
      Buffer.from([signature.recoveryParam]),
    ]);

    const verifyResult = simnet.callPublicFn(
      'regulatory-adapter',
      'verify-and-update-compliance',
      [
        Cl.principal(user),
        Cl.stringAscii('USA'),
        Cl.uint(1),
        Cl.buffer(signatureBuffer),
      ],
      deployer,
    );
    expect(verifyResult.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function mintToken(contractName: string, recipient: string, amount: bigint) {
    const result = simnet.callPublicFn(
      contractName,
      'mint',
      [Cl.uint(amount), Cl.principal(recipient)],
      deployer,
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function mintCxvg(recipient: string, amount: bigint) {
    mintToken(TOKEN_NAME, recipient, amount);
  }

  function tokenBalance(contractName: string, user: string): bigint {
    const result = simnet.callReadOnlyFn(
      contractName,
      'get-balance',
      [Cl.principal(user)],
      user,
    );
    return BigInt((result.result as any).value.value);
  }

  function tokenSupply(contractName: string): bigint {
    const result = simnet.callReadOnlyFn(contractName, 'get-total-supply', [], deployer);
    return BigInt((result.result as any).value.value);
  }

  function setMockComplianceMode(mode: bigint) {
    const result = simnet.callPublicFn(
      MOCK_COMPLIANCE_NAME,
      'set-mode',
      [Cl.uint(mode)],
      deployer,
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function createProposal(
    sender = deployer,
    startOffset = 5n,
    duration = 5n,
    quorumBps = 1000n,
    approvalBps = 6000n,
  ) {
    return createProposalWith(
      sender,
      startOffset,
      duration,
      quorumBps,
      approvalBps,
      TOKEN_NAME,
      COMPLIANCE_NAME,
    );
  }

  function createProposalWith(
    sender: string,
    startOffset: bigint,
    duration: bigint,
    quorumBps: bigint,
    approvalBps: bigint,
    tokenName: string,
    complianceName: string,
  ) {
    const start = currentHeight() + startOffset;
    const end = start + duration;
    const result = simnet.callPublicFn(
      'community-voting-engine',
      'create-proposal',
      [
        Cl.uint(start),
        Cl.uint(end),
        Cl.uint(quorumBps),
        Cl.uint(approvalBps),
        token(tokenName),
        compliance(complianceName),
      ],
      sender,
    );
    return result;
  }

  function vote(proposalId: bigint, voter: string, support: boolean, amount: bigint) {
    return voteWith(
      proposalId,
      voter,
      support,
      amount,
      TOKEN_NAME,
      COMPLIANCE_NAME,
    );
  }

  function voteWith(
    proposalId: bigint,
    voter: string,
    support: boolean,
    amount: bigint,
    tokenName: string,
    complianceName: string,
  ) {
    return simnet.callPublicFn(
      'community-voting-engine',
      'vote',
      [
        Cl.uint(proposalId),
        Cl.bool(support),
        Cl.uint(amount),
        token(tokenName),
        compliance(complianceName),
      ],
      voter,
    );
  }

  function claimStake(proposalId: bigint, voter: string, tokenName = TOKEN_NAME) {
    return simnet.callPublicFn(
      'community-voting-engine',
      'claim-stake',
      [Cl.uint(proposalId), token(tokenName)],
      voter,
    );
  }

  function finalize(proposalId: bigint) {
    return simnet.callPublicFn(
      'community-voting-engine',
      'finalize-proposal',
      [Cl.uint(proposalId)],
      wallet3,
    );
  }

  function proposalIdFrom(result: any): bigint {
    return responseUintValue(result.result);
  }

  function proposalWindow(proposalId: bigint): { start: bigint; end: bigint } {
    const result = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(proposalId)],
      deployer,
    );
    const proposal = (result.result as any).value.value;
    return {
      start: BigInt(proposal['start-block'].value),
      end: BigInt(proposal['end-block'].value),
    };
  }

  function mineUntil(target: bigint) {
    const remaining = target - currentHeight();
    if (remaining > 0n) simnet.mineEmptyStacksBlocks(Number(remaining));
  }

  function mineToVotingStart(proposalId: bigint) {
    mineUntil(proposalWindow(proposalId).start);
  }

  function mineToVotingEnd(proposalId: bigint) {
    mineUntil(proposalWindow(proposalId).end);
  }

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;

    const authorityPubkey = Buffer.from(authorityKey.getPublic(true, 'hex'), 'hex');
    const authorityResult = simnet.callPublicFn(
      'regulatory-adapter',
      'update-authority',
      [Cl.principal(deployer), Cl.buffer(authorityPubkey)],
      deployer,
    );
    expect(authorityResult.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('contains no stub success, panic, static external route, or production principal', () => {
    const source = simnet.getContractSource('community-voting-engine')!;
    expect(source).not.toContain('stub-func');
    expect(source).not.toContain('unwrap-panic');
    expect(source).not.toContain('(ok u1)');
    expect(source).not.toContain('contract-call? .cxvg-token');
    expect(source).not.toContain('contract-call? .regulatory-adapter');
    expect(source).toContain('stacks-block-height');
    expect(source).toContain('MAX_SAFE_SUPPLY');
    expect(source).toContain('ERR_SNAPSHOT_CAP');
    expect(source).not.toMatch(/\bS[TP][0-9A-Z]{38}\b/);

    const maxSafeSupply = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-max-safe-supply',
      [],
      deployer,
    );
    expect(uintValue(maxSafeSupply.result)).toBe(34_028_236_692_093_846_346_337_460_743_176_821n);
  });

  it('loads canonical token and compliance routes in a fresh simnet deployment', () => {
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-route',
        [Cl.stringAscii(TOKEN_ROUTE)],
        deployer,
      ).result,
    ).toEqual(Cl.some(token()));
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-route',
        [Cl.stringAscii(COMPLIANCE_ROUTE)],
        deployer,
      ).result,
    ).toEqual(Cl.some(compliance()));
  });

  it('fails closed on route mismatches', () => {
    configureRoutes();
    markCompliant(deployer);

    setRoute(TOKEN_ROUTE, deployer);
    expect(createProposal().result).toEqual(error(ERR_ROUTE_MISMATCH));

    setRoute(TOKEN_ROUTE, `${deployer}.${TOKEN_NAME}`);
    setRoute(COMPLIANCE_ROUTE, deployer);
    expect(createProposal().result).toEqual(error(ERR_ROUTE_MISMATCH));

    configureRoutes();
  });

  it('rejects invalid bounds, thresholds, and zero-supply proposals', () => {
    markCompliant(deployer);
    expect(createProposal(wallet3).result).toEqual(error(ERR_NON_COMPLIANT));

    const now = currentHeight();
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'create-proposal',
        [Cl.uint(now), Cl.uint(now + 2n), Cl.uint(1000), Cl.uint(6000), token(), compliance()],
        deployer,
      ).result,
    ).toEqual(error(ERR_START_NOT_FUTURE));

    const sameStart = currentHeight() + 5n;
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'create-proposal',
        [Cl.uint(sameStart), Cl.uint(sameStart), Cl.uint(1000), Cl.uint(6000), token(), compliance()],
        deployer,
      ).result,
    ).toEqual(error(ERR_INVALID_DURATION));

    const longStart = currentHeight() + 5n;
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'create-proposal',
        [Cl.uint(longStart), Cl.uint(longStart + 100001n), Cl.uint(1000), Cl.uint(6000), token(), compliance()],
        deployer,
      ).result,
    ).toEqual(error(ERR_INVALID_DURATION));

    const zeroQuorumStart = currentHeight() + 5n;
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'create-proposal',
        [Cl.uint(zeroQuorumStart), Cl.uint(zeroQuorumStart + 5n), Cl.uint(0), Cl.uint(6000), token(), compliance()],
        deployer,
      ).result,
    ).toEqual(error(ERR_INVALID_THRESHOLD));

    const invalidApprovalStart = currentHeight() + 5n;
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'create-proposal',
        [Cl.uint(invalidApprovalStart), Cl.uint(invalidApprovalStart + 5n), Cl.uint(1000), Cl.uint(10001), token(), compliance()],
        deployer,
      ).result,
    ).toEqual(error(ERR_INVALID_THRESHOLD));

    expect(createProposal().result).toEqual(error(ERR_ZERO_SUPPLY));
  });

  it('allocates monotonic IDs and stores the supply snapshot and thresholds', () => {
    mintCxvg(wallet1, 1_000_000n);
    mintCxvg(wallet2, 1_000_000n);
    markCompliant(wallet1);
    markCompliant(wallet2);

    const result = createProposal();
    expect(result.result.type).toBe('ok');
    const proposalId = proposalIdFrom(result);
    expect(proposalId).toBeGreaterThan(0n);

    const nextId = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-next-proposal-id',
      [],
      deployer,
    );
    expect(uintValue(nextId.result)).toBe(proposalId + 1n);

    const stored = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(proposalId)],
      deployer,
    );
    expect(stored.result.type).toBe('some');
    const proposal = (stored.result as any).value.value;
    expect(proposal['proposer'].value).toBe(deployer);
    expect(BigInt(proposal['total-supply-snapshot'].value)).toBe(2_000_000n);
    expect(BigInt(proposal['quorum-bps'].value)).toBe(1000n);
    expect(BigInt(proposal['approval-bps'].value)).toBe(6000n);
    expect(BigInt(proposal['yes-deposited'].value)).toBe(0n);
    expect(BigInt(proposal['no-deposited'].value)).toBe(0n);
    expect(proposal['finalized']).toEqual(Cl.bool(false));
    expect(proposal['passed']).toEqual(Cl.bool(false));
  });

  it('enforces voting windows, compliance, nonzero escrow, and immutable duplicate votes', () => {
    const result = createProposal(deployer, 8n, 5n);
    const proposalId = proposalIdFrom(result);

    expect(vote(proposalId, wallet1, true, 0n).result).toEqual(error(ERR_NOT_STARTED));
    expect(vote(proposalId, wallet3, true, 100n).result).toEqual(error(ERR_NOT_STARTED));

    mineToVotingStart(proposalId);
    expect(vote(proposalId, wallet3, true, 100n).result).toEqual(error(ERR_NON_COMPLIANT));
    expect(vote(proposalId, wallet1, true, 0n).result).toEqual(error(ERR_INVALID_AMOUNT));

    const beforeVoter = simnet.callReadOnlyFn('cxvg-token', 'get-balance', [Cl.principal(wallet1)], wallet1);
    const beforeEngine = simnet.callReadOnlyFn(
      'cxvg-token',
      'get-balance',
      [Cl.contractPrincipal(deployer, 'community-voting-engine')],
      wallet1,
    );
    expect(vote(proposalId, wallet1, true, 100n).result).toEqual(Cl.ok(Cl.bool(true)));
    const afterVoter = simnet.callReadOnlyFn('cxvg-token', 'get-balance', [Cl.principal(wallet1)], wallet1);
    const afterEngine = simnet.callReadOnlyFn(
      'cxvg-token',
      'get-balance',
      [Cl.contractPrincipal(deployer, 'community-voting-engine')],
      wallet1,
    );
    expect(beforeVoter.result).toEqual(Cl.ok(Cl.uint(1_000_000)));
    expect(afterVoter.result).toEqual(Cl.ok(Cl.uint(999_900)));
    expect(beforeEngine.result).toEqual(Cl.ok(Cl.uint(0)));
    expect(afterEngine.result).toEqual(Cl.ok(Cl.uint(100)));

    expect(vote(proposalId, wallet1, false, 100n).result).toEqual(error(ERR_ALREADY_VOTED));
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'claim-stake',
        [Cl.uint(proposalId), token()],
        wallet1,
      ).result,
    ).toEqual(error(ERR_NOT_FINALIZED));

    const storedVote = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-vote',
      [Cl.uint(proposalId), Cl.principal(wallet1)],
      wallet1,
    );
    expect(storedVote.result.type).toBe('some');
    const voteData = (storedVote.result as any).value.value;
    expect(BigInt(voteData.amount.value)).toBe(100n);
    expect(voteData.support).toEqual(Cl.bool(true));
    expect(voteData.claimed).toEqual(Cl.bool(false));

    mineToVotingEnd(proposalId);
    expect(vote(proposalId, wallet2, true, 100n).result).toEqual(error(ERR_VOTING_ENDED));
  });

  it('rejects wrong token/compliance traits and preserves state on failed transfers', () => {
    const traitResult = createProposal(deployer, 2n, 5n, 1n, 6000n);
    const traitProposalId = proposalIdFrom(traitResult);
    mineToVotingStart(traitProposalId);

    const beforeTraitProposal = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(traitProposalId)],
      deployer,
    ).result;
    expect(
      voteWith(
        traitProposalId,
        wallet1,
        true,
        100n,
        WRONG_TOKEN_NAME,
        COMPLIANCE_NAME,
      ).result,
    ).toEqual(error(ERR_TOKEN_MISMATCH));
    expect(
      voteWith(
        traitProposalId,
        wallet1,
        true,
        100n,
        TOKEN_NAME,
        MOCK_COMPLIANCE_NAME,
      ).result,
    ).toEqual(error(ERR_COMPLIANCE_MISMATCH));
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-proposal',
        [Cl.uint(traitProposalId)],
        deployer,
      ).result,
    ).toEqual(beforeTraitProposal);
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-vote',
        [Cl.uint(traitProposalId), Cl.principal(wallet1)],
        wallet1,
      ).result,
    ).toEqual(Cl.none());

    markCompliant(wallet3);
    const transferResult = createProposal(deployer, 2n, 5n, 1n, 6000n);
    const transferProposalId = proposalIdFrom(transferResult);
    mineToVotingStart(transferProposalId);
    const beforeTransferProposal = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(transferProposalId)],
      deployer,
    ).result;
    const beforeWallet3 = tokenBalance(TOKEN_NAME, wallet3);
    expect(vote(transferProposalId, wallet3, true, 1n).result).toEqual(error(ERR_TOKEN_CALL_FAILED));
    expect(tokenBalance(TOKEN_NAME, wallet3)).toBe(beforeWallet3);
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-proposal',
        [Cl.uint(transferProposalId)],
        deployer,
      ).result,
    ).toEqual(beforeTransferProposal);
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-vote',
        [Cl.uint(transferProposalId), Cl.principal(wallet3)],
        wallet3,
      ).result,
    ).toEqual(Cl.none());
  });

  it('distinguishes a compliance adapter error from negative compliance', () => {
    setRoute(COMPLIANCE_ROUTE, `${deployer}.${MOCK_COMPLIANCE_NAME}`);
    setMockComplianceMode(0n);
    const result = createProposalWith(
      deployer,
      2n,
      5n,
      1n,
      6000n,
      TOKEN_NAME,
      MOCK_COMPLIANCE_NAME,
    );
    const proposalId = proposalIdFrom(result);
    mineToVotingStart(proposalId);

    const beforeProposal = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(proposalId)],
      deployer,
    ).result;
    setMockComplianceMode(1n);
    expect(
      voteWith(proposalId, wallet1, true, 100n, TOKEN_NAME, MOCK_COMPLIANCE_NAME).result,
    ).toEqual(error(ERR_COMPLIANCE_CALL_FAILED));
    setMockComplianceMode(2n);
    expect(
      voteWith(proposalId, wallet2, true, 100n, TOKEN_NAME, MOCK_COMPLIANCE_NAME).result,
    ).toEqual(error(ERR_NON_COMPLIANT));
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-proposal',
        [Cl.uint(proposalId)],
        deployer,
      ).result,
    ).toEqual(beforeProposal);
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-vote',
        [Cl.uint(proposalId), Cl.principal(wallet1)],
        wallet1,
      ).result,
    ).toEqual(Cl.none());
    expect(
      simnet.callReadOnlyFn(
        'community-voting-engine',
        'get-vote',
        [Cl.uint(proposalId), Cl.principal(wallet2)],
        wallet2,
      ).result,
    ).toEqual(Cl.none());

    setMockComplianceMode(0n);
    configureRoutes();
  });

  it('returns false for quorum failure and permits permissionless one-time finalization', () => {
    const result = createProposal(deployer, 2n, 2n, 9000n, 5000n);
    const proposalId = proposalIdFrom(result);
    mineToVotingEnd(proposalId);

    expect(finalize(proposalId).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(finalize(proposalId).result).toEqual(error(ERR_ALREADY_FINALIZED));

    const stored = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(proposalId)],
      wallet3,
    );
    const proposal = (stored.result as any).value.value;
    expect(proposal['finalized']).toEqual(Cl.bool(true));
    expect(proposal['passed']).toEqual(Cl.bool(false));
  });

  it('fails ties and approval thresholds even when quorum is met', () => {
    const tieResult = createProposal(deployer, 2n, 3n, 1n, 5000n);
    const tieId = proposalIdFrom(tieResult);
    mineToVotingStart(tieId);
    expect(vote(tieId, wallet1, true, 100n).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(vote(tieId, wallet2, false, 100n).result).toEqual(Cl.ok(Cl.bool(true)));
    mineToVotingEnd(tieId);
    expect(finalize(tieId).result).toEqual(Cl.ok(Cl.bool(false)));

    const approvalResult = createProposal(deployer, 2n, 3n, 1n, 7500n);
    const approvalId = proposalIdFrom(approvalResult);
    mineToVotingStart(approvalId);
    expect(vote(approvalId, wallet1, true, 100n).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(vote(approvalId, wallet2, false, 300n).result).toEqual(Cl.ok(Cl.bool(true)));
    mineToVotingEnd(approvalId);
    expect(finalize(approvalId).result).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('passes at exact quorum equality and exact approval equality', () => {
    const quorumResult = createProposal(deployer, 2n, 3n, 1000n, 6000n);
    const quorumId = proposalIdFrom(quorumResult);
    mineToVotingStart(quorumId);
    expect(vote(quorumId, wallet1, true, 200_000n).result).toEqual(Cl.ok(Cl.bool(true)));
    mineToVotingEnd(quorumId);
    expect(finalize(quorumId).result).toEqual(Cl.ok(Cl.bool(true)));

    const approvalResult = createProposal(deployer, 2n, 3n, 1n, 6000n);
    const approvalId = proposalIdFrom(approvalResult);
    mineToVotingStart(approvalId);
    expect(vote(approvalId, wallet1, true, 600n).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(vote(approvalId, wallet2, false, 400n).result).toEqual(Cl.ok(Cl.bool(true)));
    mineToVotingEnd(approvalId);
    expect(finalize(approvalId).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('passes with quorum and approval, then allows one claim per voter', () => {
    const result = createProposal(deployer, 2n, 3n, 1n, 6000n);
    const proposalId = proposalIdFrom(result);
    mineToVotingStart(proposalId);
    expect(vote(proposalId, wallet1, true, 200n).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(vote(proposalId, wallet2, false, 50n).result).toEqual(Cl.ok(Cl.bool(true)));

    const beforeClaim = simnet.callReadOnlyFn('cxvg-token', 'get-balance', [Cl.principal(wallet1)], wallet1);
    mineToVotingEnd(proposalId);
    expect(finalize(proposalId).result).toEqual(Cl.ok(Cl.bool(true)));
    setRoute(TOKEN_ROUTE, `${deployer}.${WRONG_TOKEN_NAME}`);
    expect(claimStake(proposalId, wallet1, WRONG_TOKEN_NAME).result).toEqual(error(ERR_TOKEN_MISMATCH));
    expect(claimStake(proposalId, wallet1).result).toEqual(Cl.ok(Cl.uint(200)));
    const afterClaim = simnet.callReadOnlyFn('cxvg-token', 'get-balance', [Cl.principal(wallet1)], wallet1);
    expect(afterClaim.result).toEqual(
      Cl.ok(Cl.uint(BigInt((beforeClaim.result as any).value.value) + 200n)),
    );

    configureRoutes();
    expect(claimStake(proposalId, wallet1).result).toEqual(error(ERR_ALREADY_CLAIMED));
  });

  it('claims stake from a failed proposal and rejects unknown or premature claims', () => {
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'finalize-proposal',
        [Cl.uint(999999)],
        wallet3,
      ).result,
    ).toEqual(error(ERR_UNKNOWN_PROPOSAL));
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'claim-stake',
        [Cl.uint(999999), token()],
        wallet1,
      ).result,
    ).toEqual(error(ERR_UNKNOWN_PROPOSAL));

    const result = createProposal(deployer, 2n, 3n, 1n, 6000n);
    const proposalId = proposalIdFrom(result);
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'claim-stake',
        [Cl.uint(proposalId), token()],
        wallet1,
      ).result,
    ).toEqual(error(ERR_NOT_VOTED));

    mineToVotingStart(proposalId);
    expect(vote(proposalId, wallet2, false, 50n).result).toEqual(Cl.ok(Cl.bool(true)));
    mineToVotingEnd(proposalId);
    expect(finalize(proposalId).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'claim-stake',
        [Cl.uint(proposalId), token()],
        wallet2,
      ).result,
    ).toEqual(Cl.ok(Cl.uint(50)));
  });

  it('snapshots aggregate supply and lets later acquisitions vote only within the cap', () => {
    setRoute(TOKEN_ROUTE, `${deployer}.${MOCK_TOKEN_NAME}`);
    markCompliant(wallet3);
    const baselineSupply = tokenSupply(MOCK_TOKEN_NAME);
    mintToken(MOCK_TOKEN_NAME, wallet1, 1000n);
    const result = createProposalWith(
      deployer,
      2n,
      5n,
      1n,
      6000n,
      MOCK_TOKEN_NAME,
      COMPLIANCE_NAME,
    );
    const proposalId = proposalIdFrom(result);
    const stored = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(proposalId)],
      deployer,
    );
    expect(BigInt((stored.result as any).value.value['total-supply-snapshot'].value)).toBe(
      baselineSupply + 1000n,
    );

    mineToVotingStart(proposalId);
    mintToken(MOCK_TOKEN_NAME, wallet3, baselineSupply + 1n);
    expect(
      voteWith(
        proposalId,
        wallet3,
        true,
        baselineSupply + 1n,
        MOCK_TOKEN_NAME,
        COMPLIANCE_NAME,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      voteWith(proposalId, wallet1, true, 999n, MOCK_TOKEN_NAME, COMPLIANCE_NAME).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      voteWith(proposalId, wallet2, true, 1n, MOCK_TOKEN_NAME, COMPLIANCE_NAME).result,
    ).toEqual(error(ERR_SNAPSHOT_CAP));

    const after = simnet.callReadOnlyFn(
      'community-voting-engine',
      'get-proposal',
      [Cl.uint(proposalId)],
      deployer,
    );
    const proposal = (after.result as any).value.value;
    expect(BigInt(proposal['yes-deposited'].value)).toBe(baselineSupply + 1000n);
    expect(BigInt(proposal['no-deposited'].value)).toBe(0n);
    configureRoutes();
  });

  it('accepts the exact safe supply bound and rejects a higher snapshot', () => {
    setRoute(TOKEN_ROUTE, `${deployer}.${MOCK_TOKEN_NAME}`);
    const maxSafeSupply = uintValue(
      simnet.callReadOnlyFn('community-voting-engine', 'get-max-safe-supply', [], deployer).result,
    );
    const currentSupply = tokenSupply(MOCK_TOKEN_NAME);
    expect(currentSupply).toBeLessThanOrEqual(maxSafeSupply);
    mintToken(MOCK_TOKEN_NAME, wallet1, maxSafeSupply - currentSupply);
    expect(tokenSupply(MOCK_TOKEN_NAME)).toBe(maxSafeSupply);

    const exactResult = createProposalWith(
      deployer,
      2n,
      5n,
      1n,
      6000n,
      MOCK_TOKEN_NAME,
      COMPLIANCE_NAME,
    );
    expect(exactResult.result.type).toBe('ok');

    mintToken(MOCK_TOKEN_NAME, wallet1, 1n);
    expect(
      createProposalWith(
        deployer,
        2n,
        5n,
        1n,
        6000n,
        MOCK_TOKEN_NAME,
        COMPLIANCE_NAME,
      ).result,
    ).toEqual(error(ERR_SUPPLY_TOO_LARGE));
    configureRoutes();
  });

  it('rejects finalization before the end of the voting window', () => {
    const result = createProposal();
    const proposalId = proposalIdFrom(result);
    expect(finalize(proposalId).result).toEqual(error(ERR_VOTING_ACTIVE));
    expect(
      simnet.callPublicFn(
        'community-voting-engine',
        'claim-stake',
        [Cl.uint(proposalId), token()],
        wallet1,
      ).result,
    ).toEqual(error(ERR_NOT_VOTED));
  });
});
