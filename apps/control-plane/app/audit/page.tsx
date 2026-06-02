import { DataTable } from "../../components/data-table";
import { PageHeader } from "../../components/page-header";
import { getAuditData } from "../../lib/module-adapters";
import type { AuditEvent } from "@conxian/schemas";

export default function AuditPage() {
  const events = getAuditData();

  return (
    <main className="page-shell">
      <PageHeader
        eyebrow="Module"
        title="Audit"
        description="Review operational evidence and auditable activity across workflows."
      />

      <section className="card">
        <h3>Events</h3>
        <DataTable<AuditEvent>
          columns={[
            { key: "category", header: "Category", render: (item) => item.category },
            { key: "summary", header: "Summary", render: (item) => item.summary },
            { key: "actor", header: "Actor", render: (item) => item.actor },
            { key: "timestamp", header: "Timestamp", render: (item) => item.timestamp },
          ]}
          rows={events}
        />
      </section>
    </main>
  );
}
