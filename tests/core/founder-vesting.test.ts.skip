import { describe, expect, it, beforeEach } from 'vitest';
import {
  Cl,
  cvToValue,
  principalCV,
  uintCV,
} from '@stacks/transactions';
import {
  Simnet,
  getAccounts,
  getClarinetAccounts,
  initSimnet,
} from '@stacks/clarinet-sdk';

// --- Constants ---
const FOUNDER_VESTING_CONTRACT = 'founder-vesting';
const MOCK_TOKEN_CONTRACT = 'mock-ft';
const ONE_HUNDRED_MILLION = 100_000_000 * 1e8; // Example total supply

// --- Test Suite ---
describe('Founder Vesting Contract', () => {
  let simnet: Simnet;
  let deployer: string;
  let beneficiary: string;
  let unauthorizedUser: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const clarinetAccounts = await getClarinetAccounts();
    const accounts = await getAccounts(simnet);

    deployer = clarinetAccounts.deployer.address;
    beneficiary = accounts.get('wallet_1')!;
    unauthorizedUser = accounts.get('wallet_2')!;

    // Deploy a mock SIP-10 FT for testing claims
    await simnet.deployContract(
        MOCK_TOKEN_CONTRACT,
      `
      (define-trait sip-010-ft-trait
        ((transfer (uint principal principal (optional (buff 34))) (response bool uint))))
      (define-fungible-token mock-ft)
      (define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
        (begin
          (asserts! (is-eq sender tx-sender) (err u100))
          (ft-transfer? mock-ft amount sender recipient)
        )
      )
      (define-public (mint (amount uint) (recipient principal))
        (ft-mint? mock-ft amount recipient)
      )
      `,
      deployer
    );

    // Mint tokens to the vesting contract
    const vestingContractPrincipal = `${deployer}.${FOUNDER_VESTING_CONTRACT}`;
    await simnet.callPublicFn(
        MOCK_TOKEN_CONTRACT,
      'mint',
      [uintCV(ONE_HUNDRED_MILLION), principalCV(vestingContractPrincipal)],
      deployer
    );
  });

  it('allows the contract owner to initialize the contract', async () => {
    const initResult = await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'initialize',
      [principalCV(deployer)],
      deployer
    );
    expect(initResult.result).toBeOk(Cl.bool(true));
  });

  it('prevents a non-owner from adding a vesting schedule', async () => {
    const addScheduleResult = await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'add-vesting-schedule',
      [
        principalCV(beneficiary),
        uintCV(1000000),
        uintCV(100),
        uintCV(200),
      ],
      unauthorizedUser
    );
    expect(addScheduleResult.result).toBeErr(Cl.uint(401));
  });

  it('allows the owner to add a vesting schedule', async () => {
    await simnet.callPublicFn(FOUNDER_VESTING_CONTRACT, 'initialize', [principalCV(deployer)], deployer);

    const addScheduleResult = await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'add-vesting-schedule',
      [
        principalCV(beneficiary),
        uintCV(1000000),
        uintCV(100),
        uintCV(200),
      ],
      deployer
    );
    expect(addScheduleResult.result).toBeOk(Cl.bool(true));

    const schedule = await simnet.callReadOnlyFn(
        FOUNDER_VESTING_CONTRACT,
      'get-vesting-schedule',
      [principalCV(beneficiary)],
      deployer
    );

    const scheduleValue = cvToValue(schedule.result);
    expect(scheduleValue.value['total-amount']).toBe(1000000n);
  });

  it('prevents claiming tokens before the vesting period starts', async () => {
    await simnet.callPublicFn(FOUNDER_VESTING_CONTRACT, 'initialize', [principalCV(deployer)], deployer);
    await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'add-vesting-schedule',
      [
        principalCV(beneficiary),
        uintCV(1000000),
        uintCV(100), // Vesting starts at block 100
        uintCV(200),
      ],
      deployer
    );

    // Try to claim at block 50
    await simnet.mineBlock([]);

    const claimResult = await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'claim-vested-tokens',
      [Cl.contractPrincipal(deployer, MOCK_TOKEN_CONTRACT)],
      beneficiary
    );
    expect(claimResult.result).toBeErr(Cl.uint(405)); // ERR_NOTHING_TO_CLAIM
  });

  it('allows a beneficiary to claim the correct amount mid-vesting', async () => {
    await simnet.callPublicFn(FOUNDER_VESTING_CONTRACT, 'initialize', [principalCV(deployer)], deployer);
    await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'add-vesting-schedule',
      [
        principalCV(beneficiary),
        uintCV(1000000), // 1M tokens
        uintCV(100),
        uintCV(200),      // 100 blocks duration
      ],
      deployer
    );

    // Mine blocks to the halfway point (block 150)
    await simnet.mineBlocks(149); // Mine up to block 150

    const claimResult = await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'claim-vested-tokens',
      [Cl.contractPrincipal(deployer, MOCK_TOKEN_CONTRACT)],
      beneficiary
    );

    // Halfway through, 50% should be vested (500,000 tokens)
    expect(claimResult.result).toBeOk(Cl.uint(500000));
  });

  it('allows a beneficiary to claim the full amount after the vesting period', async () => {
    await simnet.callPublicFn(FOUNDER_VESTING_CONTRACT, 'initialize', [principalCV(deployer)], deployer);
    await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'add-vesting-schedule',
      [
        principalCV(beneficiary),
        uintCV(1000000),
        uintCV(100),
        uintCV(200),
      ],
      deployer
    );

    // Mine blocks to past the end of the vesting period
    await simnet.mineBlocks(250);

    const claimResult = await simnet.callPublicFn(
        FOUNDER_VESTING_CONTRACT,
      'claim-vested-tokens',
      [Cl.contractPrincipal(deployer, MOCK_TOKEN_CONTRACT)],
      beneficiary
    );

    expect(claimResult.result).toBeOk(Cl.uint(1000000));
  });
});
