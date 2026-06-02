import { getCurrentActor } from "../lib/auth";

export function PageHeader({
  eyebrow,
  title,
  description,
}: {
  eyebrow: string;
  title: string;
  description: string;
}) {
  const actor = getCurrentActor();

  return (
    <section className="hero compact">
      <p className="eyebrow">{eyebrow}</p>
      <div className="title-row">
        <div>
          <h2>{title}</h2>
          <p className="lede">{description}</p>
        </div>
        <div className="actor-chip">
          <span>{actor.name}</span>
          <span className="chip-muted">{actor.role}</span>
        </div>
      </div>
    </section>
  );
}
