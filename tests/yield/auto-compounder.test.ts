import { beforeEach, describe, expect, it } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

const AUTO_COMPOUNDER = 'auto-compounder';
const MOCK_VAULT = 'mock-compoundable-vault';
const FORWARDER = 'mock-admin-forwarder';

const ERR_UNAUTHORIZED = 1000;
const ERR_INVALID_TRIGGER_MODE = 1001;
const ERR_INVALID_INTERVAL = 1002;
const ERR_INVALID_THRESHOLD = 1003;
const ERR_INVALID_MIN_OUTPUT = 1004;
const ERR_VAULT_NOT_REGISTERED = 1005;
const ERR_VAULT_DISABLED = 1006;
const ERR_VAULT_IDENTITY_MISMATCH = 1007;
const ERR_TRIGGER_NOT_READY = 1008;
const ERR_OUTPUT_TOO_LOW = 1009;
const ERR_COMPOUND_FAILED = 7000;

const TRIGGER_FREQUENCY = 1;
const TRIGGER_THRESHOLD = 2;
const TRIGGER_EITHER = 3;
const TRIGGER_BOTH = 4;

type SimnetLike = any;

describe('Trait-driven auto-compounder Phase 2', () => {
  let simnet: SimnetLike;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let vault: string;
  let forwarder: string;

  const vaultArg = () => Cl.contractPrincipal(deployer, MOCK_VAULT);
  const vaultPrincipal = () => `${deployer}.${MOCK_VAULT}`;
  const principal = (value: string) => Cl.principal(value);

  const expectError = (result: any, code: number) => {
    expect(result).toEqual(Cl.error(Cl.uint(code)));
  };

  const callMock = (method: string, args: any[]) =>
    simnet.callPublicFn(MOCK_VAULT, method, args, deployer);

  const callForwarder = (method: string, args: any[], sender = deployer) =>
    simnet.callPublicFn(FORWARDER, method, args, sender);

  const setPending = (amount: number | bigint) => {
    expect(callMock('set-pending-rewards', [Cl.uint(amount)]).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  const setOutput = (amount: number | bigint) => {
    expect(callMock('set-compound-output', [Cl.uint(amount)]).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  const registerVault = ({
    destination = vaultPrincipal(),
    mode = TRIGGER_THRESHOLD,
    interval = 0,
    threshold = 1,
    minOutput = 1,
    enabled = true,
  }: {
    destination?: string;
    mode?: number;
    interval?: number;
    threshold?: number;
    minOutput?: number;
    enabled?: boolean;
  } = {}) =>
    simnet.callPublicFn(
      AUTO_COMPOUNDER,
      'register-vault',
      [
        vaultArg(),
        principal(destination),
        Cl.uint(mode),
        Cl.uint(interval),
        Cl.uint(threshold),
        Cl.uint(minOutput),
        Cl.bool(enabled),
      ],
      deployer,
    );

  const forwardRegisterVault = ({
    destination = vaultPrincipal(),
    mode = TRIGGER_THRESHOLD,
    interval = 0,
    threshold = 1,
    minOutput = 1,
    enabled = true,
    sender = deployer,
  }: {
    destination?: string;
    mode?: number;
    interval?: number;
    threshold?: number;
    minOutput?: number;
    enabled?: boolean;
    sender?: string;
  } = {}) =>
    callForwarder(
      'forward-auto-register-vault',
      [
        vaultArg(),
        principal(destination),
        Cl.uint(mode),
        Cl.uint(interval),
        Cl.uint(threshold),
        Cl.uint(minOutput),
        Cl.bool(enabled),
      ],
      sender,
    );

  const status = (pendingRewards: number | bigint) =>
    simnet.callReadOnlyFn(
      AUTO_COMPOUNDER,
      'get-trigger-status',
      [principal(vault), Cl.uint(pendingRewards)],
      deployer,
    );

  const config = () =>
    simnet.callReadOnlyFn(AUTO_COMPOUNDER, 'get-vault-config', [principal(vault)], deployer);

  beforeEach(async () => {
    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    wallet2 = simnet.getAccounts().get('wallet_2')!;
    vault = vaultPrincipal();
    forwarder = `${deployer}.${FORWARDER}`;
  });

  it('enforces admin registration and rejects invalid trigger/slippage configurations', () => {
    expectError(
      simnet.callPublicFn(
        AUTO_COMPOUNDER,
        'register-vault',
        [vaultArg(), principal(vault), Cl.uint(TRIGGER_THRESHOLD), Cl.uint(0), Cl.uint(1), Cl.uint(1), Cl.bool(true)],
        wallet1,
      ).result,
      ERR_UNAUTHORIZED,
    );

    expectError(registerVault({ mode: 99 }).result, ERR_INVALID_TRIGGER_MODE);
    expectError(registerVault({ mode: TRIGGER_FREQUENCY, interval: 0 }).result, ERR_INVALID_INTERVAL);
    expectError(registerVault({ mode: TRIGGER_THRESHOLD, threshold: 0 }).result, ERR_INVALID_THRESHOLD);
    expectError(registerVault({ mode: TRIGGER_EITHER, interval: 0, threshold: 0 }).result, ERR_INVALID_INTERVAL);
    expectError(registerVault({ minOutput: 0 }).result, ERR_INVALID_MIN_OUTPUT);

    const registration = registerVault();
    expect(registration.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(registration.events.some((event: any) => JSON.stringify(event).includes('compound-vault-registered'))).toBe(true);
    expect(Cl.prettyPrint(config().result)).toContain('source-vault:');
    expect(Cl.prettyPrint(config().result)).toContain(vault);
    expect(Cl.prettyPrint(config().result)).toContain('enabled: true');
  });

  it('transfers admin control and locks the previous admin out', () => {
    const transfer = simnet.callPublicFn(AUTO_COMPOUNDER, 'set-admin', [principal(wallet1)], deployer);
    expect(transfer.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(transfer.events.some((event: any) => JSON.stringify(event).includes('compounder-admin-updated'))).toBe(true);

    expect(
      simnet.callPublicFn(AUTO_COMPOUNDER, 'set-admin', [principal(deployer)], deployer).result,
    ).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(
      simnet.callPublicFn(AUTO_COMPOUNDER, 'register-vault', [
        vaultArg(),
        principal(vault),
        Cl.uint(TRIGGER_THRESHOLD),
        Cl.uint(0),
        Cl.uint(1),
        Cl.uint(1),
        Cl.bool(true),
      ], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('authenticates the immediate caller and supports deliberate contract-admin forwarding', () => {
    expectError(
      callForwarder('forward-auto-set-admin', [principal(wallet1)], deployer).result,
      ERR_UNAUTHORIZED,
    );
    expectError(forwardRegisterVault({ sender: deployer }).result, ERR_UNAUTHORIZED);

    expect(
      simnet.callPublicFn(AUTO_COMPOUNDER, 'set-admin', [principal(forwarder)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(forwardRegisterVault({ sender: wallet1 }).result).toEqual(Cl.ok(Cl.bool(true)));

    const update = callForwarder(
      'forward-auto-update-vault-config',
      [
        vaultArg(),
        principal(wallet1),
        Cl.uint(TRIGGER_THRESHOLD),
        Cl.uint(0),
        Cl.uint(20),
        Cl.uint(5),
        Cl.bool(false),
      ],
      wallet2,
    );
    expect(update.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(Cl.prettyPrint(config().result)).toContain('min-reward-threshold: u20');

    const handoff = callForwarder('forward-auto-set-admin', [principal(wallet1)], wallet2);
    expect(handoff.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(JSON.stringify(handoff.events)).toContain(forwarder);
    expectError(
      callForwarder('forward-auto-set-vault-enabled', [vaultArg(), Cl.bool(true)], wallet2).result,
      ERR_UNAUTHORIZED,
    );
    expect(
      simnet.callPublicFn(AUTO_COMPOUNDER, 'set-vault-enabled', [vaultArg(), Cl.bool(true)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('updates configuration without resetting last-success state and protects admin APIs', () => {
    expect(registerVault({ minOutput: 1 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(10);
    setOutput(10);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
    const afterCompound = Cl.prettyPrint(config().result);
    expect(afterCompound).not.toContain('last-compound-block: u0');

    expectError(
      simnet.callPublicFn(AUTO_COMPOUNDER, 'set-vault-enabled', [vaultArg(), Cl.bool(false)], wallet1).result,
      ERR_UNAUTHORIZED,
    );
    expect(
      simnet.callPublicFn(
        AUTO_COMPOUNDER,
        'update-vault-config',
        [vaultArg(), principal(wallet1), Cl.uint(TRIGGER_THRESHOLD), Cl.uint(0), Cl.uint(20), Cl.uint(5), Cl.bool(false)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    const updated = Cl.prettyPrint(config().result);
    expect(updated).not.toContain('last-compound-block: u0');
    expect(updated).toContain('min-reward-threshold: u20');
    expect(updated).toContain('min-output: u5');

    expect(
      simnet.callPublicFn(AUTO_COMPOUNDER, 'set-vault-enabled', [vaultArg(), Cl.bool(true)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(Cl.prettyPrint(config().result)).toContain('enabled: true');
  });

  it('rejects unregistered, disabled, and mismatched typed vault references', () => {
    setPending(10);
    setOutput(10);

    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], deployer).result, ERR_VAULT_NOT_REGISTERED);

    expect(registerVault({ enabled: false }).result).toEqual(Cl.ok(Cl.bool(true)));
    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_VAULT_DISABLED);

    expect(
      simnet.callPublicFn(
        AUTO_COMPOUNDER,
        'compound-for',
        [principal(wallet1), vaultArg()],
        wallet1,
      ).result,
    ).toEqual(Cl.error(Cl.uint(ERR_VAULT_IDENTITY_MISMATCH)));
  });

  it('supports frequency triggers at the burn-block boundary', () => {
    expect(registerVault({ mode: TRIGGER_FREQUENCY, interval: 20, threshold: 0 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(0);
    setOutput(10);

    const before = status(0);
    expect(Cl.prettyPrint(before.result)).toContain('frequency-ready: false');
    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_TRIGGER_NOT_READY);

    simnet.mineEmptyBlocks(19);
    expect(Cl.prettyPrint(status(0).result)).toContain('frequency-ready: false');
    simnet.mineEmptyBlocks(1);
    expect(Cl.prettyPrint(status(0).result)).toContain('frequency-ready: true');
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('supports threshold triggers at the reward boundary', () => {
    expect(registerVault({ mode: TRIGGER_THRESHOLD, threshold: 100 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(99);
    setOutput(10);

    expect(Cl.prettyPrint(status(99).result)).toContain('threshold-ready: false');
    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_TRIGGER_NOT_READY);

    setPending(100);
    expect(Cl.prettyPrint(status(100).result)).toContain('threshold-ready: true');
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('supports either and both trigger semantics', async () => {
    expect(registerVault({ mode: TRIGGER_EITHER, interval: 20, threshold: 100 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(100);
    setOutput(10);
    expect(Cl.prettyPrint(status(100).result)).toContain('should-compound: true');
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));

    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    vault = vaultPrincipal();
    expect(registerVault({ mode: TRIGGER_BOTH, interval: 20, threshold: 100 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(100);
    setOutput(10);
    expect(Cl.prettyPrint(status(100).result)).toContain('threshold-ready: true');
    expect(Cl.prettyPrint(status(100).result)).toContain('frequency-ready: false');
    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_TRIGGER_NOT_READY);

    simnet.mineEmptyBlocks(20);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('allows EITHER to become ready through frequency alone', () => {
    expect(registerVault({ mode: TRIGGER_EITHER, interval: 5, threshold: 100 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(0);
    setOutput(10);

    expect(Cl.prettyPrint(status(0).result)).toContain('frequency-ready: false');
    expect(Cl.prettyPrint(status(0).result)).toContain('threshold-ready: false');
    expect(Cl.prettyPrint(status(0).result)).toContain('should-compound: false');

    simnet.mineEmptyBlocks(5);
    expect(Cl.prettyPrint(status(0).result)).toContain('frequency-ready: true');
    expect(Cl.prettyPrint(status(0).result)).toContain('threshold-ready: false');
    expect(Cl.prettyPrint(status(0).result)).toContain('should-compound: true');
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('preserves successful interval history when a vault is re-registered', () => {
    expect(registerVault({ mode: TRIGGER_FREQUENCY, interval: 5, threshold: 0 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(0);
    setOutput(10);
    simnet.mineEmptyBlocks(5);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));

    const before = Cl.prettyPrint(config().result);
    const lastBlock = before.match(/last-compound-block: u(\d+)/)?.[1];
    expect(lastBlock).toBeDefined();

    expect(
      registerVault({ mode: TRIGGER_FREQUENCY, interval: 5, threshold: 0, minOutput: 2 }).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    const after = Cl.prettyPrint(config().result);
    expect(after).toContain(`last-compound-block: u${lastBlock}`);
    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_TRIGGER_NOT_READY);

    simnet.mineEmptyBlocks(5);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('propagates same-position and cross-position destinations to the vault', async () => {
    expect(registerVault({ destination: vaultPrincipal() }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(10);
    setOutput(10);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
    expect(
      simnet.callReadOnlyFn(MOCK_VAULT, 'get-last-destination', [], deployer).result,
    ).toEqual(Cl.principal(vaultPrincipal()));

    simnet = await initSimnet('Clarinet.toml');
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
    vault = vaultPrincipal();
    expect(registerVault({ destination: wallet1 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(10);
    setOutput(10);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
    expect(simnet.callReadOnlyFn(MOCK_VAULT, 'get-last-destination', [], deployer).result).toEqual(Cl.principal(wallet1));
  });

  it('enforces minimum output and rolls back vault/coordinator state on slippage failure', () => {
    expect(registerVault({ minOutput: 50 }).result).toEqual(Cl.ok(Cl.bool(true)));
    const initialLastCompoundBlock = Cl.prettyPrint(config().result).match(/last-compound-block: u(\d+)/)?.[1] ?? '';
    expect(initialLastCompoundBlock).not.toBe('');
    setPending(100);
    setOutput(49);

    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_OUTPUT_TOO_LOW);
    expect(simnet.callReadOnlyFn(MOCK_VAULT, 'get-pending-rewards', [], deployer).result).toEqual(Cl.ok(Cl.uint(100)));
    expect(simnet.callReadOnlyFn(MOCK_VAULT, 'get-compound-count', [], deployer).result).toEqual(Cl.uint(0));
    expect(Cl.prettyPrint(config().result)).toContain(`last-compound-block: u${initialLastCompoundBlock}`);

    setOutput(50);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(50)));
  });

  it('propagates a failed vault call and rolls back the coordinator state', () => {
    expect(registerVault().result).toEqual(Cl.ok(Cl.bool(true)));
    const initialLastCompoundBlock = Cl.prettyPrint(config().result).match(/last-compound-block: u(\d+)/)?.[1] ?? '';
    expect(initialLastCompoundBlock).not.toBe('');
    setPending(10);
    setOutput(10);
    expect(callMock('set-compound-failure', [Cl.bool(true)]).result).toEqual(Cl.ok(Cl.bool(true)));

    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_COMPOUND_FAILED);
    expect(simnet.callReadOnlyFn(MOCK_VAULT, 'get-pending-rewards', [], deployer).result).toEqual(Cl.ok(Cl.uint(10)));
    expect(Cl.prettyPrint(config().result)).toContain(`last-compound-block: u${initialLastCompoundBlock}`);

    expect(callMock('set-compound-failure', [Cl.bool(false)]).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('updates last-success state and emits an execution event only after success', () => {
    expect(registerVault({ minOutput: 4 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(10);
    setOutput(7);

    const result = callForwarder('forward-auto-compound', [vaultArg()], wallet1);
    expect(result.result).toEqual(Cl.ok(Cl.uint(7)));
    expect(simnet.callReadOnlyFn(MOCK_VAULT, 'get-last-min-output', [], deployer).result).toEqual(Cl.uint(4));
    expect(simnet.callReadOnlyFn(MOCK_VAULT, 'get-compound-count', [], deployer).result).toEqual(Cl.uint(1));
    expect(result.events.some((event: any) => JSON.stringify(event).includes('compound-executed'))).toBe(true);
    expect(JSON.stringify(result.events)).toContain(forwarder);
    expect(JSON.stringify(result.events)).toContain(wallet1);
    expect(Cl.prettyPrint(config().result)).not.toContain('last-compound-block: u0');
  });

  it('enforces the repeat interval after a successful compound', () => {
    expect(registerVault({ mode: TRIGGER_FREQUENCY, interval: 5, threshold: 0 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(0);
    setOutput(10);

    simnet.mineEmptyBlocks(5);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_TRIGGER_NOT_READY);

    simnet.mineEmptyBlocks(4);
    expectError(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result, ERR_TRIGGER_NOT_READY);
    simnet.mineEmptyBlocks(1);
    expect(simnet.callPublicFn(AUTO_COMPOUNDER, 'compound', [vaultArg()], wallet1).result).toEqual(Cl.ok(Cl.uint(10)));
  });

  it('exposes the O(1) preflight status helper for keeper snapshots', () => {
    expect(registerVault({ mode: TRIGGER_THRESHOLD, threshold: 25 }).result).toEqual(Cl.ok(Cl.bool(true)));
    setPending(25);
    setOutput(5);

    const preflight = status(25);
    expect(preflight.result).toEqual(Cl.ok(expect.anything()));
    expect(Cl.prettyPrint(preflight.result)).toContain('should-compound: true');
  });
});
