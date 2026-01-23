import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar, Legend } from 'recharts';
import { Trophy, Target, ShieldAlert, Cpu, BarChart3, Bot, Loader2, Sparkles, Zap, Globe, TrendingUp, AlertCircle, ChevronRight, Scale } from 'lucide-react';
import { GoogleGenAI } from "@google/genai";

const RADAR_DATA = [
  { subject: 'Sovereignty', Conxius: 98, IndustryAvg: 45, NicheCompetitor: 85 },
  { subject: 'Multi-Layer', Conxius: 95, IndustryAvg: 30, NicheCompetitor: 60 },
  { subject: 'Privacy', Conxius: 92, IndustryAvg: 20, NicheCompetitor: 75 },
  { subject: 'UX/AI', Conxius: 90, IndustryAvg: 85, NicheCompetitor: 40 },
  { subject: 'Fees', Conxius: 88, IndustryAvg: 50, NicheCompetitor: 70 },
];

const COMPARISON_METRICS = [
  { feature: 'Self-Hosted RPC', conxius: true, legacy: false, web3: false, niche: 'Partial' },
  { feature: 'Native Wormhole NTT', conxius: true, legacy: false, web3: 'Wrapped Only', niche: false },
  { feature: 'Tor Routing (Default)', conxius: true, legacy: false, web3: false, niche: true },
  { feature: 'Integrated Bitcoin L2s', conxius: '7+', legacy: '1-2', web3: 'Eth-focused', niche: '2-3' },
  { feature: 'Fee Transparency', conxius: 'Zero-Cost Model', legacy: 'Hidden Spreads', web3: 'High Swap Fees', niche: 'Basic' },
];

const Benchmarking: React.FC = () => {
  const [advice, setAdvice] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const getStrategicAdvice = async () => {
    setIsLoading(true);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: "Benchmark Conxius Wallet (Sovereign, Multi-layer, Local-first) against the current wallet industry. Advise on how to stay ahead regarding upcoming Bitcoin tech like BitVM, OP_CAT, and expansion into the Nostr ecosystem.",
        config: {
          systemInstruction: "You are the Chief Strategy Officer of Conxius. You provide sharp, institutional-grade advice on maintaining a technical moat in the Bitcoin ecosystem. Your focus is on self-sovereignty as a competitive advantage.",
        }
      });
      setAdvice(response.text);
    } catch (e) {
      setAdvice("Strategic intelligence feed interrupted. Maintain local node synchronization.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    getStrategicAdvice();
  }, []);

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-8 animate-in fade-in duration-500 pb-24">
      <header className="flex justify-between items-end">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Ecosystem Benchmark</h2>
          <p className="text-zinc-500 text-sm">Competitive intelligence vs. Industry Standards.</p>
        </div>
        <div className="flex items-center gap-3">
           <div className="bg-zinc-900 border border-zinc-800 px-4 py-2 rounded-xl flex items-center gap-2">
              <Trophy size={16} className="text-orange-500" />
              <span className="text-[10px] font-black uppercase text-zinc-400">Status: Dominant</span>
           </div>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-8">
          {/* Radar Chart Section */}
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8">
            <h3 className="text-lg font-bold mb-8 flex items-center gap-2">
              <BarChart3 size={20} className="text-zinc-500" />
              Sovereignty Moat Visualization
            </h3>
            <div className="h-80 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <RadarChart cx="50%" cy="50%" outerRadius="80%" data={RADAR_DATA}>
                  <PolarGrid stroke="#27272a" />
                  <PolarAngleAxis dataKey="subject" tick={{ fill: '#71717a', fontSize: 10, fontWeight: 700 }} />
                  <PolarRadiusAxis angle={30} domain={[0, 100]} tick={false} axisLine={false} />
                  <Radar name="Conxius" dataKey="Conxius" stroke="#f97316" fill="#f97316" fillOpacity={0.6} />
                  <Radar name="Industry Average" dataKey="IndustryAvg" stroke="#52525b" fill="#52525b" fillOpacity={0.3} />
                  <Legend />
                  <Tooltip contentStyle={{ backgroundColor: '#09090b', border: '1px solid #27272a', borderRadius: '12px' }} />
                </RadarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Comparison Table */}
          <div className="bg-zinc-950 border border-zinc-800 rounded-[2.5rem] overflow-hidden">
            <div className="p-6 border-b border-zinc-900 bg-zinc-900/20">
              <h3 className="text-sm font-bold uppercase tracking-widest text-zinc-500">Feature Parity Matrix</h3>
            </div>
            <table className="w-full text-left">
              <thead className="bg-zinc-900/10 text-[10px] font-black uppercase text-zinc-600 tracking-widest">
                <tr>
                  <th className="px-6 py-4">Capability</th>
                  <th className="px-6 py-4 text-orange-500">Conxius</th>
                  <th className="px-6 py-4">Legacy</th>
                  <th className="px-6 py-4">General Web3</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-900">
                {COMPARISON_METRICS.map((m, i) => (
                  <tr key={i} className="hover:bg-zinc-900/20 transition-colors">
                    <td className="px-6 py-5 text-xs font-medium text-zinc-300">{m.feature}</td>
                    <td className="px-6 py-5 text-xs">
                      {typeof m.conxius === 'boolean' ? (
                        <div className="w-5 h-5 bg-orange-500/20 rounded-full flex items-center justify-center text-orange-500">
                          <Zap size={10} fill="currentColor" />
                        </div>
                      ) : <span className="text-orange-500 font-bold">{m.conxius}</span>}
                    </td>
                    <td className="px-6 py-5 text-xs text-zinc-600">{m.legacy ? 'Yes' : 'No'}</td>
                    <td className="px-6 py-5 text-xs text-zinc-600">{m.web3.toString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="space-y-6">
          {/* Strategic Advice Panel */}
          <div className="bg-orange-600 border border-orange-500 rounded-[2.5rem] p-8 text-white relative overflow-hidden group shadow-2xl shadow-orange-600/20">
            <div className="absolute top-0 right-0 p-8 opacity-10 group-hover:scale-110 transition-transform">
               <Target size={100} />
            </div>
            <div className="relative z-10">
              <h4 className="text-lg font-bold mb-4 flex items-center gap-2">
                <Sparkles size={18} />
                CSO Strategic Advisory
              </h4>
              <div className="text-xs leading-relaxed font-medium space-y-4 opacity-90 max-h-[400px] overflow-y-auto custom-scrollbar pr-2">
                {isLoading ? (
                  <div className="flex flex-col items-center justify-center py-12 gap-3">
                    <Loader2 className="animate-spin" />
                    <span className="uppercase tracking-widest text-[10px] font-black">Synthesizing Alpha...</span>
                  </div>
                ) : (
                  <div className="whitespace-pre-wrap">{advice}</div>
                )}
              </div>
              <button onClick={getStrategicAdvice} className="mt-8 w-full bg-white text-orange-600 font-bold py-3 rounded-2xl text-[10px] uppercase tracking-widest hover:bg-zinc-100 transition-all flex items-center justify-center gap-2">
                <RefreshCw size={14} /> Refresh Analysis
              </button>
            </div>
          </div>

          {/* Risk Tracker */}
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6">
            <h4 className="font-bold text-sm flex items-center gap-2 text-zinc-400">
              <ShieldAlert size={18} className="text-yellow-500" />
              Industry Risk Watch
            </h4>
            <div className="space-y-4">
              <div className="p-4 bg-zinc-950 border border-zinc-900 rounded-2xl space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-[10px] font-bold text-zinc-500 uppercase">CEX Liquidity Risk</span>
                  <span className="text-[10px] font-bold text-red-500 uppercase">High</span>
                </div>
                <div className="w-full h-1 bg-zinc-900 rounded-full">
                  <div className="w-[85%] h-full bg-red-500" />
                </div>
              </div>
              <div className="p-4 bg-zinc-950 border border-zinc-900 rounded-2xl space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-[10px] font-bold text-zinc-500 uppercase">Sovereign Moat Depth</span>
                  <span className="text-[10px] font-bold text-green-500 uppercase">Deep</span>
                </div>
                <div className="w-full h-1 bg-zinc-900 rounded-full">
                  <div className="w-[98%] h-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.4)]" />
                </div>
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

export default Benchmarking;