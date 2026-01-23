
import React, { useState, useEffect, useRef } from 'react';
import { UserCheck, ShieldCheck, Fingerprint, Plus, Copy, CheckCircle2, Link2, X, Wallet, Zap, Lock, Radio, RefreshCw, Loader2 } from 'lucide-react';
import { getDIDInsight } from '../services/gemini';
import { DIDProfile } from '../types';
import { generateNostrKeypair } from '../services/nostr';
import { IdentityService } from '../services/identity';

interface LinkedItem {
  label: string;
  value: string;
  status: 'verified' | 'linked' | 'pending';
  type: 'btc' | 'bns' | 'nostr' | 'rif' | 'external_wallet' | 'pgp' | 'nft_pass';
  walletType?: 'Electrum' | 'Sparrow' | 'BlueWallet' | 'Specter';
  attestation?: string;
}

const INITIAL_DID: DIDProfile = {
  did: 'did:btc:7c8a4b2e9f1d0c5a',
  alias: 'satoshi_disciple.btc',
  bio: 'Sovereign individual. Building on Bitcoin layers. 21M forever.',
  verified: true,
  linkedAddress: 'bc1q...4h8f',
  avatarUrl: 'https://api.dicebear.com/7.x/pixel-art/svg?seed=satoshi',
  socials: {
    twitter: '@btc_sovereign',
    nostr: 'npub1satoshi...'
  }
};

const IdentityManager: React.FC = () => {
  const [profile, setProfile] = useState<DIDProfile>(INITIAL_DID);
  const [insight, setInsight] = useState<string | null>(null);
  const [isLoadingInsight, setIsLoadingInsight] = useState(false);
  const [links, setLinks] = useState<LinkedItem[]>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [nostrKeys, setNostrKeys] = useState<{npub: string, nsec: string} | null>(null);
  const [isGeneratingNostr, setIsGeneratingNostr] = useState(false);

  useEffect(() => {
    const loadIdentity = async () => {
        try {
            const idService = new IdentityService();
            const identity = await idService.getDid();
            
            // Merge with existing profile structure
            setProfile(prev => ({
                ...prev,
                did: identity.did,
                linkedAddress: identity.address,
                verified: true // Enclave verified
            }));
            
            // Check cache for insight to avoid expensive API call
            const cacheKey = `did_insight_${identity.did}`;
            const cachedInsight = localStorage.getItem(cacheKey);
            
            if (cachedInsight) {
                setInsight(cachedInsight);
            } else {
                // Fetch insight for the real DID
                setIsLoadingInsight(true);
                try {
                    const res = await getDIDInsight(identity.did);
                    setInsight(res);
                    localStorage.setItem(cacheKey, res);
                } catch (err) {
                    console.error("Insight fetch failed", err);
                } finally {
                    setIsLoadingInsight(false);
                }
            }
        } catch (e) {
            console.error("Failed to load identity", e);
        }
    };
    loadIdentity();
  }, []);

  const handleGenerateNostr = async () => {
     setIsGeneratingNostr(true);
     try {
        const keys = await generateNostrKeypair();
        setNostrKeys(keys);
     } finally {
        setIsGeneratingNostr(false);
     }
  };

  const handleLnLogin = async () => {
      const lnurl = prompt("Enter LNURL-Auth string for testing:");
      if (!lnurl) return;
      
      try {
          const idService = new IdentityService();
          await idService.loginWithLightning(lnurl);
          alert("Lightning Login Successful!");
      } catch (e) {
          alert("Login Failed: " + (e as Error).message);
      }
  };

  const handleLinkWallet = async () => {
    const walletType = prompt("Enter wallet type (e.g. Electrum, Sparrow, BlueWallet):");
    const address = prompt("Enter wallet address:");
    
    if (!walletType || !address) return;

    try {
        const idService = new IdentityService();
        await idService.linkExternalWallet(walletType, address);
        
        const newItem: LinkedItem = {
            label: `${walletType} Wallet`,
            value: address,
            status: 'linked',
            type: 'external_wallet',
            walletType: walletType as any
        };
        
        setLinks(prev => [...prev, newItem]);
        alert("External Wallet Linked Successfully!");
    } catch (e) {
        alert("Linking Failed: " + (e as Error).message);
    }
  };

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-12 animate-in fade-in duration-500 pb-24">
      <header className="flex justify-between items-end">
        <div>
          <h2 className="text-3xl font-black italic uppercase tracking-tighter text-zinc-100">Identity Enclave</h2>
          <p className="text-zinc-500 text-sm italic">Verification through Proof-of-Work and Decentralized Identity.</p>
        </div>
        <button type="button" onClick={() => setIsModalOpen(true)} className="bg-orange-600 hover:bg-orange-500 text-white px-6 py-3 rounded-2xl font-black text-xs uppercase tracking-widest flex items-center gap-2 transition-all shadow-xl shadow-orange-600/20 active:scale-95">
          <Plus size={18} /> Link Account
        </button>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10">
        <div className="lg:col-span-4 space-y-8">
           <div className="bg-zinc-900/40 border border-zinc-800 rounded-[3.5rem] p-1 shadow-2xl overflow-hidden group">
             <div className="bg-zinc-950 rounded-[3.4rem] p-10 space-y-10 relative overflow-hidden text-center">
                <div className="w-24 h-24 rounded-[2rem] border-4 border-orange-500/20 p-1 bg-zinc-900 shadow-2xl mx-auto">
                   <img src={profile.avatarUrl} alt="Avatar" className="w-full h-full rounded-[1.8rem] object-cover" />
                </div>
                <div>
                   <h3 className="text-2xl font-black text-zinc-100 flex items-center justify-center gap-2">
                      {profile.alias} <ShieldCheck size={20} className="text-blue-500" />
                   </h3>
                   <p className="text-[10px] font-black uppercase tracking-[0.3em] text-orange-500 mt-2">Verified Peer Root</p>
                </div>
                <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 flex items-center justify-between text-left">
                   <div>
                      <p className="text-[9px] font-black text-zinc-600 uppercase">Primary DID</p>
                      <p className="text-[10px] font-mono text-zinc-400 truncate w-32">{profile.did}</p>
                   </div>
                   <button 
                      type="button"
                      aria-label="Copy DID to clipboard"
                      onClick={() => navigator.clipboard.writeText(profile.did)} 
                      className="p-2 hover:bg-zinc-800 rounded-lg text-zinc-700"
                   >
                      <Copy size={14} />
                   </button>
                </div>
             </div>
           </div>
        </div>

        <div className="lg:col-span-8 space-y-10">
           {/* Real Nostr Module */}
           <div className="bg-purple-600/10 border border-purple-500/20 rounded-[3rem] p-10 space-y-8 relative overflow-hidden group">
              <div className="absolute top-0 right-0 p-8 opacity-5 group-hover:scale-110 transition-transform">
                 <Radio size={140} className="text-purple-500" />
              </div>
              <div className="relative z-10 flex flex-col md:flex-row items-center justify-between gap-8">
                 <div className="space-y-3">
                    <h3 className="text-xl font-black italic uppercase tracking-tighter text-purple-200">Nostr Transport Layer</h3>
                    <p className="text-xs text-zinc-400 max-w-md leading-relaxed italic">Enable encrypted multi-sig coordination and decentralized profile metadata via relays.</p>
                 </div>
                 {nostrKeys ? (
                    <div className="flex items-center gap-2 bg-green-500/10 text-green-500 px-4 py-2 rounded-full border border-green-500/20 text-[10px] font-black uppercase">
                       <CheckCircle2 size={12} /> Transport Active
                    </div>
                 ) : (
                    <button 
                       type="button"
                       onClick={handleGenerateNostr}
                       disabled={isGeneratingNostr}
                       className="bg-purple-600 hover:bg-purple-500 text-white px-8 py-4 rounded-2xl font-black text-xs uppercase tracking-widest transition-all shadow-xl shadow-purple-600/30 flex items-center gap-2"
                    >
                       {isGeneratingNostr ? <Loader2 size={16} className="animate-spin" /> : <Fingerprint size={16} />}
                       Initialize Mesh Keys
                    </button>
                 )}
              </div>

              {nostrKeys && (
                 <div className="grid grid-cols-1 md:grid-cols-2 gap-4 animate-in fade-in slide-in-from-top-4">
                    <div className="p-6 bg-zinc-950 border border-zinc-900 rounded-3xl space-y-2">
                       <p className="text-[9px] font-black uppercase text-zinc-600">Public Key (npub)</p>
                       <p className="text-[10px] font-mono text-zinc-300 break-all bg-zinc-900/50 p-3 rounded-xl border border-zinc-800">{nostrKeys.npub}</p>
                    </div>
                    <div className="p-6 bg-zinc-950 border border-zinc-900 rounded-3xl space-y-2">
                       <p className="text-[9px] font-black uppercase text-zinc-600">Private Enclave Key (nsec)</p>
                       <p className="text-[10px] font-mono text-zinc-500 blur-md hover:blur-0 cursor-pointer break-all bg-zinc-900/50 p-3 rounded-xl border border-zinc-800 transition-all">{nostrKeys.nsec}</p>
                    </div>
                 </div>
              )}
           </div>

           <div className="bg-zinc-900/20 border border-zinc-800 rounded-[3rem] p-10 space-y-6">
              <div className="flex items-center gap-3">
                 <div className="bg-blue-500/20 p-2 rounded-xl">
                    <Zap size={20} className="text-blue-500" />
                 </div>
                 <h3 className="text-xs font-black uppercase tracking-widest text-zinc-400">Identity Audit</h3>
              </div>
              <div className="bg-zinc-950 p-8 rounded-[2rem] border border-zinc-900 relative">
                 <div className="absolute top-0 right-0 p-8 opacity-[0.02]"><Bot size={120} /></div>
                 {isLoadingInsight ? (
                    <div className="flex flex-col items-center justify-center py-10 gap-4 text-zinc-700">
                       <Loader2 className="animate-spin" size={32} />
                       <p className="text-[10px] font-black uppercase tracking-widest animate-pulse">Satoshi AI auditing DID path...</p>
                    </div>
                 ) : (
                    <p className="text-xs font-mono text-zinc-400 leading-relaxed italic whitespace-pre-wrap">{insight}</p>
                 )}
              </div>
           </div>
           
           {/* Sovereign Backup & Features */}
           <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
               <div className="bg-orange-600/10 border border-orange-500/20 rounded-[2.5rem] p-8 space-y-4">
                   <h3 className="text-xs font-black uppercase tracking-widest text-orange-400 flex items-center gap-2">
                       <Lock size={14} /> Sovereign Backup
                   </h3>
                   <p className="text-[10px] text-zinc-400 leading-relaxed">
                       Your keys are protected by the Secure Enclave. Ensure your device's 
                       <span className="font-bold text-zinc-300"> iCloud / Google Drive </span> 
                       backup is active. We are non-custodial.
                   </p>
               </div>
               
               <button type="button" onClick={handleLnLogin} className="bg-yellow-500/10 border border-yellow-500/20 rounded-[2.5rem] p-8 space-y-4 text-left hover:bg-yellow-500/20 transition-all group">
                   <h3 className="text-xs font-black uppercase tracking-widest text-yellow-500 flex items-center gap-2">
                       <Zap size={14} /> Test Lightning Login
                   </h3>
                   <p className="text-[10px] text-zinc-400 leading-relaxed group-hover:text-zinc-300">
                       Authenticate with L402/LNURL services using your Enclave keys. Passwordless.
                   </p>
               </button>
           </div>
        </div>
      </div>
    </div>
  );
};

export default IdentityManager;
