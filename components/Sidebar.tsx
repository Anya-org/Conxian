
import React from 'react';
import { LayoutDashboard, Repeat, Settings, Shield, Zap, Info, UserCheck, Coins, CreditCard, Network, Lock, Crown, TrendingUp, Trophy, BarChart3, Briefcase, Terminal, FlaskConical, Medal, Gavel, Landmark, BookOpen, Package, Rocket, Layers, Castle, Binary, Palette, ShoppingBag, Activity, Globe } from 'lucide-react';

interface SidebarProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab }) => {
  const menuItems = [
    { id: 'dashboard', icon: LayoutDashboard, label: 'Dashboard' },
    { id: 'diagnostics', icon: Activity, label: 'System Health' },
    { id: 'bazaar', icon: ShoppingBag, label: 'Sovereign Bazaar' },
    { id: 'browser', icon: Globe, label: 'Web3 Browser' },
    { id: 'studio', icon: Palette, label: 'Sovereign Studio' },
    { id: 'payments', icon: CreditCard, label: 'Payments' },
    { id: 'utxos', icon: Binary, label: 'Coin Control' },
    { id: 'citadel', icon: Castle, label: 'My Citadel' },
    { id: 'defi', icon: Layers, label: 'DeFi Enclave' },
    { id: 'rewards', icon: Trophy, label: 'Rewards Hub' },
    { id: 'labs', icon: FlaskConical, label: 'Labs Discovery' },
    { id: 'governance', icon: Gavel, label: 'Senate' },
    { id: 'reserves', icon: Landmark, label: 'Reserves' },
    { id: 'investor', icon: Briefcase, label: 'Stakeholder' },
    { id: 'benchmark', icon: BarChart3, label: 'Benchmark' },
    { id: 'docs', icon: BookOpen, label: 'System Manual' },
    { id: 'handoff', icon: Package, label: 'Release Manager' },
    { id: 'deploy', icon: Rocket, label: 'Deploy Network' },
    { id: 'stacking', icon: Coins, label: 'Stacking (PoX)' },
    { id: 'bridge', icon: Repeat, label: 'NTT Bridge' },
    { id: 'identity', icon: UserCheck, label: 'Identity (D.i.D)' },
    { id: 'nodes', icon: Network, label: 'Node Hub' },
    { id: 'privacy', icon: Lock, label: 'Privacy Enclave' },
    { id: 'security', icon: Shield, label: 'Security' },
    { id: 'settings', icon: Settings, label: 'Settings' },
  ];

  return (
    <div className="w-64 h-screen border-r border-border bg-background flex flex-col p-6 sticky top-0 overflow-hidden">
      <div className="flex items-center gap-4 mb-10 group">
        <div className="w-11 h-11 rounded-xl overflow-hidden ring-1 ring-border shadow-xl transition-transform group-hover:scale-105 duration-500">
          <img src="/conxius-logo.svg" alt="Conxius" className="w-full h-full object-cover" />
        </div>
        <div className="space-y-0.5">
          <h1 className="text-xl font-bold tracking-tight text-white leading-none">Conxius</h1>
          <div className="flex items-center gap-2">
            <span className="text-[10px] text-bitcoin font-bold uppercase tracking-wider">Wallet</span>
            <span className="bg-bitcoin/10 text-bitcoin text-[8px] px-1.5 py-0.5 rounded border border-bitcoin/20 font-bold uppercase">v0.3</span>
          </div>
        </div>
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto custom-scrollbar -mr-2 pr-2">
        {menuItems.map((item) => (
          <button
            key={item.id}
            onClick={() => setActiveTab(item.id)}
            className={`w-full flex items-center gap-3.5 px-4 py-2.5 rounded-xl transition-all duration-300 group ${
              activeTab === item.id 
                ? 'bg-bitcoin/10 text-bitcoin border border-bitcoin/20 shadow-lg shadow-bitcoin/5' 
                : 'text-muted hover:text-white hover:bg-surface-200'
            }`}
          >
            <item.icon size={18} className={`transition-colors ${activeTab === item.id ? 'text-bitcoin' : 'text-muted group-hover:text-bitcoin/70'}`} />
            <span className="font-bold text-xs uppercase tracking-wider">{item.label}</span>
          </button>
        ))}
      </nav>

      <div className="mt-6 pt-6 border-t border-border">
        <div className="bg-surface-200 border border-border rounded-2xl p-4 flex items-center gap-3 shadow-inner group transition-colors hover:border-bitcoin/30">
           <div className="p-2.5 bg-bitcoin rounded-xl text-black shadow-lg shadow-bitcoin/20">
              <Medal size={16} />
           </div>
           <div>
              <p className="text-[9px] font-bold uppercase text-muted tracking-widest group-hover:text-bitcoin transition-colors">Sovereign Build</p>
              <p className="text-[10px] font-bold text-white italic">Hardware-Backed</p>
           </div>
        </div>
      </div>
    </div>
  );
};

export default Sidebar;
