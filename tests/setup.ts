import { expect, afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';
import * as matchers from '@testing-library/jest-dom/matchers';

// Extends Vitest's expect method with methods from react-testing-library
// expect.extend(matchers);

// Runs a cleanup after each test case (e.g. clearing jsdom)
afterEach(() => {
  cleanup();
});

import { TextEncoder as NodeTextEncoder, TextDecoder as NodeTextDecoder } from 'node:util';
try {
  new globalThis.TextEncoder();
} catch {
  // @ts-ignore
  globalThis.TextEncoder = NodeTextEncoder;
}
try {
  new globalThis.TextDecoder();
} catch {
  // @ts-ignore
  globalThis.TextDecoder = NodeTextDecoder;
}

// Polyfill for crypto.subtle
import { webcrypto } from 'crypto';
// @ts-ignore
if (!globalThis.crypto) {
    // @ts-ignore
    globalThis.crypto = webcrypto;
}

// Ensure URL is globally available
import { URL } from 'url';
// @ts-ignore
globalThis.URL = URL;
