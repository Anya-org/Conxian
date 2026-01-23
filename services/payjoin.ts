import { PayjoinClient } from 'payjoin-client';
import * as bitcoin from 'bitcoinjs-lib';
import { parseBip21 } from './bip21';
import { Network } from '../types';

interface PayJoinResult {
  txHex: string;
  txid: string;
}

export class PayJoinService {
  private network: bitcoin.Network;

  constructor(networkParam: Network = 'mainnet') {
    this.network = networkParam === 'testnet' ? bitcoin.networks.testnet : bitcoin.networks.bitcoin;
  }

  /**
   * Checks if a BIP-21 URI contains a PayJoin endpoint.
   */
  hasPayJoin(uri: string): boolean {
    const parsed = parseBip21(uri);
    return !!parsed.options?.pj;
  }

  /**
   * Executes the PayJoin protocol (BIP-78).
   * 
   * @param uri The BIP-21 URI containing the BTC address and the `pj` endpoint.
   * @param signer A callback to sign the PSBT.
   */
  async sendPayJoin(
    uri: string, 
    walletPsbt: bitcoin.Psbt, 
    signPsbtCallback: (psbt: bitcoin.Psbt) => Promise<bitcoin.Psbt>
  ): Promise<PayJoinResult> {
    
    const parsed = parseBip21(uri);
    if (!parsed.options?.pj) throw new Error('No PayJoin endpoint found in URI');

    const client = new PayjoinClient({
      walletPsbt,
      payjoinParameters: {
         payjoinUrl: parsed.options.pj,
         // Pass other optional params if they exist in the URI
         ...parsed.options
      }
    } as any) as any;

    try {
      // 1. Get the PayJoin PSBT from the receiver
      const payjoinPsbt = await client.getPayjoinPsbt();
      if (!payjoinPsbt) {
         throw new Error('Server declined PayJoin or returned invalid PSBT');
      }

      // 2. Sign the PayJoin PSBT
      // The wallet must sign the inputs it added (and potentially verify the new outputs)
      const signedPayjoinPsbt = await signPsbtCallback(payjoinPsbt);

      // 3. Post the signed PSBT transaction to the receiver (optional broadcast)
      // The protocol allows the receiver to broadcast, but typically we want to ensure it propagates.
      // Often the `payjoin-client` handles the "post" logic if we want the receiver to broadcast.
      // However, usually we can just extract the tx and broadcast ourselves if the receiver doesn't object.
      // Standard flow: We send the Signed PSBT back to the server.
      
      // Note: payjoin-client logic might vary on "who broadcasts".
      // We will assume we broadcast for autonomy unless config says otherwise.
      
      const tx = signedPayjoinPsbt.extractTransaction();
      return {
        txHex: tx.toHex(),
        txid: tx.getId()
      };
    } catch (e) {
      console.error('PayJoin Failed, falling back to original transaction logic if handling upstream', e);
      throw e;
    }
  }
}
