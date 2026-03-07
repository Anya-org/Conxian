# Technical Flow: Autonomous Agentic Transaction (March 2026)

This diagram maps the cryptographic execution path of an autonomous transaction initiated by an AI agent within the Conxius ecosystem.

\`\`\`mermaid
sequenceDiagram
    participant LLM as External AI (LLM)
    participant MCP as Kotlin MCP Server (Android)
    participant AP2 as AP2 Service (Mandates)
    participant TEE as StrongBox/TEE (Hardware)
    participant STX as Stacks Blockchain (Clarity)

    Note over LLM, STX: 1. Context Generation & Mandate Creation
    LLM->>MCP: request_transaction(intent, budget)
    MCP->>AP2: create_intent_mandate(constraints)
    AP2->>TEE: sign_mandate(VC)
    TEE-->>AP2: Signed Verifiable Mandate
    AP2-->>MCP: Intent Mandate Ready

    Note over LLM, STX: 2. Execution & Hardware Guardrails
    MCP-->>LLM: Context provided (Limits + Tools)
    LLM->>MCP: call_tool(execute_transfer, payload)
    MCP->>TEE: request_signing(payload, mandate)

    Note right of TEE: StrongBox verifies payload<br/>against AP2 Mandate constraints

    alt Policy Pass
        TEE->>TEE: Hardware Signing (No Egress)
        TEE-->>MCP: Signed Transaction
    else Policy Violation (e.g. Prompt Injection)
        TEE-->>MCP: Reject (Spend Limit Exceeded)
        MCP-->>LLM: Error: Security Violation
    end

    Note over LLM, STX: 3. Protocol Settlement
    MCP->>STX: broadcast(signed_tx)
    STX->>STX: authorize-spend(agent, amount)

    Note right of STX: Clarity Contract enforces<br/>on-chain daily caps

    alt On-Chain Limit Pass
        STX-->>STX: Settlement Complete
    else On-Chain Limit Fail
        STX-->>MCP: Reject (Contract Spend Limit)
    end
\`\`\`

## Key Components
1. **Kotlin MCP Server**: The local context hub that bridges the AI agent with wallet tools.
2. **AP2 Mandate**: A cryptographically signed Verifiable Credential (VC) that defines the agent's spending boundaries.
3. **StrongBox Hardware Logic**: The final arbiter of truth. It verifies the mandate before accessing private keys, mitigating application-layer compromise.
4. **Clarity Spend Limits**: Protocol-level guardrails that prevent systemic drainage even if the hardware-enclosed logic is bypassed.
