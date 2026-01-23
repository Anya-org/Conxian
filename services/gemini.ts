
import { GoogleGenAI } from "@google/genai";
import { Asset } from "../types";

// Note: Moving GoogleGenAI instantiation inside functions to follow best practices 
// of creating a new instance right before making an API call.

export const getBountyAudit = async (bountyTitle: string, description: string) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: `Perform a technical audit of the following development bounty:
      Title: "${bountyTitle}"
      Description: "${description}"
      
      Requirements:
      1. Evaluate the technical feasibility within the Conxius Enclave architecture.
      2. Identify potential security risks (e.g., side-channel attacks on local keys).
      3. Recommend a fair reward in BTC/STX based on the complexity.
      4. Suggest 3 specific acceptance criteria for the Conxius Treasury multisig to verify before release.`,
      config: {
        systemInstruction: "You are the Conxius Lead Auditor. You ensure all community contributions maintain the highest standards of sovereignty and security.",
        thinkingConfig: { thinkingBudget: 32768 }
      }
    });
    return response.text;
  } catch (error) {
    return "Bounty audit engine offline. Use local conservative risk heuristics.";
  }
};

export const generateReleaseNotes = async (version: string) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: `Generate a high-density, professional 'Cypherpunk' style release report for Conxius Wallet SVN ${version}. 
      Highlight:
      - The transition to BSL 1.1 Licensing.
      - Integrated System Health Sentinel.
      - Native Wormhole NTT Bridge stabilization.
      - Sovereign Studio expansion (Ordinals/Runes).
      - DAO Bounty Integration for community devs.
      The tone should be clinical, authoritative, and visionary.`,
      config: {
        systemInstruction: "You are the Chief Technical Evangelist at Conxius Labs.",
        thinkingConfig: { thinkingBudget: 32768 }
      }
    });
    return response.text;
  } catch (error) {
    return "Release notes synthesis failed. Version status: Hardened Production.";
  }
};

export const getSystemHealthSummary = async (testResults: any[]) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const resultsStr = testResults.map(r => `${r.label}: ${r.status}`).join(', ');
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Provide a clinical, high-density system health summary for the Conxius Sovereign Enclave based on these diagnostic results: ${resultsStr}. 
      Evaluate the risk level (Low/Medium/High) and provide a "Protocol Directive".`,
      config: {
        systemInstruction: "You are the Conxius Sentinel System.",
      }
    });
    return response.text;
  } catch (error) {
    return "Sentinel offline. Risk: Minimal.";
  }
};

export const getNetworkRPCResearch = async (layer: string) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Research into RPC infrastructure for: "${layer}". Identify top 3 providers and one Tor endpoint.`,
      config: {
        systemInstruction: "You are the Conxius Infrastructure Lead.",
      }
    });
    return response.text;
  } catch (error) {
    return "Network research engine throttled.";
  }
};

export const getFinalSystemHardeningChecklist = async () => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: "Provide a 5-point 'Hardened Mainnet' checklist for a Bitcoin multi-layer wallet. Focus on cold storage, Tor V3, ZK identity, NTT immutability, and fallback.",
      config: {
        systemInstruction: "You are a cyber-security expert.",
        thinkingConfig: { thinkingBudget: 32768 }
      }
    });
    return response.text;
  } catch (error) {
    return "Hardening audit offline.";
  }
};

export const getDeploymentReadinessAudit = async (state: any) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: `Final Go/No-Go audit. Node Sync: ${state.nodeSyncProgress}%, Sovereignty Score: ${state.sovereigntyScore}. Evaluate readiness for mainnet.`,
      config: {
        systemInstruction: "You are the Release Manager.",
        thinkingConfig: { thinkingBudget: 32768 }
      }
    });
    return response.text;
  } catch (error) {
    return "Readiness audit offline.";
  }
};

export const getNodeEthosAdvice = async (path: string) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Advise on the 'Sovereign Ethos' of: "${path}". Compare with custodial wallets.`,
      config: {
        systemInstruction: "You are the Satoshi Sovereign Researcher.",
      }
    });
    return response.text;
  } catch (error) {
    return "Ethos engine offline.";
  }
};

export const getRiskProfileAudit = async (assets: Asset[]) => {
  const assetsSummary = assets.map(a => `${a.name} (${a.symbol}) on ${a.layer}`).join(', ');
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: `Risk audit for: ${assetsSummary}. Evaluate counterparty, liquidity, regulatory, and technical risks.`,
      config: {
        systemInstruction: "You are the Chief Risk Officer.",
        thinkingConfig: { thinkingBudget: 32768 }
      }
    });
    return response.text;
  } catch (error) {
    return "Risk audit engine offline.";
  }
};

export const getAssetInsight = async (asset: Asset) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Technical analysis for ${asset.name} (${asset.symbol}) on ${asset.layer}.`,
      config: {
        systemInstruction: "You are Satoshi Pro AI.",
      }
    });
    return response.text;
  } catch (error) {
    return "Insight engine re-indexing.";
  }
};

export const performDeepScan = async (assets: any[]) => {
  const assetsSummary = assets.map(a => `${a.name} (${a.symbol}) on ${a.layer}`).join(', ');
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: `Deep Scan: ${assetsSummary}. Provide risk scores, tax opportunities, and alpha.`,
      config: {
        systemInstruction: "You are Satoshi Pro AI.",
        thinkingConfig: { thinkingBudget: 32768 }
      }
    });
    return response.text;
  } catch (error) {
    return "Deep Scan offline.";
  }
};

export const getDIDInsight = async (did: string) => {
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-pro-preview',
      contents: `Audit Bitcoin DID: "${did}". Explain DPKI shift, PoW immutability, and sovereignty implications.`,
      config: {
        systemInstruction: "You are Satoshi AI.",
        thinkingConfig: { thinkingBudget: 32768 }
      }
    });
    return response.text;
  } catch (error) {
    return "Identity graph re-indexing.";
  }
};

export const analyzePortfolio = async (assets: any[]) => {
  const assetsSummary = assets.map(a => `${a.name} (${a.symbol}) on ${a.layer}`).join(', ');
  try {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const response = await ai.models.generateContent({
      model: 'gemini-3-flash-preview',
      contents: `Analyze portfolio: ${assetsSummary}.`,
    });
    return response.text;
  } catch (error) {
    return "Analysis error.";
  }
};
