
import React, { useState } from 'react';
import { Palette, Hammer, Zap, Image, FileText, CheckCircle2, Loader2, Sparkles, AlertCircle, Upload, Eye, EyeOff, Bot, Lock, Code, Coins, ArrowRight, Share2, Layers } from 'lucide-react';
import { GoogleGenAI } from "@google/genai";

const Studio: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'inscribe' | 'runes' | 'zaps'>('inscribe');
  const [isProcessing, setIsProcessing] = useState(false);
  
  // Inscription State
  const [file, setFile] = useState<File | null>(null);
  const [feeRate, setFeeRate] = useState(12);
  const [aiFeeAdvice, setAiFeeAdvice] = useState<string | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  // Rune State
  const [runeName, setRuneName] = useState('');
  const [runeSupply, setRuneSupply] = useState('');
  const [fairMint, setFairMint] = useState(true);

  // Zap State
  const [contentTitle, setContentTitle] = useState('');
  const [zapPrice, setZapPrice] = useState(100);
  const [nostrEvent, setNostrEvent] = useState<string | null>(null);

  const analyzeFees = async () => {
    setIsAnalyzing(true);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: "Analyze the current Bitcoin mempool state (simulate real-time data). Advise on the optimal fee rate for inscribing a 15KB image to ensure it confirms within 3 blocks but doesn't overpay. Suggest a specific sat/vB rate and explain why. Use a technical, 'Economic Scribe' persona.",
        config: {
          systemInstruction: "You are the Conxius Economic Scribe. You optimize Bitcoin block space usage.",
        }
      });
      setAiFeeAdvice(response.text);
      setFeeRate(18); // Simulated optimization result
    } catch (e) {
      setAiFeeAdvice("Fee oracle offline. Reverting to safe estimate: 22 sat/vB.");
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleInscribe = () => {
    setIsProcessing(true);
    setTimeout(() => setIsProcessing(false), 3000);
  };

  const handleEtch = () => {
    setIsProcessing(true);
    setTimeout(() => setIsProcessing(false), 4000);
  };

  const handleCreateZap = () => {
    setIsProcessing(true);
    setTimeout(() => {
      setNostrEvent("nevent1qqs8...92z");
      setIsProcessing(false);
    }, 2000);
  };

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3 italic uppercase">
            <Palette className="text-orange-500" />
            Sovereign Studio
          </h2>
          <p className="text-zinc-500 text-sm italic">Command center for the Bitcoin Creator Economy.</p>
        </div>
        
        {/* Tab Switcher */}
        <div className="flex bg-zinc-900 border border-zinc-800 p-1 rounded-2xl self-start md:self-auto">
           {[
             { id: 'inscribe', label: 'Inscription Press', icon: Image },
             { id: 'runes', label: 'Rune Etcher', icon: Coins },
             { id: 'zaps', label: 'Zap Gates', icon: Zap }
           ].map(tab => (
             <button 
               key={tab.id}
               onClick={() => setActiveTab(tab.id as any)}
               className={`flex items-center gap-2 px-6 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                 activeTab === tab.id 
                   ? 'bg-orange-600 text-white shadow-lg' 
                   : 'text-zinc-500 hover:text-zinc-300'
               }`}
             >
                <tab.icon size={14} /> {tab.label}
             </button>
           ))}
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        
        {/* Main Work Area */}
        <div className="lg:col-span-8 space-y-8">
           
           {activeTab === 'inscribe' && (
              <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3rem] p-10 space-y-8 shadow-2xl animate-in slide-in-from-left-4">
                 <div className="border-2 border-dashed border-zinc-800 rounded-3xl p-12 text-center hover:border-orange-500/50 hover:bg-zinc-900/30 transition-all cursor-pointer group">
                    <Upload size={48} className="mx-auto mb-4 text-zinc-600 group-hover:text-orange-500 transition-colors" />
                    <h3 className="text-lg font-bold text-zinc-300 group-hover:text-white">Upload Artifact</h3>
                    <p className="text-xs text-zinc-500 mt-2">Support: JPG, WEBP, GLTF, TXT (Max 350KB)</p>
                 </div>

                 <div className="bg-zinc-950 border border-zinc-900 rounded-3xl p-8 space-y-6">
                    <div className="flex justify-between items-center">
                       <h4 className="font-bold text-sm text-zinc-200 flex items-center gap-2">
                          <Bot size={16} className="text-purple-500" /> Economic Scribe
                       </h4>
                       <button onClick={analyzeFees} className="text-[10px] font-black uppercase text-purple-500 hover:text-purple-400 flex items-center gap-1">
                          {isAnalyzing ? <Loader2 size={12} className="animate-spin" /> : <Sparkles size={12} />}
                          Optimize Fees
                       </button>
                    </div>
                    
                    {aiFeeAdvice && (
                       <div className="p-4 bg-purple-500/5 border border-purple-500/20 rounded-2xl text-[10px] text-zinc-400 italic leading-relaxed animate-in fade-in">
                          {aiFeeAdvice}
                       </div>
                    )}

                    <div className="space-y-4">
                       <div className="flex justify-between text-xs font-bold text-zinc-500 uppercase tracking-widest">
                          <span>Fee Rate</span>
                          <span className="text-orange-500">{feeRate} sat/vB</span>
                       </div>
                       <input 
                          type="range" 
                          min="1" 
                          max="100" 
                          value={feeRate} 
                          onChange={(e) => setFeeRate(parseInt(e.target.value))}
                          className="w-full accent-orange-500"
                       />
                       <div className="flex justify-between text-[9px] font-bold text-zinc-700">
                          <span>Low Priority (10m)</span>
                          <span>High Priority (1m)</span>
                       </div>
                    </div>
                 </div>

                 <button 
                    onClick={handleInscribe}
                    disabled={isProcessing}
                    className="w-full py-5 bg-orange-600 hover:bg-orange-500 text-white font-black rounded-3xl text-xs uppercase tracking-widest shadow-xl flex items-center justify-center gap-3 active:scale-[0.98]"
                 >
                    {isProcessing ? <Loader2 size={16} className="animate-spin" /> : <Hammer size={16} />}
                    {isProcessing ? 'Scribing to Mempool...' : 'Inscribe Ordinal'}
                 </button>
              </div>
           )}

           {activeTab === 'runes' && (
              <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3rem] p-10 space-y-8 shadow-2xl animate-in slide-in-from-left-4">
                 <div className="space-y-6">
                    <div className="space-y-2">
                       <label className="text-xs font-bold text-zinc-500 uppercase ml-2">Rune Name</label>
                       <input 
                          value={runeName}
                          onChange={e => setRuneName(e.target.value.toUpperCase())}
                          placeholder="SATOSHI•THE•CREATOR" 
                          className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 px-6 font-mono text-sm text-zinc-200 focus:outline-none focus:border-orange-500/50"
                       />
                       <p className="text-[10px] text-zinc-600 italic ml-2">Must be 13+ chars or use open namespaces.</p>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                       <div className="space-y-2">
                          <label className="text-xs font-bold text-zinc-500 uppercase ml-2">Supply Cap</label>
                          <input 
                             value={runeSupply}
                             onChange={e => setRuneSupply(e.target.value)}
                             placeholder="21,000,000" 
                             className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 px-6 font-mono text-sm text-zinc-200 focus:outline-none focus:border-orange-500/50"
                          />
                       </div>
                       <div className="space-y-2">
                          <label className="text-xs font-bold text-zinc-500 uppercase ml-2">Symbol</label>
                          <div className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 px-6 font-mono text-sm text-zinc-500 cursor-not-allowed">
                             Coming Soon
                          </div>
                       </div>
                    </div>

                    <div className="bg-zinc-950 border border-zinc-900 rounded-2xl p-6 flex items-center justify-between">
                       <div className="space-y-1">
                          <h4 className="text-sm font-bold text-zinc-200">Sovereign Fair Mint</h4>
                          <p className="text-[10px] text-zinc-500 max-w-[250px]">Enforces 0% pre-mine and equal minting terms for all participants via smart contract logic.</p>
                       </div>
                       <button 
                          onClick={() => setFairMint(!fairMint)}
                          className={`w-12 h-6 rounded-full relative transition-colors ${fairMint ? 'bg-green-500' : 'bg-zinc-800'}`}
                       >
                          <div className={`absolute top-1 w-4 h-4 bg-white rounded-full shadow-sm transition-all ${fairMint ? 'left-7' : 'left-1'}`} />
                       </button>
                    </div>
                 </div>

                 <button 
                    onClick={handleEtch}
                    disabled={isProcessing || !runeName}
                    className="w-full py-5 bg-purple-600 hover:bg-purple-500 text-white font-black rounded-3xl text-xs uppercase tracking-widest shadow-xl flex items-center justify-center gap-3 active:scale-[0.98]"
                 >
                    {isProcessing ? <Loader2 size={16} className="animate-spin" /> : <Coins size={16} />}
                    {isProcessing ? 'Etching Rune...' : 'Etch Protocol'}
                 </button>
              </div>
           )}

           {activeTab === 'zaps' && (
              <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3rem] p-10 space-y-8 shadow-2xl animate-in slide-in-from-left-4">
                 <div className="bg-orange-500/5 border border-orange-500/10 p-6 rounded-2xl flex gap-4">
                    <Zap size={24} className="text-orange-500 shrink-0" />
                    <div>
                       <h4 className="font-bold text-sm text-orange-200">Zap to Reveal</h4>
                       <p className="text-[10px] text-orange-200/70 leading-relaxed mt-1">
                          Monetize content directly on Nostr. Files are locally encrypted and the key is released only upon Lightning payment confirmation.
                       </p>
                    </div>
                 </div>

                 <div className="space-y-4">
                    <div className="space-y-2">
                       <label className="text-xs font-bold text-zinc-500 uppercase ml-2">Content Title</label>
                       <input 
                          value={contentTitle}
                          onChange={e => setContentTitle(e.target.value)}
                          placeholder="Exclusive Alpha Report #42..." 
                          className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 px-6 text-sm text-zinc-200 focus:outline-none focus:border-orange-500/50"
                       />
                    </div>
                    
                    <div className="space-y-2">
                       <label className="text-xs font-bold text-zinc-500 uppercase ml-2">Unlock Price (Sats)</label>
                       <div className="relative">
                          <input 
                             type="number"
                             value={zapPrice}
                             onChange={e => setZapPrice(parseInt(e.target.value))}
                             className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 px-6 font-mono text-sm text-zinc-200 focus:outline-none focus:border-orange-500/50"
                          />
                          <Zap className="absolute right-6 top-1/2 -translate-y-1/2 text-orange-500" size={16} />
                       </div>
                    </div>

                    <div className="border-2 border-dashed border-zinc-800 rounded-2xl p-8 text-center hover:border-zinc-700 transition-all">
                       <Lock size={32} className="mx-auto mb-2 text-zinc-700" />
                       <p className="text-xs text-zinc-500">Drag & Drop file to Encrypt</p>
                    </div>
                 </div>

                 {nostrEvent ? (
                    <div className="bg-zinc-950 p-6 rounded-2xl border border-zinc-900 animate-in zoom-in">
                       <div className="flex justify-between items-center mb-4">
                          <span className="text-[10px] font-black uppercase text-green-500">Event Ready</span>
                          <button className="text-zinc-500 hover:text-white"><Share2 size={16} /></button>
                       </div>
                       <p className="text-[10px] font-mono text-zinc-600 break-all bg-zinc-900 p-4 rounded-xl border border-zinc-800">
                          {nostrEvent}
                       </p>
                       <button className="w-full mt-4 py-3 bg-purple-600 text-white font-bold rounded-xl text-[10px] uppercase tracking-widest hover:bg-purple-500 transition-all">
                          Broadcast to Relays
                       </button>
                    </div>
                 ) : (
                    <button 
                       onClick={handleCreateZap}
                       disabled={isProcessing}
                       className="w-full py-5 bg-zinc-100 hover:bg-white text-zinc-950 font-black rounded-3xl text-xs uppercase tracking-widest shadow-xl flex items-center justify-center gap-3 active:scale-[0.98]"
                    >
                       {isProcessing ? <Loader2 size={16} className="animate-spin" /> : <Code size={16} />}
                       {isProcessing ? 'Encrypting & Signing...' : 'Generate Zap Gate'}
                    </button>
                 )}
              </div>
           )}

        </div>

        {/* Info Sidebar */}
        <div className="lg:col-span-4 space-y-8">
           
           <div className="bg-orange-600 border border-orange-500 rounded-[2.5rem] p-8 text-white relative overflow-hidden group shadow-2xl shadow-orange-600/30">
              <div className="absolute top-0 right-0 p-8 opacity-20 group-hover:scale-110 transition-transform">
                 <Layers size={100} />
              </div>
              <div className="relative z-10">
                 <h4 className="text-xl font-black italic uppercase tracking-tighter mb-4">Creator Sovereignty</h4>
                 <p className="text-xs font-medium leading-relaxed opacity-90 mb-6">
                    By inscribing directly from your node, you bypass platforms like Gamma or Unisat. You own the provenance, the UTXO, and the keys.
                 </p>
                 <div className="space-y-3">
                    <div className="flex items-center gap-3 text-xs font-bold opacity-80">
                       <CheckCircle2 size={14} /> No Platform Fees
                    </div>
                    <div className="flex items-center gap-3 text-xs font-bold opacity-80">
                       <CheckCircle2 size={14} /> Censorship Resistant
                    </div>
                    <div className="flex items-center gap-3 text-xs font-bold opacity-80">
                       <CheckCircle2 size={14} /> Parent/Child Provenance
                    </div>
                 </div>
              </div>
           </div>

           <div className="bg-zinc-950 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6">
              <h4 className="font-bold text-sm text-zinc-400 flex items-center gap-2">
                 <AlertCircle size={18} className="text-yellow-500" />
                 Studio Stats
              </h4>
              <div className="space-y-4">
                 <div className="flex justify-between items-center border-b border-zinc-900 pb-3">
                    <span className="text-[10px] font-black uppercase text-zinc-600">Total Inscribed</span>
                    <span className="text-xs font-bold text-zinc-200">142 items</span>
                 </div>
                 <div className="flex justify-between items-center border-b border-zinc-900 pb-3">
                    <span className="text-[10px] font-black uppercase text-zinc-600">Total Fees Saved</span>
                    <span className="text-xs font-mono font-bold text-green-500">0.012 BTC</span>
                 </div>
                 <div className="flex justify-between items-center">
                    <span className="text-[10px] font-black uppercase text-zinc-600">Rune Tickers</span>
                    <span className="text-xs font-bold text-zinc-200">2 Active</span>
                 </div>
              </div>
           </div>

        </div>
      </div>
    </div>
  );
};

export default Studio;
