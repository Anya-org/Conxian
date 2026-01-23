
import React, { useState } from 'react';
import { Vote, ShieldCheck, Scale, MessageSquare, ChevronRight, Gavel, Award, Zap, Loader2, Sparkles, Filter, AlertCircle, Users, UserPlus, Undo2, Fingerprint, Info, Globe2, Briefcase, Backpack, Wallet, Landmark } from 'lucide-react';
import { GovernanceService, OpsPersona, PERSONA_CONFIGS } from '../services/governance';

interface Proposal {
  id: string;
  title: string;
  description: string;
  status: 'Active' | 'Passed' | 'Rejected';
  tierRequired: number;
  votesFor: number;
  votesAgainst: number;
  endsIn: string;
}

interface Delegation {
  from: string;
  weight: number;
  timestamp: string;
}

const MOCK_PROPOSALS: Proposal[] = [
  { 
    id: 'SLP-025', 
    title: 'Implement BitVM Bridge Logic', 
    description: 'Enable trust-minimized bridging between Bitcoin L1 and Conxius Enclave using BitVM-based fraud proofs.', 
    status: 'Active', 
    tierRequired: 2, 
    votesFor: 1420, 
    votesAgainst: 42, 
    endsIn: '2d 14h' 
  },
  { 
    id: 'SLP-026', 
    title: 'Increase Stacks Reward Multiplier', 
    description: 'Modify the PoX logic to prioritize Sovereign Pass holders with 99.9% node uptime.', 
    status: 'Active', 
    tierRequired: 1, 
    votesFor: 890, 
    votesAgainst: 310, 
    endsIn: '4d 2h' 
  },
  { 
    id: 'SLP-024', 
    title: 'Wormhole NTT Root Rotation', 
    description: 'Rotate the attestation root for the NTT bridge to include three new institutional guardians.', 
    status: 'Passed', 
    tierRequired: 3, 
    votesFor: 2100, 
    votesAgainst: 12, 
    endsIn: 'Ended' 
  },
];

const MOCK_RECEIVED_DELEGATIONS: Delegation[] = [
  { from: 'did:btc:xyz...789', weight: 1.5, timestamp: '2024-10-20' },
  { from: 'did:btc:abc...456', weight: 0.8, timestamp: '2024-10-21' },
];

const GovernancePortal: React.FC = () => {
  const [selectedProposal, setSelectedProposal] = useState<Proposal | null>(MOCK_PROPOSALS[0]);
  const [isVoting, setIsVoting] = useState(false);
  const [isDelegating, setIsDelegating] = useState(false);
  const [delegatedTo, setDelegatedTo] = useState<string | null>(null);
  const [delegationInput, setDelegationInput] = useState('');
  const [receivedDelegations, setReceivedDelegations] = useState<Delegation[]>(MOCK_RECEIVED_DELEGATIONS);
  const [showDelegationModal, setShowDelegationModal] = useState(false);
  const [opsMode, setOpsMode] = useState<'view' | 'setup'>( 'view' ); // Toggle for Ops Setup
  const [selectedPersona, setSelectedPersona] = useState<OpsPersona | null>(null);

  const baseTier = 3; // Citadel Guard Tier
  const delegatedWeight = receivedDelegations.reduce((acc, curr) => acc + curr.weight, 0);
  const totalVotingPower = (baseTier + delegatedWeight).toFixed(2);

  const handleVote = async () => {
    if (delegatedTo) return;
    setIsVoting(true);
    await new Promise(r => setTimeout(r, 2000));
    setIsVoting(false);
  };

  const handleDelegate = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsDelegating(true);
    await new Promise(r => setTimeout(r, 1500));
    setDelegatedTo(delegationInput);
    setIsDelegating(false);
    setShowDelegationModal(false);
    setDelegationInput('');
  };

  const revokeDelegation = () => {
    setDelegatedTo(null);
  };

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3">
            <Gavel className="text-orange-500" />
            Governance & Treasury
          </h2>
          <p className="text-zinc-500 text-sm italic">Protocol management via proof-of-contribution and delegated trust.</p>
        </div>
        <div className="flex gap-4">
           <div className="bg-zinc-900 border border-zinc-800 px-6 py-3 rounded-2xl flex items-center gap-4">
              <div className="w-12 h-12 bg-orange-500 rounded-xl flex items-center justify-center text-white shadow-lg">
                 <Award size={24} />
              </div>
              <div>
                 <p className="text-[10px] font-black uppercase text-zinc-500">Aggregate Voting Power</p>
                 <div className="flex items-center gap-2">
                    <p className="text-xl font-bold text-zinc-100 font-mono">{totalVotingPower}</p>
                    {delegatedWeight > 0 && (
                       <span className="text-[10px] text-green-500 font-bold">(+{delegatedWeight} Delegated)</span>
                    )}
                 </div>
              </div>
           </div>
           <button 
               type="button"
               onClick={() => setOpsMode('setup')} 
               className="bg-zinc-100 hover:bg-white text-black px-6 py-3 rounded-2xl font-black text-xs uppercase tracking-widest transition-all shadow-xl active:scale-95 flex items-center gap-2"
           >
               <Briefcase size={16} /> Ops Setup
           </button>
        </div>
      </header>

      {/* Ops Persona Setup Modal */}
      {opsMode === 'setup' && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/95 backdrop-blur-xl animate-in fade-in duration-300 overflow-y-auto">
             <div className="w-full max-w-5xl bg-zinc-950 border border-zinc-900 rounded-[3rem] p-10 space-y-8 relative shadow-2xl">
                <div className="flex justify-between items-start">
                    <div className="space-y-2">
                        <h3 className="text-3xl font-black tracking-tighter text-zinc-100">Initialize Ops Governance</h3>
                        <p className="text-sm text-zinc-500">Select a structural template for your Sovereign Entity.</p>
                    </div>
                    <button 
                        type="button"
                        onClick={() => setOpsMode('view')} 
                        className="p-4 hover:bg-zinc-900 rounded-full text-zinc-500"
                        aria-label="Close setup"
                    >
                        <Undo2 />
                    </button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                    {(Object.keys(PERSONA_CONFIGS) as OpsPersona[]).map(key => {
                        const p = PERSONA_CONFIGS[key];
                        const isSelected = selectedPersona === key;
                        return (
                            <button 
                                key={key}
                                type="button"
                                onClick={() => setSelectedPersona(key)}
                                className={`p-8 rounded-[2rem] border text-left transition-all space-y-4 group relative overflow-hidden ${
                                    isSelected ? 'bg-zinc-900 border-orange-500 ring-2 ring-orange-500/20' : 'bg-zinc-900/40 border-zinc-800 hover:bg-zinc-900 hover:border-zinc-700'
                                }`}
                                aria-pressed={isSelected}
                            >
                                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center text-white mb-4 ${
                                    key === 'brics' ? 'bg-red-500' : 
                                    key === 'business' ? 'bg-blue-600' :
                                    key === 'nomad' ? 'bg-purple-600' : 
                                    key === 'unbanked' ? 'bg-green-600' : 'bg-zinc-600'
                                }`}>
                                    {key === 'brics' && <Globe2 size={24} />}
                                    {key === 'business' && <Landmark size={24} />}
                                    {key === 'nomad' && <Backpack size={24} />}
                                    {key === 'unbanked' && <Wallet size={24} />}
                                    {key === 'retail' && <UserPlus size={24} />}
                                </div>
                                <div>
                                    <h4 className="text-lg font-black text-zinc-100">{p.name}</h4>
                                    <p className="text-[10px] font-mono text-orange-500 mt-1 uppercase tracking-wider">{p.minSigners}-of-{p.totalSigners} • {p.defaults.backup.toUpperCase()} Backup</p>
                                </div>
                                <p className="text-xs text-zinc-400 leading-relaxed min-h-[3rem]">{p.description}</p>
                                <div className="flex flex-wrap gap-2">
                                    {p.features.slice(0, 2).map((f, i) => (
                                        <span key={i} className="text-[9px] bg-zinc-950 px-2 py-1 rounded-md text-zinc-500 border border-zinc-900">{f}</span>
                                    ))}
                                </div>
                            </button>
                        );
                    })}
                </div>

                {selectedPersona && (
                    <div className="flex justify-end pt-4 border-t border-zinc-900">
                        <button 
                            type="button"
                            className="bg-orange-600 hover:bg-orange-500 text-white px-12 py-4 rounded-2xl font-black text-xs uppercase tracking-widest shadow-xl shadow-orange-600/20 transition-all flex items-center gap-3 animate-in fade-in slide-in-from-bottom-4"
                            onClick={async () => {
                                const svc = new GovernanceService();
                                await svc.initializeOpsWallet(PERSONA_CONFIGS[selectedPersona]);
                                alert(`Initialized ${PERSONA_CONFIGS[selectedPersona].name} Structure!`);
                                setOpsMode('view');
                            }}
                        >
                            <ShieldCheck size={18} /> Deploy Structure
                        </button>
                    </div>
                )}
             </div>
          </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        {/* Left Column: Proposals & Delegation Management */}
        <div className="lg:col-span-5 space-y-10">
           
           {/* Delegation Control Card */}
           <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6 shadow-xl relative overflow-hidden group">
              <div className="absolute top-0 right-0 p-8 opacity-5">
                 <Users size={80} />
              </div>
              <div className="relative z-10">
                 <h3 className="text-xs font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2 mb-6">
                    <Fingerprint size={16} className="text-orange-500" />
                    Delegation Control
                 </h3>
                 
                 {delegatedTo ? (
                    <div className="p-5 bg-orange-500/10 border border-orange-500/20 rounded-2xl space-y-4 animate-in slide-in-from-top-2">
                       <div className="flex justify-between items-start">
                          <div>
                             <p className="text-[10px] font-black uppercase text-orange-500">Status: Outbound Delegation</p>
                             <p className="text-sm font-mono font-bold text-zinc-200 mt-1 truncate w-48">{delegatedTo}</p>
                          </div>
                          <button 
                            type="button"
                            onClick={revokeDelegation}
                            className="p-2 hover:bg-orange-500/20 rounded-lg text-orange-500 transition-colors"
                            aria-label="Revoke delegation"
                          >
                             <Undo2 size={18} />
                          </button>
                       </div>
                       <p className="text-[10px] text-zinc-500 italic">Your voting power is currently being exercised by this address.</p>
                    </div>
                 ) : (
                    <div className="space-y-4">
                       <p className="text-xs text-zinc-400 leading-relaxed italic">Delegate your NFT voting weight to a trusted technical expert or a community multi-sig.</p>
                       <button 
                        type="button"
                        onClick={() => setShowDelegationModal(true)}
                        className="w-full py-3 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-[10px] font-black uppercase tracking-widest border border-zinc-700 transition-all flex items-center justify-center gap-2"
                       >
                          <UserPlus size={16} /> Manage Delegation
                       </button>
                    </div>
                 )}

                 <div className="mt-8 pt-6 border-t border-zinc-800">
                    <p className="text-[10px] font-black uppercase text-zinc-600 mb-4">Inbound Weight ({receivedDelegations.length})</p>
                    <div className="space-y-2">
                       {receivedDelegations.map((d, i) => (
                          <div key={i} className="flex justify-between items-center text-[10px] bg-zinc-950 p-2.5 rounded-xl border border-zinc-900">
                             <span className="font-mono text-zinc-500">{d.from.slice(0, 16)}...</span>
                             <span className="font-bold text-orange-500">+{d.weight} Weight</span>
                          </div>
                       ))}
                    </div>
                 </div>
              </div>
           </div>

           <div className="space-y-4">
              <div className="flex items-center justify-between px-4">
                 <h3 className="text-xs font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
                    <Filter size={14} /> Active Measures
                 </h3>
                 <span className="text-[10px] font-bold text-orange-500">{MOCK_PROPOSALS.length} Protocols</span>
              </div>
              <div className="space-y-4">
                 {MOCK_PROPOSALS.map((p) => (
                    <button 
                     key={p.id}
                     type="button"
                     onClick={() => setSelectedProposal(p)}
                     className={`w-full p-6 rounded-[2rem] border text-left transition-all group ${
                       selectedProposal?.id === p.id 
                       ? 'bg-zinc-900 border-orange-500/50 shadow-2xl scale-[1.02]' 
                       : 'bg-zinc-950 border-zinc-900 hover:border-zinc-800'
                     }`}
                     aria-pressed={selectedProposal?.id === p.id}
                    >
                       <div className="flex justify-between items-start mb-4">
                          <span className="text-[10px] font-mono font-black text-zinc-500 bg-zinc-900 px-2 py-1 rounded">{p.id}</span>
                          <span className={`text-[10px] font-black uppercase px-2 py-1 rounded-full ${
                             p.status === 'Active' ? 'bg-green-500/10 text-green-500' : 'bg-zinc-800 text-zinc-500'
                          }`}>{p.status}</span>
                       </div>
                       <h4 className="font-bold text-zinc-100 mb-2 group-hover:text-orange-500 transition-colors">{p.title}</h4>
                       <div className="flex items-center gap-4 mt-4">
                          <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-500">
                             <Zap size={12} className="text-orange-500" /> Tier {p.tierRequired}+
                          </div>
                          <div className="flex items-center gap-1.5 text-[10px] font-bold text-zinc-500">
                             <Scale size={12} /> {p.votesFor + p.votesAgainst} Weight
                          </div>
                       </div>
                    </button>
                 ))}
              </div>
           </div>
        </div>

        {/* Right Column: Detailed View */}
        <div className="lg:col-span-7">
           {selectedProposal ? (
              <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3rem] p-10 space-y-10 animate-in slide-in-from-right-4 duration-500 sticky top-24">
                 <div className="space-y-4">
                    <div className="flex items-center gap-3">
                       <Scale size={24} className="text-orange-500" />
                       <h3 className="text-3xl font-black tracking-tighter text-zinc-100">{selectedProposal.title}</h3>
                    </div>
                    <p className="text-sm text-zinc-400 leading-relaxed italic">{selectedProposal.description}</p>
                 </div>

                 <div className="grid grid-cols-2 gap-6">
                    <div className="bg-zinc-950 p-6 rounded-3xl border border-zinc-900">
                       <p className="text-[10px] font-black uppercase text-zinc-500 mb-2">Voting Progress</p>
                       <div className="flex justify-between items-end mb-2">
                          <span className="text-2xl font-mono font-bold text-green-500">{(selectedProposal.votesFor / (selectedProposal.votesFor + selectedProposal.votesAgainst) * 100).toFixed(1)}%</span>
                          <span className="text-[10px] font-bold text-zinc-600">Quorum Progress</span>
                       </div>
                       <div className="w-full h-2 bg-zinc-900 rounded-full overflow-hidden flex">
                          <div className="h-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.4)]" style={{ width: `${(selectedProposal.votesFor / (selectedProposal.votesFor + selectedProposal.votesAgainst) * 100)}%` }} />
                          <div className="h-full bg-red-500/50" style={{ width: `${(selectedProposal.votesAgainst / (selectedProposal.votesFor + selectedProposal.votesAgainst) * 100)}%` }} />
                       </div>
                    </div>
                    <div className="bg-zinc-950 p-6 rounded-3xl border border-zinc-900 flex flex-col justify-center">
                       <p className="text-[10px] font-black uppercase text-zinc-500 mb-2">Time Remaining</p>
                       <p className="text-2xl font-mono font-bold text-zinc-100">{selectedProposal.endsIn}</p>
                    </div>
                 </div>

                 <div className="p-6 bg-orange-500/5 border border-orange-500/10 rounded-3xl space-y-4">
                    <div className="flex items-center gap-3">
                       <ShieldCheck size={20} className="text-orange-500" />
                       <h4 className="text-xs font-black uppercase text-zinc-300">Sovereign Verification</h4>
                    </div>
                    {delegatedTo ? (
                       <div className="flex items-center gap-3 text-orange-500 font-bold text-xs italic">
                          <AlertCircle size={16} />
                          Power delegated to: {delegatedTo.slice(0, 8)}...
                       </div>
                    ) : (
                       <p className="text-xs text-zinc-500 leading-relaxed">
                          Your active weight of <span className="text-zinc-200 font-bold">{totalVotingPower}</span> allows you to influence this protocol change. 
                          Votes are cryptographically signed using your secure enclave.
                       </p>
                    )}
                 </div>

                 <div className="flex gap-4">
                    <button 
                       type="button"
                       onClick={handleVote}
                       disabled={isVoting || !!delegatedTo}
                       className="flex-1 bg-zinc-100 hover:bg-white text-zinc-950 font-black py-5 rounded-2xl text-xs uppercase tracking-widest transition-all shadow-xl flex items-center justify-center gap-3 disabled:opacity-50 disabled:grayscale active:scale-95"
                    >
                       {isVoting ? <Loader2 size={16} className="animate-spin" /> : <ShieldCheck size={16} />}
                       Affirm Measure
                    </button>
                    <button 
                       type="button"
                       onClick={handleVote}
                       disabled={isVoting || !!delegatedTo}
                       className="flex-1 bg-zinc-900 hover:bg-zinc-800 text-zinc-400 font-black py-5 rounded-2xl text-xs uppercase tracking-widest transition-all border border-zinc-800 flex items-center justify-center gap-3 disabled:opacity-50 active:scale-95"
                    >
                       {isVoting ? <Loader2 size={16} className="animate-spin" /> : <AlertCircle size={16} />}
                       Dissent
                    </button>
                 </div>
              </div>
           ) : (
              <div className="h-full flex flex-col items-center justify-center text-zinc-800 opacity-50 space-y-4">
                 <Scale size={84} />
                 <p className="text-sm font-black uppercase tracking-widest">Audit a measure to continue</p>
              </div>
           )}
        </div>
      </div>

      {/* Delegation Management Modal */}
      {showDelegationModal && (
         <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/90 backdrop-blur-md animate-in fade-in duration-300">
            <div className="w-full max-w-md bg-zinc-950 border border-zinc-800 rounded-[3rem] p-10 space-y-8 relative shadow-2xl">
               <div className="text-center space-y-2">
                  <h3 className="text-2xl font-bold text-zinc-100">Delegation Hub</h3>
                  <p className="text-xs text-zinc-500">Empower a delegate to vote on your behalf.</p>
               </div>
               
               <form onSubmit={handleDelegate} className="space-y-6">
                  <div className="space-y-2">
                     <label className="text-[10px] font-black uppercase text-zinc-600 ml-1">Delegate DID / Address</label>
                     <div className="relative">
                        <input 
                           autoFocus
                           value={delegationInput}
                           onChange={e => setDelegationInput(e.target.value)}
                           placeholder="did:btc:..."
                           className="w-full bg-zinc-900 border border-zinc-800 rounded-2xl py-4 px-5 font-mono text-sm text-zinc-200 focus:outline-none focus:border-orange-500/50"
                        />
                        <Users className="absolute right-4 top-1/2 -translate-y-1/2 text-zinc-700" size={18} />
                     </div>
                  </div>

                  <div className="bg-zinc-900/50 border border-zinc-800 p-5 rounded-2xl flex gap-4">
                     <Info size={20} className="text-blue-500 shrink-0" />
                     <p className="text-[10px] text-zinc-500 leading-relaxed italic">
                        Delegation is fluid. You can revoke it at any time to reclaim your voting rights. The delegate receives only voting weight, never custody of assets.
                     </p>
                  </div>

                  <div className="flex gap-4">
                     <button 
                        type="button"
                        onClick={() => setShowDelegationModal(false)}
                        className="flex-1 py-4 bg-zinc-900 hover:bg-zinc-800 text-zinc-500 rounded-2xl text-[10px] font-black uppercase tracking-widest border border-zinc-800 transition-all"
                     >
                        Cancel
                     </button>
                     <button 
                        disabled={isDelegating || !delegationInput}
                        type="submit"
                        className="flex-[2] bg-orange-600 hover:bg-orange-500 disabled:opacity-50 text-white font-black py-4 rounded-2xl text-[10px] uppercase tracking-widest transition-all shadow-xl shadow-orange-600/20 flex items-center justify-center gap-3"
                     >
                        {isDelegating ? <Loader2 className="animate-spin" size={16} /> : <ShieldCheck size={16} />}
                        Confirm Delegation
                     </button>
                  </div>
               </form>
            </div>
         </div>
      )}
    </div>
  );
};

export default GovernancePortal;
