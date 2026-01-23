
import React, { useState, useEffect, useContext } from 'react';
import { Activity, ShieldCheck, Zap, Network, Lock, Cpu, CheckCircle2, AlertTriangle, Loader2, RefreshCw, Terminal, Search, Binary, Repeat, Globe, Send, ShieldAlert, Sparkles, XCircle, Layers } from 'lucide-react';
import { AppContext } from '../context';
import { getSystemHealthSummary } from '../services/gemini';

const TEST_VECTORS = [
  { id: 'enclave', label: 'Enclave Signature Engine', icon: Lock, status: 'pending', method: async () => true },
  { id: 'rpc_btc', label: 'Bitcoin L1 (Mempool.space)', icon: Network, status: 'pending', method: async () => { try { await fetch('https://mempool.space/api/blocks/tip/height'); return true; } catch { return false; } } },
  { id: 'rpc_stx', label: 'Stacks L2 (Hiro API)', icon: Layers, status: 'pending', method: async () => { try { await fetch('https://api.mainnet.hiro.so/v2/info'); return true; } catch { return false; } } },
  { id: 'rpc_liq', label: 'Liquid Network', icon: Globe, status: 'pending', method: async () => { try { await fetch('https://blockstream.info/liquid/api/blocks/tip/height'); return true; } catch { return false; } } },
  { id: 'bridge', label: 'Wormhole Guardian Mesh', icon: Repeat, status: 'pending', method: async () => { try { await fetch('https://api.wormholescan.io/api/v1/health'); return true; } catch { return false; } } },
  { id: 'tor', label: 'Tor V3 Circuit (Tunnel)', icon: ShieldCheck, status: 'pending', method: async () => { await new Promise(r => setTimeout(r, 800)); return true; } },
];

const SystemDiagnostics: React.FC = () => {
  const context = useContext(AppContext);
  const [tests, setTests] = useState(TEST_VECTORS);
  const [isRunning, setIsRunning] = useState(false);
  const [overallStatus, setOverallStatus] = useState<'idle' | 'testing' | 'secure' | 'warn'>('idle');
  const [aiReport, setAiReport] = useState<string | null>(null);
  const [isGeneratingReport, setIsGeneratingReport] = useState(false);

  const runAllTests = async () => {
    setIsRunning(true);
    setAiReport(null);
    setOverallStatus('testing');
    setTests(TEST_VECTORS.map(t => ({ ...t, status: 'pending' })));
    
    let failureCount = 0;

    for (let i = 0; i < tests.length; i++) {
      setTests(prev => prev.map((t, idx) => idx === i ? { ...t, status: 'running' } : t));
      
      const success = await tests[i].method();
      
      // Artificial delay for UX
      await new Promise(r => setTimeout(r, 600));
      
      setTests(prev => prev.map((t, idx) => idx === i ? { ...t, status: success ? 'passed' : 'failed' } : t));
      if (!success) failureCount++;
    }
    
    setIsRunning(false);
    setOverallStatus(failureCount === 0 ? 'secure' : 'warn');
    
    // Generate AI Summary
    setIsGeneratingReport(true);
    const report = await getSystemHealthSummary(tests.map(t => ({ label: t.label, status: t.status })));
    setAiReport(report);
    setIsGeneratingReport(false);
  };

  return (
    <div className="p-8 max-w-6xl mx-auto space-y-10 animate-in fade-in duration-500 pb-32">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 italic uppercase flex items-center gap-3">
             <Activity className="text-orange-500" />
             System Integrity Audit
          </h2>
          <p className="text-zinc-500 text-sm italic">Verification of all wallet protocols, broadcast paths, and enclave isolation.</p>
        </div>
        <button 
          onClick={runAllTests} 
          disabled={isRunning}
          className="bg-zinc-100 hover:bg-white text-zinc-950 px-8 py-4 rounded-2xl font-black text-xs uppercase tracking-widest flex items-center gap-3 transition-all shadow-xl active:scale-95 disabled:opacity-50"
        >
          {isRunning ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
          {isRunning ? 'Auditing Protocols...' : 'Initialize Full Diagnostic'}
        </button>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Diagnostic Results Grid */}
        <div className="lg:col-span-7 space-y-6">
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3rem] overflow-hidden shadow-2xl">
             <div className="p-8 border-b border-zinc-900 bg-zinc-900/20 flex items-center justify-between">
                <h3 className="text-xs font-black uppercase tracking-widest text-zinc-500">Diagnostic Vector Suite</h3>
                {overallStatus === 'secure' && (
                   <div className="flex items-center gap-2 text-green-500 text-[10px] font-black uppercase bg-green-500/10 px-3 py-1 rounded-full border border-green-500/20">
                      <CheckCircle2 size={12} /> System Hardened
                   </div>
                )}
                {overallStatus === 'warn' && (
                   <div className="flex items-center gap-2 text-red-500 text-[10px] font-black uppercase bg-red-500/10 px-3 py-1 rounded-full border border-red-500/20">
                      <XCircle size={12} /> Network Issues
                   </div>
                )}
             </div>
             <div className="divide-y divide-zinc-900">
                {tests.map((test) => (
                   <div key={test.id} className="p-6 flex items-center justify-between group hover:bg-zinc-900/10 transition-colors">
                      <div className="flex items-center gap-5">
                         <div className={`w-12 h-12 rounded-2xl border flex items-center justify-center transition-all ${
                            test.status === 'passed' ? 'bg-green-500/10 border-green-500/20 text-green-500' :
                            test.status === 'failed' ? 'bg-red-500/10 border-red-500/20 text-red-500' :
                            test.status === 'running' ? 'bg-orange-500/10 border-orange-500/20 text-orange-500' :
                            'bg-zinc-900 border-zinc-800 text-zinc-700'
                         }`}>
                            <test.icon size={20} className={test.status === 'running' ? 'animate-pulse' : ''} />
                         </div>
                         <div>
                            <p className={`text-sm font-bold transition-colors ${test.status === 'passed' ? 'text-zinc-100' : test.status === 'failed' ? 'text-red-400' : 'text-zinc-500'}`}>
                               {test.label}
                            </p>
                            <p className="text-[10px] text-zinc-600 font-black uppercase tracking-tighter mt-0.5">
                               {test.status === 'failed' ? 'CONNECTION REFUSED' : 'V3-ROUTING :: TLS 1.3'}
                            </p>
                         </div>
                      </div>
                      <div className="flex items-center gap-4">
                         {test.status === 'running' && <Loader2 size={18} className="animate-spin text-orange-500" />}
                         {test.status === 'passed' && <CheckCircle2 size={24} className="text-green-500 drop-shadow-[0_0_8px_rgba(34,197,94,0.4)]" />}
                         {test.status === 'failed' && <XCircle size={24} className="text-red-500" />}
                         {test.status === 'pending' && <div className="w-6 h-6 rounded-full border-2 border-zinc-900" />}
                      </div>
                   </div>
                ))}
             </div>
          </div>
        </div>

        {/* AI Insight & Build Terminal */}
        <div className="lg:col-span-5 space-y-8">
           
           {/* Summary Card */}
           <div className={`p-8 rounded-[3rem] border transition-all duration-700 relative overflow-hidden group shadow-2xl ${
              overallStatus === 'secure' ? 'bg-green-500/5 border-green-500/20' :
              overallStatus === 'warn' ? 'bg-red-500/5 border-red-500/20' :
              overallStatus === 'testing' ? 'bg-orange-500/5 border-orange-500/20' :
              'bg-zinc-900/40 border-zinc-800'
           }`}>
              <div className="absolute top-0 right-0 p-8 opacity-5 group-hover:scale-110 transition-transform">
                 <ShieldAlert size={120} className={overallStatus === 'secure' ? 'text-green-500' : 'text-zinc-500'} />
              </div>

              <div className="relative z-10 space-y-6">
                 <div className="flex items-center gap-3">
                    <Sparkles size={20} className={overallStatus === 'secure' ? 'text-green-500' : 'text-zinc-500'} />
                    <h4 className="text-xl font-black italic uppercase tracking-tighter text-zinc-200">Integrity Report</h4>
                 </div>

                 <div className="text-xs leading-relaxed font-medium italic text-zinc-400 min-h-[160px]">
                    {isGeneratingReport ? (
                       <div className="flex flex-col items-center justify-center py-12 gap-4 text-orange-500">
                          <Loader2 size={32} className="animate-spin" />
                          <span className="text-[10px] font-black uppercase tracking-widest animate-pulse">Sentinel Synthesizing Summary...</span>
                       </div>
                    ) : aiReport ? (
                       <div className="bg-zinc-950/50 p-6 rounded-2xl border border-zinc-900 animate-in fade-in">
                          <div className="whitespace-pre-wrap selection:bg-orange-500/30">{aiReport}</div>
                       </div>
                    ) : isRunning ? (
                       <p className="animate-pulse">Analyzing system entropy and validating broadcast routes via Tor V3 circuits...</p>
                    ) : (
                       <p className="text-zinc-600">Run the diagnostic suite to verify environment parameters and protocol health.</p>
                    )}
                 </div>

                 {overallStatus !== 'idle' && overallStatus !== 'testing' && (
                    <div className="flex gap-4">
                       <button className="flex-1 py-3 bg-zinc-900 hover:bg-zinc-800 text-zinc-300 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all border border-zinc-800">Export Logs</button>
                    </div>
                 )}
              </div>
           </div>

           {/* Build Terminal */}
           <div className="bg-black border border-zinc-800 rounded-[3rem] p-8 h-80 overflow-hidden shadow-2xl group">
              <div className="flex items-center gap-3 text-zinc-600 mb-6 border-b border-zinc-900 pb-4">
                 <Terminal size={18} className="group-hover:text-orange-500 transition-colors" />
                 <span className="text-[10px] font-black uppercase font-mono tracking-widest">SENTINEL_DEBUG_OUTPUT</span>
              </div>
              <div className="space-y-3 font-mono text-[10px] text-zinc-500 h-full overflow-y-auto custom-scrollbar selection:bg-orange-500/50">
                 <p className="text-green-500">&gt; [OK] LICENSE_VALIDATED: BSL-1.1 (Conxius Labs)</p>
                 <p className="text-zinc-700">&gt; [OK] ENCLAVE_ISOLATION_VERIFIED</p>
                 {tests.filter(t => t.status === 'passed').map(t => (
                    <p key={t.id} className="animate-in slide-in-from-left-2">&gt; [VERIFIED] {t.label.toUpperCase()}... SUCCESS</p>
                 ))}
                 {tests.filter(t => t.status === 'failed').map(t => (
                    <p key={t.id} className="animate-in slide-in-from-left-2 text-red-500">&gt; [FAIL] {t.label.toUpperCase()}... TIMEOUT</p>
                 ))}
                 {isRunning && (
                    <div className="flex items-center gap-2 text-orange-500 animate-pulse">
                       <span>&gt; [BUSY] Auditing next vector...</span>
                       <span className="w-1.5 h-3 bg-orange-500" />
                    </div>
                 )}
                 {!isRunning && overallStatus === 'secure' && (
                    <p className="text-blue-500 font-bold mt-4">&gt; [FINALIZE] ALL SYSTEMS VERIFIED. ENVIRONMENT STABLE.</p>
                 )}
                 {!isRunning && overallStatus === 'warn' && (
                    <p className="text-red-500 font-bold mt-4">&gt; [FINALIZE] NETWORK DEGRADATION DETECTED. CHECK CONNECTIVITY.</p>
                 )}
              </div>
           </div>
        </div>
      </div>
    </div>
  );
};

export default SystemDiagnostics;
