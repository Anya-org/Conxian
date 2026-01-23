
import React, { useState } from 'react';
import { BookOpen, Shield, Zap, Network, Repeat, Database, Key, Info, ChevronRight, FileCode, Landmark, Terminal, FlaskConical, Globe, Lock, History, Sparkles, Smartphone, Scale, XCircle, CheckCircle2, AlertTriangle, Fingerprint, Palette, ShoppingBag, Gavel } from 'lucide-react';

const DOCS_DATA = [
  {
    id: 'compliance',
    title: 'Standard Compliance',
    icon: FileCode,
    color: 'text-blue-500',
    content: `Conxius is engineered for universal compatibility. By adhering to core Bitcoin and Stacks standards, we ensure your assets are never locked into our interface.
    
    ### Supported BIPs (Bitcoin):
    - **BIP-39**: Mnemonic seed phrase generation and recovery.
    - **BIP-32/44**: Deterministic key derivation.
    - **BIP-84**: Native SegWit (Bech32) for reduced fees and better security.
    - **BIP-322**: Standardized message signing for proof-of-reserve.
    - **BIP-21**: Unified payment URI for cross-app coordination.
    
    ### Supported SIPs (Stacks):
    - **SIP-010**: Standard for Fungible Tokens on Stacks.
    - **SIP-009**: Non-Fungible Token standard for Bitcoin-native digital artifacts.`
  },
  {
    id: 'architecture',
    title: 'Enclave Security',
    icon: Shield,
    color: 'text-orange-500',
    content: `The Conxius Enclave uses a "Shared-Nothing" architecture. Your private keys are derived locally from hardware-level entropy and stored within the browser's origin-private file system.
    
    ### Verification Pillars:
    - **No-Phoning-Home**: Public addresses are queried via your selected RPC nodes (or Tor relays).
    - **Local Inscription**: Ordinals and Runes are etched directly from the client, eliminating platform-level risk.
    - **Zero Knowledge Identity**: DID profiles are anchored to the Bitcoin L1 state.`
  }
];

const Documentation: React.FC = () => {
  const [activeSection, setActiveSection] = useState(DOCS_DATA[0].id);
  const activeDoc = DOCS_DATA.find(d => d.id === activeSection) || DOCS_DATA[0];

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3 italic uppercase">
            <BookOpen className="text-orange-500" />
            System Manual
          </h2>
          <p className="text-zinc-500 text-sm italic">Formal specification of the Conxius Sovereign Standard.</p>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        <div className="lg:col-span-4 space-y-4">
          {DOCS_DATA.map((doc) => (
            <button
              key={doc.id}
              onClick={() => setActiveSection(doc.id)}
              className={`w-full p-6 rounded-[2rem] border text-left transition-all group flex items-center gap-5 ${
                activeSection === doc.id ? 'bg-zinc-900 border-orange-500/50 shadow-2xl' : 'bg-zinc-950 border-zinc-900 hover:border-zinc-800'
              }`}
            >
              <div className={`p-3 rounded-2xl bg-zinc-900 border border-zinc-800 ${doc.color}`}><doc.icon size={20} /></div>
              <div>
                <h4 className="font-bold text-zinc-100 group-hover:text-orange-500">{doc.title}</h4>
                <p className="text-[10px] text-zinc-600 font-black uppercase tracking-widest mt-0.5">SVN 0.3 Specification</p>
              </div>
            </button>
          ))}
        </div>

        <div className="lg:col-span-8">
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3rem] p-12 min-h-[600px] shadow-2xl relative overflow-hidden">
             <div className="relative z-10 prose prose-invert max-w-none">
                <div className="flex items-center gap-4 mb-10">
                   <div className={`p-4 rounded-[1.5rem] bg-zinc-950 border border-zinc-800 ${activeDoc.color}`}><activeDoc.icon size={32} /></div>
                   <h1 className="text-4xl font-black tracking-tighter text-zinc-100 uppercase italic m-0">{activeDoc.title}</h1>
                </div>
                <div className="text-zinc-400 leading-loose space-y-6 text-sm whitespace-pre-wrap selection:bg-orange-500/30">
                   {activeDoc.content}
                </div>
             </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Documentation;
