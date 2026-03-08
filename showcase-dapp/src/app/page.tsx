"use client";

import { useState } from "react";
import { Shield, Zap, Lock, Code, CheckCircle2, ChevronRight, Activity } from "lucide-react";
import { motion } from "framer-motion";

export default function Home() {
  const [signingState, setSigningState] = useState<"idle" | "signing" | "success">("idle");
  const [latency, setLatency] = useState(0);

  const simulateSigning = () => {
    setSigningState("signing");
    const start = performance.now();
    
    // Simulate ~300ms StrongBox hardware signing latency
    setTimeout(() => {
      const end = performance.now();
      setLatency(Math.round(end - start));
      setSigningState("success");
      
      setTimeout(() => setSigningState("idle"), 3000);
    }, 312);
  };

  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-orange-500 selection:text-black">
      {/* Header */}
      <header className="border-b border-white/10 sticky top-0 bg-black/50 backdrop-blur-md z-50">
        <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Shield className="w-6 h-6 text-orange-500" />
            <span className="font-bold text-xl tracking-tight">Conclave SDK</span>
          </div>
          <nav className="hidden md:flex gap-6 text-sm text-gray-400">
            <a href="#" className="hover:text-white transition-colors">Documentation</a>
            <a href="#" className="hover:text-white transition-colors">Pricing</a>
            <a href="#" className="hover:text-white transition-colors">B2B Institutional</a>
          </nav>
          <div className="flex items-center gap-4">
            <button className="text-sm font-medium hover:text-orange-500 transition-colors">
              Sign In
            </button>
            <button className="bg-white text-black px-4 py-2 rounded-md text-sm font-bold hover:bg-orange-500 hover:text-white transition-all">
              Get API Key
            </button>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <main className="max-w-7xl mx-auto px-6 py-24 grid md:grid-cols-2 gap-12 items-center">
        <div className="space-y-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10 text-sm text-orange-400">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-orange-500"></span>
            </span>
            Now supporting Musig2 & Android StrongBox
          </div>
          <h1 className="text-5xl md:text-7xl font-extrabold tracking-tighter leading-tight">
            The Institutional <br/>
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-orange-400 to-red-600">
              Citadel.
            </span>
          </h1>
          <p className="text-xl text-gray-400 max-w-lg leading-relaxed">
            A headless cryptographic state machine. Commoditize your users' mobile hardware for 
            Nakamoto-native finality with zero vendor lock-in.
          </p>
          <div className="flex gap-4">
            <button className="bg-orange-500 text-black px-6 py-3 rounded-md font-bold flex items-center gap-2 hover:bg-orange-400 transition-all">
              Start Building Free <ChevronRight className="w-4 h-4" />
            </button>
            <button className="px-6 py-3 rounded-md font-bold border border-white/20 hover:bg-white/5 transition-all flex items-center gap-2">
              <Code className="w-4 h-4" /> View Docs
            </button>
          </div>
          
          <div className="pt-8 border-t border-white/10 flex gap-8">
            <div>
              <p className="text-3xl font-bold">50k</p>
              <p className="text-sm text-gray-500 uppercase tracking-wider mt-1">Free Sigs/Mo</p>
            </div>
            <div>
              <p className="text-3xl font-bold">~300ms</p>
              <p className="text-sm text-gray-500 uppercase tracking-wider mt-1">Avg Latency</p>
            </div>
            <div>
              <p className="text-3xl font-bold">100%</p>
              <p className="text-sm text-gray-500 uppercase tracking-wider mt-1">Self Custodial</p>
            </div>
          </div>
        </div>

        {/* Interactive Demo */}
        <div className="relative">
          <div className="absolute inset-0 bg-gradient-to-tr from-orange-500/20 to-transparent blur-3xl -z-10 rounded-full" />
          <div className="bg-black border border-white/10 rounded-xl p-8 shadow-2xl relative overflow-hidden">
            <div className="flex items-center justify-between mb-8 border-b border-white/10 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-orange-500/20 flex items-center justify-center">
                  <Activity className="w-5 h-5 text-orange-500" />
                </div>
                <div>
                  <h3 className="font-bold">Hardware Enclave Demo</h3>
                  <p className="text-xs text-gray-500">Testing ECDSA / Musig2 Latency</p>
                </div>
              </div>
            </div>

            <div className="space-y-6">
              <div className="bg-white/5 rounded-lg p-4 font-mono text-sm text-gray-300 break-all">
                Payload: 0x9a8f7b...3c2d1e
                <br />
                Path: m/86'/0'/0'/0/0
              </div>

              <button 
                onClick={simulateSigning}
                disabled={signingState === "signing"}
                className={`w-full py-4 rounded-md font-bold flex items-center justify-center gap-2 transition-all ${
                  signingState === "signing" ? "bg-orange-500/50 cursor-not-allowed" :
                  signingState === "success" ? "bg-green-500 text-black" :
                  "bg-white text-black hover:bg-orange-500 hover:text-white"
                }`}
              >
                {signingState === "idle" && <><Lock className="w-5 h-5" /> Request Hardware Signature</>}
                {signingState === "signing" && <><Activity className="w-5 h-5 animate-spin" /> Enclave Processing...</>}
                {signingState === "success" && <><CheckCircle2 className="w-5 h-5" /> Signed in {latency}ms!</>}
              </button>

              <div className="text-center text-xs text-gray-500 mt-4">
                Powered by native Android StrongBox / iOS Secure Enclave
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* Features Grid */}
      <section className="border-t border-white/10 bg-black py-24">
        <div className="max-w-7xl mx-auto px-6 grid md:grid-cols-3 gap-12">
          <div>
            <Zap className="w-10 h-10 text-orange-500 mb-4" />
            <h3 className="text-xl font-bold mb-2">Zero Network Latency</h3>
            <p className="text-gray-400">
              Unlike MPC networks (Privy/Turnkey), Conclave signs directly on the local hardware enclave. No round-trips. No waiting.
            </p>
          </div>
          <div>
            <Shield className="w-10 h-10 text-orange-500 mb-4" />
            <h3 className="text-xl font-bold mb-2">Mathematical Supremacy</h3>
            <p className="text-gray-400">
              Full Nakamoto-native finality. Keys never leave the TEE/StrongBox. Immune to cloud provider breaches.
            </p>
          </div>
          <div>
            <Code className="w-10 h-10 text-orange-500 mb-4" />
            <h3 className="text-xl font-bold mb-2">Headless Rust Architecture</h3>
            <p className="text-gray-400">
              Drop it into any L2 React or Native app. Pure state machine. You completely own the UI and UX.
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
