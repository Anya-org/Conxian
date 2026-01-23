import React, { useState } from 'react';
import { Browser } from '@capacitor/browser';
import { Search, Globe, ShieldCheck, ExternalLink, RefreshCw, X } from 'lucide-react';

const FEATURED_DAPPS = [
  { name: 'Bitrefill', url: 'https://www.bitrefill.com', icon: 'https://www.bitrefill.com/favicon.ico', category: 'Spencer' },
  { name: 'LN Markets', url: 'https://lnmarkets.com', icon: 'https://lnmarkets.com/favicon.ico', category: 'Finance' },
  { name: 'Magma', url: 'https://magma.amboss.space', icon: 'https://magma.amboss.space/favicon.ico', category: 'Liquidity' },
  { name: 'Mempool.space', url: 'https://mempool.space', icon: 'https://mempool.space/favicon.ico', category: 'Explorer' },
  { name: 'Gamma', url: 'https://gamma.io', icon: 'https://gamma.io/favicon.ico', category: 'NFTs' },
  { name: 'ALEX', url: 'https://app.alexlab.co', icon: 'https://app.alexlab.co/favicon.ico', category: 'DeFi' }
];

const Web3Browser: React.FC = () => {
  const [url, setUrl] = useState('');
  
  const handleOpen = async (targetUrl: string) => {
    let finalUrl = targetUrl;
    if (!finalUrl.startsWith('http')) {
       finalUrl = 'https://' + finalUrl;
    }
    
    // Use Capacitor Browser to open in-app
    try {
      await Browser.open({ url: finalUrl, presentationStyle: 'popover' });
    } catch (e) {
      // Fallback for web
      window.open(finalUrl, '_blank');
    }
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (url) {
        // If it looks like a search term, use DuckDuckGo
        if (!url.includes('.') || url.includes(' ')) {
            handleOpen(`https://duckduckgo.com/?q=${encodeURIComponent(url)}`);
        } else {
            handleOpen(url);
        }
    }
  };

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-8 animate-in fade-in duration-500 pb-24">
      <header className="flex justify-between items-end">
        <div>
          <h2 className="text-3xl font-bold mb-1 tracking-tight">Sovereign Browser</h2>
          <p className="text-zinc-500 text-sm">Access the decentralized web without leaving the Citadel.</p>
        </div>
      </header>

      {/* URL Bar */}
      <form onSubmit={handleSearch} className="relative group z-10">
        <div className="absolute inset-0 bg-orange-500/10 rounded-2xl blur-xl group-hover:bg-orange-500/20 transition-all opacity-0 group-hover:opacity-100" />
        <div className="relative bg-zinc-900/80 border border-zinc-800 rounded-2xl p-2 flex items-center shadow-2xl backdrop-blur-md">
            <div className="p-3 text-zinc-500">
                <Globe size={20} />
            </div>
            <input 
                type="text" 
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="Search or enter URL (e.g. gamma.io)"
                className="bg-transparent border-none outline-none flex-1 text-zinc-200 placeholder:text-zinc-600 font-mono text-sm h-12"
            />
            <button type="submit" className="p-3 bg-zinc-800 hover:bg-orange-600 text-zinc-400 hover:text-white rounded-xl transition-all">
                <Search size={20} />
            </button>
        </div>
      </form>

      {/* Featured Grid */}
      <div className="space-y-4">
        <h3 className="text-xs font-black uppercase tracking-widest text-zinc-600 px-2">Sovereign Verified</h3>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {FEATURED_DAPPS.map((dapp, i) => (
                <button 
                    key={i}
                    onClick={() => handleOpen(dapp.url)}
                    className="flex flex-col items-center justify-center p-6 bg-zinc-900/40 border border-zinc-800 hover:border-orange-500/50 hover:bg-zinc-800/80 rounded-3xl transition-all group gap-4"
                >
                    <div className="w-12 h-12 bg-zinc-950 rounded-2xl flex items-center justify-center border border-zinc-800 group-hover:scale-110 transition-transform overflow-hidden relative">
                         {/* Fallback Icon */}
                         <div className="absolute inset-0 flex items-center justify-center text-zinc-700">
                             <ShieldCheck size={20} />
                         </div>
                         <img src={dapp.icon} alt={dapp.name} className="relative z-10 w-8 h-8 object-contain" onError={(e) => e.currentTarget.style.display = 'none'} />
                    </div>
                    <div className="text-center">
                        <p className="font-bold text-zinc-200 text-sm group-hover:text-orange-500 transition-colors">{dapp.name}</p>
                        <p className="text-[10px] text-zinc-600 font-black uppercase tracking-wider">{dapp.category}</p>
                    </div>
                </button>
            ))}
        </div>
      </div>

      {/* Info Card */}
      <div className="bg-orange-500/5 border border-orange-500/10 rounded-3xl p-6 flex gap-4 items-start">
         <div className="p-2 bg-orange-500/10 rounded-xl text-orange-500">
            <ShieldCheck size={18} />
         </div>
         <div>
            <h4 className="text-xs font-bold text-orange-500 uppercase tracking-widest mb-1">Sandbox Environment</h4>
            <p className="text-[10px] text-zinc-500 leading-relaxed">
                External sites are loaded in an isolated webview. They cannot access your private keys or enclave data directly. Always verify the URL before connecting wallet sessions.
            </p>
         </div>
      </div>
    </div>
  );
};

export default Web3Browser;
