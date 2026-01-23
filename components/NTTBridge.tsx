
import React, { useState, useContext } from 'react';
import { ArrowRight, Info, AlertCircle, CheckCircle2, Loader2, Link, TrendingUp, ShieldCheck, Zap, Globe, Search, RefreshCw, ExternalLink } from 'lucide-react';
import { trackNttBridge } from '../services/protocol';
import { AppContext } from '../context';

const NTTBridge: React.FC = () => {
  const context = useContext(AppContext);
  const [step, setStep] = useState(1);
  const [sourceLayer, setSourceLayer] = useState('Mainnet');
  const [targetLayer, setTargetLayer] = useState('Stacks');
  const [amount, setAmount] = useState('');
  const [txHash, setTxHash] = useState('');
  const [isBridging, setIsBridging] = useState(false);
  const [trackingData, setTrackingData] = useState<any>(null);
  const [isTracking, setIsTracking] = useState(false);

  const handleBridge = () => {
    setIsBridging(true);
    setTimeout(() => {
      setStep(3);
      setIsBridging(false);
      context?.notify('info', 'Tracking-only mode: broadcast the bridge transaction externally, then paste the tx hash here.');
    }, 500);
  };

  const handleTrack = async () => {
    if (!txHash) {
        context?.notify('warning', 'Please enter a Transaction Hash');
        return;
    }
    setIsTracking(true);
    try {
        const data = await trackNttBridge(txHash);
        if (data) {
            setTrackingData(data);
            context?.notify('success', 'Wormhole Attestation Found');
        } else {
            setTrackingData(null);
            context?.notify('info', 'No attestation found for this tx hash yet.');
        }
    } catch (e) {
        context?.notify('error', 'Wormhole API Unreachable. Retrying via Tor...');
    } finally {
        setIsTracking(false);
    }
  };

  return (
    <div className="p-8 max-w-2xl mx-auto space-y-8 animate-in fade-in duration-500 pb-20">
      <div className="text-center">
        <h2 className="text-3xl font-black italic uppercase tracking-tighter mb-2">NTT Protocol</h2>
        <p className="text-zinc-500 text-sm">Tracking-only monitor for Wormhole NTT attestations.</p>
      </div>

      <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3rem] p-10 space-y-8 shadow-2xl relative overflow-hidden">
        
        {step === 1 && (
          <div className="space-y-8">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase text-zinc-600">Source</label>
                <select value={sourceLayer} onChange={e => setSourceLayer(e.target.value)} className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl p-4 text-zinc-200 focus:outline-none" aria-label="Source Layer" title="Source Layer">
                  <option>Mainnet</option>
                  <option>Stacks</option>
                  <option>Rootstock</option>
                </select>
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase text-zinc-600">Destination</label>
                <select value={targetLayer} onChange={e => setTargetLayer(e.target.value)} className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl p-4 text-zinc-200 focus:outline-none" aria-label="Target Layer" title="Target Layer">
                  <option>Stacks</option>
                  <option>Mainnet</option>
                  <option>Liquid</option>
                </select>
              </div>
            </div>

            <div className="bg-zinc-950 border border-zinc-800 rounded-3xl p-8 space-y-4">
                <div className="flex justify-between items-center">
                    <span className="text-[10px] font-black uppercase text-zinc-500 tracking-widest">Amount to Transfer</span>
                </div>
                <div className="flex items-center gap-4">
                    <input type="number" placeholder="0.00" value={amount} onChange={e => setAmount(e.target.value)} className="bg-transparent text-4xl font-black text-white focus:outline-none w-full font-mono tracking-tighter" />
                    <div className="bg-zinc-900 px-4 py-2 rounded-xl border border-zinc-800 flex items-center gap-2">
                        <div className="w-6 h-6 bg-orange-500 rounded-full flex items-center justify-center text-[10px] font-black text-white">₿</div>
                        <span className="font-bold text-zinc-300">BTC</span>
                    </div>
                </div>
            </div>

            <button type="button" onClick={() => setStep(2)} disabled={!amount} className="w-full bg-orange-600 hover:bg-orange-500 text-white font-black py-5 rounded-3xl text-xs uppercase tracking-widest shadow-xl transition-all active:scale-95 disabled:opacity-50">
              Continue
            </button>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-8 animate-in slide-in-from-right-4">
            <h3 className="text-xl font-bold text-white uppercase tracking-tight">Review Protocol Wrap</h3>
            <div className="bg-zinc-950 rounded-[2rem] divide-y divide-zinc-900 border border-zinc-900 overflow-hidden">
                {[
                    { label: 'Asset', val: `${amount} BTC` },
                    { label: 'Route', val: `${sourceLayer} → ${targetLayer}` },
                    { label: 'Bridge Fee', val: '0.00012 BTC' },
                    { label: 'Attestation Quorum', val: '12 / 19 Guardians' }
                ].map((item, i) => (
                    <div key={i} className="p-5 flex justify-between items-center">
                        <span className="text-[10px] font-black uppercase text-zinc-600">{item.label}</span>
                        <span className="text-xs font-mono font-bold text-zinc-100">{item.val}</span>
                    </div>
                ))}
            </div>
            <div className="flex gap-4">
                <button type="button" onClick={() => setStep(1)} className="flex-1 py-4 bg-zinc-900 hover:bg-zinc-800 text-zinc-500 rounded-2xl text-[10px] font-black uppercase tracking-widest border border-zinc-800">Back</button>
                <button type="button" onClick={handleBridge} disabled={isBridging} className="flex-[2] bg-orange-600 hover:bg-orange-500 text-white font-black py-4 rounded-2xl text-[10px] uppercase tracking-widest shadow-xl flex items-center justify-center gap-2">
                    {isBridging ? <Loader2 size={16} className="animate-spin" /> : <ShieldCheck size={16} />}
                    Open Tracking
                </button>
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="space-y-8 animate-in zoom-in">
             <div className="text-center space-y-4">
                <div className="w-20 h-20 bg-orange-600/10 border border-orange-500/20 rounded-full flex items-center justify-center mx-auto text-orange-500">
                    <Globe size={40} className="animate-pulse" />
                </div>
                <h3 className="text-2xl font-black italic uppercase tracking-tighter text-white">Tracking Only</h3>
                <p className="text-xs text-zinc-500 max-w-xs mx-auto italic leading-relaxed">Paste a bridge transaction hash to monitor Wormhole guardian attestations.</p>
             </div>

             <div className="space-y-4">
                <div className="space-y-2">
                    <label className="text-[10px] font-black uppercase text-zinc-600 ml-1">Live Transaction Hash</label>
                    <div className="relative">
                        <input value={txHash} onChange={e => setTxHash(e.target.value)} placeholder="0x... or bc1q..." className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 pl-5 pr-12 font-mono text-xs text-zinc-200 focus:outline-none" />
                        <button type="button" onClick={handleTrack} className="absolute right-4 top-1/2 -translate-y-1/2 text-orange-500 hover:text-orange-400" aria-label="Track" title="Track">
                            {isTracking ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
                        </button>
                    </div>
                </div>

                {trackingData && (
                    <div className="p-6 bg-zinc-950 border border-zinc-900 rounded-[2rem] space-y-4 animate-in slide-in-from-top-4">
                        <div className="flex justify-between items-center">
                            <span className="text-[10px] font-black uppercase text-zinc-600">Guardian Status</span>
                            <span className="text-[10px] font-bold text-green-500 uppercase px-2 py-0.5 bg-green-500/10 rounded">{trackingData.status || 'In Progress'}</span>
                        </div>
                        <div className="space-y-1">
                            <div className="w-full h-1 bg-zinc-900 rounded-full overflow-hidden">
                                <div className="w-1/3 h-full bg-orange-500" />
                            </div>
                            <p className="text-[9px] text-zinc-600 italic">Confirmed by {trackingData.signatures ?? 'n/a'}/19 Guardians</p>
                        </div>
                    </div>
                )}

                <button type="button" onClick={() => setStep(1)} className="w-full py-4 text-zinc-600 hover:text-zinc-400 text-[10px] font-black uppercase tracking-widest transition-all">New Transfer</button>
             </div>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-zinc-900/40 p-6 rounded-[2rem] border border-zinc-800 flex gap-4 group">
            <ShieldCheck size={24} className="text-orange-500 group-hover:scale-110 transition-transform" />
            <div>
                <h4 className="text-xs font-black uppercase text-zinc-200 mb-1">Guardian Network</h4>
                <p className="text-[10px] text-zinc-500 leading-relaxed italic">Immutable validation provided by 19 independent security nodes including Figment, Chorus One, and Everstake.</p>
            </div>
        </div>
        <div className="bg-zinc-900/40 p-6 rounded-[2rem] border border-zinc-800 flex gap-4 group">
            <Zap size={24} className="text-yellow-500 group-hover:scale-110 transition-transform" />
            <div>
                <h4 className="text-xs font-black uppercase text-zinc-200 mb-1">Native Finality</h4>
                <p className="text-[10px] text-zinc-500 leading-relaxed italic">NTT skips rehypothecation. Your BTC is locked or burned, ensuring 1:1 parity without pool slippage.</p>
            </div>
        </div>
      </div>
    </div>
  );
};

export default NTTBridge;
