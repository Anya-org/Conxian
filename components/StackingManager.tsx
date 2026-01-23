
import React, { useState, useEffect } from 'react';
import { Coins, TrendingUp, Clock, Info, ArrowUpRight, Lock, Unlock, Bot, Loader2, ChevronRight, CheckCircle2, Calendar } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { getAssetInsight } from '../services/gemini';
// Added Asset import to satisfy type requirements for getAssetInsight
import { Asset } from '../types';

const MOCK_HISTORICAL_REWARDS = [
  { cycle: '#90', btc: 0.0011, date: 'Aug 12' },
  { cycle: '#91', btc: 0.0013, date: 'Aug 26' },
  { cycle: '#92', btc: 0.0012, date: 'Sep 09' },
  { cycle: '#93', btc: 0.0015, date: 'Sep 23' },
  { cycle: '#94', btc: 0.0014, date: 'Oct 07' },
  { cycle: '#95', btc: 0.0016, date: 'Oct 21' },
  { cycle: '#96', btc: 0.0014, date: 'Nov 04' },
  { cycle: '#97', btc: 0.0018, date: 'Nov 18' },
];

const StackingManager: React.FC = () => {
  const [isStacking, setIsStacking] = useState(false);
  const [stackAmount, setStackAmount] = useState('5000');
  const [duration, setDuration] = useState(12);
  const [isProcessing, setIsProcessing] = useState(false);
  const [insight, setInsight] = useState<string | null>(null);
  const [isLoadingInsight, setIsLoadingInsight] = useState(false);

  useEffect(() => {
    const fetchInsight = async () => {
      setIsLoadingInsight(true);
      // Fix: Passing a mock Asset object to match the expected signature of getAssetInsight (expects 1 argument of type Asset)
      const res = await getAssetInsight({
        id: 'pox-protocol',
        name: 'Proof of Transfer (PoX)',
        symbol: 'STX',
        balance: 0,
        valueUsd: 0,
        layer: 'Stacks',
        type: 'Native'
      } as Asset);
      setInsight(res);
      setIsLoadingInsight(false);
    };
    fetchInsight();
  }, []);

  const handleStartStacking = () => {
    setIsProcessing(true);
    setTimeout(() => {
      setIsProcessing(false);
      setIsStacking(true);
    }, 2500);
  };

  return (
    <div className="p-8 max-w-5xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-20">
      <header className="flex justify-between items-end">
        <div>
          <h2 className="text-3xl font-bold mb-1 tracking-tight">Stacking (PoX)</h2>
          <p className="text-zinc-500 text-sm">Lock STX to earn native Bitcoin rewards</p>
        </div>
        <div className="flex gap-3">
          <div className="bg-zinc-900/50 border border-zinc-800 px-4 py-2 rounded-xl">
            <p className="text-[10px] text-zinc-600 font-bold uppercase">Estimated APY</p>
            <p className="text-lg font-bold text-green-500">~9.4% <span className="text-[10px] text-zinc-500">in BTC</span></p>
          </div>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          {/* Main Stacking Card */}
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-3xl p-8 relative overflow-hidden">
            <div className="absolute -top-4 -right-4 opacity-5">
              <Coins size={200} />
            </div>
            
            <div className="relative z-10 space-y-8">
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="text-xl font-bold mb-1">Stacking Cycle #98</h3>
                  <div className="flex items-center gap-2 text-zinc-500 text-sm">
                    <Clock size={14} />
                    <span>Next cycle starts in 482 blocks (~3.5 days)</span>
                  </div>
                </div>
                {isStacking && (
                  <div className="bg-green-500/10 text-green-500 border border-green-500/20 px-3 py-1 rounded-full text-xs font-black uppercase tracking-tighter flex items-center gap-1">
                    <CheckCircle2 size={12} /> Active
                  </div>
                )}
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="bg-zinc-950 border border-zinc-900 rounded-2xl p-6">
                  <p className="text-xs font-bold text-zinc-600 uppercase mb-2">You are Stacking</p>
                  <p className="text-3xl font-mono font-bold tracking-tighter">{isStacking ? '5,000' : '0'} <span className="text-zinc-500 text-sm">STX</span></p>
                </div>
                <div className="bg-zinc-950 border border-zinc-900 rounded-2xl p-6">
                  <p className="text-xs font-bold text-zinc-600 uppercase mb-2">Rewards Earned</p>
                  <p className="text-3xl font-mono font-bold text-orange-500 tracking-tighter">{isStacking ? '0.0042' : '0.0000'} <span className="text-zinc-500 text-sm">BTC</span></p>
                </div>
              </div>

              {!isStacking ? (
                <div className="space-y-6 bg-zinc-950/50 p-8 rounded-3xl border border-zinc-900">
                  <div className="space-y-4">
                    <label className="text-xs font-bold text-zinc-500 uppercase">Amount to Lock</label>
                    <div className="flex items-center gap-4">
                      <input 
                        type="number" 
                        value={stackAmount}
                        onChange={(e) => setStackAmount(e.target.value)}
                        className="bg-transparent text-4xl font-bold text-white focus:outline-none w-full"
                      />
                      <button className="text-xs bg-zinc-800 hover:bg-zinc-700 px-3 py-1 rounded-lg text-zinc-400">MAX</button>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <div className="flex justify-between items-center">
                      <label className="text-xs font-bold text-zinc-500 uppercase">Duration ({duration} cycles)</label>
                      <span className="text-xs text-zinc-400">~{duration * 14} days</span>
                    </div>
                    <input 
                      type="range" 
                      min="1" 
                      max="12" 
                      value={duration}
                      onChange={(e) => setDuration(parseInt(e.target.value))}
                      className="w-full accent-orange-500"
                    />
                    <div className="flex justify-between text-[10px] font-bold text-zinc-700 uppercase">
                      <span>1 Cycle</span>
                      <span>6 Cycles</span>
                      <span>12 Cycles</span>
                    </div>
                  </div>

                  <button 
                    onClick={handleStartStacking}
                    disabled={isProcessing}
                    className="w-full bg-orange-600 hover:bg-orange-500 disabled:opacity-50 text-white font-bold py-4 rounded-2xl transition-all shadow-lg shadow-orange-600/20 flex items-center justify-center gap-2 active:scale-[0.98]"
                  >
                    {isProcessing ? <Loader2 size={20} className="animate-spin" /> : <Lock size={20} />}
                    {isProcessing ? 'Broadcasting to Mainnet...' : 'Lock STX and Start Earning'}
                  </button>
                </div>
              ) : (
                <div className="flex gap-3">
                  <button className="flex-1 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 font-bold py-4 rounded-2xl transition-all flex items-center justify-center gap-2">
                    <Unlock size={18} /> Stop Stacking
                  </button>
                  <button className="flex-1 bg-zinc-100 hover:bg-white text-zinc-900 font-bold py-4 rounded-2xl transition-all flex items-center justify-center gap-2">
                    <TrendingUp size={18} /> Compounding On
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* Stacking Analytics Chart */}
          <div className="bg-zinc-900/20 border border-zinc-800 rounded-3xl p-8 space-y-6">
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-bold flex items-center gap-2">
                <TrendingUp size={18} className="text-zinc-500" />
                Yield Performance
              </h3>
              <div className="flex items-center gap-4 text-xs font-bold text-zinc-500">
                <div className="flex items-center gap-2">
                  <div className="w-3 h-3 rounded-full bg-orange-500" />
                  <span>BTC Rewards</span>
                </div>
              </div>
            </div>
            
            <div className="h-64 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={MOCK_HISTORICAL_REWARDS}>
                  <defs>
                    <linearGradient id="colorBtc" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f97316" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#f97316" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#1f1f23" />
                  <XAxis 
                    dataKey="cycle" 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{ fill: '#52525b', fontSize: 10, fontWeight: 700 }} 
                    dy={10}
                  />
                  <YAxis 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{ fill: '#52525b', fontSize: 10, fontWeight: 700 }}
                  />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#09090b', border: '1px solid #27272a', borderRadius: '12px' }}
                    itemStyle={{ color: '#f97316', fontWeight: 700 }}
                    labelStyle={{ color: '#a1a1aa', fontSize: '10px', marginBottom: '4px' }}
                  />
                  <Area 
                    type="monotone" 
                    dataKey="btc" 
                    stroke="#f97316" 
                    strokeWidth={3}
                    fillOpacity={1} 
                    fill="url(#colorBtc)" 
                    animationDuration={1500}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        {/* Right Column: AI & Reward List */}
        <div className="space-y-6">
          <div className="bg-orange-500/5 border border-orange-500/10 rounded-3xl p-7">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-orange-500/20 p-2 rounded-lg">
                <Bot className="text-orange-500" size={18} />
              </div>
              <h3 className="font-bold text-xs uppercase tracking-widest text-orange-500">Stacking Specialist</h3>
            </div>
            
            <div className="text-sm text-zinc-300 leading-relaxed min-h-[250px]">
              {isLoadingInsight ? (
                <div className="flex flex-col items-center justify-center gap-4 py-12 text-zinc-500 italic">
                  <Loader2 className="animate-spin" size={24} />
                  <p className="text-xs uppercase font-bold tracking-widest">Calculating PoX yields...</p>
                </div>
              ) : (
                <div className="space-y-6">
                  <p className="whitespace-pre-wrap leading-relaxed">{insight}</p>
                  <div className="pt-6 border-t border-orange-500/10 space-y-4">
                    <h4 className="text-xs font-bold text-zinc-500 uppercase tracking-widest">Yield Comparison</h4>
                    <div className="space-y-3">
                      <div className="flex justify-between items-center text-xs">
                        <span className="text-zinc-400">Solo Stacking</span>
                        <span className="text-zinc-100 font-mono font-bold">9.8% APY</span>
                      </div>
                      <div className="flex justify-between items-center text-xs">
                        <span className="text-zinc-400">Pool Stacking</span>
                        <span className="text-zinc-100 font-mono font-bold">9.2% APY</span>
                      </div>
                      <div className="flex justify-between items-center text-xs">
                        <span className="text-zinc-400">Liquid Stacking</span>
                        <span className="text-zinc-100 font-mono font-bold">8.5% APY</span>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          <div className="bg-zinc-900/40 border border-zinc-800 rounded-3xl p-7">
            <h4 className="font-bold text-sm mb-4 flex items-center gap-2">
              <HistoryIcon size={16} className="text-zinc-500" />
              Recent Reward History
            </h4>
            <div className="space-y-3">
              {[...MOCK_HISTORICAL_REWARDS].reverse().slice(0, 5).map((item, i) => (
                <div key={i} className="flex justify-between items-center py-2 border-b border-zinc-800/50 last:border-0 group">
                  <div>
                    <p className="text-xs font-bold text-zinc-200 group-hover:text-orange-500 transition-colors">Cycle {item.cycle}</p>
                    <p className="text-[10px] text-zinc-500">{item.date}, 2024</p>
                  </div>
                  <p className="text-xs font-mono font-bold text-orange-500">+{item.btc} BTC</p>
                </div>
              ))}
            </div>
            <button className="w-full mt-4 py-2 text-xs font-bold text-zinc-500 hover:text-zinc-300 transition-colors border border-dashed border-zinc-800 rounded-xl">
              View All History
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

const HistoryIcon = ({ size, className }: { size: number, className?: string }) => (
  <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l4 2"/></svg>
);

export default StackingManager;
