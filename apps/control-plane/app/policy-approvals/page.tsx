import { DataTable, StatusBadge } from "../../components/data-table";
import { PageHeader } from "../../components/page-header";
import { getCurrentActor, canApprove } from "../../lib/auth";
import { getPolicyApprovalData } from "../../lib/module-adapters";
import type { GovernanceAction } from "@conxian/schemas";
import { GovernanceDecisionForm } from "../../components/governance-decision-form";

export default function PolicyApprovalsPage() {
  const actor = getCurrentActor();
  const actions = getPolicyApprovalData();

  return (
    <main className="page-shell">
      <PageHeader
        eyebrow="Module"
        title="Policy approvals"
        description="Review pending governance and policy actions before execution."
      />

      <section className="grid">
        <article className="card">
          <h3>Approval gate</h3>
          <p>{canApprove(actor.role) ? "This actor can approve or reject actions." : "This actor can review but not approve actions."}</p>
        </article>

        <GovernanceDecisionForm actions={actions} />
      </section>

      <section className="card">
        <h3>Queue</h3>
        <DataTable<GovernanceAction>
          columns={[
            { key: "title", header: "Action", render: (item) => item.title },
            { key: "status", header: "Status", render: (item) => <StatusBadge value={item.status} /> },
            { key: "owner", header: "Owner", render: (item) => item.owner },
            { key: "updatedAt", header: "Updated", render: (item) => item.updatedAt },
          ]}
          rows={actions}
        />
      </section>
    </main>
  );
}
