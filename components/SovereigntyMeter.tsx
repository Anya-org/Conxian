
import React, { useContext } from 'react';
import { ArrowRight, Crown, Star, Medal, AlertTriangle } from 'lucide-react';
import { AppContext } from '../context';

interface Quest {
  id: string;
  label: string;
  points: number;
  completed: boolean;
  category: 'Security' | 'Privacy' | 'Yield' | 'Community';
}

interface SovereigntyMeterProps {
  score?: number;
}

const SovereigntyMeter: React.FC<SovereigntyMeterProps> = ({ score }) => {
  const context = useContext(AppContext);
  const isHotWallet = context?.state.walletConfig?.type === 'hot';
  const sovereigntyScore = score ?? context?.state.sovereigntyScore ?? 0;
  const isTorActive = context?.state.isTorActive ?? false;

  // Dynamic quests based on wallet state
  const MOCK_QUESTS: Quest[] = [
    { id: 'wallet_setup', label: 'Initialize Wallet', points: 10, completed: true, category: 'Security' },
    { id: 'node', label: 'Connect Local Node', points: 30, completed: sovereigntyScore > 80, category: 'Security' },
    { id: 'hardware', label: 'Migrate to Hardware', points: 40, completed: !isHotWallet, category: 'Security' },
    { id: 'citadel', label: 'Join a Citadel', points: 20, completed: !!context?.state.activeCitadel, category: 'Community' },
    { id: 'tor', label: 'Enable Tor Routing', points: 20, completed: isTorActive, category: 'Privacy' },
  ];

  const currentXP = MOCK_QUESTS.reduce((acc, q) => q.completed ? acc + q.points : acc, 0);
  const totalXP = MOCK_QUESTS.reduce((acc, q) => acc + q.points, 0);
  const level = Math.floor(currentXP / 25) + 1;
  
  let rankName = 'Initiate';
  if (level > 2) rankName = 'Citadel Guard';
  if (level > 4) rankName = 'Sovereign';

  return (
    <div className="bg-surface-100 border border-border rounded-[2.5rem] p-8 space-y-8 shadow-2xl relative overflow-hidden group">
      <div className={`absolute -top-12 -right-12 w-40 h-40 blur-3xl rounded-full transition-all pointer-events-none ${isHotWallet ? 'bg-bitcoin/5' : 'bg-success/10'}`} />
      
      <div className="flex items-center justify-between relative z-10">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 bg-surface-200 border border-bitcoin/20 rounded-2xl flex items-center justify-center shadow-inner group-hover:border-bitcoin/50 transition-all">
             {rankName === 'Sovereign' ? <Crown className="text-bitcoin fill-bitcoin/20" size={28} /> : <Medal className="text-bitcoin" size={28} />}
          </div>
          <div className="space-y-0.5">
            <h3 className="font-bold text-base text-white tracking-tight flex items-center gap-2">
              {rankName}
            </h3>
            <p className="text-[10px] text-muted font-bold uppercase tracking-widest">Sovereignty Status</p>
          </div>
        </div>
        <div className="text-right">
           <span className="text-[10px] bg-bitcoin text-black px-2.5 py-1 rounded-lg font-bold uppercase tracking-wider shadow-lg shadow-bitcoin/20">LVL {level}</span>
        </div>
      </div>

      <div className="space-y-3">
        <div className="flex justify-between text-[10px] font-bold uppercase tracking-widest text-muted px-1">
          <span className="text-bitcoin">{currentXP} XP</span>
          <span>Next Milestone: {totalXP} XP</span>
        </div>
        <div className="w-full h-2.5 bg-surface-200 rounded-full overflow-hidden p-0.5 border border-border">
          <div 
            className="h-full bg-bitcoin rounded-full transition-all duration-1000 shadow-custom-bitcoin"
            style={{ width: `${(currentXP / totalXP) * 100}%` }}
          />
        </div>
      </div>

      {/* Warning for Hot Wallets */}
      {isHotWallet && (
         <div className="bg-bitcoin/5 border border-bitcoin/10 p-5 rounded-2xl flex items-start gap-4">
            <AlertTriangle size={18} className="text-bitcoin shrink-0 mt-0.5" />
            <div className="space-y-1">
               <p className="text-[10px] font-bold text-bitcoin uppercase tracking-wider">Security Risk: Browser Enclave</p>
               <p className="text-[10px] text-muted leading-relaxed font-medium">
                  Your keys are software-stored. Integrate a <span className="text-white font-bold">Hardware Vault</span> to achieve Maximum Sovereignty.
               </p>
            </div>
         </div>
      )}

      <div className="space-y-4">
        <div className="flex items-center gap-3 px-1">
          <h4 className="text-[10px] font-bold uppercase text-muted tracking-[0.2em]">Sovereignty Quests</h4>
          <div className="h-px flex-1 bg-border/50" />
        </div>
        <div className="grid gap-3">
          {MOCK_QUESTS.filter(q => !q.completed).slice(0, 3).map((quest) => (
            <button 
                key={quest.id} 
                type="button"
                aria-label={`Complete quest: ${quest.label}`}
                className="w-full flex items-center justify-between group cursor-pointer p-4 bg-surface-200/50 hover:bg-surface-200 border border-border hover:border-bitcoin/30 rounded-2xl transition-all active:scale-[0.98]"
              >
              <div className="flex items-center gap-4">
                <div className="p-2 bg-surface-100 rounded-xl text-muted group-hover:text-bitcoin transition-colors">
                  <Star size={16} />
                </div>
                <div className="space-y-0.5">
                  <span className="text-xs font-bold text-white block tracking-tight">{quest.label}</span>
                  <span className="text-[9px] font-bold uppercase text-muted tracking-widest">{quest.category}</span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                  <span className="text-[10px] font-mono font-bold text-bitcoin/60 group-hover:text-bitcoin transition-colors">+{quest.points} XP</span>
                  <ArrowRight size={12} className="text-muted group-hover:text-bitcoin group-hover:translate-x-0.5 transition-all" />
                </div>
              </button>
            ))}
        </div>
        {MOCK_QUESTS.every(q => q.completed) && (
           <div className="bg-success/5 border border-success/10 p-4 rounded-2xl text-center">
             <p className="text-[10px] text-success font-bold uppercase tracking-widest">Maximum Sovereignty Achieved</p>
           </div>
        )}
      </div>

      <button type="button" className="w-full py-4 bg-bitcoin hover:bg-bitcoin/90 text-black rounded-2xl text-[10px] font-bold uppercase tracking-[0.2em] transition-all flex items-center justify-center gap-3 active:scale-95 shadow-xl shadow-bitcoin/10">
        Expand Your Enclave <ArrowRight size={16} />
      </button>
    </div>
  );
};

export default SovereigntyMeter;
