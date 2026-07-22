const contractNamePattern = /^\s*contract-name:\s+([a-z0-9-]+)\s*$/gm;

export const issue501Contracts = [
  "stacking-traits",
  "native-stacking-operator",
  "dual-stacking-orchestrator",
] as const;

export function contractNamesFromPlan(planText: string): string[] {
  return [...planText.matchAll(contractNamePattern)].map((match) => match[1]);
}

/**
* Validate only the runtime-plan compatibility needed by issue 501.
*
* The pinned Clarinet SDK can emit stale Clarity 1 metadata while generating
* the local plan, so version checks intentionally remain in the generator and
* deployment-plan regression tests rather than this SDK compatibility gate.
*/
export function validateIssue501RuntimePlan(planText: string): void {
  const names = contractNamesFromPlan(planText);
  const traitIndex = names.indexOf("stacking-traits");

  for (const contract of issue501Contracts) {
    if (names.indexOf(contract) < 0) {
      throw new Error(`SDK-generated runtime plan is missing issue-501 contract: ${contract}`);
    }
  }

  for (const consumer of ["native-stacking-operator", "dual-stacking-orchestrator"]) {
    const consumerIndex = names.indexOf(consumer);
    if (traitIndex >= consumerIndex) {
      throw new Error(
        `SDK-generated runtime plan orders stacking-traits after ${consumer}; issue-501 consumers require the trait first`,
      );
    }
  }
}
