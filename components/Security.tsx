
import React from 'react';
import { ShieldCheck, Cpu, Wallet, ExternalLink, ShieldAlert, Key, HeartPulse, ShoppingCart, Award, ArrowUpRight } from 'lucide-react';

const Security: React.FC = () => {
  const hardwareAffiliates = [
    { name: 'BitBox02', desc: 'Swiss-made, Bitcoin-only hardware with secure chip.', link: 'https://shiftcrypto.ch/bitbox02', color: 'bg-zinc-100 text-zinc-950' },
    { name: 'Coldcard MK4', desc: 'The most security-hardened air-gapped device.', link: 'https://coinkite.com/coldcard', color: 'bg-orange-600 text-white' },
    { name: 'Blockstream Jade', desc: 'Open-source, Liquid-ready, QR-based security.', link: 'https://blockstream.com/jade', color: 'bg-emerald-600 text-white' },
  ];

  return (
    <div className="p-8 max-w-5xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <header className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold mb-1 tracking-tight">Hardened Security</h2>
          <p className="text-zinc-500 text-sm">Protect your root of trust with air-gapped hardware and recovery planning.</p>
        </div>
        <div className="bg-green-500/10 border border-green-500/20 px-4 py-2 rounded-2xl flex items-center gap-2">
          <ShieldCheck size={18} className="text-green-500" />
          <span className="text-xs font-bold text-green-500 uppercase tracking-widest">Enclave Active</span>
        </div>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-3xl p-8 space-y-8">
             <div className="flex items-center gap-4">
                <div className="w-16 h-16 bg-zinc-950 rounded-2xl flex items-center justify-center border border-zinc-800">
                   <Key className="text-orange-500" size={32} />
                </div>
                <div>
                   <h3 className="text-xl font-bold">Local BIP-39 Vault</h3>
                   <p className="text-sm text-zinc-500">Manage your seed phrases. SatoshiLayer never transmits this data.</p>
                </div>
             </div>
             <div className="grid grid-cols-2 gap-4">
                <button type="button" className="p-6 bg-zinc-950 border border-zinc-900 rounded-2xl text-left hover:border-zinc-700 transition-all group">
                   <p className="text-[10px] font-black uppercase text-zinc-600 mb-2 group-hover:text-zinc-400">Master Seed</p>
                   <p className="font-mono text-xs text-zinc-400">View Recovery Phrase</p>
                </button>
                <button type="button" className="p-6 bg-zinc-950 border border-zinc-900 rounded-2xl text-left hover:border-zinc-700 transition-all group">
                   <p className="text-[10px] font-black uppercase text-zinc-600 mb-2 group-hover:text-zinc-400">Entropy Source</p>
                   <p className="font-mono text-xs text-zinc-400">Hardware RNG Status</p>
                </button>
             </div>
          </div>

          <div className="bg-orange-500/5 border border-orange-500/10 rounded-3xl p-8">
             <div className="flex items-center justify-between mb-8">
                <h3 className="font-bold flex items-center gap-2 uppercase tracking-widest text-orange-500 text-xs">
                   <ShoppingCart size={16} />
                   Hardware Shop (Affiliate)
                </h3>
                <span className="text-[10px] font-bold text-zinc-600 uppercase">Trusted Partners</span>
             </div>
             <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {hardwareAffiliates.map((device, i) => (
                   <a 
                    key={i}
                    href={device.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="bg-zinc-900/40 border border-zinc-800 p-6 rounded-2xl flex flex-col justify-between hover:border-orange-500/50 transition-all group"
                   >
                      <div className="space-y-3">
                         <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold ${device.color}`}>
                            {device.name[0]}
                         </div>
                         <h4 className="font-bold text-sm text-zinc-200">{device.name}</h4>
                         <p className="text-[10px] text-zinc-500 leading-relaxed">{device.desc}</p>
                      </div>
                      <div className="mt-4 pt-4 border-t border-zinc-800 flex items-center justify-between">
                         <span className="text-[10px] font-bold text-orange-500 uppercase">Buy Now</span>
                         <ExternalLink size={12} className="text-zinc-700 group-hover:text-orange-500" />
                      </div>
                   </a>
                ))}
             </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-zinc-900/40 border border-zinc-800 rounded-3xl p-8 space-y-6">
             <h4 className="font-bold text-sm text-zinc-200 flex items-center gap-2">
                <HeartPulse size={18} className="text-red-500" />
                Recovery Services
             </h4>
             <p className="text-xs text-zinc-500 leading-relaxed">
                Lost access to your keys? We partner with <strong>Unchained Capital</strong> and <strong>Casa</strong> for professional inheritance and recovery planning.
             </p>
             <button type="button" className="w-full py-3 bg-zinc-800 hover:bg-zinc-700 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2">
                Referral Programs <ArrowUpRight size={14} />
             </button>
          </div>

          <div className="bg-zinc-950 border border-zinc-800 rounded-3xl p-8">
             <div className="flex items-center gap-3 mb-4">
                <ShieldAlert className="text-yellow-500" size={20} />
                <h4 className="font-bold text-sm text-zinc-200">Security Audit</h4>
             </div>
             <p className="text-xs text-zinc-500 leading-relaxed mb-4">
                You haven't performed a backup audit in <strong>92 days</strong>. Your sovereign risk is increasing.
             </p>
             <div className="w-full h-1.5 bg-zinc-900 rounded-full overflow-hidden">
                <div className="w-1/3 h-full bg-yellow-500" />
             </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Security;
