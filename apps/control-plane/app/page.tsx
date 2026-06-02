import { OverviewCards } from "../components/overview-cards";
import { PageHeader } from "../components/page-header";
import { getAuditData, getPolicyApprovalData, getReleaseGovernanceData } from "../lib/module-adapters";

export default function HomePage() {
  const artifacts = getReleaseGovernanceData();
  const auditEvents = getAuditData();
  const governanceActions = getPolicyApprovalData();

  return (
    <main className="page-shell">
      <PageHeader
        eyebrow="Private BOS application"
        title="Overview"
        description="This app is the internal starting point for governance, audit, release, policy, and environment workflows across the Conxian stack."
      />

      <OverviewCards />

      <section className="grid two-up">
        <article className="card">
          <h3>Release artifacts</h3>
          <ul>
            {artifacts.map((artifact) => (
              <li key={artifact.id}>
                {artifact.name} — {artifact.status}
              </li>
            ))}
          </ul>
        </article>

        <article className="card">
          <h3>Audit events</h3>
          <ul>
            {auditEvents.map((event) => (
              <li key={event.id}>{event.summary}</li>
            ))}
          </ul>
        </article>
      </section>

      <section className="card">
        <h3>Policy actions</h3>
        <ul>
          {governanceActions.map((action) => (
            <li key={action.id}>
              {action.title} — {action.status}
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
