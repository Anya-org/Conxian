import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { simnet } from './setup-test-env';
import { Cl } from "@stacks/transactions";

let deployer: string;

describe("BitVM2 Bridge Logic (CON-75)", () => {
  beforeAll(async () => {

  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("should verify a labor attestation with a valid SNARK proof placeholder", () => {
    const jobId = "0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
    const stateRoot = "0x201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201";
    const proof = "0x" + "00".repeat(1024);

    const result = simnet.callPublicFn(
      "clarity-bitcoin",
      "verify-labor-attestation",
      [Cl.buffer(Buffer.from(jobId.slice(2), "hex")), Cl.buffer(Buffer.from(stateRoot.slice(2), "hex")), Cl.buffer(Buffer.from(proof.slice(2), "hex"))],
      deployer
    );

    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));

    const verifiedResult = simnet.callReadOnlyFn(
      "clarity-bitcoin",
      "is-job-verified",
      [Cl.buffer(Buffer.from(jobId.slice(2), "hex"))],
      deployer
    );
    expect(verifiedResult.result).toEqual(Cl.bool(true));
  });

  it("should fail verification if proof length is incorrect", () => {
    const jobId = "0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
    const stateRoot = "0x201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201";
    const shortProof = "0x" + "00".repeat(512);

    const result = simnet.callPublicFn(
      "clarity-bitcoin",
      "verify-labor-attestation",
      [Cl.buffer(Buffer.from(jobId.slice(2), "hex")), Cl.buffer(Buffer.from(stateRoot.slice(2), "hex")), Cl.buffer(Buffer.from(shortProof.slice(2), "hex"))],
      deployer
    );

    expect(result.result).toEqual(Cl.error(Cl.uint(9000)));
  });
});
