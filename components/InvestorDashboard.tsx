
import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area, BarChart, Bar, Cell } from 'recharts';
import { TrendingUp, PieChart, Landmark, Users, Vote, ExternalLink, Loader2, Sparkles, ShieldCheck, DollarSign, BarChart4, Briefcase, Zap, Activity, Sword, Medal, Award, FileText, Target, Scale, History, TrendingDown, ShieldAlert, Binary, AlertTriangle, Fingerprint, Eye } from 'lucide-react';
import { GoogleGenAI } from "@google/genai";
import { getRiskProfileAudit } from '../services/gemini';
import { MOCK_ASSETS } from '../constants';

const TREASURY_ASSETS = [
  { name: 'Bitcoin (L1)', value: '14.2 BTC', usd: '$923,000', change: '+2.4%' },
  { name: 'Stacks (STX)', value: '450,000 STX', usd: '$900,000', change: '+12.1%' },
  { name: 'DAO USDC', value: '250,000 USDC', usd: '$250,000', change: '0%' },
];

const RISK_VECTORS = [
  { id: 'tech', label: 'Protocol Stability', status: 'Hardened', value: 92, color: 'text-green-500' },
  { id: 'liq', label: 'Liquidity Exit', status: 'Fragmented', value: 64, color: 'text-yellow-500' },
  { id: 'reg', label: 'Regulatory Surface', status: 'Low Risk', value: 88, color: 'text-blue-500' },
  { id: 'sec', label: 'Enclave Security', status: 'Verified', value: 98, color: 'text-emerald-500' },
];

const InvestorDashboard: React.FC = () => {
  const [memo, setMemo] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [valuationRange, setValuationRange] = useState('$85M - $115M');
  const [activeVector, setActiveVector] = useState<string | null>(null);

  const runInstitutionalAudit = async () => {
    setIsLoading(true);
    const result = await getRiskProfileAudit(MOCK_ASSETS);
    setMemo(result);
    setIsLoading(false);
  };

  useEffect(() => { runInstitutionalAudit(); }, []);

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <div className="flex items-center gap-3 mb-2">
             <Briefcase className="text-bitcoin" />
             <h2 className="text-3xl font-black tracking-tighter text-white uppercase italic">Research & Risk Enclave</h2>
          </div>
          <p className="text-muted text-sm">Quantifying protocol-native moats and risk-adjusted valuation.</p>
        </div>
        <div className="flex items-center gap-4">
           <div className="bg-surface-200 border border-border px-6 py-4 rounded-[2rem] text-right group hover:border-bitcoin/30 transition-all shadow-2xl">
              <p className="text-[10px] font-black uppercase text-muted tracking-widest mb-1">Pre-Market Evaluation</p>
              <div className="flex items-center gap-2">
                 <span className="text-2xl font-mono font-bold text-bitcoin">{valuationRange}</span>
                 <TrendingUp size={16} className="text-success" />
              </div>
           </div>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        <div className="lg:col-span-8 space-y-10">
          
          {/* Risk Matrix Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
             {RISK_VECTORS.map((vector) => (
                <div 
                  key={vector.id}
                  onClick={() => setActiveVector(vector.id)}
                  className={`p-8 bg-surface-200/40 border rounded-[2.5rem] transition-all cursor-pointer group relative overflow-hidden ${
                    activeVector === vector.id ? 'border-bitcoin/50 bg-bitcoin/5' : 'border-border hover:border-muted'
                  }`}
                >
                   <div className="absolute top-0 right-0 p-6 opacity-5 group-hover:scale-110 transition-transform">
                      {vector.id === 'tech' ? <Binary size={80} /> : vector.id === 'liq' ? <Activity size={80} /> : vector.id === 'reg' ? <Scale size={80} /> : <ShieldCheck size={80} />}
                   </div>
                   <div className="relative z-10 space-y-4">
                      <div className="flex justify-between items-start">
                         <h4 className="text-[10px] font-black uppercase text-muted tracking-widest">{vector.label}</h4>
                         <span className={`text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-background border border-border ${vector.color}`}>
                            {vector.status}
                         </span>
                      </div>
                      <div className="flex items-baseline gap-2">
                         <span className="text-4xl font-mono font-bold text-white">{vector.value}</span>
                         <span className="text-xs font-bold text-muted">/ 100</span>
                      </div>
                      <div className="w-full h-1 bg-background rounded-full overflow-hidden">
                         <div className={`h-full transition-all duration-1000 ${vector.id === 'liq' ? 'bg-warning' : 'bg-bitcoin'}`} style={{ width: `${vector.value}%` }} />
                      </div>
                   </div>
                </div>
             ))}
          </div>

          {/* CRO Research Terminal */}
          <div className="bg-surface-200 border border-border rounded-[3rem] p-1 shadow-2xl overflow-hidden">
             <div className="bg-background rounded-[2.8rem] flex flex-col min-h-[600px]">
                <div className="p-8 border-b border-border bg-surface-200/20 flex items-center justify-between">
                   <div className="flex items-center gap-3">
                      <FileText size={20} className="text-bitcoin" />
                      <h3 className="text-xs font-black uppercase tracking-widest text-muted font-mono italic">CRO_STRATEGIC_AUDIT_2024</h3>
                   </div>
                   <div className="flex items-center gap-4">
                      <button type="button" onClick={runInstitutionalAudit} className="text-[10px] font-black uppercase text-orange-500 hover:text-orange-400 transition-all flex items-center gap-2">
                         <RefreshCw size={14} className={isLoading ? 'animate-spin' : ''} />
                         Refine Analysis
                      </button>
                   </div>
                </div>
                
                <div className="flex-1 p-10 font-serif text-sm text-zinc-300 leading-relaxed overflow-y-auto custom-scrollbar relative">
                   {isLoading ? (
                      <div className="flex flex-col items-center justify-center h-full gap-6 py-20">
                         <Loader2 className="animate-spin text-orange-500" size={48} />
                         <p className="text-sm font-black uppercase tracking-[0.3em] text-zinc-500">Deconstructing Protocol Risks...</p>
                      </div>
                   ) : memo ? (
                      <div className="animate-in fade-in slide-in-from-bottom-4 duration-700">
                         <div className="bg-orange-600/10 border border-orange-500/20 p-6 rounded-3xl mb-8 flex items-center gap-4">
                            <ShieldAlert className="text-orange-500 shrink-0" size={24} />
                            <p className="text-xs italic text-orange-200">
                               <strong>Warning:</strong> Valuation is sensitive to L1 congestion. Current fees suggest a 4.2% discount on NTT liquidity depth.
                            </p>
                         </div>
                         <div className="whitespace-pre-wrap selection:bg-orange-500/40 leading-[1.8] drop-shadow-sm">{memo}</div>
                      </div>
                   ) : null}
                </div>
             </div>
          </div>
        </div>

        <div className="lg:col-span-4 space-y-8">
           {/* Treasury Health */}
           <div className="bg-zinc-950 border border-zinc-800 rounded-[2.5rem] p-8 space-y-8 shadow-xl">
              <h4 className="text-xs font-black uppercase text-zinc-500 tracking-widest flex items-center gap-2">
                 <Landmark size={16} className="text-orange-500" /> Treasury Exposure
              </h4>
              <div className="space-y-4">
                 {TREASURY_ASSETS.map((asset, i) => (
                    <div key={i} className="flex justify-between items-center p-5 bg-zinc-900/50 rounded-2xl border border-zinc-800 group hover:border-orange-500/20 transition-all">
                       <div>
                          <p className="text-[10px] font-black uppercase text-zinc-600">{asset.name}</p>
                          <p className="text-sm font-bold text-zinc-100">{asset.value}</p>
                       </div>
                       <div className="text-right">
                          <p className="text-xs font-mono font-bold text-zinc-400">{asset.usd}</p>
                          <p className={`text-[10px] font-black ${asset.change.startsWith('+') ? 'text-green-500' : 'text-zinc-500'}`}>{asset.change}</p>
                       </div>
                    </div>
                 ))}
              </div>
           </div>

           {/* Institutional Bull Case */}
           <div className="bg-orange-600 border border-orange-500 rounded-[2.5rem] p-8 text-white relative overflow-hidden group shadow-2xl shadow-orange-600/30">
              <div className="absolute top-0 right-0 p-8 opacity-20 group-hover:scale-110 transition-transform">
                 <Medal size={120} />
              </div>
              <div className="relative z-10">
                 <h4 className="text-xl font-black italic uppercase tracking-tighter mb-4">Investment Thesis</h4>
                 <p className="text-xs font-medium leading-relaxed italic opacity-90 mb-8">
                    "Conxius captures the 'Bitcoin Multi-Layer' renaissance. By integrating NTT natively, it creates an exit-liquidity moat that CEXs cannot match without sacrificing their custodial margins."
                 </p>
                 <button type="button" className="w-full bg-white text-orange-600 font-black py-4 rounded-2xl text-[10px] uppercase tracking-widest hover:bg-zinc-100 transition-all shadow-xl">
                    Download Full PDF Report
                 </button>
              </div>
           </div>

           {/* Exit Strategy Monitor */}
           <div className="bg-zinc-950 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6">
              <h4 className="font-bold text-sm text-zinc-400 flex items-center gap-2">
                 <Target size={18} className="text-blue-500" />
                 Market Depth Vectors
              </h4>
              <div className="space-y-4 pt-4">
                 <div className="flex justify-between items-center border-b border-zinc-900 pb-3">
                    <span className="text-[10px] font-black uppercase text-zinc-600">Integrator Yield</span>
                    <span className="text-xs font-mono font-bold text-green-500">14.2% APY</span>
                 </div>
                 <div className="flex justify-between items-center border-b border-zinc-900 pb-3">
                    <span className="text-[10px] font-black uppercase text-zinc-600">Sovereign Retention</span>
                    <span className="text-xs font-mono font-bold text-zinc-200">88.4%</span>
                 </div>
                 <div className="flex justify-between items-center">
                    <span className="text-[10px] font-black uppercase text-zinc-600">Exit Volatility</span>
                    <span className="text-xs font-mono font-bold text-orange-500">Moderate</span>
                 </div>
              </div>
           </div>
        </div>
      </div>
    </div>
  );
};

const RefreshCw = ({ size, className }: { size: number, className?: string }) => (
  <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M3 21v-5h5"/></svg>
);

export default InvestorDashboard;
