import * as bitcoin from 'bitcoinjs-lib';
import BIP32Factory from 'bip32';
import * as ecc from 'tiny-secp256k1';
import ECPairFactory from 'ecpair';
import { UTXO, Network } from '../types';

const bip32 = BIP32Factory(ecc);
const ECPair = ECPairFactory(ecc);

function networkFrom(network: Network) {
  return network === 'mainnet' ? bitcoin.networks.bitcoin : bitcoin.networks.testnet;
}

function coinType(network: Network) {
  return network === 'mainnet' ? 0 : 1;
}

export function estimateVbytes(inputs: number, outputs: number) {
  return Math.max(10 + inputs * 68 + outputs * 31, 110);
}

export function buildPsbt(params: {
  utxos: UTXO[];
  toAddress: string;
  amountSats: number;
  changeAddress: string;
  feeRate: number;
  rbf?: boolean;
  network: Network;
}) {
  const net = networkFrom(params.network);
  const psbt = new bitcoin.Psbt({ network: net });
  let totalIn = 0;
  params.utxos.forEach(u => {
    totalIn += u.amount;
    psbt.addInput({
      hash: u.txid,
      index: u.vout,
      sequence: params.rbf ? 0xfffffffd : undefined,
      witnessUtxo: {
        script: bitcoin.payments.p2wpkh({ address: u.address, network: net })!.output!,
        value: BigInt(u.amount)
      }
    });
  });
  const vbytes = estimateVbytes(params.utxos.length, 2);
  const fee = Math.floor(vbytes * params.feeRate);
  const change = totalIn - params.amountSats - fee;
  if (change < 0) {
    throw new Error('Insufficient funds');
  }
  psbt.addOutput({ address: params.toAddress, value: BigInt(params.amountSats) });
  psbt.addOutput({ address: params.changeAddress, value: BigInt(change) });
  return psbt.toBase64();
}

export async function signPsbtBase64(mnemonic: string, psbtBase64: string, network: Network) {
  const seed = await (await import('bip39')).mnemonicToSeed(mnemonic);
  return signPsbtBase64WithSeed(new Uint8Array(seed), psbtBase64, network);
}

export async function signPsbtBase64WithSeed(seed: Uint8Array, psbtBase64: string, network: Network) {
  const root = bip32.fromSeed(Buffer.from(seed));
  const path = `m/84'/${coinType(network)}'/0'/0/0`;
  const child = root.derivePath(path);
  const keyPair = ECPair.fromPrivateKey(child.privateKey!, { network: networkFrom(network) });
  const psbt = bitcoin.Psbt.fromBase64(psbtBase64, { network: networkFrom(network) });
  for (let i = 0; i < psbt.inputCount; i++) {
    psbt.signInput(i, keyPair);
  }
  psbt.finalizeAllInputs();
  return psbt.extractTransaction().toHex();
}

export function getPsbtSighashes(
  psbtBase64: string,
  pubkey: Buffer,
  network: Network,
): { hash: Buffer; index: number }[] {
  const psbt = bitcoin.Psbt.fromBase64(psbtBase64, {
    network: networkFrom(network),
  });
  const hashes: { hash: Buffer; index: number }[] = [];

  // Dummy signer to capture hashes
  const captureSigner = {
    publicKey: pubkey,
    sign: (hash: Buffer) => {
      hashes.push({ hash, index: -1 }); // index update below
      return Buffer.alloc(64);
    },
  };

  for (let i = 0; i < psbt.inputCount; i++) {
    const startLen = hashes.length;
    try {
      psbt.signInput(i, captureSigner);
    } catch (e) {}
    if (hashes.length > startLen) {
      hashes[hashes.length - 1].index = i;
    }
  }
  return hashes;
}

export function finalizePsbtWithSigs(
  psbtBase64: string,
  signatures: { index: number; signature: Buffer }[],
  pubkey: Buffer,
  network: Network,
) {
  const psbt = bitcoin.Psbt.fromBase64(psbtBase64, {
    network: networkFrom(network),
  });

  signatures.forEach((sigItem) => {
    const signer = {
      publicKey: pubkey,
      sign: () => sigItem.signature,
    };
    psbt.signInput(sigItem.index, signer);
  });

  psbt.finalizeAllInputs();
  return psbt.extractTransaction().toHex();
}

export function finalizePsbtWithSigsReturnBase64(
  psbtBase64: string,
  signatures: { index: number; signature: Buffer }[],
  pubkey: Buffer,
  network: Network,
) {
  const psbt = bitcoin.Psbt.fromBase64(psbtBase64, {
    network: networkFrom(network),
  });

  signatures.forEach((sigItem) => {
    const signer = {
      publicKey: pubkey,
      sign: () => sigItem.signature,
    };
    psbt.signInput(sigItem.index, signer);
  });

  psbt.finalizeAllInputs();
  return psbt.toBase64();
}
