
import React, { useState, useEffect, useContext } from 'react';
import { Terminal, ShieldCheck, Rocket, RefreshCw, Activity, Network, CheckCircle2, Loader2, Bot, Lock, Globe, Zap, Box, Code, Play } from 'lucide-react';
import { getDeploymentReadinessAudit } from '../services/gemini';
import { AppContext } from '../context';

const TEST_SUITE = [
  { id: 'wallet_gen', label: 'Wallet Generation', detail: 'BIP-84 Testnet' },
  { id: 'faucet', label: 'Faucet Request', detail: '5.0 sBTC Airdrop' },
  { id: 'ntt_bridge', label: 'NTT Bridge Logic', detail: 'L1 -> Stacks L2' },
  { id: 'defi_swap', label: 'DeFi Swap Execution', detail: 'ALEX Pool Interaction' },
  { id: 'stacking', label: 'PoX Stacking Lock', detail: 'Cycle #99' },
];

const HandoffProtocol: React.FC = () => {
  const context = useContext(AppContext);
  const [activePhase, setActivePhase] = useState<'simulation' | 'broadcast'>('simulation');
  const [testLog, setTestLog] = useState<string[]>([]);
  const [testProgress, setTestProgress] = useState(0);
  const [testStatus, setTestStatus] = useState<'idle' | 'running' | 'success' | 'failed'>('idle');
  const [generatedWallet, setGeneratedWallet] = useState<string | null>(null);
  const [testBalance, setTestBalance] = useState(0);
  
  const [auditMemo, setAuditMemo] = useState<string | null>(null);
  const [isDeploying, setIsDeploying] = useState(false);
  const [deployStep, setDeployStep] = useState(0);

  const addLog = (msg: string) => setTestLog(prev => [...prev, `> ${msg}`]);

  const runFlightCheck = async () => {
    setTestStatus('running');
    setTestProgress(0);
    setTestLog([]);
    setGeneratedWallet(null);
    setTestBalance(0);

    // 1. Wallet Generation
    addLog("Initializing BIP-39 Seed Entropy...");
    await new Promise(r => setTimeout(r, 800));
    const mockWallet = "tb1q" + Math.random().toString(36).substring(2, 10) + "xp9";
    setGeneratedWallet(mockWallet);
    addLog(`Wallet Generated: ${mockWallet}`);
    setTestProgress(20);

    // 2. Faucet
    await new Promise(r => setTimeout(r, 1000));
    addLog("Requesting testnet coins from Conxius Faucet...");
    setTestBalance(5.0);
    addLog("Airdrop Received: 5.00000000 sBTC");
    setTestProgress(40);

    // 3. NTT Bridge
    await new Promise(r => setTimeout(r, 1200));
    addLog("Initiating NTT Bridge Transfer (1.0 sBTC -> Stacks)...");
    addLog("Guardians Attesting: 12/19 signatures verified.");
    setTestBalance(4.0);
    addLog("Bridge Finality Reached. TXID: 0x7f...3a");
    setTestProgress(60);

    // 4. DeFi Swap
    await new Promise(r => setTimeout(r, 1000));
    addLog("Testing Swap Contract (sBTC -> xBTC)...");
    addLog("Swap Route: sBTC -> SIP-10 -> xBTC");
    addLog("Execution Success.");
    setTestProgress(80);

    // 5. Stacking
    await new Promise(r => setTimeout(r, 1000));
    addLog("Locking 1.0 sBTC for PoX Cycle #99...");
    setTestBalance(3.0);
    addLog("Stacking Confirmed. Yield Address Registered.");
    setTestProgress(100);

    addLog("ALL SYSTEMS GREEN. RELEASE CANDIDATE VERIFIED.");
    setTestStatus('success');
  };

  const handleLaunch = async () => {
    setIsDeploying(true);
    const steps = [
      'Packaging Signed Artifacts',
      'Broadcasting Mainnet Roots',
      'Activating Production Enclave',
      'Going Live'
    ];
    
    for (let i = 1; i <= steps.length; i++) {
      setDeployStep(i);
      await new Promise(r => setTimeout(r, 1500));
    }
    context?.setMainnetLive(true);
    setIsDeploying(false);
  };

  useEffect(() => {
    // Pre-fetch audit for visual filler
    getDeploymentReadinessAudit({ nodeSyncProgress: 100 }).then(setAuditMemo);
  }, []);

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-8 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3 italic uppercase">
            <Rocket className="text-orange-500" />
            Deploy Network
          </h2>
          <p className="text-zinc-500 text-sm italic">Automated Flight Check & Mainnet Release Protocol.</p>
        </div>
        <div className="flex items-center gap-4">
           {context?.state.isMainnetLive ? (
             <div className="bg-green-500/10 border border-green-500/20 px-6 py-2 rounded-2xl flex items-center gap-2">
                <Globe size={16} className="text-green-500" />
                <span className="text-xs font-black uppercase text-green-500 tracking-widest">Mainnet Live</span>
             </div>
           ) : (
             <div className="bg-orange-500/10 border border-orange-500/20 px-6 py-2 rounded-2xl flex items-center gap-2">
                <Activity size={16} className="text-orange-500 animate-pulse" />
                <span className="text-xs font-black uppercase text-orange-500 tracking-widest">Testnet Mode</span>
             </div>
           )}
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        
        {/* Testnet Flight Recorder (Left Panel) */}
        <div className="lg:col-span-8 space-y-8">
           <div className="bg-black border border-zinc-800 rounded-[3rem] p-1 shadow-2xl relative overflow-hidden group">
              <div className="bg-zinc-950 rounded-[2.8rem] flex flex-col min-h-[600px] relative z-10">
                 
                 {/* Terminal Header */}
                 <div className="p-8 border-b border-zinc-900 bg-zinc-900/20 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                       <Terminal size={18} className="text-orange-500" />
                       <h3 className="text-xs font-black uppercase tracking-widest text-zinc-400 font-mono">FLIGHT_CHECK_TERMINAL</h3>
                    </div>
                    {testStatus === 'idle' ? (
                       <button 
                         onClick={runFlightCheck}
                         className="bg-zinc-800 hover:bg-zinc-700 text-zinc-200 px-6 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all flex items-center gap-2"
                       >
                          <Play size={12} fill="currentColor" /> Initialize Simulation
                       </button>
                    ) : testStatus === 'running' ? (
                       <div className="flex items-center gap-2 text-orange-500 text-[10px] font-black uppercase tracking-widest">
                          <Loader2 size={12} className="animate-spin" /> Running Tests...
                       </div>
                    ) : (
                       <div className="flex items-center gap-2 text-green-500 text-[10px] font-black uppercase tracking-widest">
                          <CheckCircle2 size={12} /> Flight Check Passed
                       </div>
                    )}
                 </div>

                 {/* Simulation Canvas */}
                 <div className="flex-1 p-0 flex flex-col md:flex-row">
                    {/* Visualizer */}
                    <div className="flex-1 p-8 border-r border-zinc-900 space-y-8">
                       <div className="bg-zinc-900/30 rounded-2xl p-6 border border-zinc-800">
                          <p className="text-[10px] font-black uppercase text-zinc-500 mb-2">Ephemeral Test Wallet</p>
                          <div className="flex items-center justify-between">
                             <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-lg bg-zinc-800 flex items-center justify-center text-zinc-500">
                                   <Zap size={16} />
                                </div>
                                <span className="font-mono text-sm text-zinc-200">{generatedWallet || "Waiting for generation..."}</span>
                             </div>
                             <span className="font-mono text-sm font-bold text-orange-500">{testBalance.toFixed(4)} sBTC</span>
                          </div>
                       </div>

                       <div className="space-y-4">
                          <p className="text-[10px] font-black uppercase text-zinc-600 pl-1">Execution Pipeline</p>
                          {TEST_SUITE.map((test, idx) => {
                             const isActive = (testProgress / 20) > idx;
                             const isPending = (testProgress / 20) === idx && testStatus === 'running';
                             
                             return (
                                <div key={test.id} className={`flex items-center justify-between p-4 rounded-xl border transition-all ${isActive ? 'bg-green-500/5 border-green-500/20' : 'bg-zinc-900/20 border-zinc-900 opacity-50'}`}>
                                   <div className="flex items-center gap-4">
                                      <div className={`w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-black ${isActive ? 'bg-green-500 text-black' : 'bg-zinc-800 text-zinc-500'}`}>
                                         {isActive ? <CheckCircle2 size={14} /> : idx + 1}
                                      </div>
                                      <div>
                                         <p className={`text-xs font-bold ${isActive ? 'text-zinc-200' : 'text-zinc-500'}`}>{test.label}</p>
                                         <p className="text-[10px] text-zinc-600">{test.detail}</p>
                                      </div>
                                   </div>
                                   {isPending && <Loader2 size={14} className="animate-spin text-orange-500" />}
                                </div>
                             )
                          })}
                       </div>
                    </div>

                    {/* Console Output */}
                    <div className="w-full md:w-80 bg-black p-6 font-mono text-[10px] text-zinc-500 overflow-y-auto custom-scrollbar h-64 md:h-auto border-t md:border-t-0 md:border-l border-zinc-900">
                       <p className="text-zinc-700 mb-4">// CONXIUS TESTNET LOGS</p>
                       {testLog.map((log, i) => (
                          <p key={i} className="mb-2 text-zinc-400 animate-in slide-in-from-left-2 duration-200">
                             {log}
                          </p>
                       ))}
                       {testStatus === 'running' && (
                          <span className="w-2 h-4 bg-orange-500 block animate-pulse mt-2"/>
                       )}
                    </div>
                 </div>
              </div>
           </div>
        </div>

        {/* Release Control (Right Panel) */}
        <div className="lg:col-span-4 space-y-8">
           
           {/* Launch Button Card */}
           <div className={`border rounded-[3rem] p-10 space-y-8 shadow-2xl relative overflow-hidden group transition-all duration-700 ${
              context?.state.isMainnetLive 
                ? 'bg-zinc-100 border-zinc-100 text-zinc-950 shadow-zinc-100/20' 
                : testStatus === 'success'
                   ? 'bg-orange-600 border-orange-500 text-white shadow-orange-600/30'
                   : 'bg-zinc-900 border-zinc-800 text-zinc-500'
           }`}>
              
              <div className="relative z-10 space-y-6">
                 <div className="flex items-center gap-3">
                    {context?.state.isMainnetLive ? <Activity size={24} className="animate-pulse text-green-600" /> : <Rocket size={24} />}
                    <h4 className="text-2xl font-black tracking-tighter italic uppercase">
                       {context?.state.isMainnetLive ? 'Mainnet Active' : 'Authorize Launch'}
                    </h4>
                 </div>
                 
                 <p className="text-xs opacity-90 leading-relaxed italic font-medium">
                    {context?.state.isMainnetLive 
                      ? "Production Enclave is live. System metrics are nominal."
                      : testStatus === 'success'
                         ? "Flight check passed. Artifacts signed. Ready to broadcast to mainnet."
                         : "System locked. Please run full flight check simulation to unlock release controls."}
                 </p>

                 <button 
                    onClick={handleLaunch}
                    disabled={testStatus !== 'success' || context?.state.isMainnetLive || isDeploying}
                    className={`w-full font-black py-5 rounded-3xl text-xs uppercase tracking-widest transition-all shadow-xl active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed ${
                       context?.state.isMainnetLive 
                          ? 'bg-green-500 text-white border-none' 
                          : testStatus === 'success'
                             ? 'bg-white text-orange-600 hover:bg-zinc-100'
                             : 'bg-zinc-800 text-zinc-600'
                    }`}
                 >
                    {isDeploying ? 'Deploying...' : context?.state.isMainnetLive ? 'SYSTEM DEPLOYED' : 'GO LIVE'}
                 </button>
              </div>
           </div>

           {/* Readiness Audit */}
           <div className="bg-zinc-950 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6 shadow-xl">
              <h4 className="text-[10px] font-black uppercase text-zinc-500 tracking-widest flex items-center gap-2">
                 <ShieldCheck size={14} className="text-blue-500" /> Pre-Flight Audit
              </h4>
              <div className="text-[10px] text-zinc-400 italic leading-relaxed whitespace-pre-wrap">
                 {auditMemo || "Pending audit..."}
              </div>
           </div>
        </div>
      </div>
    </div>
  );
};

export default HandoffProtocol;
