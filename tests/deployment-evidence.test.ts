// @vitest-environment node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import {
  createHiroApi,
  type DeploymentEvidenceManifest,
  type FetchInitLike,
  type FetchLike,
  isCanonicalStacksAddress,
  validateEvidenceBinding,
  validateManifest,
  verifyDeploymentEvidence,
} from "../scripts/verify-deployment-evidence";

const deployer = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P";
const mainnetDeployer = "SP000000000000000000002Q6VF78";
const alternateDeployer = `ST${"1".repeat(39)}`;
const contractName = "example-contract";
const principal = `${deployer}.${contractName}`;
const txId = `0x${"a".repeat(64)}`;
const blockHash = `0x${"b".repeat(64)}`;
const baseUrl = "https://api.testnet.hiro.so";
const gitCommit = "c".repeat(40);
const planSha256 = "d".repeat(64);

type MockRoute = {
  status: number;
  body?: unknown;
};

function baseManifest(): DeploymentEvidenceManifest {
  return {
    schemaVersion: "1.0.0",
    network: "testnet",
    apiBaseUrl: baseUrl,
    deployer,
    evidence: {
      source: "confirmed-receipts",
      capturedAt: "2026-07-22T00:00:00Z",
      gitCommit,
      planPath: "deployments/full-system.testnet-plan.yaml",
      planSha256,
    },
    contracts: [
      {
        name: contractName,
        principal,
        publishTxId: txId,
        interface: {
          required: true,
          expectedContractName: contractName,
          expectedFunctions: ["get-version"],
        },
        readOnlyChecks: [
          {
            function: "get-version",
            sender: deployer,
            arguments: [],
            expectedResultHex: "0x0701",
          },
        ],
      },
    ],
  };
}

function pathForTransaction(id = txId): string {
  return `/extended/v1/tx/${encodeURIComponent(id)}`;
}

function pathForInterface(contractPrincipal = principal): string {
  return `/extended/v1/contract/${encodeURIComponent(contractPrincipal)}/interface`;
}

function pathForReadOnly(contractPrincipal = principal, functionName = "get-version"): string {
  return `/v2/contracts/call-read/${encodeURIComponent(contractPrincipal)}/${encodeURIComponent(functionName)}`;
}

function mockFetch(routes: Record<string, MockRoute>, calls: Array<{ url: string; init?: FetchInitLike }>): FetchLike {
  return async (url, init) => {
    calls.push({ url, init });
    const key = `${init?.method ?? "GET"} ${new URL(url).pathname}`;
    const route = routes[key];
    if (!route) {
      return {
        status: 404,
        ok: false,
        json: async () => ({ error: "unconfigured route" }),
      };
    }
    return {
      status: route.status,
      ok: route.status >= 200 && route.status < 300,
      json: async () => route.body,
    };
  };
}

function defaultRoutes(manifest = baseManifest()): Record<string, MockRoute> {
  const contract = manifest.contracts[0];
  return {
    [`GET ${pathForTransaction(contract.publishTxId)}`]: {
      status: 200,
      body: {
        tx_id: contract.publishTxId,
        tx_status: "success",
        tx_type: "smart_contract",
        sender_address: manifest.deployer,
        smart_contract: {
          contract_id: contract.principal,
        },
        canonical: true,
        block_hash: blockHash,
        block_height: 123,
      },
    },
    [`GET ${pathForInterface(contract.principal)}`]: {
      status: 200,
      body: {
        contract_id: contract.principal,
        functions: [{ name: "get-version" }],
      },
    },
    [`POST ${pathForReadOnly(contract.principal)}`]: {
      status: 200,
      body: {
        okay: true,
        result: "0x0701",
      },
    },
  };
}

async function verifyWith(
  manifest: DeploymentEvidenceManifest,
  routes: Record<string, MockRoute> = defaultRoutes(manifest),
  calls: Array<{ url: string; init?: FetchInitLike }> = [],
) {
  const api = createHiroApi({
    baseUrl: manifest.apiBaseUrl,
    fetchImpl: mockFetch(routes, calls),
  });
  return verifyDeploymentEvidence(manifest, api);
}

function classifications(report: Awaited<ReturnType<typeof verifyWith>>): string[] {
  return report.failures.map((entry) => entry.classification);
}

describe("deployment evidence verifier", () => {
  it("accepts a confirmed canonical publish, interface, and read-only result", async () => {
    const calls: Array<{ url: string; init?: FetchInitLike }> = [];
    const report = await verifyWith(baseManifest(), defaultRoutes(), calls);

    expect(report.ok).toBe(true);
    expect(report.claim).toBe("declared evidence entries verified");
    expect(report.failures).toEqual([]);
    expect(report.contracts[0]?.transaction?.canonical).toBe(true);
    expect(report.contracts[0]?.contractInterface?.available).toBe(true);
    expect(report.contracts[0]?.readOnlyChecks[0]?.actualResultHex).toBe("0x0701");
    expect(calls).toHaveLength(3);
    expect(calls[2]?.init?.method).toBe("POST");
    expect(calls[2]?.init?.body).toBe(JSON.stringify({ sender: deployer, arguments: [] }));
  });

  it.each([
    ["pending", "transaction-pending"],
    ["abort_by_response", "transaction-failed"],
  ] as const)("rejects a %s publish transaction", async (status, expectedClassification) => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForTransaction()}`] = {
      status: 200,
      body: {
        ...(defaultRoutes(manifest)[`GET ${pathForTransaction()}`]?.body as object),
        tx_status: status,
      },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain(expectedClassification);
  });

  it("rejects a successful transaction that is not canonical", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForTransaction()}`] = {
      status: 200,
      body: {
        ...(routes[`GET ${pathForTransaction()}`]?.body as object),
        canonical: false,
      },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("transaction-noncanonical");
  });

  it("classifies a missing transaction without making a global nonexistence claim", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForTransaction()}`] = {
      status: 404,
      body: { error: "not found" },
    };

    const report = await verifyWith(manifest, routes);
    const missing = report.failures.find((entry) => entry.classification === "missing-transaction");

    expect(report.ok).toBe(false);
    expect(missing?.message).toContain("documented transaction ID");
    expect(missing?.message).toContain("not a claim of global nonexistence");
  });

  it("rejects a network mismatch before making API calls", async () => {
    const manifest = baseManifest();
    manifest.network = "mainnet";
    const report = await verifyWith(manifest);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("network-mismatch");
  });

  it("validates Stacks checksum, canonical encoding, and network address version", () => {
    expect(isCanonicalStacksAddress(deployer, "testnet")).toBe(true);
    expect(isCanonicalStacksAddress(mainnetDeployer, "mainnet")).toBe(true);
    expect(isCanonicalStacksAddress(`${deployer.slice(0, -1)}Q`, "testnet")).toBe(false);
    expect(isCanonicalStacksAddress(deployer, "mainnet")).toBe(false);
    expect(isCanonicalStacksAddress(mainnetDeployer, "testnet")).toBe(false);
    expect(isCanonicalStacksAddress(deployer.toLowerCase(), "testnet")).toBe(false);
  });

  it.each([
    ["trailing slash API URL", (manifest: DeploymentEvidenceManifest) => {
      manifest.apiBaseUrl = `${baseUrl}/`;
    }],
    ["date-only timestamp", (manifest: DeploymentEvidenceManifest) => {
      manifest.evidence.capturedAt = "2026-07-22";
    }],
    ["empty plan path", (manifest: DeploymentEvidenceManifest) => {
      manifest.evidence.planPath = "";
    }],
    ["empty Clarity argument", (manifest: DeploymentEvidenceManifest) => {
      manifest.contracts[0]!.readOnlyChecks![0]!.arguments = ["0x"];
    }],
    ["duplicate expected function", (manifest: DeploymentEvidenceManifest) => {
      manifest.contracts[0]!.interface.expectedFunctions = ["get-version", "get-version"];
    }],
  ])("rejects schema/runtime drift: %s", (_name, mutate) => {
    const manifest = baseManifest();
    mutate(manifest);

    const validation = validateManifest(manifest);

    expect(validation.ok).toBe(false);
    expect(validation.failures.some((entry) => entry.classification === "malformed-manifest" || entry.classification === "network-mismatch")).toBe(true);
  });

  it("rejects a checksum-invalid manifest deployer and principal", () => {
    const manifest = baseManifest();
    const invalidAddress = `${deployer.slice(0, -1)}Q`;
    manifest.deployer = invalidAddress;
    manifest.contracts[0]!.principal = `${invalidAddress}.${contractName}`;
    manifest.contracts[0]!.readOnlyChecks![0]!.sender = invalidAddress;

    const validation = validateManifest(manifest);

    expect(validation.ok).toBe(false);
    expect(validation.failures.filter((entry) => entry.scope.includes("deployer") || entry.scope.includes("principal") || entry.scope.includes("sender")).length).toBeGreaterThan(0);
  });

  it("rejects a testnet address set on a mainnet manifest", () => {
    const manifest = baseManifest();
    manifest.network = "mainnet";
    manifest.apiBaseUrl = "https://api.mainnet.hiro.so";

    const validation = validateManifest(manifest);

    expect(validation.ok).toBe(false);
    expect(validation.failures.some((entry) => entry.scope === "deployer")).toBe(true);
  });

  it("rejects a cross-network read-only sender", () => {
    const manifest = baseManifest();
    manifest.contracts[0]!.readOnlyChecks![0]!.sender = mainnetDeployer;

    const validation = validateManifest(manifest);

    expect(validation.ok).toBe(false);
    expect(validation.failures.some((entry) => entry.scope.endsWith("sender"))).toBe(true);
  });

  it("rejects a publish transaction from the wrong deployer", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForTransaction()}`] = {
      status: 200,
      body: {
        ...(routes[`GET ${pathForTransaction()}`]?.body as object),
        sender_address: alternateDeployer,
      },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("deployer-mismatch");
  });

  it("rejects a publish transaction for the wrong exact contract principal", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForTransaction()}`] = {
      status: 200,
      body: {
        ...(routes[`GET ${pathForTransaction()}`]?.body as object),
        smart_contract: {
          contract_id: `${deployer}.different-contract`,
        },
      },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("contract-mismatch");
  });

  it("rejects a missing interface at the documented address without claiming global nonexistence", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForInterface()}`] = {
      status: 404,
      body: { error: "not found" },
    };

    const report = await verifyWith(manifest, routes);
    const missing = report.failures.find((entry) => entry.classification === "interface-missing");

    expect(report.ok).toBe(false);
    expect(missing?.message).toContain("documented contract address");
    expect(missing?.message).toContain("not a claim of global nonexistence");
  });

  it("rejects an interface response that omits contract_id", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForInterface()}`] = {
      status: 200,
      body: { functions: [{ name: "get-version" }] },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("interface-mismatch");
  });

  it("rejects an interface response with a mismatched contract_id", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForInterface()}`] = {
      status: 200,
      body: {
        contract_id: `${deployer}.different-contract`,
        functions: [{ name: "get-version" }],
      },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("interface-mismatch");
  });

  it.each([
    ["short", "0x00"],
    ["nonhex", `0x${"g".repeat(64)}`],
    ["missing prefix", "b".repeat(64)],
    ["too long", `0x${"b".repeat(66)}`],
    ["uppercase Hiro-incompatible", `0x${"B".repeat(64)}`],
  ] as const)("rejects a %s block hash", async (_label, malformedBlockHash) => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForTransaction()}`] = {
      status: 200,
      body: {
        ...(routes[`GET ${pathForTransaction()}`]?.body as object),
        block_hash: malformedBlockHash,
      },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("transaction-unconfirmed");
  });

  it("rejects malformed or broadcast-only evidence", async () => {
    const manifest = baseManifest() as unknown as Record<string, unknown>;
    manifest.evidence = {
      source: "broadcast-only",
      capturedAt: "2026-07-22T00:00:00Z",
    };

    const report = await verifyDeploymentEvidence(manifest, {
      getTransaction: async () => ({ status: null, ok: false }),
      getContractInterface: async () => ({ status: null, ok: false }),
      callReadOnly: async () => ({ status: null, ok: false }),
    });

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("malformed-manifest");
  });

  it("rejects a read-only result mismatch", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`POST ${pathForReadOnly()}`] = {
      status: 200,
      body: {
        okay: true,
        result: "0x0702",
      },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("read-only-mismatch");
  });

  it("classifies a Hiro API failure separately from missing evidence", async () => {
    const manifest = baseManifest();
    const routes = defaultRoutes(manifest);
    routes[`GET ${pathForTransaction()}`] = {
      status: 503,
      body: { error: "temporarily unavailable" },
    };

    const report = await verifyWith(manifest, routes);

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("transaction-api-error");
    expect(classifications(report)).not.toContain("missing-transaction");
  });

  it("turns thrown injected API errors into fail-closed reports without leaking details", async () => {
    const secret = "super-secret-api-key";
    const report = await verifyDeploymentEvidence(baseManifest(), {
      getTransaction: async () => {
        throw new Error(`injected failure ${secret}`);
      },
      getContractInterface: async () => {
        throw new Error(`injected failure ${secret}`);
      },
      callReadOnly: async () => {
        throw new Error(`injected failure ${secret}`);
      },
    });

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("transaction-api-error");
    expect(JSON.stringify(report)).not.toContain(secret);
  });

  it("aborts stalled Hiro requests and returns a timeout result", async () => {
    let signal: AbortSignal | undefined;
    const api = createHiroApi({
      baseUrl,
      timeoutMs: 10,
      fetchImpl: async (_url, init) => {
        signal = init?.signal;
        await new Promise(() => undefined);
        return {
          status: 200,
          ok: true,
          json: async () => ({}),
        };
      },
    });

    const result = await api.getTransaction(txId);

    expect(result.error).toBe("timeout");
    expect(signal?.aborted).toBe(true);
  });

  it("requires an exact verification binding before querying Hiro", async () => {
    const manifest = baseManifest();
    const calls: Array<{ url: string; init?: FetchInitLike }> = [];
    const report = await verifyDeploymentEvidence(
      manifest,
      createHiroApi({ baseUrl, fetchImpl: mockFetch(defaultRoutes(manifest), calls) }),
      {
        network: "testnet",
        deployer,
        gitCommit: "e".repeat(40),
        planPath: manifest.evidence.planPath,
        planSha256: manifest.evidence.planSha256,
      },
    );

    expect(report.ok).toBe(false);
    expect(classifications(report)).toContain("evidence-binding-mismatch");
    expect(calls).toHaveLength(0);
  });

  it("accepts only an exact evidence binding", () => {
    const manifest = baseManifest();

    expect(
      validateEvidenceBinding(manifest, {
        network: "testnet",
        deployer,
        gitCommit,
        planPath: manifest.evidence.planPath,
        planSha256,
      }),
    ).toEqual([]);
  });

  it("accepts the versioned example shape without treating it as live evidence", () => {
    const examplePath = resolve("deployment/evidence/examples/testnet.example.json");
    const example = JSON.parse(readFileSync(examplePath, "utf8")) as unknown;
    const validation = validateManifest(example);

    expect(validation.ok).toBe(true);
    expect(validation.manifest?.network).toBe("testnet");
    expect(validation.manifest?.evidence.source).toBe("confirmed-receipts");
  });
});
