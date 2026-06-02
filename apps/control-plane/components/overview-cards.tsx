import { getControlPlaneHealth } from "@conxian/client-sdk";

const cards = [
  {
    title: "Repo role",
    body: "`conxian-business` is the private BOS control plane for governance and operations workflows.",
  },
  {
    title: "Runtime boundary",
    body: "Privileged execution remains in `conxian-nexus` and adjacent trusted services.",
  },
  {
    title: "First modules",
    body: "Release governance, audit, policy approvals, and environment registry form the first implementation slice.",
  },
];

export function OverviewCards() {
  const health = getControlPlaneHealth();

  return (
    <section className="grid">
      {cards.map((card) => (
        <article key={card.title} className="card">
          <h3>{card.title}</h3>
          <p>{card.body}</p>
        </article>
      ))}

      <article className="card">
        <h3>Health</h3>
        <p>{health.status}</p>
        <p className="muted">{health.message}</p>
      </article>
    </section>
  );
}
