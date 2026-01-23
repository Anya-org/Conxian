
import React, { useState, useContext } from 'react';
import { TrendingUp, Layers, ShieldAlert, ExternalLink, Zap, Lock, RefreshCw, Loader2, ArrowRight, Activity, Percent, Network, AlertTriangle, Coins } from 'lucide-react';
import { AreaChart, Area, XAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { MOCK_DEFI_POSITIONS, MOCK_YIELD_DATA, LAYER_COLORS } from '../constants';
import { GoogleGenAI } from "@google/genai";
import { AppContext } from '../context';

const DeFiDashboard: React.FC = () => {
  const appContext = useContext(AppContext);
  const [activeTab, setActiveTab] = useState<'positions' | 'opportunities'>('positions');
  const [riskAnalysis, setRiskAnalysis] = useState<string | null>(null);
  const [analyzingRisk, setAnalyzingRisk] = useState(false);
  const [isZapping, setIsZapping] = useState(false);

  if (!appContext) return null;
  const { mode } = appContext.state;

  const positions = mode === 'simulation' ? MOCK_DEFI_POSITIONS : [];
  const yieldData = mode === 'simulation' ? MOCK_YIELD_DATA : [];
  if (mode === 'sovereign') {
    console.info('DeFi mock data disabled in Sovereign mode');
  }

  const analyzeProtocol = async (protocol: string) => {
    setAnalyzingRisk(true);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: `Analyze the sovereign risk for the Bitcoin DeFi protocol: "${protocol}". 
        Focus on: 
        1. Custody model (DLC vs. Multi-sig). 
        2. L1 Finality dependance. 
        3. Admin key centralization. 
        Keep it brief and technical.`,
      });
      setRiskAnalysis(response.text || "Analysis unavailable.");
    } catch (e) {
      setRiskAnalysis("Network error. Risk assessment defaulted to High.");
    } finally {
      setAnalyzingRisk(false);
    }
  };
  
  const handleZap = () => {
     setIsZapping(true);
     setTimeout(() => setIsZapping(false), 3000);
  };

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3">
            <Layers className="text-purple-500" />
            DeFi Enclave
          </h2>
          <p className="text-zinc-500 text-sm italic">Interact with decentralized finance protocols without sacrificing custody.</p>
        </div>
        <div className="flex gap-4">
           <div className="bg-zinc-900 border border-zinc-800 px-6 py-3 rounded-2xl flex items-center gap-4 shadow-xl">
              <div className="w-12 h-12 bg-green-500/10 rounded-xl flex items-center justify-center text-green-500 border border-green-500/20">
                 <Percent size={24} />
              </div>
              <div>
                 <p className="text-[10px] font-black uppercase text-zinc-500">Blended APY</p>
                 <p className="text-xl font-bold text-zinc-100 font-mono">12.4%</p>
              </div>
           </div>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        
        {/* Main Chart Area */}
        <div className="lg:col-span-8 space-y-8">
           <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8 shadow-2xl relative overflow-hidden">
              <div className="flex justify-between items-center mb-6">
                 <h3 className="text-lg font-bold flex items-center gap-2 text-zinc-200">
                    <Activity size={20} className="text-purple-500" />
                    Yield Landscape
                 </h3>
                 <div className="flex gap-2">
                    <span className="text-[10px] font-bold bg-purple-500/10 text-purple-500 px-2 py-1 rounded border border-purple-500/20 uppercase">Stacks</span>
                    <span className="text-[10px] font-bold bg-blue-500/10 text-blue-500 px-2 py-1 rounded border border-blue-500/20 uppercase">Rootstock</span>
                 </div>
              </div>
              <div className="h-64 w-full">
                 <ResponsiveContainer width="100%" height="100%">
                    {mode === 'sovereign' ? (
                       <div className="flex flex-col items-center justify-center h-full opacity-50 border border-zinc-800 rounded-xl bg-zinc-900/20">
                          <Activity size={32} className="text-zinc-600 mb-2" />
                          <p className="text-xs font-bold text-zinc-500 uppercase tracking-widest">No Yield Data</p>
                       </div>
                    ) : (
                    <AreaChart data={yieldData}>
                       <defs>
                          <linearGradient id="colorYield" x1="0" y1="0" x2="0" y2="1">
                             <stop offset="5%" stopColor="#a855f7" stopOpacity={0.3}/>
                             <stop offset="95%" stopColor="#a855f7" stopOpacity={0}/>
                          </linearGradient>
                       </defs>
                       <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#27272a" />
                       <XAxis 
                          dataKey="month" 
                          axisLine={false} 
                          tickLine={false} 
                          tick={{ fill: '#71717a', fontSize: 10, fontWeight: 700 }} 
                          dy={10}
                       />
                       <Tooltip 
                          contentStyle={{ backgroundColor: '#09090b', border: '1px solid #3f3f46', borderRadius: '12px' }}
                          itemStyle={{ color: '#a855f7', fontWeight: 700 }}
                       />
                       <Area 
                          type="monotone" 
                          dataKey="yield" 
                          stroke="#a855f7" 
                          strokeWidth={3}
                          fillOpacity={1} 
                          fill="url(#colorYield)" 
                       />
                    </AreaChart>
                    )}
                 </ResponsiveContainer>
              </div>
           </div>

           {/* Tabs & Content */}
           <div>
              <div className="flex gap-4 mb-6 border-b border-zinc-800 pb-2">
                 <button 
                    onClick={() => setActiveTab('positions')}
                    className={`pb-2 text-sm font-bold uppercase tracking-widest transition-all ${activeTab === 'positions' ? 'text-purple-500 border-b-2 border-purple-500' : 'text-zinc-500 hover:text-zinc-300'}`}
                 >
                    Active Positions
                 </button>
                 <button 
                    onClick={() => setActiveTab('opportunities')}
                    className={`pb-2 text-sm font-bold uppercase tracking-widest transition-all ${activeTab === 'opportunities' ? 'text-purple-500 border-b-2 border-purple-500' : 'text-zinc-500 hover:text-zinc-300'}`}
                 >
                    Yield Discovery
                 </button>
              </div>

              {activeTab === 'positions' ? (
                 <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {mode === 'sovereign' && positions.length === 0 ? (
                       <div className="col-span-2 flex flex-col items-center justify-center py-12 opacity-50 border border-zinc-800 rounded-3xl bg-zinc-900/20">
                          <Lock size={48} className="text-zinc-700 mb-4" />
                          <p className="text-sm font-bold text-zinc-500 uppercase tracking-widest">No Active Positions</p>
                          <p className="text-xs text-zinc-600 italic mt-2">Connect to sovereign DeFi protocols to view positions.</p>
                       </div>
                    ) : (
                    positions.map((pos) => (
                       <div key={pos.id} className="bg-zinc-950 border border-zinc-800 rounded-3xl p-6 hover:border-zinc-700 transition-all group">
                          <div className="flex justify-between items-start mb-4">
                             <div className="flex items-center gap-3">
                                <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold text-white shadow-lg ${pos.layer === 'Stacks' ? 'bg-purple-600' : 'bg-blue-600'}`}>
                                   {pos.protocol[0]}
                                </div>
                                <div>
                                   <h4 className="font-bold text-zinc-100">{pos.protocol}</h4>
                                   <p className="text-[10px] text-zinc-500 uppercase tracking-widest">{pos.type}</p>
                                </div>
                             </div>
                             <button type="button" onClick={() => analyzeProtocol(pos.protocol)} className="p-2 text-zinc-600 hover:text-purple-500 transition-colors" aria-label="Analyze Protocol Risk">
                                <ShieldAlert size={16} />
                             </button>
                          </div>
                          
                          <div className="space-y-3">
                             <div className="flex justify-between items-center text-xs">
                                <span className="text-zinc-500 font-bold uppercase">Pair</span>
                                <span className="text-zinc-200 font-mono">{pos.pair}</span>
                             </div>
                             <div className="flex justify-between items-center text-xs">
                                <span className="text-zinc-500 font-bold uppercase">Value</span>
                                <span className="text-zinc-200 font-mono">{pos.value}</span>
                             </div>
                             <div className="flex justify-between items-center text-xs">
                                <span className="text-zinc-500 font-bold uppercase">Net APY</span>
                                <span className="text-green-500 font-mono font-bold">{pos.apy}</span>
                             </div>
                          </div>

                          <div className="mt-4 pt-4 border-t border-zinc-900 flex gap-2">
                             <button type="button" className="flex-1 py-2 bg-zinc-900 hover:bg-zinc-800 text-zinc-400 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all">
                                Unstake
                             </button>
                             <button type="button" className="flex-1 py-2 bg-zinc-100 hover:bg-white text-zinc-950 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all">
                                Compound
                             </button>
                          </div>
                       </div>
                    )))}
                 </div>
              ) : (
                 <div className="bg-zinc-950 border border-zinc-800 rounded-3xl p-8 text-center space-y-4">
                    <Zap size={48} className="text-zinc-700 mx-auto" />
                    <p className="text-sm font-bold text-zinc-400">Yield scanner active via local node.</p>
                    <p className="text-xs text-zinc-600">Connecting to Alex, Sovryn, and Bitflow RPCs...</p>
                 </div>
              )}
           </div>
        </div>

        {/* Sidebar / Analysis */}
        <div className="lg:col-span-4 space-y-8">
           
           {/* Risk Analyzer */}
           <div className="bg-purple-600/10 border border-purple-500/20 rounded-[2.5rem] p-8 relative overflow-hidden">
              <div className="flex items-center gap-3 mb-6">
                 <div className="bg-purple-500/20 p-2 rounded-lg">
                    <ShieldAlert className="text-purple-500" size={20} />
                 </div>
                 <h4 className="font-bold text-sm uppercase tracking-widest text-purple-200">Protocol Auditor</h4>
              </div>
              
              <div className="min-h-[200px] text-xs text-purple-100/80 leading-relaxed font-medium">
                 {analyzingRisk ? (
                    <div className="flex flex-col items-center justify-center h-full py-10 gap-3">
                       <Loader2 className="animate-spin text-purple-500" size={24} />
                       <span className="uppercase tracking-widest text-[10px]">Auditing Contracts...</span>
                    </div>
                 ) : riskAnalysis ? (
                    <div className="animate-in fade-in duration-500 whitespace-pre-wrap">
                       {riskAnalysis}
                    </div>
                 ) : (
                    <div className="flex flex-col items-center justify-center h-full py-10 text-center opacity-50">
                       <p>Select a position to audit sovereign risk vectors.</p>
                    </div>
                 )}
              </div>
           </div>

           {/* Sovereign Yield Zap */}
           <div className="bg-gradient-to-br from-orange-600 to-red-600 text-white border border-orange-500 rounded-[2.5rem] p-8 space-y-6 shadow-xl relative overflow-hidden group">
              <div className="absolute -top-4 -right-4 opacity-20 group-hover:scale-110 transition-transform">
                 <Zap size={100} />
              </div>
              <div className="relative z-10">
                 <h4 className="font-black text-xl italic uppercase tracking-tighter mb-2">Sovereign Zap</h4>
                 <p className="text-xs font-medium opacity-90 leading-relaxed mb-6">
                    Bundle Swap + Bridge + Staking into one atomic transaction. 
                 </p>
                 <div className="bg-white/10 p-4 rounded-2xl mb-6 backdrop-blur-sm border border-white/20">
                    <div className="flex justify-between items-center text-[10px] font-black uppercase mb-1">
                       <span>Yield Route</span>
                       <span className="text-green-300">Target: 14% APY</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs font-bold">
                       <span>BTC</span> <ArrowRight size={12} /> <span>sBTC</span> <ArrowRight size={12} /> <Coins size={14} />
                    </div>
                 </div>
                 <button type="button"
                  onClick={handleZap}
                  disabled={isZapping}
                  className="w-full py-4 bg-amber-600 text-white font-black rounded-2xl text-[10px] uppercase tracking-widest hover:bg-amber-500 transition-all shadow-xl active:scale-95 flex items-center justify-center gap-2"
                 >
                    {isZapping ? <Loader2 size={16} className="animate-spin" /> : <Zap size={16} />}
                    {isZapping ? 'Bundling Tx...' : 'One-Click Yield'}
                 </button>
              </div>
           </div>

           {/* Bridge Shortcut */}
           <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8 text-center space-y-4">
              <h4 className="font-bold text-sm text-zinc-200">Need Liquidity?</h4>
              <p className="text-xs text-zinc-500">Move assets between layers instantly via NTT.</p>
              <button className="w-full py-3 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all flex items-center justify-center gap-2">
                 Open Bridge <ExternalLink size={12} />
              </button>
           </div>

        </div>
      </div>
    </div>
  );
};

export default DeFiDashboard;
