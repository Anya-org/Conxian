"use client";

import type { ReleaseArtifact } from "@conxian/schemas";
import { useState } from "react";
import { ActionFeedback, ActionPanel } from "./action-panel";
import { getCurrentActor } from "../lib/auth";
import { createAuditActionEvent } from "../lib/audit";
import { requestReleaseApprovalV1 } from "../lib/workflow-clients";

export function ReleaseApprovalForm({ artifacts }: { artifacts: ReleaseArtifact[] }) {
  const actor = getCurrentActor();
  const [artifactId, setArtifactId] = useState(artifacts[0]?.id ?? "");
  const [notes, setNotes] = useState("");
  const [message, setMessage] = useState<string | null>(null);

  return (
    <ActionPanel
      title="Request release approval"
      description="Bootstrap flow for requesting approval on a release artifact."
    >
      <form
        className="stack"
        onSubmit={(event) => {
          event.preventDefault();
          const result = requestReleaseApprovalV1({
            artifactId,
            requestedBy: actor.id,
            notes,
          });

          if (result.accepted) {
            const audit = createAuditActionEvent({
              category: "release",
              actor: actor.name,
              summary: "Release approval requested",
              relatedEntityId: artifactId,
              actionType: "request_release_approval",
              outcome: "accepted",
            });
            setMessage(`${result.message} Audit event ${audit.id} created.`);
          }
        }}
      >
        <label>
          Artifact
          <select value={artifactId} onChange={(event) => setArtifactId(event.target.value)}>
            {artifacts.map((artifact) => (
              <option key={artifact.id} value={artifact.id}>
                {artifact.name}
              </option>
            ))}
          </select>
        </label>

        <label>
          Notes
          <textarea
            rows={4}
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            placeholder="Add approval context"
          />
        </label>

        <button type="submit">Request approval</button>
      </form>

      <ActionFeedback message={message} />
    </ActionPanel>
  );
}
