import { DataTable, StatusBadge } from "../../components/data-table";
import { PageHeader } from "../../components/page-header";
import { getEnvironmentData } from "../../lib/module-adapters";
import type { EnvironmentRecord } from "@conxian/schemas";

export default function EnvironmentsPage() {
  const environments = getEnvironmentData();

  return (
    <main className="page-shell">
      <PageHeader
        eyebrow="Module"
        title="Environments"
        description="Track environment ownership, classification, and verification state."
      />

      <section className="card">
        <h3>Registry</h3>
        <DataTable<EnvironmentRecord>
          columns={[
            { key: "name", header: "Environment", render: (item) => item.name },
            { key: "classification", header: "Classification", render: (item) => item.classification },
            { key: "owner", header: "Owner", render: (item) => item.owner },
            {
              key: "verificationStatus",
              header: "Verification",
              render: (item) => <StatusBadge value={item.verificationStatus} />,
            },
          ]}
          rows={environments}
        />
      </section>
    </main>
  );
}
