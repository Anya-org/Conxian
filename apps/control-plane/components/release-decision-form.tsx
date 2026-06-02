"use client";

import type { ReleaseArtifact, WorkflowDecision } from "@conxian/schemas";
import { useState } from "react";
import { ActionFeedback, ActionPanel } from "./action-panel";
import { getCurrentActor } from "../lib/auth";
import { createAuditActionEvent } from "../lib/audit";
import { submitReleaseDecisionV1 } from "../lib/workflow-clients";

export function ReleaseDecisionForm({ artifacts }: { artifacts: ReleaseArtifact[] }) {
  const actor = getCurrentActor();
  const [artifactId, setArtifactId] = useState(artifacts[0]?.id ?? "");
  const [decision, setDecision] = useState<WorkflowDecision>("approve");
  const [notes, setNotes] = useState("");
  const [message, setMessage] = useState<string | null>(null);

  return (
    <ActionPanel
      title="Record release decision"
      description="Bootstrap decision flow for release-governance actions."
    >
      <form
        className="stack"
        onSubmit={(event) => {
          event.preventDefault();
          const result = submitReleaseDecisionV1({
            artifactId,
            decision,
            actorId: actor.id,
            notes,
          });

          if (result.accepted) {
            const audit = createAuditActionEvent({
              category: "release",
              actor: actor.name,
              summary: `Release decision ${decision}`,
              relatedEntityId: artifactId,
              actionType: "release_decision",
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
          Decision
          <select value={decision} onChange={(event) => setDecision(event.target.value as WorkflowDecision)}>
            <option value="approve">Approve</option>
            <option value="reject">Reject</option>
            <option value="request_changes">Request changes</option>
          </select>
        </label>

        <label>
          Notes
          <textarea
            rows={4}
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            placeholder="Add release decision notes"
          />
        </label>

        <button type="submit">Submit release decision</button>
      </form>

      <ActionFeedback message={message} />
    </ActionPanel>
  );
}
