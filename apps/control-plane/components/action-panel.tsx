"use client";

import { useState } from "react";

export function ActionPanel({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <article className="card">
      <h3>{title}</h3>
      <p className="muted">{description}</p>
      <div className="action-panel-body">{children}</div>
    </article>
  );
}

export function ActionFeedback({ message }: { message: string | null }) {
  if (!message) return null;
  return <p className="feedback-message">{message}</p>;
}

export function useActionFeedback() {
  const [message, setMessage] = useState<string | null>(null);
  return { message, setMessage };
}
