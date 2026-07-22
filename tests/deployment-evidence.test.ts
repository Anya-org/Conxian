// @vitest-environment node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import {
  createHiroApi,
  type DeploymentEvidenceManifest,
  type FetchInitLike,
  type FetchLike,
  validateManifest,
  verifyDeploymentEvidence,
} from "../scripts/verify-deployment-evidence";

const deployer = "ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P";
const alternateDeployer = `ST${"1".repeat(39)}`;
const contractName = "example-contract";
const principal = `${deployer}.${contractName}`;
const txId = `0x${"a".repeat(64)}`;
const blockHash = `0x${"b".repeat(64)}`;
const baseUrl = "https://api.testnet.hiro.so";

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
      planPath: "deployments/full-system.testnet-plan.yaml",
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

  it("accepts the versioned example shape without treating it as live evidence", () => {
    const examplePath = resolve("deployment/evidence/examples/testnet.example.json");
    const example = JSON.parse(readFileSync(examplePath, "utf8")) as unknown;
    const validation = validateManifest(example);

    expect(validation.ok).toBe(true);
    expect(validation.manifest?.network).toBe("testnet");
    expect(validation.manifest?.evidence.source).toBe("confirmed-receipts");
  });
});
