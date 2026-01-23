
import React, { useState, useContext } from 'react';
import { Lock, EyeOff, ShieldAlert, Cpu, Share2, ToggleLeft as Toggle, Ghost, Zap, Bot, Loader2, Coins, Network, Database } from 'lucide-react';
import { AppContext } from '../context';

const PrivacyEnclave: React.FC = () => {
  const context = useContext(AppContext);
  const [torEnabled, setTorEnabled] = useState(true);
  const [localOnly, setLocalOnly] = useState(true);
  const [nostrMetadata, setNostrMetadata] = useState(true);
  
  // Data Monetization State
  const [isDataUnionActive, setIsDataUnionActive] = useState(context?.state.dataSharing.enabled || false);
  const [askPrice, setAskPrice] = useState(context?.state.dataSharing.minAskPrice || 50);

  const toggleDataUnion = () => {
     setIsDataUnionActive(!isDataUnionActive);
     // In a real app, this would update the context/global state
  };

  return (
    <div className="p-8 max-w-4xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-24">
      <header>
        <div className="flex items-center gap-4 mb-2">
          <div className="w-12 h-12 bg-orange-500/10 rounded-2xl flex items-center justify-center">
            <Lock className="text-orange-500" size={24} />
          </div>
          <h2 className="text-3xl font-bold tracking-tight">Privacy Enclave</h2>
        </div>
        <p className="text-zinc-500 text-sm">Fine-tune your digital footprint. SatoshiLayer is built on the principle of Zero Knowledge.</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        
        {/* Sovereign Data Union Module */}
        <div className="md:col-span-2 bg-gradient-to-r from-zinc-900 to-purple-900/10 border border-purple-500/30 rounded-[2.5rem] p-8 relative overflow-hidden group shadow-2xl">
           <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:scale-110 transition-transform">
              <Database size={100} />
           </div>
           
           <div className="relative z-10 grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
              <div className="space-y-4">
                 <h3 className="text-xl font-black italic uppercase tracking-tighter text-white flex items-center gap-2">
                    <Network size={24} className="text-purple-500" />
                    Sovereign Data Union
                 </h3>
                 <p className="text-xs text-zinc-300 leading-relaxed font-medium">
                    Negotiate your own terms. Lease anonymized wallet metadata to AI researchers directly from your node. 
                    <span className="block mt-2 text-purple-400">
                       • You hold the data (Local Storage). <br/>
                       • You set the price (Sats/Query). <br/>
                       • You keep 95% of revenue.
                    </span>
                 </p>
                 
                 <div className="flex items-center gap-4 pt-2">
                    <button 
                      onClick={toggleDataUnion}
                      aria-label="Toggle sovereign data union"
                      title="Toggle sovereign data union"
                      className={`relative w-14 h-7 rounded-full transition-colors ${isDataUnionActive ? 'bg-purple-600' : 'bg-zinc-800'}`}
                    >
                       <div className={`absolute top-1 w-5 h-5 rounded-full bg-white transition-all shadow-md ${isDataUnionActive ? 'left-8' : 'left-1'}`} />
                    </button>
                    <span className="text-xs font-bold uppercase tracking-widest text-zinc-400">
                       {isDataUnionActive ? 'Broadcasting Offer' : 'Union Inactive'}
                    </span>
                 </div>
              </div>

              <div className="bg-zinc-950/80 rounded-3xl p-6 border border-zinc-900 space-y-4 backdrop-blur-sm">
                 <div className="flex justify-between items-center">
                    <span className="text-[10px] font-black uppercase text-zinc-500">Incentive Status</span>
                    {isDataUnionActive ? (
                       <span className="text-[10px] font-bold text-green-500 bg-green-500/10 px-2 py-1 rounded border border-green-500/20 uppercase">2x AI Caps Active</span>
                    ) : (
                       <span className="text-[10px] font-bold text-zinc-600 uppercase">Standard</span>
                    )}
                 </div>
                 
                 <div>
                    <label className="text-[10px] font-black uppercase text-zinc-500 mb-2 block">Min. Ask Price (Negotiable)</label>
                    <div className="flex items-center gap-4">
                       <input 
                          type="range" 
                          min="10" 
                          max="500" 
                          value={askPrice} 
                          onChange={(e) => setAskPrice(parseInt(e.target.value))}
                          disabled={!isDataUnionActive}
                          aria-label="Minimum ask price"
                          title="Minimum ask price"
                          className="flex-1 accent-purple-500"
                       />
                       <span className="text-lg font-mono font-bold text-white">{askPrice} <span className="text-xs text-zinc-500">SATS</span></span>
                    </div>
                 </div>
                 
                 <p className="text-[9px] text-zinc-600 italic border-t border-zinc-900 pt-3">
                    *Conxius Labs takes a 5% protocol fee for facilitating the P2P handshake. Data is never stored on our servers.
                 </p>
              </div>
           </div>
        </div>

        <div className="space-y-6">
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-3xl p-8 space-y-8">
            <h3 className="font-bold text-sm uppercase tracking-widest text-zinc-500 flex items-center gap-2">
              <Cpu size={16} />
              Hardware & Storage
            </h3>
            
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <p className="font-bold text-zinc-200">Local-Only Key Generation</p>
                  <p className="text-xs text-zinc-500 max-w-[240px]">Keys are generated in the browser's secure enclave and never touch our servers.</p>
                </div>
                <button 
                  onClick={() => setLocalOnly(!localOnly)}
                  aria-label="Toggle local-only key generation"
                  title="Toggle local-only key generation"
                  className={`relative w-12 h-6 rounded-full transition-colors ${localOnly ? 'bg-orange-600' : 'bg-zinc-800'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-all ${localOnly ? 'left-7' : 'left-1'}`} />
                </button>
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <p className="font-bold text-zinc-200">Nostr Metadata Storage</p>
                  <p className="text-xs text-zinc-500 max-w-[240px]">Store your wallet profile and D.i.D info on decentralized Nostr relays instead of databases.</p>
                </div>
                <button 
                  onClick={() => setNostrMetadata(!nostrMetadata)}
                  aria-label="Toggle Nostr metadata storage"
                  title="Toggle Nostr metadata storage"
                  className={`relative w-12 h-6 rounded-full transition-colors ${nostrMetadata ? 'bg-orange-600' : 'bg-zinc-800'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-all ${nostrMetadata ? 'left-7' : 'left-1'}`} />
                </button>
              </div>
            </div>
          </div>

          <div className="bg-zinc-900/40 border border-zinc-800 rounded-3xl p-8 space-y-8">
            <h3 className="font-bold text-sm uppercase tracking-widest text-zinc-500 flex items-center gap-2">
              <Ghost size={16} />
              Network Identity
            </h3>
            
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <p className="font-bold text-zinc-200">Always Route through Tor</p>
                  <p className="text-xs text-zinc-500 max-w-[240px]">Obfuscate your IP address for all RPC and API calls. Increases latency but maximizes privacy.</p>
                </div>
                <button 
                  onClick={() => setTorEnabled(!torEnabled)}
                  aria-label="Toggle Tor routing"
                  title="Toggle Tor routing"
                  className={`relative w-12 h-6 rounded-full transition-colors ${torEnabled ? 'bg-orange-600' : 'bg-zinc-800'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-all ${torEnabled ? 'left-7' : 'left-1'}`} />
                </button>
              </div>

              <div className="flex items-center gap-4 p-4 rounded-2xl bg-zinc-950 border border-zinc-900 text-xs text-zinc-500">
                <ShieldAlert size={18} className="text-yellow-600 shrink-0" />
                <p>Public mempool listeners can still deanonymize transactions via timing analysis. Use <strong>CoinJoin</strong> for maximum L1 privacy.</p>
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-orange-500/5 border border-orange-500/10 rounded-3xl p-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-orange-500/20 p-2 rounded-lg">
                <Bot className="text-orange-500" size={18} />
              </div>
              <h4 className="font-bold text-xs uppercase tracking-widest text-orange-500">Satoshi AI: Privacy Audit</h4>
            </div>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-zinc-300">Privacy Score</span>
                <span className="text-lg font-bold text-green-500">98/100</span>
              </div>
              <div className="w-full h-2 bg-zinc-900 rounded-full overflow-hidden">
                <div className="w-[98%] h-full bg-gradient-to-r from-orange-600 to-green-500 rounded-full" />
              </div>
              <p className="text-xs text-zinc-500 leading-relaxed">
                "Excellent work. By utilizing local-only key generation and Nostr for metadata, you have effectively removed SatoshiLayer as a potential point of failure or surveillance. Your digital sovereignity is currently high."
              </p>
            </div>
          </div>

          <div className="bg-zinc-900/20 border border-zinc-800 rounded-3xl p-8 space-y-4">
            <h4 className="font-bold text-sm text-zinc-200 flex items-center gap-2">
              <Share2 size={16} className="text-blue-500" />
              Zero-Knowledge Proofs
            </h4>
            <p className="text-xs text-zinc-500 leading-relaxed">
              We are working on integrating <strong>ZK-Rollup</strong> metadata. Soon, you'll be able to prove you own a specific amount of BTC or a D.i.D credential without revealing your actual addresses.
            </p>
            <button className="w-full py-2 bg-zinc-800 rounded-xl text-[10px] font-bold text-zinc-400 uppercase tracking-widest hover:bg-zinc-700 transition-colors" aria-label="Request early access" title="Request early access">
              Request Early Access
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PrivacyEnclave;
