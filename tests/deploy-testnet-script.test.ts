// @vitest-environment node
import { readFileSync } from "node:fs";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  DEPLOYMENT_SCOPE,
  DEPLOYMENT_SEQUENCE,
  DEPLOYMENT_TRANSACTION_POLICY,
  DeploymentPreflightError,
  getJson,
  preflightTargetContracts,
} from "../scripts/deploy-testnet";
import { PostConditionMode } from "@stacks/transactions";

const helperSource = readFileSync(new URL("../scripts/deploy-testnet.ts", import.meta.url), "utf8");

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("testnet deployment helper", () => {
  it("uses the repository revenue-automation path", () => {
    expect(DEPLOYMENT_SEQUENCE.find((contract) => contract.name === "revenue-automation")?.path).toBe(
      "contracts/treasury/revenue-automation.clar",
    );
  });

  it("uses deny-mode post conditions", () => {
    expect(DEPLOYMENT_TRANSACTION_POLICY.postConditionMode).toBe(PostConditionMode.Deny);
  });

  it("is explicitly bounded to preparatory testnet work", () => {
    expect(DEPLOYMENT_SCOPE).toBe("testnet-helper-preparatory-only");
    expect(helperSource).toContain("not the full-system");
    expect(helperSource).toContain("or partnership deployer");
    expect(helperSource).toContain('requiredEnvironment("DEPLOYMENT_PLAN_PATH")');
    expect(helperSource).toContain("matching");
  });

  it("retains only a broadcast/partial candidate until complete verification", () => {
    expect(helperSource).toContain('evidenceStatus: "broadcast"');
    expect(helperSource).toContain('coverage: "partial"');
    expect(helperSource).toContain("writeBroadcastCandidate();");
    expect(helperSource).toContain("} finally {");
    expect(helperSource).not.toContain('evidenceStatus: "confirmed"');
    expect(helperSource).not.toContain('coverage: "complete"');
  });

  it("aborts the bounded preflight when any target already exists", async () => {
    const checked: string[] = [];
    await expect(
      preflightTargetContracts("ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P", async (_address, name) => {
        checked.push(name);
        return name === DEPLOYMENT_SEQUENCE[3].name;
      }),
    ).rejects.toMatchObject({
      code: "PREEXISTING_CONTRACT",
      contractIds: [`ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P.${DEPLOYMENT_SEQUENCE[3].name}`],
    } satisfies Partial<DeploymentPreflightError>);
    expect(checked).toHaveLength(DEPLOYMENT_SEQUENCE.length);
    expect(helperSource).toContain("await preflightTargetContracts(deployerAddress)");
    expect(helperSource).toContain('throw new DeploymentPreflightError([contractId], "broadcast recheck")');
    expect(helperSource).toContain("independent original publish receipt and interface evidence is required");
  });

  it("times out a successful response whose JSON body never settles", async () => {
    vi.stubEnv("DEPLOY_API_TIMEOUT_MS", "1");
    let signal: AbortSignal | undefined;
    const fetcher = vi.fn(async (_url: string | Request | URL, init?: RequestInit) => {
      signal = init?.signal ?? undefined;
      return {
        status: 200,
        json: () => new Promise<unknown>(() => {}),
      } as Response;
    });

    await expect(getJson("https://provider.invalid/v2/info", fetcher)).rejects.toThrow("request timed out");
    expect(signal?.aborted).toBe(true);
  });
});
