
import React from 'react';
import { LayoutDashboard, CreditCard, Repeat, Shield, Grid } from 'lucide-react';

interface BottomNavProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

const BottomNav: React.FC<BottomNavProps> = ({ activeTab, setActiveTab }) => {
  const items = [
    { id: 'dashboard', icon: LayoutDashboard, label: 'Wallet' },
    { id: 'payments', icon: CreditCard, label: 'Pay' },
    { id: 'bridge', icon: Repeat, label: 'Bridge' },
    { id: 'security', icon: Shield, label: 'Security' },
    { id: 'menu', icon: Grid, label: 'Menu' },
  ];

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-background/80 backdrop-blur-xl border-t border-border pb-safe-area-inset px-6 h-20 z-[90] flex items-center justify-between shadow-[0_-10px_30px_rgba(0,0,0,0.5)]">
      {items.map((item) => (
        <button
          key={item.id}
          onClick={() => setActiveTab(item.id)}
          className={`relative flex flex-col items-center gap-1.5 transition-all px-4 py-2 rounded-2xl active:scale-90 ${
            activeTab === item.id ? 'text-bitcoin' : 'text-muted'
          }`}
        >
          {activeTab === item.id && (
            <div className="absolute inset-0 bg-bitcoin/10 rounded-2xl animate-in fade-in zoom-in duration-300" />
          )}
          <item.icon size={20} strokeWidth={activeTab === item.id ? 2.5 : 2} className="relative z-10" />
          <span className="text-[9px] font-bold uppercase tracking-[0.15em] relative z-10">{item.label}</span>
        </button>
      ))}
    </nav>
  );
};

export default BottomNav;
