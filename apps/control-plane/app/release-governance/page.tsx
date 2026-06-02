import { DataTable, StatusBadge } from "../../components/data-table";
import { PageHeader } from "../../components/page-header";
import { getCurrentActor, canApprove, canOperate } from "../../lib/auth";
import { getReleaseGovernanceData } from "../../lib/module-adapters";
import type { ReleaseArtifact } from "@conxian/schemas";
import { ReleaseApprovalForm } from "../../components/release-approval-form";
import { ReleaseDecisionForm } from "../../components/release-decision-form";

export default function ReleaseGovernancePage() {
  const actor = getCurrentActor();
  const artifacts = getReleaseGovernanceData();

  return (
    <main className="page-shell">
      <PageHeader
        eyebrow="Module"
        title="Release governance"
        description="Track release artifacts, approval state, and promotion readiness."
      />

      <section className="grid">
        <article className="card">
          <h3>Capabilities</h3>
          <ul>
            <li>Read access: enabled</li>
            <li>Request approval: {canOperate(actor.role) ? "enabled" : "not allowed"}</li>
            <li>Approve/reject: {canApprove(actor.role) ? "enabled" : "not allowed"}</li>
          </ul>
        </article>

        <ReleaseApprovalForm artifacts={artifacts} />
        <ReleaseDecisionForm artifacts={artifacts} />
      </section>

      <section className="card">
        <h3>Artifacts</h3>
        <DataTable<ReleaseArtifact>
          columns={[
            { key: "name", header: "Artifact", render: (item) => item.name },
            { key: "status", header: "Status", render: (item) => <StatusBadge value={item.status} /> },
            { key: "owner", header: "Owner", render: (item) => item.owner },
            { key: "updatedAt", header: "Updated", render: (item) => item.updatedAt },
          ]}
          rows={artifacts}
        />
      </section>
    </main>
  );
}