
import React, { useState } from 'react';
import { Rocket, FlaskConical, Terminal, ArrowRight, Sparkles, Shield, Cpu, Code2, Loader2, Search, ExternalLink, Hammer, Zap, Award, ShieldCheck, Microscope } from 'lucide-react';
import { GoogleGenAI } from "@google/genai";

const UPCOMING_PROJECTS = [
  { id: 'guard', name: 'Conxius Guard', status: 'Incubating', desc: 'Hardware-level entropy monitoring for mobile devices.', icon: Shield, color: 'text-blue-500' },
  { id: 'mesh', name: 'Sovereign Mesh V2', status: 'Alpha', desc: 'Peer-to-peer mempool sharing via encrypted local tunnels.', icon: Cpu, color: 'text-purple-500' },
  { id: 'relay', name: 'Conxius Relay', status: 'Concept', desc: 'Universal Nostr-to-Bitcoin settlement engine.', icon: Code2, color: 'text-emerald-500' },
];

const LabsExplorer: React.FC = () => {
  const [activeSubTab, setActiveSubTab] = useState<'incubator' | 'forge'>('incubator');
  const [blueprint, setBlueprint] = useState<string | null>(null);
  const [isGenerating, setIsGenerating] = useState(false);
  const [activeProject, setActiveProject] = useState<string | null>(null);

  const getProjectBlueprint = async (project: string) => {
    setIsGenerating(true);
    setActiveProject(project);
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: `Provide a high-level technical blueprint for a new Conxius Labs project: "${project}". 
        Explain: 
        1. How it enhances user sovereignty.
        2. Its integration points with the existing Conxius Wallet.
        3. Why it is a necessary addition to the Bitcoin multi-layer ecosystem. 
        Focus on technical moats and developer-first architecture.`,
        config: {
          systemInstruction: "You are the Lead Architect at Conxius Labs. Your tone is visionary, highly technical, and deeply aligned with open-source sovereign principles.",
        }
      });
      setBlueprint(response.text);
    } catch (e) {
      setBlueprint("Blueprint engine offline. Local R&D logs indicate progress is steady.");
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <div className="p-8 max-w-6xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-bold tracking-tight text-zinc-100 flex items-center gap-3">
            <FlaskConical className="text-orange-500" />
            Conxius Labs
          </h2>
          <p className="text-zinc-500 text-sm italic">The production engine for sovereign multi-layer software.</p>
        </div>
        
        <div className="flex bg-zinc-900 border border-zinc-800 p-1 rounded-2xl self-start md:self-auto">
           <button 
            onClick={() => setActiveSubTab('incubator')}
            className={`px-6 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${activeSubTab === 'incubator' ? 'bg-orange-600 text-white' : 'text-zinc-500 hover:text-zinc-300'}`}
           >
              Product Incubator
           </button>
           <button 
            onClick={() => setActiveSubTab('forge')}
            className={`px-6 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${activeSubTab === 'forge' ? 'bg-orange-600 text-white' : 'text-zinc-500 hover:text-zinc-300'}`}
           >
              Sovereign Forge
           </button>
        </div>
      </header>

      {activeSubTab === 'incubator' ? (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          <div className="lg:col-span-4 space-y-6">
            <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6 shadow-2xl">
               <h3 className="text-sm font-black uppercase text-zinc-500 tracking-widest">Active R&D Slots</h3>
               <div className="space-y-4">
                  {UPCOMING_PROJECTS.map((project) => (
                     <button 
                      key={project.id}
                      onClick={() => getProjectBlueprint(project.name)}
                      className={`w-full p-6 bg-zinc-950 border rounded-3xl text-left transition-all group ${
                        activeProject === project.name ? 'border-orange-500/50 bg-orange-500/5' : 'border-zinc-900 hover:border-zinc-800'
                      }`}
                     >
                        <div className="flex items-center justify-between mb-4">
                           <div className={`p-2 rounded-xl bg-zinc-900 border border-zinc-800 ${project.color}`}>
                              <project.icon size={20} />
                           </div>
                           <span className="text-[9px] font-black uppercase px-2 py-0.5 bg-zinc-900 text-zinc-600 rounded-full">{project.status}</span>
                        </div>
                        <h4 className="font-bold text-zinc-100 mb-1">{project.name}</h4>
                        <p className="text-[10px] text-zinc-500 leading-relaxed italic">{project.desc}</p>
                     </button>
                  ))}
               </div>
            </div>
          </div>

          <div className="lg:col-span-8 space-y-8">
             <div className="bg-black border border-zinc-800 rounded-[2.5rem] min-h-[600px] flex flex-col overflow-hidden relative group">
                <div className="p-6 border-b border-zinc-900 bg-zinc-900/20 flex items-center justify-between">
                   <div className="flex items-center gap-3">
                      <Terminal size={18} className="text-orange-500" />
                      <h3 className="text-xs font-black uppercase tracking-widest text-zinc-400">Research Terminal</h3>
                   </div>
                   {isGenerating && <Loader2 className="animate-spin text-orange-500" size={14} />}
                </div>
                
                <div className="flex-1 p-10 font-mono text-xs text-zinc-400 leading-relaxed overflow-y-auto custom-scrollbar">
                   {isGenerating ? (
                      <div className="flex flex-col items-center justify-center h-full gap-4 text-center">
                         <Loader2 className="animate-spin text-orange-500" size={32} />
                         <p className="uppercase tracking-widest animate-pulse">Synthesizing Blueprint...</p>
                      </div>
                   ) : blueprint ? (
                      <div className="animate-in fade-in slide-in-from-bottom-2 duration-500">
                         <div className="mb-8 p-4 bg-orange-500/5 border border-orange-500/20 rounded-xl text-orange-500 flex items-center gap-3">
                            <Microscope size={18} />
                            <span className="font-black uppercase tracking-widest">Audit: {activeProject}</span>
                         </div>
                         <div className="whitespace-pre-wrap">{blueprint}</div>
                      </div>
                   ) : (
                      <div className="flex flex-col items-center justify-center h-full text-zinc-700 opacity-50 select-none">
                         <Search size={48} className="mb-4" />
                         <p className="text-sm uppercase tracking-[0.3em] font-black text-center">Select an R&D Slot to Audit</p>
                      </div>
                   )}
                </div>
             </div>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
           <div className="lg:col-span-7 space-y-8">
              <div className="bg-gradient-to-br from-zinc-900 to-orange-950/20 border border-orange-500/20 rounded-[3rem] p-10 relative overflow-hidden group shadow-2xl">
                 <div className="absolute top-0 right-0 p-12 opacity-5">
                    <Hammer size={240} />
                 </div>
                 <div className="relative z-10 space-y-8">
                    <div className="flex justify-between items-start">
                       <div>
                          <h3 className="text-3xl font-black tracking-tighter text-zinc-100">The Forge</h3>
                          <p className="text-sm text-zinc-500 italic">Evolve your Sovereign Pass with verifiable proof-of-work.</p>
                       </div>
                       <div className="w-16 h-16 bg-orange-600 rounded-[1.5rem] flex items-center justify-center shadow-2xl shadow-orange-600/40">
                          <Zap size={32} className="text-white fill-current" />
                       </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                       <div className="bg-zinc-950/80 border border-zinc-900 p-6 rounded-3xl hover:border-orange-500/30 transition-all cursor-pointer group">
                          <div className="flex items-center gap-3 mb-4">
                             <div className="p-2 bg-blue-500/10 rounded-xl text-blue-500">
                                <Award size={20} />
                             </div>
                             <span className="text-[10px] font-black uppercase text-zinc-500">Socket Trait</span>
                          </div>
                          <h4 className="text-sm font-bold text-zinc-100">Genesis Node Uptime</h4>
                          <p className="text-[10px] text-zinc-600 mt-1 italic">+420 Multiplier | Verified On-Chain</p>
                          <div className="mt-4 w-full h-1 bg-zinc-900 rounded-full overflow-hidden">
                             <div className="w-full h-full bg-blue-500" />
                          </div>
                       </div>
                       <div className="bg-zinc-950/80 border border-zinc-900 p-6 rounded-3xl hover:border-orange-500/30 transition-all cursor-pointer group">
                          <div className="flex items-center gap-3 mb-4">
                             <div className="p-2 bg-orange-500/10 rounded-xl text-orange-500">
                                <Zap size={20} />
                             </div>
                             <span className="text-[10px] font-black uppercase text-zinc-500">Socket Trait</span>
                          </div>
                          <h4 className="text-sm font-bold text-zinc-100">NTT Bridge Master</h4>
                          <p className="text-[10px] text-zinc-600 mt-1 italic">Locked at $10k Volume | Level 2</p>
                          <div className="mt-4 w-full h-1 bg-zinc-900 rounded-full overflow-hidden">
                             <div className="w-3/4 h-full bg-orange-500" />
                          </div>
                       </div>
                    </div>

                    <button className="w-full py-5 bg-orange-600 hover:bg-orange-500 text-white font-black rounded-3xl text-sm uppercase tracking-widest shadow-2xl shadow-orange-600/20 transition-all active:scale-[0.98]">
                       Cast Sovereign Evolution
                    </button>
                 </div>
              </div>
           </div>

           <div className="lg:col-span-5 space-y-6">
              <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2.5rem] p-8 space-y-6">
                 <h3 className="text-xs font-black uppercase text-zinc-500 tracking-widest flex items-center gap-2">
                    <ShieldCheck size={16} className="text-green-500" />
                    Evolution Requirements
                 </h3>
                 <div className="space-y-4">
                    {[
                       { label: 'Local Node Uptime', val: '92%', status: 'active' },
                       { label: 'NTT Liquidity Support', val: '0.042 BTC', status: 'pending' },
                       { label: 'Nostr Identity Age', val: '142 Days', status: 'active' },
                    ].map((req, i) => (
                       <div key={i} className="flex items-center justify-between p-4 bg-zinc-950 rounded-2xl border border-zinc-900">
                          <div>
                             <p className="text-[9px] font-black uppercase text-zinc-600">{req.label}</p>
                             <p className="text-xs font-bold text-zinc-200">{req.val}</p>
                          </div>
                          <div className={`w-2 h-2 rounded-full ${req.status === 'active' ? 'bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.4)]' : 'bg-zinc-800'}`} />
                       </div>
                    ))}
                 </div>
              </div>
           </div>
        </div>
      )}
    </div>
  );
};

export default LabsExplorer;
