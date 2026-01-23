
import React, { useContext } from 'react';
import { LayoutDashboard, CreditCard, Trophy, FlaskConical, Gavel, Landmark, Briefcase, BarChart3, BookOpen, Package, Rocket, Coins, Repeat, UserCheck, Network, Lock, Shield, Settings, X, ChevronRight, LogOut, Zap, Layers, Palette, ShoppingBag, Globe, Activity, Binary, Castle } from 'lucide-react';
import { AppContext } from '../context';

interface MobileMenuProps {
  setActiveTab: (tab: string) => void;
  activeTab: string;
}

const MobileMenu: React.FC<MobileMenuProps> = ({ setActiveTab, activeTab }) => {
  const context = useContext(AppContext);

  const MENU_SECTIONS = [
    {
      title: 'Finance',
      items: [
        { id: 'dashboard', label: 'Wallet', icon: LayoutDashboard },
        { id: 'bazaar', label: 'Bazaar', icon: ShoppingBag },
        { id: 'payments', label: 'Payments', icon: CreditCard },
        { id: 'defi', label: 'DeFi', icon: Layers },
        { id: 'stacking', label: 'Stacking', icon: Coins },
        { id: 'bridge', label: 'Bridge', icon: Repeat },
        { id: 'browser', label: 'Browser', icon: Globe },
        { id: 'utxos', label: 'UTXOs', icon: Binary },
        { id: 'citadel', label: 'Citadel', icon: Castle },
      ]
    },
    {
      title: 'Protocol',
      items: [
        { id: 'studio', label: 'Studio', icon: Palette },
        { id: 'governance', label: 'Senate', icon: Gavel },
        { id: 'labs', label: 'Labs', icon: FlaskConical },
        { id: 'rewards', label: 'Rewards', icon: Trophy },
        { id: 'nodes', label: 'Nodes', icon: Network },
        { id: 'deploy', label: 'Deploy', icon: Rocket },
        { id: 'benchmark', label: 'Benchmark', icon: BarChart3 },
        { id: 'docs', label: 'Docs', icon: BookOpen },
      ]
    },
    {
      title: 'System',
      items: [
        { id: 'identity', label: 'Identity', icon: UserCheck },
        { id: 'privacy', label: 'Privacy', icon: Lock },
        { id: 'security', label: 'Security', icon: Shield },
        { id: 'handoff', label: 'Release', icon: Package },
        { id: 'reserves', label: 'Reserves', icon: Landmark },
        { id: 'investor', label: 'Investor', icon: Briefcase },
        { id: 'diagnostics', label: 'Health', icon: Activity },
        { id: 'settings', label: 'Config', icon: Settings },
      ]
    }
  ];

  return (
    <div className="p-6 pb-32 animate-in slide-in-from-bottom-10 duration-500">
      
      {/* Mobile Header Profile */}
      <div className="bg-surface-100 border border-border p-6 rounded-[2.5rem] mb-8 flex items-center justify-between shadow-2xl relative overflow-hidden">
        <div className="absolute top-0 right-0 -mt-8 -mr-8 w-24 h-24 bg-bitcoin/5 rounded-full blur-2xl" />
        
        <div className="flex items-center gap-4 relative z-10">
           <div className="w-14 h-14 rounded-2xl overflow-hidden ring-1 ring-border shadow-xl">
              <img src="/conxius-logo.svg" alt="Conxius" className="w-full h-full object-cover" />
           </div>
           <div className="space-y-0.5">
              <h3 className="text-lg font-bold text-white tracking-tight">Sovereign Mode</h3>
              <div className="flex items-center gap-2">
                <span className={`w-1.5 h-1.5 rounded-full animate-pulse ${context?.state.isMainnetLive ? 'bg-success' : 'bg-bitcoin'}`} />
                <p className="text-[10px] font-bold text-muted uppercase tracking-wider">
                   {context?.state.isMainnetLive ? 'Mainnet Active' : 'Testnet Alpha'}
                </p>
              </div>
           </div>
        </div>
        <div className="text-right relative z-10">
           <p className="text-[10px] font-bold uppercase text-muted tracking-widest">Score</p>
           <p className="text-2xl font-bold text-bitcoin shadow-bitcoin/20 drop-shadow-sm">{context?.state.sovereigntyScore}</p>
        </div>
      </div>

      <div className="space-y-10">
        {MENU_SECTIONS.map((section, idx) => (
          <div key={idx} className="space-y-4">
            <div className="flex items-center gap-3 px-2">
              <h4 className="text-[10px] font-bold uppercase tracking-[0.25em] text-muted">{section.title}</h4>
              <div className="h-px flex-1 bg-border/50" />
            </div>
            <div className="grid grid-cols-4 gap-4">
              {section.items.map((item) => (
                <button
                  key={item.id}
                  onClick={() => setActiveTab(item.id)}
                  className={`flex flex-col items-center justify-center gap-2.5 p-3 rounded-[1.5rem] border transition-all active:scale-90 aspect-square group ${
                    activeTab === item.id 
                      ? 'bg-bitcoin text-black border-bitcoin shadow-lg shadow-bitcoin/20' 
                      : 'bg-surface-200 border-border text-muted hover:text-white hover:border-bitcoin/30'
                  }`}
                >
                  <item.icon size={20} className={activeTab === item.id ? 'text-black' : 'text-muted group-hover:text-bitcoin transition-colors'} />
                  <span className={`text-[9px] font-bold uppercase tracking-tight truncate w-full text-center ${activeTab === item.id ? 'text-black' : 'text-muted'}`}>{item.label}</span>
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="mt-12 pt-8 border-t border-border space-y-6">
         <button 
           onClick={() => context?.lockWallet?.()} 
           className="w-full py-4 flex items-center justify-center gap-3 text-red-500 font-bold uppercase text-[10px] tracking-[0.2em] bg-red-500/5 hover:bg-red-500/10 border border-red-500/10 rounded-2xl transition-all active:scale-95"
         >
            <LogOut size={16} /> Lock Enclave
         </button>
         <div className="flex flex-col items-center gap-1">
            <p className="text-[9px] text-muted font-bold uppercase tracking-widest">Conxius OS v0.3</p>
            <div className="w-1 h-1 bg-border rounded-full" />
            <p className="text-[8px] text-muted italic">Secure Hardware Module Active</p>
         </div>
      </div>
    </div>
  );
};

export default MobileMenu;
