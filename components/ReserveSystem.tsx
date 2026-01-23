
import React, { useState } from 'react';
import { Landmark, ShieldCheck, TrendingUp, AlertCircle, RefreshCw, ExternalLink, Bot, Loader2, Sparkles, BarChart3, Activity, ShieldAlert, History } from 'lucide-react';
import { MOCK_RESERVES } from '../constants';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';

const ReserveSystem: React.FC = () => {
  const [isVerifying, setIsVerifying] = useState(false);
  const [lastAudit, setLastAudit] = useState('14m ago');

  const totalReservesValue = 42100000; // Mock $42M
  const tvlValue = 40500000; // Mock $40.5M
  const reserveRatio = (totalReservesValue / tvlValue * 100).toFixed(2);

  const handleVerify = () => {
    setIsVerifying(true);
    setTimeout(() => {
      setIsVerifying(false);
      setLastAudit('Just now');
    }, 2500);
  };

  const chartData = [
    { name: 'Liquid BTC Backing', value: 45 },
    { name: 'Stacks PoX Yield', value: 25 },
    { name: 'Rootstock Peg', value: 20 },
    { name: 'NTT Liquidity Cushion', value: 10 },
  ];
  const COLORS = ['#f97316', '#a855f7', '#2563eb', '#10b981'];

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3">
            <Landmark className="text-orange-500" />
            Sovereign Reserve Engine
          </h2>
          <p className="text-zinc-500 text-sm italic">Verifiable Proof of Reserves (PoR) for all wrapped and bridged assets.</p>
        </div>
        <div className="flex gap-4">
           <div className="bg-zinc-900 border border-zinc-800 px-6 py-3 rounded-2xl flex items-center gap-4">
              <div className="w-12 h-12 bg-green-500 rounded-xl flex items-center justify-center text-white shadow-lg">
                 <ShieldCheck size={24} />
              </div>
              <div>
                 <p className="text-[10px] font-black uppercase text-zinc-500">Aggregate Reserve Ratio</p>
                 <div className="flex items-center gap-2">
                    <p className="text-xl font-bold text-green-500 font-mono">{reserveRatio}%</p>
                    <span className="text-[10px] text-zinc-500 font-bold uppercase">(Over-collateralized)</span>
                 </div>
              </div>
           </div>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        <div className="lg:col-span-8 space-y-10">
           {/* Main Status Grid */}
           <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {MOCK_RESERVES.map((res, i) => (
                 <div key={i} className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6 group hover:border-orange-500/30 transition-all">
                    <div className="flex justify-between items-start">
                       <div>
                          <p className="text-[10px] font-black uppercase text-zinc-500 tracking-widest">{res.asset} Backing</p>
                          <h4 className="text-2xl font-black text-zinc-100 mt-1">{res.collateralRatio}%</h4>
                       </div>
                       <span className="px-3 py-1 bg-green-500/10 text-green-500 rounded-full text-[10px] font-black uppercase border border-green-500/20">{res.status}</span>
                    </div>
                    
                    <div className="space-y-2">
                       <div className="flex justify-between text-[10px] font-bold text-zinc-600 uppercase">
                          <span>Supply: {res.totalSupplied} BTC</span>
                          <span>Reserves: {res.totalReserves} BTC</span>
                       </div>
                       <div className="w-full h-1.5 bg-zinc-950 rounded-full overflow-hidden">
                          <div className="h-full bg-orange-500" style={{ width: `${Math.min(res.collateralRatio, 100)}%` }} />
                       </div>
                    </div>
                    
                    <button className="w-full py-3 bg-zinc-950 border border-zinc-900 rounded-xl text-[10px] font-black uppercase text-zinc-500 hover:text-orange-500 hover:border-orange-500/30 transition-all flex items-center justify-center gap-2">
                       Audit On-Chain Proof <ExternalLink size={12} />
                    </button>
                 </div>
              ))}
           </div>

           {/* Proof of Reserves Terminal */}
           <div className="bg-black border border-zinc-800 rounded-[3rem] p-1 shadow-2xl overflow-hidden group">
              <div className="bg-zinc-950 rounded-[2.8rem] flex flex-col min-h-[400px]">
                 <div className="p-8 border-b border-zinc-900 bg-zinc-900/20 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                       <Activity size={18} className="text-orange-500" />
                       <h3 className="text-xs font-black uppercase tracking-widest text-zinc-400 font-mono">LIVE_COLLATERAL_MONITOR</h3>
                    </div>
                    <div className="flex items-center gap-4">
                       <span className="text-[10px] text-zinc-600 font-mono uppercase italic">Last Global Audit: {lastAudit}</span>
                       <button onClick={handleVerify} disabled={isVerifying} className="text-orange-500 hover:text-orange-400 transition-all flex items-center gap-2 bg-orange-500/10 px-4 py-2 rounded-xl border border-orange-500/20 text-[10px] font-black uppercase">
                          {isVerifying ? <Loader2 size={12} className="animate-spin" /> : <RefreshCw size={12} />}
                          Trigger Verification
                       </button>
                    </div>
                 </div>
                 
                 <div className="flex-1 p-8 font-mono text-[11px] text-zinc-500 leading-relaxed overflow-y-auto custom-scrollbar">
                    <p className="text-zinc-700">[SYSTEM] PULLING MERKLE ROOT FROM BITCOIN BLOCK #873,042...</p>
                    <p className="text-green-500">[SUCCESS] L-BTC ASSETS MATCH BITCOIN SCRIPT_PUBKEY_HASH</p>
                    <p className="text-green-500">[SUCCESS] ROOTSTOCK PEG IN-SYNC | FEDERATION QUORUM (11/15) OK</p>
                    <p className="text-blue-500">[INFO] NTT LIQUIDITY POOL DETECTED: 550 BTC VERIFIED IN MULTI-SIG</p>
                    <p className="text-zinc-700 mt-4 border-t border-zinc-900 pt-4">[SYSTEM] GENERATING ATTESTATION CERTIFICATE #42-AF-93...</p>
                 </div>
              </div>
           </div>
        </div>

        <div className="lg:col-span-4 space-y-8">
           {/* Asset Allocation Pie */}
           <div className="bg-zinc-950 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6 shadow-xl">
              <h4 className="text-xs font-black uppercase text-zinc-500 tracking-widest flex items-center gap-2">
                 <PieChartIcon size={16} className="text-orange-500" /> Reserve Allocation
              </h4>
              <div className="h-64 w-full">
                 <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                       <Pie
                          data={chartData}
                          innerRadius={60}
                          outerRadius={80}
                          paddingAngle={5}
                          dataKey="value"
                       >
                          {chartData.map((entry, index) => (
                             <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                          ))}
                       </Pie>
                       <Tooltip 
                         contentStyle={{ backgroundColor: '#09090b', border: '1px solid #27272a', borderRadius: '12px', fontSize: '10px' }}
                         itemStyle={{ color: '#e5e5e5' }}
                       />
                    </PieChart>
                 </ResponsiveContainer>
              </div>
              <div className="space-y-2">
                 {chartData.map((d, i) => (
                    <div key={i} className="flex justify-between items-center text-[10px] font-bold">
                       <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full" style={{ backgroundColor: COLORS[i] }} />
                          <span className="text-zinc-500">{d.name}</span>
                       </div>
                       <span className="text-zinc-200">{d.value}%</span>
                    </div>
                 ))}
              </div>
           </div>

           {/* Risk Warning */}
           <div className="bg-orange-600 border border-orange-500 rounded-[2.5rem] p-8 text-white relative overflow-hidden group shadow-2xl shadow-orange-600/30">
              <div className="absolute top-0 right-0 p-8 opacity-20 group-hover:scale-110 transition-transform">
                 <ShieldAlert size={120} />
              </div>
              <div className="relative z-10">
                 <h4 className="text-xl font-black italic uppercase tracking-tighter mb-4">Risk Safeguard</h4>
                 <p className="text-xs font-medium leading-relaxed italic opacity-90 mb-8">
                    "Our Reserve Engine utilizes decentralized attestation from 19 independent Guardians. In case of a peg-failure on any layer, the protocol triggers a 48-hour Circuit Breaker."
                 </p>
                 <div className="p-4 bg-white/10 rounded-2xl border border-white/20">
                    <p className="text-[10px] font-black uppercase mb-1">Cushion Health</p>
                    <div className="flex items-center gap-2">
                       <span className="text-2xl font-bold">4.2M</span>
                       <span className="text-xs">Sats Buffered</span>
                    </div>
                 </div>
              </div>
           </div>

           {/* Treasury History */}
           <div className="bg-zinc-950 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6">
              <h4 className="font-bold text-sm text-zinc-400 flex items-center gap-2">
                 <History size={18} className="text-blue-500" />
                 Audit History
              </h4>
              <div className="space-y-4 pt-4">
                 {[
                   { date: 'Oct 24', event: 'NTT Pool Rebalance', delta: '+4.2 BTC' },
                   { date: 'Oct 22', event: 'L-BTC Peg Verify', delta: 'OK' },
                   { date: 'Oct 19', event: 'Rootstock Audit', delta: 'OK' },
                 ].map((h, i) => (
                    <div key={i} className="flex justify-between items-center border-b border-zinc-900 pb-3 last:border-0">
                       <div>
                          <p className="text-[10px] font-black uppercase text-zinc-600">{h.date}</p>
                          <p className="text-xs font-bold text-zinc-200">{h.event}</p>
                       </div>
                       <span className="text-[10px] font-mono font-bold text-green-500">{h.delta}</span>
                    </div>
                 ))}
              </div>
           </div>
        </div>
      </div>
    </div>
  );
};

const PieChartIcon = ({ size, className }: { size: number, className?: string }) => (
  <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
);

export default ReserveSystem;
