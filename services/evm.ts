const ROUND_CONSTANTS = [
  0x0000000000000001n, 0x0000000000008082n, 0x800000000000808an, 0x8000000080008000n,
  0x000000000000808bn, 0x0000000080000001n, 0x8000000080008081n, 0x8000000000008009n,
  0x000000000000008an, 0x0000000000000088n, 0x0000000080008009n, 0x000000008000000an,
  0x000000008000808bn, 0x800000000000008bn, 0x8000000000008089n, 0x8000000000008003n,
  0x8000000000008002n, 0x8000000000000080n, 0x000000000000800an, 0x800000008000000an,
  0x8000000080008081n, 0x8000000000008080n, 0x0000000080000001n, 0x8000000080008008n
];

const ROTATION_OFFSETS = [
  [0, 36, 3, 41, 18],
  [1, 44, 10, 45, 2],
  [62, 6, 43, 15, 61],
  [28, 55, 25, 21, 56],
  [27, 20, 39, 8, 14]
];

const MASK_64 = (1n << 64n) - 1n;

function rotl64(x: bigint, n: number) {
  const bn = BigInt(n);
  return ((x << bn) | (x >> (64n - bn))) & MASK_64;
}

function keccakF1600(state: bigint[]) {
  for (let round = 0; round < 24; round++) {
    const c = new Array<bigint>(5);
    for (let x = 0; x < 5; x++) {
      c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
    }

    const d = new Array<bigint>(5);
    for (let x = 0; x < 5; x++) {
      d[x] = c[(x + 4) % 5] ^ rotl64(c[(x + 1) % 5], 1);
    }
    for (let x = 0; x < 5; x++) {
      for (let y = 0; y < 5; y++) {
        state[x + 5 * y] = (state[x + 5 * y] ^ d[x]) & MASK_64;
      }
    }

    const b = new Array<bigint>(25);
    for (let x = 0; x < 5; x++) {
      for (let y = 0; y < 5; y++) {
        const idx = x + 5 * y;
        const rot = ROTATION_OFFSETS[y][x];
        const X = y;
        const Y = (2 * x + 3 * y) % 5;
        b[X + 5 * Y] = rotl64(state[idx], rot);
      }
    }

    for (let x = 0; x < 5; x++) {
      for (let y = 0; y < 5; y++) {
        const idx = x + 5 * y;
        const v = b[idx] ^ ((~b[((x + 1) % 5) + 5 * y]) & b[((x + 2) % 5) + 5 * y]);
        state[idx] = v & MASK_64;
      }
    }

    state[0] = (state[0] ^ ROUND_CONSTANTS[round]) & MASK_64;
  }
}

function readUint64LE(bytes: Uint8Array, offset: number) {
  let v = 0n;
  for (let i = 0; i < 8; i++) {
    v |= BigInt(bytes[offset + i] ?? 0) << (8n * BigInt(i));
  }
  return v;
}

function writeUint64LE(out: Uint8Array, offset: number, v: bigint) {
  for (let i = 0; i < 8; i++) {
    out[offset + i] = Number((v >> (8n * BigInt(i))) & 0xffn);
  }
}

export function keccak256(data: Uint8Array): Uint8Array {
  const rate = 136;
  const state = new Array<bigint>(25).fill(0n);

  let offset = 0;
  while (offset + rate <= data.length) {
    for (let i = 0; i < rate / 8; i++) {
      state[i] = (state[i] ^ readUint64LE(data, offset + i * 8)) & MASK_64;
    }
    keccakF1600(state);
    offset += rate;
  }

  const block = new Uint8Array(rate);
  block.set(data.slice(offset));
  block[data.length - offset] = 0x01;
  block[rate - 1] |= 0x80;
  for (let i = 0; i < rate / 8; i++) {
    state[i] = (state[i] ^ readUint64LE(block, i * 8)) & MASK_64;
  }
  keccakF1600(state);

  const out = new Uint8Array(32);
  for (let i = 0; i < 4; i++) {
    writeUint64LE(out, i * 8, state[i]);
  }
  return out;
}

function bytesToHex(bytes: Uint8Array) {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
}

export function toEip55Address(address20: Uint8Array) {
  const hex = bytesToHex(address20);
  const hash = bytesToHex(keccak256(new TextEncoder().encode(hex)));
  let out = '0x';
  for (let i = 0; i < hex.length; i++) {
    const ch = hex[i];
    const h = parseInt(hash[i], 16);
    out += h >= 8 ? ch.toUpperCase() : ch;
  }
  return out;
}

export function publicKeyToEvmAddress(uncompressedPubkey: Uint8Array) {
  const pub = uncompressedPubkey[0] === 4 ? uncompressedPubkey.slice(1) : uncompressedPubkey;
  const digest = keccak256(pub);
  const addr = digest.slice(12);
  return toEip55Address(addr);
}
