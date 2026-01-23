
import React, { useState, useContext } from 'react';
import { Castle, Users, ShieldCheck, Zap, TrendingUp, Network, Share2, Crown, Plus, Copy, CheckCircle2, ArrowRight, Wallet, Target, Gavel, FileSignature, Coins, ArrowUpRight, Lock, Vote, Search, Globe, UserPlus, Info, Terminal, Award, Hammer, MessageSquare, Loader2, Sparkles, X } from 'lucide-react';
import { AppContext } from '../context';
import { Citadel, Bounty } from '../types';
import { getBountyAudit } from '../services/gemini';

const MOCK_CITADEL: Citadel = {
  id: 'citadel-alpha',
  name: 'Satoshi\'s Vanguard',
  motto: 'Vires in Numeris',
  members: [
    { id: '1', name: 'You (Leader)', role: 'Architect', sovereigntyScore: 92, nodeStatus: 'Online', stackedAmount: 15000, votingPower: 4500 },
    { id: '2', name: 'Alice.btc', role: 'Guardian', sovereigntyScore: 85, nodeStatus: 'Online', stackedAmount: 42000, votingPower: 12500 },
    { id: '3', name: 'Bob.stx', role: 'Initiate', sovereigntyScore: 45, nodeStatus: 'Leech', stackedAmount: 5000, votingPower: 1500 },
    { id: '4', name: 'Anon#921', role: 'Guardian', sovereigntyScore: 78, nodeStatus: 'Offline', stackedAmount: 25000, votingPower: 7500 },
  ],
  treasuryBalance: 2.45,
  sharedRpcEndpoint: 'http://vanguard-node.onion:8332',
  alignmentScore: 94,
  nextPayout: '2 days',
  pool: {
    totalStacked: 87000,
    nextCycleTarget: 100000,
    estimatedYieldBtc: 0.084,
    coordinatorFee: 5.0
  },
  proposals: [
    { id: 'CP-12', title: 'Increase Coordinator Fee', description: 'Raise fee to 6% to fund a backup Tor relay node.', type: 'Fee Change', status: 'Active', votesFor: 14000, votesAgainst: 2000, deadline: '24h' },
  ],
  pendingTxs: [
    { id: 'tx-89', description: 'Payout: Dev Fund', amount: 0.05, asset: 'BTC', to: 'bc1q...9z', signatures: 2, required: 3, status: 'Pending' }
  ],
  bounties: [] // Handled by global state now
};

const CitadelManager: React.FC = () => {
  const context = useContext(AppContext);
  const [inCitadel, setInCitadel] = useState(false);
  const [activeTab, setActiveTab] = useState<'pool' | 'treasury' | 'governance' | 'bounties' | 'members'>('pool');
  const [selectedBounty, setSelectedBounty] = useState<Bounty | null>(null);
  const [bountyAudit, setBountyAudit] = useState<string | null>(null);
  const [isAuditing, setIsAuditing] = useState(false);

  if (!context) return null;
  const bounties = context.state.bounties;

  const auditBounty = async (bounty: Bounty) => {
    setSelectedBounty(bounty);
    setIsAuditing(true);
    const res = await getBountyAudit(bounty.title, bounty.description);
    setBountyAudit(res);
    setIsAuditing(false);
  };

  const handleClaim = () => {
    if (selectedBounty) {
      context.claimBounty(selectedBounty.id);
      setSelectedBounty(null);
      setBountyAudit(null);
    }
  };

  if (!inCitadel) {
    return (
      <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
         <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
            <div>
               <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3 italic uppercase">
                  <Globe className="text-orange-500" />
                  Citadel Discovery
               </h2>
               <p className="text-zinc-500 text-sm italic">Join a sovereign guild to boost yield and share node resources.</p>
            </div>
            <button onClick={() => setInCitadel(true)} className="bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-zinc-300 px-6 py-3 rounded-2xl font-bold text-xs uppercase tracking-widest transition-all">
               Skip to My Citadel
            </button>
         </header>
         <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <button onClick={() => setInCitadel(true)} className="flex flex-col items-center justify-center p-8 bg-zinc-900/20 border-2 border-dashed border-zinc-800 rounded-[2.5rem] hover:border-orange-500/50 hover:bg-zinc-900/40 transition-all group min-h-[300px]">
               <Plus size={32} className="text-zinc-500 group-hover:text-orange-500" />
               <h3 className="text-xl font-black uppercase text-zinc-300 group-hover:text-white mt-6">Forge New Citadel</h3>
            </button>
         </div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <button onClick={() => setInCitadel(false)} className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest mb-2 hover:text-orange-500 flex items-center gap-1 transition-colors">
             <ArrowUpRight className="rotate-[-135deg]" size={12} /> Back to Discovery
          </button>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3">
            <Castle className="text-purple-500" />
            {MOCK_CITADEL.name}
          </h2>
          <p className="text-zinc-500 text-sm italic">"{MOCK_CITADEL.motto}"</p>
        </div>
        <div className="bg-purple-900/20 border border-purple-500/20 px-6 py-3 rounded-2xl flex items-center gap-4">
           <div className="w-12 h-12 bg-purple-600 rounded-xl flex items-center justify-center text-white shadow-lg">
              <Target size={24} />
           </div>
           <div>
              <p className="text-[10px] font-black uppercase text-purple-300">Alignment Score</p>
              <p className="text-xl font-bold text-purple-100 font-mono">{MOCK_CITADEL.alignmentScore}%</p>
           </div>
        </div>
      </header>

      <div className="flex bg-zinc-900/50 p-1 rounded-2xl w-full md:w-auto self-start border border-zinc-800 overflow-x-auto custom-scrollbar">
         {[
            { id: 'pool', label: 'Pooling', icon: Zap },
            { id: 'treasury', label: 'Treasury', icon: Wallet },
            { id: 'governance', label: 'Governance', icon: Gavel },
            { id: 'bounties', label: 'Bounty Board', icon: Hammer },
            { id: 'members', label: 'Members', icon: Users },
         ].map((tab) => (
            <button
               key={tab.id}
               onClick={() => setActiveTab(tab.id as any)}
               className={`flex items-center gap-2 px-6 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all whitespace-nowrap ${
                  activeTab === tab.id 
                     ? 'bg-purple-600 text-white shadow-lg' 
                     : 'text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800'
               }`}
            >
               <tab.icon size={14} />
               {tab.label}
            </button>
         ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
         <div className="lg:col-span-8 space-y-10">
            
            {activeTab === 'pool' && (
               <div className="space-y-8 animate-in slide-in-from-right-4 duration-500">
                  <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-10 relative overflow-hidden group shadow-2xl">
                     <div className="relative z-10 flex flex-col gap-8">
                        <div>
                           <p className="text-[10px] font-black uppercase text-zinc-500 tracking-[0.2em] mb-4">Batched Stacking Protocol (PoX-4)</p>
                           <h3 className="text-5xl font-bold text-zinc-100 font-mono tracking-tighter mb-2">
                              {MOCK_CITADEL.pool.totalStacked.toLocaleString()} <span className="text-lg text-zinc-500">STX Pooled</span>
                           </h3>
                        </div>
                        <button className="w-full md:w-64 px-6 py-4 bg-purple-600 hover:bg-purple-500 text-white font-black rounded-2xl text-[10px] uppercase tracking-widest transition-all shadow-xl flex items-center justify-center gap-2 active:scale-[0.98]">
                           <Plus size={16} /> Delegate STX
                        </button>
                     </div>
                  </div>
               </div>
            )}

            {activeTab === 'bounties' && (
               <div className="space-y-8 animate-in slide-in-from-right-4 duration-500">
                  <div className="grid grid-cols-1 gap-4">
                     {bounties.map((bounty) => (
                        <div key={bounty.id} className={`p-8 bg-zinc-950 border border-zinc-900 rounded-[2.5rem] flex flex-col md:flex-row justify-between items-start md:items-center gap-6 group hover:border-orange-500/30 transition-all ${selectedBounty?.id === bounty.id ? 'border-orange-500/50 ring-1 ring-orange-500/20' : ''}`}>
                           <div className="flex items-center gap-6">
                              <div className={`w-14 h-14 rounded-2xl bg-zinc-900 border border-zinc-800 flex items-center justify-center transition-all ${bounty.status === 'Open' ? 'text-green-500' : 'text-zinc-700'}`}>
                                 {bounty.category === 'Core' ? <Terminal size={24} /> : bounty.category === 'UI/UX' ? <Sparkles size={24} /> : <Lock size={24} />}
                              </div>
                              <div>
                                 <div className="flex items-center gap-3">
                                    <span className="text-[9px] font-black uppercase text-zinc-600 tracking-widest bg-zinc-900 px-2 py-0.5 rounded">v1.2.0 Enhancement</span>
                                    <span className={`text-[9px] font-black uppercase px-2 py-0.5 rounded-full border ${
                                       bounty.difficulty === 'Elite' ? 'text-red-500 border-red-500/20' : 
                                       bounty.difficulty === 'Intermediate' ? 'text-orange-500 border-orange-500/20' : 
                                       'text-green-500 border-green-500/20'
                                    }`}>{bounty.difficulty}</span>
                                    {bounty.status === 'Claimed' && <span className="text-[9px] font-black uppercase text-zinc-100 bg-orange-600 px-2 py-0.5 rounded">Claimed</span>}
                                 </div>
                                 <h4 className="text-lg font-bold text-zinc-100 mt-1">{bounty.title}</h4>
                                 <p className="text-xs text-zinc-500 mt-1">{bounty.description}</p>
                              </div>
                           </div>
                           <div className="flex items-center gap-6 w-full md:w-auto justify-between border-t md:border-t-0 pt-4 md:pt-0">
                              <div className="text-right">
                                 <p className="text-[10px] font-black uppercase text-zinc-600">Reward</p>
                                 <p className="text-lg font-mono font-bold text-orange-500">{bounty.reward}</p>
                              </div>
                              <button 
                                 disabled={bounty.status === 'Claimed'}
                                 onClick={() => auditBounty(bounty)}
                                 className="px-6 py-3 bg-zinc-900 hover:bg-zinc-800 disabled:opacity-50 text-zinc-300 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all border border-zinc-800 flex items-center gap-2"
                              >
                                 <Search size={14} /> Audit & Claim
                              </button>
                           </div>
                        </div>
                     ))}
                  </div>
                  
                  {selectedBounty && (
                     <div className="bg-zinc-900/40 border border-orange-500/30 rounded-[3rem] p-10 space-y-8 animate-in zoom-in duration-300 relative overflow-hidden">
                        <div className="absolute top-0 right-0 p-8 opacity-[0.03] rotate-12">
                           <Award size={200} />
                        </div>
                        <div className="relative z-10 space-y-6">
                           <div className="flex items-center justify-between">
                              <div className="flex items-center gap-3">
                                 <div className="p-3 bg-orange-500/10 rounded-2xl text-orange-500">
                                    <Hammer size={24} />
                                 </div>
                                 <h3 className="text-2xl font-black italic uppercase tracking-tighter">Bounty Protocol Audit</h3>
                              </div>
                              <button onClick={() => setSelectedBounty(null)} className="p-2 text-zinc-600 hover:text-white transition-colors"><X size={24} /></button>
                           </div>

                           <div className="bg-zinc-950 border border-zinc-900 rounded-[2rem] p-8 min-h-[300px] relative">
                              {isAuditing ? (
                                 <div className="flex flex-col items-center justify-center h-full gap-4 py-20">
                                    <Loader2 className="animate-spin text-orange-500" size={32} />
                                    <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 animate-pulse">Sovereign Sentinel Auditing Codebase...</p>
                                 </div>
                              ) : (
                                 <div className="prose prose-invert max-w-none text-xs leading-relaxed text-zinc-400 font-mono whitespace-pre-wrap selection:bg-orange-500/40">
                                    {bountyAudit}
                                 </div>
                              )}
                           </div>
                           
                           {!isAuditing && (
                              <div className="flex gap-4">
                                 <button onClick={handleClaim} className="flex-1 py-4 bg-orange-600 hover:bg-orange-500 text-white font-black rounded-2xl text-[10px] uppercase tracking-widest transition-all shadow-xl shadow-orange-600/20 active:scale-[0.98]">
                                    Initialize Work Channel
                                 </button>
                                 <button className="px-6 py-4 bg-zinc-900 hover:bg-zinc-800 text-zinc-500 rounded-2xl text-[10px] font-black uppercase tracking-widest transition-all border border-zinc-800">
                                    <MessageSquare size={16} />
                                 </button>
                              </div>
                           )}
                        </div>
                     </div>
                  )}
               </div>
            )}

            {(activeTab === 'treasury' || activeTab === 'governance' || activeTab === 'members') && (
               <div className="p-20 text-center opacity-30 italic">Module synchronized with Citadel mesh.</div>
            )}
         </div>

         <div className="lg:col-span-4 space-y-8">
            <div className="bg-purple-600 border border-purple-500 rounded-[2.5rem] p-8 text-white relative overflow-hidden group shadow-2xl">
               <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:scale-110 transition-transform">
                  <Network size={100} />
               </div>
               <div className="relative z-10 space-y-6">
                  <h4 className="text-xl font-black italic uppercase tracking-tighter mb-4 flex items-center gap-2">
                     <Share2 size={20} /> Shared Hub
                  </h4>
                  <div className="p-4 bg-white/10 rounded-2xl border border-white/10">
                     <p className="text-[9px] font-black uppercase opacity-70 mb-1">Treasury (Multi-Sig)</p>
                     <p className="text-lg font-mono font-bold">{MOCK_CITADEL.treasuryBalance} BTC</p>
                  </div>
                  <p className="text-xs font-medium leading-relaxed opacity-80">
                     "Architects set the vision. Initiates follow the path. Together we out-compete the legacy system."
                  </p>
               </div>
            </div>
         </div>
      </div>
    </div>
  );
};

export default CitadelManager;
