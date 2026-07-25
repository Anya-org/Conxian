// @vitest-environment node
import {
  cpSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { getAddressFromPrivateKey } from "@stacks/transactions";
import { afterEach, describe, expect, it } from "vitest";
import {
  evaluateUnsignedWithdrawalGate,
  expectedWithdrawalLock,
  validateRecipientTuple,
  validateOfficialNetworkMatrix,
  verifyEvidencePack,
} from "../scripts/sbtc-phase2/verify-evidence";

const fixtureRoots: string[] = [];
const UPSTREAM_COMMIT = "11567fc6a111c130177e64380503acca8546aab6";
const SYNTHETIC_PRIVATE_KEY = "11".repeat(32);
const SYNTHETIC_SOURCE_HASH = "ab".repeat(32);

function syntheticProvenance() {
  return {
    sourceUrl: `https://raw.githubusercontent.com/stacks-sbtc/sbtc/${UPSTREAM_COMMIT}/contracts/contracts/synthetic-test-only.clar`,
    sourceCommit: UPSTREAM_COMMIT,
    sourceSha256: SYNTHETIC_SOURCE_HASH,
  };
}

function completeSyntheticMatrix(network: "mainnet" | "testnet" = "testnet") {
  const address = getAddressFromPrivateKey(SYNTHETIC_PRIVATE_KEY, network);
  const verifiedAt = "2026-07-24T12:00:00Z";
  const contractCell = (id: string) => {
    const principal = `${address}.${id.replace("bootstrap-signers", "bootstrap-signers-test")}`;
    return {
      id,
      kind: "contract",
      principal,
      chainVerified: true,
      provenance: syntheticProvenance(),
      readBack: { principal, sourceHash: SYNTHETIC_SOURCE_HASH },
      verifiedAt,
    };
  };
  return {
    schemaVersion: "1",
    targetNetwork: network,
    upstreamRelease: "v1.3.3",
    upstreamCommit: UPSTREAM_COMMIT,
    requiredEvidence: [
      contractCell("token"),
      contractCell("registry"),
      contractCell("deposit"),
      contractCell("withdrawal"),
      contractCell("bootstrap-signers"),
      {
        id: "signer-state",
        kind: "state",
        value: "synthetic-test-only-read-back",
        chainVerified: true,
        provenance: syntheticProvenance(),
        readBack: {
          value: "synthetic-test-only-read-back",
          sourceHash: SYNTHETIC_SOURCE_HASH,
        },
        verifiedAt,
      },
      {
        id: "emily",
        kind: "service",
        endpoint: "https://synthetic.invalid/emily",
        version: "0.1.0-test",
        liveVerified: true,
        schemaEvidence: syntheticProvenance(),
        verifiedAt,
      },
    ],
  };
}

function isolatedEvidence(): string {
  const root = mkdtempSync(join(tmpdir(), "conxian-sbtc-phase2-"));
  fixtureRoots.push(root);
  cpSync("evidence", join(root, "evidence"), { recursive: true });
  return root;
}

function updateJson(
  root: string,
  relativePath: string,
  mutate: (value: any) => void,
): void {
  const path = join(root, relativePath);
  const value = JSON.parse(readFileSync(path, "utf8"));
  mutate(value);
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

afterEach(() => {
  for (const root of fixtureRoots.splice(0))
    rmSync(root, { recursive: true, force: true });
});

describe("Phase 2 sBTC evidence harness", () => {
  it("grants GO only to the pinned offline snapshot and remains NO-GO elsewhere", () => {
    const decision = verifyEvidencePack();

    expect(decision.offlineSnapshot).toBe("GO");
    expect(decision.officialNetworkIntegration).toBe("NO-GO");
    expect(decision.bitcoinSettlementClaim).toBe("NO-GO");
    expect(
      decision.reasons.some(
        (reason) => reason.code === "TARGET_NETWORK_UNSUPPORTED",
      ),
    ).toBe(true);
    expect(
      decision.reasons.some(
        (reason) => reason.code === "MATRIX_CONTRACT_PRINCIPAL_INVALID",
      ),
    ).toBe(true);
    expect(
      decision.reasons.some(
        (reason) => reason.code === "OFFLINE_HARNESS_CANNOT_PROVE_SETTLEMENT",
      ),
    ).toBe(true);
  });

  it("rejects the original boolean-only verification bypass", () => {
    const matrix = completeSyntheticMatrix("mainnet") as any;
    matrix.requiredEvidence = matrix.requiredEvidence.map((cell: any) => ({
      id: cell.id,
      kind: cell.kind,
      ...(cell.kind === "service"
        ? { liveVerified: true }
        : { chainVerified: true }),
    }));

    const reasons = validateOfficialNetworkMatrix(matrix);
    expect(reasons.map((reason) => reason.code)).toEqual(
      expect.arrayContaining([
        "MATRIX_CONTRACT_PRINCIPAL_INVALID",
        "MATRIX_PROVENANCE_MISSING",
        "MATRIX_READ_BACK_MISSING",
        "MATRIX_VERIFICATION_TIMESTAMP_INVALID",
        "SIGNER_STATE_VALUE_MISSING",
        "EMILY_ENDPOINT_INVALID",
        "EMILY_VERSION_MISSING",
      ]),
    );
  });

  it.each(["", "unresolved", "devnet", "arbitrary-network", null])(
    "rejects unsupported target network %j",
    (targetNetwork) => {
      const matrix = completeSyntheticMatrix() as any;
      matrix.targetNetwork = targetNetwork;
      expect(
        validateOfficialNetworkMatrix(matrix).some(
          (reason) => reason.code === "TARGET_NETWORK_UNSUPPORTED",
        ),
      ).toBe(true);
    },
  );

  it("rejects an unsupported matrix schema version", () => {
    const matrix = completeSyntheticMatrix() as any;
    matrix.schemaVersion = "2";

    expect(
      validateOfficialNetworkMatrix(matrix).some(
        (reason) => reason.code === "MATRIX_SCHEMA_VERSION_UNSUPPORTED",
      ),
    ).toBe(true);
  });

  it("rejects wrong-kind required cells before their verification flags are considered", () => {
    const matrix = completeSyntheticMatrix() as any;
    matrix.requiredEvidence.find((cell: any) => cell.id === "token").kind =
      "service";

    const reasons = validateOfficialNetworkMatrix(matrix);
    expect(reasons).toContainEqual(
      expect.objectContaining({
        code: "MATRIX_CELL_KIND_INVALID",
        message: expect.stringContaining("token.kind"),
      }),
    );
  });

  it("rejects missing, duplicate, and unexpected required cells", () => {
    const matrix = completeSyntheticMatrix() as any;
    const token = matrix.requiredEvidence.find(
      (cell: any) => cell.id === "token",
    );
    matrix.requiredEvidence = matrix.requiredEvidence.filter(
      (cell: any) => cell.id !== "registry",
    );
    matrix.requiredEvidence.push(
      { ...token },
      { id: "extra", kind: "contract" },
    );

    const codes = validateOfficialNetworkMatrix(matrix).map(
      (reason) => reason.code,
    );
    expect(codes).toEqual(
      expect.arrayContaining([
        "MATRIX_CELL_MISSING",
        "MATRIX_CELL_DUPLICATE",
        "MATRIX_CELL_UNEXPECTED",
      ]),
    );
  });

  it.each([
    ["principal", "MATRIX_CONTRACT_PRINCIPAL_INVALID"],
    ["readBack", "MATRIX_READ_BACK_MISSING"],
    ["sourceHash", "MATRIX_READ_BACK_INVALID"],
    ["verifiedAt", "MATRIX_VERIFICATION_TIMESTAMP_INVALID"],
  ])("rejects a contract cell missing %s", (field, expectedCode) => {
    const matrix = completeSyntheticMatrix() as any;
    const token = matrix.requiredEvidence.find(
      (cell: any) => cell.id === "token",
    );
    if (field === "sourceHash") delete token.readBack.sourceHash;
    else delete token[field];

    expect(
      validateOfficialNetworkMatrix(matrix).some(
        (reason) => reason.code === expectedCode,
      ),
    ).toBe(true);
  });

  it("rejects incomplete signer-state read-back and provenance", () => {
    const matrix = completeSyntheticMatrix() as any;
    const signerState = matrix.requiredEvidence.find(
      (cell: any) => cell.id === "signer-state",
    );
    signerState.value = "unresolved";
    delete signerState.readBack.value;
    delete signerState.provenance.sourceUrl;

    const codes = validateOfficialNetworkMatrix(matrix).map(
      (reason) => reason.code,
    );
    expect(codes).toEqual(
      expect.arrayContaining([
        "SIGNER_STATE_VALUE_MISSING",
        "SIGNER_STATE_READ_BACK_INVALID",
        "MATRIX_PROVENANCE_INVALID",
      ]),
    );
  });

  it.each([
    ["endpoint", "EMILY_ENDPOINT_INVALID"],
    ["version", "EMILY_VERSION_MISSING"],
    ["schemaEvidence", "MATRIX_PROVENANCE_MISSING"],
  ])("rejects Emily evidence missing %s", (field, expectedCode) => {
    const matrix = completeSyntheticMatrix() as any;
    const emily = matrix.requiredEvidence.find(
      (cell: any) => cell.id === "emily",
    );
    delete emily[field];

    expect(
      validateOfficialNetworkMatrix(matrix).some(
        (reason) => reason.code === expectedCode,
      ),
    ).toBe(true);
  });

  it("allows a structurally complete synthetic matrix through only the official-network gate", () => {
    expect(validateOfficialNetworkMatrix(completeSyntheticMatrix())).toEqual(
      [],
    );

    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/target-network-matrix.json",
      (matrix) => {
        const synthetic = completeSyntheticMatrix();
        matrix.targetNetwork = synthetic.targetNetwork;
        matrix.requiredEvidence = synthetic.requiredEvidence;
      },
    );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.offlineSnapshot).toBe("GO");
    expect(decision.officialNetworkIntegration).toBe("GO");
    expect(decision.bitcoinSettlementClaim).toBe("NO-GO");
    expect(
      decision.reasons.some(
        (reason) => reason.code === "OFFLINE_HARNESS_CANNOT_PROVE_SETTLEMENT",
      ),
    ).toBe(true);
  });

  it("fails closed on floating or missing upstream pins", () => {
    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/manifest.json",
      (manifest) => {
      manifest.upstream.release = "main";
      manifest.upstream.commit = "11567fc6";
      },
    );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.offlineSnapshot).toBe("NO-GO");
    expect(decision.reasons.map((reason) => reason.code)).toEqual(
      expect.arrayContaining([
        "FLOATING_UPSTREAM_RELEASE",
        "MISSING_IMMUTABLE_COMMIT",
      ]),
    );
  });

  it("rejects an alternate valid-looking release and full commit", () => {
    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/manifest.json",
      (manifest) => {
      manifest.upstream.release = "v9.9.9";
      manifest.upstream.commit = "a".repeat(40);
      for (const artifact of manifest.artifacts) {
        artifact.sourceUrl = artifact.sourceUrl.replace(
          "11567fc6a111c130177e64380503acca8546aab6",
          "a".repeat(40),
        );
      }
      },
    );
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/target-network-matrix.json",
      (matrix) => {
      matrix.upstreamRelease = "v9.9.9";
      matrix.upstreamCommit = "a".repeat(40);
      },
    );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.offlineSnapshot).toBe("NO-GO");
    expect(decision.reasons.map((reason) => reason.code)).toEqual(
      expect.arrayContaining([
        "UNEXPECTED_UPSTREAM_PIN",
        "ARTIFACT_PROVENANCE_MISMATCH",
      ]),
    );
  });

  it("fails closed on snapshot hash mismatches", () => {
    const root = isolatedEvidence();
    const withdrawal = join(
      root,
      "evidence/sbtc/phase2/v1.3.3/sources/sbtc-withdrawal.clar",
    );
    writeFileSync(
      withdrawal,
      `${readFileSync(withdrawal, "utf8")}\n;; tampered\n`,
      "utf8",
    );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.offlineSnapshot).toBe("NO-GO");
    expect(
      decision.reasons.some(
        (reason) => reason.code === "ARTIFACT_HASH_MISMATCH",
      ),
    ).toBe(true);
  });

  it("requires withdrawal ABI, registry, and public Emily evidence", () => {
    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/manifest.json",
      (manifest) => {
      manifest.artifacts = manifest.artifacts.filter(
          (artifact: { kind: string }) =>
            artifact.kind !== "withdrawal-contract" &&
            artifact.kind !== "emily-public-openapi",
        );
      },
      );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.offlineSnapshot).toBe("NO-GO");
    expect(
      decision.reasons.filter(
        (reason) => reason.code === "REQUIRED_ARTIFACT_MISSING",
      ),
    ).toHaveLength(2);
  });

  it("returns structured NO-GO when a required source file is unreadable", () => {
    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/manifest.json",
      (manifest) => {
      const withdrawal = manifest.artifacts.find(
          (artifact: { kind: string }) =>
            artifact.kind === "withdrawal-contract",
        );
        withdrawal.path =
          "evidence/sbtc/phase2/v1.3.3/sources/missing-withdrawal.clar";
      },
      );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.offlineSnapshot).toBe("NO-GO");
    expect(decision.reasons.map((reason) => reason.code)).toEqual(
      expect.arrayContaining([
        "ARTIFACT_PROVENANCE_MISMATCH",
        "ARTIFACT_MISSING",
        "WITHDRAWAL_ABI_EVIDENCE_UNREADABLE",
      ]),
    );
  });

  it("requires complete recipient-vector boundary coverage", () => {
    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/recipient-vectors.json",
      (document) => {
        document.vectors = document.vectors.filter(
          (vector: { version: number; valid: boolean }) => {
        return vector.version === 0 && vector.valid === true;
          },
        );
      },
    );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.offlineSnapshot).toBe("NO-GO");
    expect(
      decision.reasons.some(
        (reason) => reason.code === "RECIPIENT_VECTOR_COVERAGE_MISSING",
      ),
    ).toBe(true);
  });

  it("keeps registry and Emily states separate", () => {
    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/target-network-matrix.json",
      (matrix) => {
        matrix.stateModels.registryWithdrawal =
          matrix.stateModels.emilyWithdrawal;
      },
    );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.officialNetworkIntegration).toBe("NO-GO");
    expect(
      decision.reasons.some(
        (reason) => reason.code === "REGISTRY_STATES_INVALID",
      ),
    ).toBe(true);
  });

  it("rejects any sole-proof settlement claim, including Emily confirmed", () => {
    const root = isolatedEvidence();
    updateJson(
      root,
      "evidence/sbtc/phase2/v1.3.3/target-network-matrix.json",
      (matrix) => {
      matrix.settlementClaims.emilyStatusAlone = true;
      },
    );

    const decision = verifyEvidencePack({ rootDir: root });
    expect(decision.bitcoinSettlementClaim).toBe("NO-GO");
    expect(
      decision.reasons.some(
        (reason) => reason.code === "PROHIBITED_SOLE_SETTLEMENT_PROOF",
      ),
    ).toBe(true);
  });
});

describe("withdrawal recipient tuple vectors", () => {
  for (const version of [0, 1, 2, 3, 4]) {
    it(`accepts version 0x${version.toString(16).padStart(2, "0")} only with 20 bytes`, () => {
      expect(
        validateRecipientTuple({ version, hashbytes: "ab".repeat(20) }),
      ).toBe(true);
      expect(
        validateRecipientTuple({ version, hashbytes: "ab".repeat(32) }),
      ).toBe(false);
    });
  }

  for (const version of [5, 6]) {
    it(`accepts version 0x${version.toString(16).padStart(2, "0")} only with 32 bytes`, () => {
      expect(
        validateRecipientTuple({ version, hashbytes: "cd".repeat(32) }),
      ).toBe(true);
      expect(
        validateRecipientTuple({ version, hashbytes: "cd".repeat(20) }),
      ).toBe(false);
    });
  }

  it("rejects unsupported versions and malformed tuple bytes without parsing address strings", () => {
    expect(
      validateRecipientTuple({ version: 7, hashbytes: "ef".repeat(32) }),
    ).toBe(false);
    expect(
      validateRecipientTuple({ version: 4, hashbytes: "not-an-address" }),
    ).toBe(false);
  });
});

describe("unsigned withdrawal construction gate", () => {
  it("preserves amount + maxFee semantics but blocks construction while principals are unresolved", () => {
    expect(expectedWithdrawalLock(50_000n, 2_500n)).toBe(52_500n);

    const result = evaluateUnsignedWithdrawalGate({
      amount: 50_000n,
      maxFee: 2_500n,
      recipient: { version: 6, hashbytes: "12".repeat(32) },
      token: { principal: "unresolved", chainVerified: false },
      withdrawal: { principal: "unresolved", chainVerified: false },
    });

    expect(result.allowed).toBe(false);
    expect(result.lockedAmount).toBe(52_500n);
    expect(result.reviewOnlyIntent).toEqual({
      amount: 50_000n,
      maxFee: 2_500n,
      recipient: { version: 6, hashbytes: "12".repeat(32) },
      tokenDebit: "amount-plus-max-fee",
    });
    expect(result.reasons).toEqual([
      "TOKEN_PRINCIPAL_NOT_CHAIN_VERIFIED",
      "WITHDRAWAL_PRINCIPAL_NOT_CHAIN_VERIFIED",
    ]);
  });

  it("does not fabricate transaction bytes even after the evidence gate shape is satisfied", () => {
    const result = evaluateUnsignedWithdrawalGate({
      amount: 50_000n,
      maxFee: 2_500n,
      recipient: { version: 4, hashbytes: "34".repeat(20) },
      token: { principal: "chain-verified-by-caller", chainVerified: true },
      withdrawal: {
        principal: "chain-verified-by-caller",
        chainVerified: true,
      },
    });

    expect(result.allowed).toBe(false);
    expect(result.reasons).toEqual([
      "UNSIGNED_TRANSACTION_BUILDER_INTENTIONALLY_NOT_IMPLEMENTED",
    ]);
    expect(result).not.toHaveProperty("transactionBytes");
  });
});
