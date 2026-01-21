import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;

describe('Enhanced Governance NFT (Seats)', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  it('allows admin to mint a seat', () => {
    const mint = simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(1), // Protocol Council
        Cl.uint(100), // 100 Voting Power
        Cl.stringAscii("human")
      ],
      deployer
    );
    expect(mint.result).toBeOk(Cl.uint(1));

    // Verify Seat Data
    const seatInfo = simnet.callReadOnlyFn(
        'enhanced-governance-nft',
        'get-seat-info',
        [Cl.uint(1)],
        deployer
    );
    expect(seatInfo.result).toBeSome(Cl.tuple({
        'council-id': Cl.uint(1),
        'voting-power': Cl.uint(100),
        'member-type': Cl.stringAscii("human"),
        'created-at': Cl.uint(0) // Simnet starts at 0? Or 1? Usually 0 or small number. 
                                  // Actually block-height is usually 1 in beforeAll? 
                                  // We'll just check it's a tuple for now to be safe on height.
    }));
  });

  it('prevents non-admin from minting', () => {
    const mint = simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [
        Cl.standardPrincipal(wallet1),
        Cl.uint(1),
        Cl.uint(100),
        Cl.stringAscii("human")
      ],
      wallet1 // Not admin
    );
    expect(mint.result).toBeErr(Cl.uint(1000)); // ERR_UNAUTHORIZED
  });

  it('prevents multiple seats on same council for one user', () => {
    // Mint first seat
    simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [Cl.standardPrincipal(wallet1), Cl.uint(1), Cl.uint(100), Cl.stringAscii("human")],
      deployer
    );

    // Try minting second seat on SAME council
    const mint2 = simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [Cl.standardPrincipal(wallet1), Cl.uint(1), Cl.uint(50), Cl.stringAscii("human")],
      deployer
    );
    expect(mint2.result).toBeErr(Cl.uint(1002)); // ERR_SEAT_TAKEN
  });

  it('allows user to hold seats on DIFFERENT councils', () => {
    // Protocol Council
    simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [Cl.standardPrincipal(wallet1), Cl.uint(1), Cl.uint(100), Cl.stringAscii("human")],
      deployer
    );

    // Risk Council
    const mint2 = simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [Cl.standardPrincipal(wallet1), Cl.uint(2), Cl.uint(50), Cl.stringAscii("human")],
      deployer
    );
    expect(mint2.result).toBeOk(Cl.uint(2));
  });

  it('tracks total council power correctly', () => {
    // User 1 on Council 1 (Power 100)
    simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [Cl.standardPrincipal(wallet1), Cl.uint(1), Cl.uint(100), Cl.stringAscii("human")],
      deployer
    );

    // User 2 on Council 1 (Power 200)
    simnet.callPublicFn(
      'enhanced-governance-nft',
      'mint-seat',
      [Cl.standardPrincipal(wallet2), Cl.uint(1), Cl.uint(200), Cl.stringAscii("human")],
      deployer
    );

    const totalPower = simnet.callReadOnlyFn(
        'enhanced-governance-nft',
        'get-total-council-power',
        [Cl.uint(1)],
        deployer
    );
    expect(totalPower.result).toBeUint(300);
  });

  it('updates total power on burn', () => {
     // User 1 on Council 1 (Power 100)
    const mint = simnet.callPublicFn(
        'enhanced-governance-nft',
        'mint-seat',
        [Cl.standardPrincipal(wallet1), Cl.uint(1), Cl.uint(100), Cl.stringAscii("human")],
        deployer
    );
    const seatId = (mint.result as any).value;

    // Burn
    const burn = simnet.callPublicFn(
        'enhanced-governance-nft',
        'burn-seat',
        [seatId],
        deployer
    );
    expect(burn.result).toBeOk(Cl.bool(true));

    const totalPower = simnet.callReadOnlyFn(
        'enhanced-governance-nft',
        'get-total-council-power',
        [Cl.uint(1)],
        deployer
    );
    expect(totalPower.result).toBeUint(0);
  });
});
